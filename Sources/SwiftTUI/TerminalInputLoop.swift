import Foundation

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

/// Event pump that mirrors TVision's TermIO behaviour:
/// - enables richer keyboard/mouse streams in Terminal.enableRawMode()
/// - reads bytes from the controlling TTY via select()
/// - feeds them through TerminalInputParser to emit KeyEvent/MouseEvent with modifiers intact.
final class TerminalInputLoop: @unchecked Sendable {
    private let parser = TerminalInputParser()
    private weak var application: Application?
    private let fileDescriptor: Int32
    private let wakeReadFD: Int32
    private let wakeWriteFD: Int32
    private var task: Task<Void, Never>?
    private let bufferSize = 1024
    private var timers: [TimerToken: TimerEntry] = [:]
    private let timerLock = NSLock()

    private struct TimerEntry {
        var deadline: UInt64 // nanoseconds, monotonic
        let interval: UInt64? // nanoseconds, for repeating timers
        let token: TimerToken
    }

    init?(application: Application, fileDescriptor: Int32) {
        guard fileDescriptor >= 0 else { return nil }
        self.application = application
        self.fileDescriptor = fileDescriptor

        let pipeFds = TerminalInputLoop.makeWakePipe()
        guard let pipeFds else { return nil }
        self.wakeReadFD = pipeFds.read
        self.wakeWriteFD = pipeFds.write
    }

    deinit {
        #if os(Linux)
        Glibc.close(wakeReadFD)
        Glibc.close(wakeWriteFD)
        #else
        Darwin.close(wakeReadFD)
        Darwin.close(wakeWriteFD)
        #endif
    }

