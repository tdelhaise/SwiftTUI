import Foundation

/// A utility struct for generating ANSI escape codes for terminal control.
public struct ANSI {
    // MARK: - Cursor Control

    /// Moves the cursor to the specified row and column (1-based).
    public static func cursorPosition(row: Int, col: Int) -> String {
        return "\u{001B}[\(row);\(col)H"
    }

    /// Hides the cursor.
    public static let hideCursor = "\u{001B}[?25l"

    /// Shows the cursor.
    public static let showCursor = "\u{001B}[?25h"

    /// Enters the terminal's alternate screen buffer.
    public static let enterAlternateScreen = "\u{001B}[?1049h"

    /// Exits the terminal's alternate screen buffer.
    public static let exitAlternateScreen = "\u{001B}[?1049l"

    // MARK: - Screen Control

    /// Clears the entire screen.
    public static let clearScreen = "\u{001B}[2J"

    /// Clears from cursor to end of screen.
    public static let clearScreenFromCursor = "\u{001B}[0J"

    /// Clears from cursor to beginning of screen.
    public static let clearScreenToCursor = "\u{001B}[1J"

    /// Clears the current line.
    public static let clearLine = "\u{001B}[2K"

    /// Clears from cursor to end of line.
    public static let clearLineFromCursor = "\u{001B}[0K"

    /// Clears from cursor to beginning of line.
    public static let clearLineToCursor = "\u{001B}[1K"

    // MARK: - SGR (Select Graphic Rendition) - Colors and Styles

    /// Resets all SGR attributes to their default.
    public static let resetAttributes = "\u{001B}[0m"

    /// Sets the foreground color.
    public static func foregroundColor(_ color: ANSIColor) -> String {
        return "\u{001B}[\(color.rawValue)m"
    }

    /// Sets the background color.
    public static func backgroundColor(_ color: ANSIColor) -> String {
        return "\u{001B}[\(color.rawValue + 10)m" // Background colors are +10 from foreground
    }

    // MARK: - Mouse Tracking (SGR mode)

    /// Enables SGR mouse tracking.
    public static let enableSGRMouse = "\u{001B}[?1000h\u{001B}[?1002h\u{001B}[?1006h"

    /// Disables SGR mouse tracking.
    public static let disableSGRMouse = "\u{001B}[?1000l\u{001B}[?1002l\u{001B}[?1006l"
}

/// Represents standard ANSI colors.
public enum ANSIColor: UInt8, CaseIterable, Sendable {
    case black = 30
    case red = 31
    case green = 32
    case yellow = 33
    case blue = 34
    case magenta = 35
    case cyan = 36
    case white = 37
    case `default` = 39

    case brightBlack = 90
    case brightRed = 91
    case brightGreen = 92
    case brightYellow = 93
    case brightBlue = 94
    case brightMagenta = 95
    case brightCyan = 96
    case brightWhite = 97
}

extension ANSIColor {
    /// Best-effort mapping from ANSI SGR to terminfo color index.
    /// Returns nil for `.default`.
    var terminfoIndex: Int? {
        switch self {
        case .default:
            return nil
        case .black: return 0
        case .red: return 1
        case .green: return 2
        case .yellow: return 3
        case .blue: return 4
        case .magenta: return 5
        case .cyan: return 6
        case .white: return 7
        case .brightBlack: return 8
        case .brightRed: return 9
        case .brightGreen: return 10
        case .brightYellow: return 11
        case .brightBlue: return 12
        case .brightMagenta: return 13
        case .brightCyan: return 14
        case .brightWhite: return 15
        }
    }
}
