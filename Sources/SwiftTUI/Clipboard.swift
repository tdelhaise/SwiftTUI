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
