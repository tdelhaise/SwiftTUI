import Foundation
import CNcurses

#if os(Linux)
import Glibc
#else
import Darwin
#endif

/// A thin wrapper around terminfo/termcap data so we can emit
/// terminal-specific escape sequences instead of relying on
/// hard-coded ANSI values.
public struct TerminalCapabilities: Sendable {
    public let terminalName: String
    public let colors: Int
    public let hasTrueColorFlag: Bool
    public let clearSequence: String?
    public let cursorAddressSequence: String?
    public let hideCursorSequence: String?
    public let showCursorSequence: String?
    public let enterAltScreenSequence: String?
    public let exitAltScreenSequence: String?
    public let setForegroundSequence: String?
    public let setBackgroundSequence: String?
    public let resetColorsSequence: String?

    /// Fallback capabilities when terminfo is unavailable.
    public static let fallback = TerminalCapabilities(
        terminalName: "unknown",
        colors: 8,
        hasTrueColorFlag: false,
        clearSequence: nil,
        cursorAddressSequence: nil,
        hideCursorSequence: nil,
        showCursorSequence: nil,
        enterAltScreenSequence: nil,
        exitAltScreenSequence: nil,
        setForegroundSequence: nil,
        setBackgroundSequence: nil,
        resetColorsSequence: nil
    )

    /// Attempts to load capabilities via terminfo for the current terminal.
    public static func load(fileDescriptor: Int32 = STDOUT_FILENO) -> TerminalCapabilities {
        let envTerm = ProcessInfo.processInfo.environment["TERM"] ?? ""
        return load(term: envTerm.isEmpty ? nil : envTerm, fileDescriptor: fileDescriptor)
    }

    /// Attempts to load capabilities via terminfo for a specific terminal.
    public static func load(term: String?, fileDescriptor: Int32 = STDOUT_FILENO) -> TerminalCapabilities {
        var errorCode: Int32 = 0

        let result: Int32
        if var cString = term?.utf8CString {
            result = cString.withUnsafeMutableBufferPointer { buffer -> Int32 in
                guard let base = buffer.baseAddress else {
                    return setupterm(nil, fileDescriptor, &errorCode)
                }
                return setupterm(base, fileDescriptor, &errorCode)
            }
        } else {
            result = setupterm(nil, fileDescriptor, &errorCode)
        }

        if result == -1 || errorCode < 0 {
            return .fallback
        }

        let terminalName = term ?? (ProcessInfo.processInfo.environment["TERM"] ?? "unknown")
        let colors = Self.getNumericCapability("colors") ?? 8
        let hasTrueColorFlag = Self.getFlagCapability("Tc") ?? false

        let clearSequence = Self.getStringCapability("clear")
        let cursorAddressSequence = Self.getStringCapability("cup")
        let hideCursorSequence = Self.getStringCapability("civis")
        let showCursorSequence = Self.getStringCapability("cnorm")
        let enterAltScreenSequence = Self.getStringCapability("smcup")
        let exitAltScreenSequence = Self.getStringCapability("rmcup")
        let setForegroundSequence = Self.getStringCapability("setaf")
        let setBackgroundSequence = Self.getStringCapability("setab")
        let resetColorsSequence = Self.getStringCapability("op")

        return TerminalCapabilities(
            terminalName: terminalName,
            colors: colors,
            hasTrueColorFlag: hasTrueColorFlag,
            clearSequence: clearSequence,
            cursorAddressSequence: cursorAddressSequence,
            hideCursorSequence: hideCursorSequence,
            showCursorSequence: showCursorSequence,
            enterAltScreenSequence: enterAltScreenSequence,
            exitAltScreenSequence: exitAltScreenSequence,
            setForegroundSequence: setForegroundSequence,
            setBackgroundSequence: setBackgroundSequence,
            resetColorsSequence: resetColorsSequence
        )
    }

    /// Returns true if the terminal likely supports 24-bit color.
    public var supportsTrueColor: Bool {
        if hasTrueColorFlag { return true }
        if colors >= 16777216 { return true }
        let lowerName = terminalName.lowercased()
        return lowerName.contains("truecolor") || lowerName.contains("24bit")
    }

    /// Returns a cursor addressing sequence for the given (zero-based) row and column.
    public func cursorAddress(row: Int, column: Int) -> String? {
        guard let sequence = cursorAddressSequence else { return nil }
        return TerminalCapabilities.expand(capability: sequence, parameters: [Int32(row), Int32(column)])
    }

    /// Builds a foreground color sequence for the given ANSIColor using terminfo, if available.
    public func foreground(color: ANSIColor) -> String? {
        guard let sequence = setForegroundSequence else { return nil }
        guard let index = color.terminfoIndex else { return nil }
        return TerminalCapabilities.expand(capability: sequence, parameters: [Int32(index)])
    }

    /// Builds a background color sequence for the given ANSIColor using terminfo, if available.
    public func background(color: ANSIColor) -> String? {
        guard let sequence = setBackgroundSequence else { return nil }
        guard let index = color.terminfoIndex else { return nil }
        return TerminalCapabilities.expand(capability: sequence, parameters: [Int32(index)])
    }

    // MARK: - Helpers

    static func expand(capability: String, parameters: [Int32]) -> String? {
        var args = parameters
        if args.count < 9 {
            args.append(contentsOf: Array(repeating: 0, count: 9 - args.count))
        }
        return capability.withCString { ptr -> String? in
            guard let expanded = swift_tparm(
                ptr,
                args[0],
                args[1],
                args[2],
                args[3],
                args[4],
                args[5],
                args[6],
                args[7],
                args[8]
            ) else {
                return nil
            }
            return String(cString: expanded)
        }
    }

    private static func getStringCapability(_ name: String) -> String? {
        var capabilityName = Array(name.utf8CString)
        return capabilityName.withUnsafeMutableBufferPointer { buffer -> String? in
            guard let ptr = buffer.baseAddress else { return nil }
            guard let raw = tigetstr(ptr) else { return nil }
            if OpaquePointer(raw) == OpaquePointer(bitPattern: -1) {
                return nil
            }
            return String(cString: raw)
        }
    }

    private static func getNumericCapability(_ name: String) -> Int? {
        var capabilityName = Array(name.utf8CString)
        return capabilityName.withUnsafeMutableBufferPointer { buffer -> Int? in
            guard let ptr = buffer.baseAddress else { return nil }
            let value = tigetnum(ptr)
            return value >= 0 ? Int(value) : nil
        }
    }

    private static func getFlagCapability(_ name: String) -> Bool? {
        var capabilityName = Array(name.utf8CString)
        return capabilityName.withUnsafeMutableBufferPointer { buffer -> Bool? in
            guard let ptr = buffer.baseAddress else { return nil }
            let value = tigetflag(ptr)
            guard value != -1 else { return nil }
            return value == 1
        }
    }
}
