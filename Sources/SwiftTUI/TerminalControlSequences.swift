import Foundation

/// Terminal escape sequences derived from TVision's TermIO implementation.
/// These sequences enable richer keyboard/mouse reporting without relying on ncurses.
struct TerminalControlSequences {
    static let enableMouseReporting = "\u{001B}[?1001s\u{001B}[?1000h\u{001B}[?1002h\u{001B}[?1006h"
    static let disableMouseReporting = "\u{001B}[?1006l\u{001B}[?1002l\u{001B}[?1000l\u{001B}[?1001r"

    static let enableModifierReporting = "\u{001B}[?1036s\u{001B}[?1036h\u{001B}[?2004s\u{001B}[?2004h\u{001B}[>4;1m\u{001B}[>5u\u{001B}[?9001h\u{001B}_far2l1\u{001B}\\"
    static let disableModifierReporting = "\u{001B}_far2l0\u{001B}\\\u{001B}[?9001l\u{001B}[<u\u{001B}[>4m\u{001B}[?2004l\u{001B}[?2004r\u{001B}[?1036r"

    static func osc52Set(_ text: String) -> String {
        guard let data = text.data(using: .utf8) else { return "" }
        let base64 = data.base64EncodedString()
        return "\u{001B}]52;;\(base64)\u{0007}"
    }

    static func osc52Request() -> String {
        return "\u{001B}]52;;?\u{0007}"
    }

    static func far2lSendClipboard(_ text: String) -> String {
        guard let data = text.data(using: .utf8) else { return "" }
        let base64 = data.base64EncodedString()
        return "\u{001B}_far2l:\(base64)\u{001B}\\"
    }

    static func kittyClipboardRequest() -> String {
        return "\u{001B}_far2l?\u{001B}\\"
    }
}
