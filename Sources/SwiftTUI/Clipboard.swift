import Foundation

/// Abstraction for clipboard operations.
@MainActor
public protocol ClipboardManaging: Sendable {
    func set(_ text: String)
    func get() -> String?
}

/// OSC52-based clipboard: pushes text to terminal clipboard; stores locally as fallback.
@MainActor
public final class OSC52ClipboardManager: ClipboardManaging {
    private var local: String = ""

    public init() {}

    public func set(_ text: String) {
        local = text
        Application.shared.terminal.write(TerminalControlSequences.osc52Set(text))
        Application.shared.terminal.write(TerminalControlSequences.far2lSendClipboard(text))
    }

    public func get() -> String? {
        return local
    }
}

/// System clipboard manager using platform utilities (pbcopy/pbpaste, wl-clipboard, xclip/xsel).
@MainActor
public final class SystemClipboardManager: ClipboardManaging {
    private struct Backend {
        let setCommand: [String]
        let getCommand: [String]
    }

    private let backend: Backend?
    private var local: String = "" // fallback cache if backend is write-only

    public init() {
        self.backend = SystemClipboardManager.detectBackend()
    }

    public func set(_ text: String) {
        local = text
        guard let backend else { return }
        _ = run(command: backend.setCommand, input: text)
    }

    public func get() -> String? {
        guard let backend else { return local }
        if let output = run(command: backend.getCommand) {
            return output
        }
        return local
    }

    // MARK: - Detection
    private static func detectBackend() -> Backend? {
        #if os(macOS)
        if executableExists("/usr/bin/pbcopy"), executableExists("/usr/bin/pbpaste") {
            return Backend(setCommand: ["/usr/bin/pbcopy"], getCommand: ["/usr/bin/pbpaste"])
        }
        #endif

        // Prefer Wayland wl-clipboard if present
        if executableExists("/usr/bin/wl-copy"), executableExists("/usr/bin/wl-paste") {
            return Backend(setCommand: ["/usr/bin/wl-copy", "-n"], getCommand: ["/usr/bin/wl-paste", "-n"])
        }

        // X11 xclip
        if executableExists("/usr/bin/xclip") {
            return Backend(setCommand: ["/usr/bin/xclip", "-selection", "clipboard"], getCommand: ["/usr/bin/xclip", "-selection", "clipboard", "-o"])
        }

        // xsel fallback
        if executableExists("/usr/bin/xsel") {
            return Backend(setCommand: ["/usr/bin/xsel", "--clipboard", "--input"], getCommand: ["/usr/bin/xsel", "--clipboard", "--output"])
        }

        return nil
    }

    // MARK: - Helpers
    private static func executableExists(_ path: String) -> Bool {
        return FileManager.default.isExecutableFile(atPath: path)
    }

    private func run(command: [String], input: String? = nil) -> String? {
        guard let program = command.first else { return nil }
        let arguments = Array(command.dropFirst())

        let process = Process()
        process.executableURL = URL(fileURLWithPath: program)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        if let input = input {
            let inputPipe = Pipe()
            process.standardInput = inputPipe
            do {
                try process.run()
                if let data = input.data(using: .utf8) {
                    inputPipe.fileHandleForWriting.write(data)
                }
                try inputPipe.fileHandleForWriting.close()
            } catch {
                return nil
            }
        } else {
            do {
                try process.run()
            } catch {
                return nil
            }
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}

/// Aggregates multiple clipboard managers: `set` is sent to all; `get` returns the first non-nil.
@MainActor
public final class MultiClipboardManager: ClipboardManaging {
    private let managers: [ClipboardManaging]

    public init(_ managers: [ClipboardManaging]) {
        self.managers = managers
    }

    public func set(_ text: String) {
        managers.forEach { $0.set(text) }
    }

    public func get() -> String? {
        for mgr in managers {
            if let val = mgr.get(), !val.isEmpty {
                return val
            }
        }
        return nil
    }
}