    func start() {
        guard task == nil else { return }
        task = Task(priority: .userInitiated) { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.readLoop()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func readLoop() {
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while !Task.isCancelled {
            var readSet = fd_set()
            fdZero(&readSet)
            fdSet(self.fileDescriptor, set: &readSet)
            fdSet(self.wakeReadFD, set: &readSet)

            var timeout = computeSelectTimeout()
            let maxFD = max(self.fileDescriptor, self.wakeReadFD)
            let ready = select(maxFD + 1, &readSet, nil, nil, &timeout)

            if ready > 0 && fdIsSet(self.fileDescriptor, set: &readSet) {
                pumpAvailableBytes(into: &buffer)
            } else if ready == -1 {
                if errno == EINTR {
                    continue
                }
                break
            }

            if ready > 0 && fdIsSet(self.wakeReadFD, set: &readSet) {
                drainWakePipe()
            }

            fireDueTimers()
        }
    }

    private func pumpAvailableBytes(into buffer: inout [UInt8]) {
        while !Task.isCancelled {
            let bytesRead: Int
            #if os(Linux)
            bytesRead = Glibc.read(self.fileDescriptor, &buffer, buffer.count)
            #else
            bytesRead = Darwin.read(self.fileDescriptor, &buffer, buffer.count)
            #endif

            if bytesRead > 0 {
                process(bytes: buffer.prefix(bytesRead))
                continue
            }

            if bytesRead == 0 {
                break
            }

            if errno == EAGAIN || errno == EWOULDBLOCK {
                break
            } else {
                break
            }
        }
    }

    private func process(bytes: ArraySlice<UInt8>) {
        for byte in bytes {
            let events = parser.feed(byte: byte)
            dispatch(events: events)
        }
    }

    private func dispatch(events: [Event]) {
        guard !events.isEmpty else { return }
        for event in events {
            Task { [weak application] in
                await application?.post(event: event)
            }
        }
    }

    // MARK: - Timer scheduling

    func scheduleTimer(interval: TimeInterval, repeating: Bool) -> TimerToken? {
        guard interval > 0 else { return nil }
        let token = TimerToken()
        let now = DispatchTime.now().uptimeNanoseconds
        let intervalNanos = UInt64(interval * 1_000_000_000)
        let entry = TimerEntry(deadline: now + intervalNanos, interval: repeating ? intervalNanos : nil, token: token)
        timerLock.lock()
        timers[token] = entry
        timerLock.unlock()
        notifyWake()
        return token
    }

    func cancelTimer(_ token: TimerToken) {
        timerLock.lock()
        timers.removeValue(forKey: token)
        timerLock.unlock()
        notifyWake()
    }

    private func computeSelectTimeout() -> timeval {
        let defaultUsec: UInt64 = 200_000 // 200 ms
        let now = DispatchTime.now().uptimeNanoseconds
        let nextDeadline = timerLock.withLocking { timers.values.map(\.deadline).min() }

        var timeoutUsec = defaultUsec
        if let next = nextDeadline {
            if next <= now {
                timeoutUsec = 0
            } else {
                let delta = next - now
                timeoutUsec = min(delta / 1_000, defaultUsec)
            }
        }

        return timeval(tv_sec: time_t(timeoutUsec / 1_000_000), tv_usec: suseconds_t(timeoutUsec % 1_000_000))
    }

    private func fireDueTimers() {
        let now = DispatchTime.now().uptimeNanoseconds
        var fired: [TimerEntry] = []

        timerLock.lock()
        for (token, entry) in timers {
            if entry.deadline <= now {
                fired.append(entry)
                if let interval = entry.interval {
                    var updated = entry
                    updated.deadline = now + interval
                    timers[token] = updated
                } else {
                    timers.removeValue(forKey: token)
                }
            }
        }
        timerLock.unlock()

        guard !fired.isEmpty else { return }
        let events = fired.map { Event.timer($0.token) }
        dispatch(events: events)
    }

    private func fdZero(_ set: inout fd_set) {
        set = fd_set()
    }

    private func fdSet(_ fd: Int32, set: inout fd_set) {
        let intSize = MemoryLayout<Int>.size * 8
        let idx = Int(fd) / intSize
        let bit = Int(fd) % intSize
        withUnsafeMutablePointer(to: &set) {
            $0.withMemoryRebound(to: Int.self, capacity: MemoryLayout<fd_set>.size / MemoryLayout<Int>.size) { ptr in
                ptr[idx] |= 1 << bit
            }
        }
    }

    private func fdIsSet(_ fd: Int32, set: inout fd_set) -> Bool {
        let intSize = MemoryLayout<Int>.size * 8
        let idx = Int(fd) / intSize
        let bit = Int(fd) % intSize
        return withUnsafePointer(to: &set) {
            $0.withMemoryRebound(to: Int.self, capacity: MemoryLayout<fd_set>.size / MemoryLayout<Int>.size) { ptr in
                return (ptr[idx] & (1 << bit)) != 0
            }
        }
    }
}

private extension NSLock {
    func withLocking<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}

// MARK: - Wake pipe helpers
private extension TerminalInputLoop {
    static func makeWakePipe() -> (read: Int32, write: Int32)? {
        var fds: [Int32] = [0, 0]
        #if os(Linux)
        if Glibc.pipe(&fds) != 0 { return nil }
        setNonBlocking(fds[0])
        setNonBlocking(fds[1])
        #else
        if Darwin.pipe(&fds) != 0 { return nil }
        setNonBlocking(fds[0])
        setNonBlocking(fds[1])
        #endif
        return (read: fds[0], write: fds[1])
    }

    static func setNonBlocking(_ fd: Int32) {
        #if os(Linux)
        let flags = Glibc.fcntl(fd, F_GETFL)
        _ = Glibc.fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        #else
        let flags = Darwin.fcntl(fd, F_GETFL)
        _ = Darwin.fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        #endif
    }

    func notifyWake() {
        var byte: UInt8 = 1
        #if os(Linux)
        _ = Glibc.write(wakeWriteFD, &byte, 1)
        #else
        _ = Darwin.write(wakeWriteFD, &byte, 1)
        #endif
    }

    func drainWakePipe() {
        var buf = [UInt8](repeating: 0, count: 64)
        while true {
            let readBytes: Int
            #if os(Linux)
            readBytes = Glibc.read(wakeReadFD, &buf, buf.count)
            #else
            readBytes = Darwin.read(wakeReadFD, &buf, buf.count)
            #endif
            if readBytes <= 0 { break }
            if readBytes < buf.count { break }
        }
    }
}
