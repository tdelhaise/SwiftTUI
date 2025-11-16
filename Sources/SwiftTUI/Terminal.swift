import Foundation

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

// MARK: - TerminalProtocol (for dependency injection)

/// A protocol that defines the interface for terminal interaction.
/// This allows for easy mocking and testing.
@MainActor public protocol TerminalProtocol: AnyObject {
    var cursorPosition: Point { get set }
    var isCursorHidden: Bool { get set }
    var windowSize: Size { get }

    func enableRawMode() throws
    func disableRawMode() throws
    func enableMouseTracking()
    func disableMouseTracking()
    func readCharacter() -> UInt8?
    func write(_ string: String)
    func clearScreen()
    func moveCursor(to point: Point)
    func hideCursor()
    func showCursor()
    func getWindowSize() -> Size
    func writeToBuffer(x: Int, y: Int, char: Character, foreground: ANSIColor, background: ANSIColor)
    func renderBuffer()
}

/// A utility class for managing terminal settings and raw input/output.
@MainActor
public class Terminal: TerminalProtocol {

    internal static var originalTerminalAttributes: termios?
    
    internal var currentBuffer: ScreenBuffer
    internal var previousBuffer: ScreenBuffer

    public var cursorPosition: Point = .zero
    public var isCursorHidden: Bool = false
    public var windowSize: Size {
        return self.getWindowSize()
    }

    public init() {
        let defaultSize = Size(width: 80, height: 24)
        let sizeTuple = Terminal.getStaticWindowSize()
        let size = sizeTuple.map { Size(width: $0.width, height: $0.height) } ?? defaultSize
        self.currentBuffer = ScreenBuffer(width: size.width, height: size.height)
        self.previousBuffer = ScreenBuffer(width: size.width, height: size.height)
    }

    /// Switches the terminal to raw mode.
    /// In raw mode, input is unbuffered and special characters (like Ctrl+C) are not processed by the terminal driver.
    public func enableRawMode() throws {
        var term = termios()

        // Get current terminal attributes
        if tcgetattr(STDIN_FILENO, &term) != 0 {
            throw TerminalError.failedToGetTerminalAttributes(errno: errno)
        }

        // Save original attributes to restore later
        Terminal.originalTerminalAttributes = term

        // Modify attributes for raw mode
        term.c_lflag &= ~(tcflag_t(ICANON) | tcflag_t(ECHO)) // Disable canonical mode and echo
        term.c_cc.6 = 0 // VMIN = 0 (read returns immediately if no input)
        term.c_cc.5 = 1 // VTIME = 1 (timeout of 0.1 seconds for read)

        // Set new terminal attributes
        if tcsetattr(STDIN_FILENO, TCSANOW, &term) != 0 {
            throw TerminalError.failedToSetTerminalAttributes(errno: errno)
        }

        enableMouseTracking()
    }

    /// Restores the terminal to its original (cooked) mode.
    public func disableRawMode() throws {
        guard var originalTerm = Terminal.originalTerminalAttributes else {
            // If original attributes were not saved, something went wrong or raw mode was never enabled.
            return
        }

        if tcsetattr(STDIN_FILENO, TCSANOW, &originalTerm) != 0 {
            throw TerminalError.failedToRestoreTerminalAttributes(errno: errno)
        }
        Terminal.originalTerminalAttributes = nil

        disableMouseTracking()
    }

    public func enableMouseTracking() {
        self.write("\u{001B}[?1000h") // Enable X10 mouse tracking
        self.write("\u{0001B}[?1002h") // Enable button-event tracking (for drag)
        self.write("\u{001B}[?1006h") // Enable SGR mouse tracking (more detailed, easier to parse)
    }

    public func disableMouseTracking() {
        self.write("\u{001B}[?1000l") // Disable X10 mouse tracking
        self.write("\u{001B}[?1002l") // Disable button-event tracking
        self.write("\u{001B}[?1006l") // Disable SGR mouse tracking
    }

    /// Reads a single character from standard input.
    /// This function is blocking if VMIN > 0 and VTIME = 0, or non-blocking with timeout if VMIN = 0 and VTIME > 0.
    public func readCharacter() -> UInt8? {
        var byte: UInt8 = 0
        #if os(Linux)
        let bytesRead = Glibc.read(STDIN_FILENO, &byte, 1)
        #else
        let bytesRead = Darwin.read(STDIN_FILENO, &byte, 1)
        #endif

        if bytesRead == 1 {
            return byte
        } else if bytesRead == -1 {
            // Handle error, e.g., EAGAIN for non-blocking read with no data
            // For now, just return nil
        }
        return nil
    }

    /// Writes a string to standard output.
    public func write(_ string: String) {
        #if os(Linux)
        _ = string.withCString { ptr in
            Glibc.write(STDOUT_FILENO, ptr, Glibc.strlen(ptr))
        }
        #else
        _ = string.withCString { ptr in
            Darwin.write(STDOUT_FILENO, ptr, Darwin.strlen(ptr))
        }
        #endif
    }

    /// Writes a character to standard output.
    public func write(_ char: Character) {
        if let asciiValue = char.asciiValue {
            var byte = asciiValue
            #if os(Linux)
            _ = Glibc.write(STDOUT_FILENO, &byte, 1)
            #else
            _ = Darwin.write(STDOUT_FILENO, &byte, 1)
            #endif
        }
    }

    /// Writes a character to the internal screen buffer at the specified coordinates with given colors.
    public func writeToBuffer(x: Int, y: Int, char: Character, foreground: ANSIColor = .default, background: ANSIColor = .default) {
        currentBuffer.setCell(x: x, y: y, cell: Cell(character: char, foregroundColor: foreground, backgroundColor: background))
    }

    /// Renders the current screen buffer to the actual terminal, optimizing by only writing changed cells.
    public func renderBuffer() {
        var outputString = ""
        var lastFg = ANSIColor.default
        var lastBg = ANSIColor.default
        var lastX = -1
        var lastY = -1

        for y in 0..<currentBuffer.height {
            for x in 0..<currentBuffer.width {
                let currentCell = currentBuffer.getCell(x: x, y: y)!
                let previousCell = previousBuffer.getCell(x: x, y: y)!

                if currentCell != previousCell {
                    // Move cursor if not adjacent to last written character
                    if !(x == lastX + 1 && y == lastY && currentCell.foregroundColor == lastFg && currentCell.backgroundColor == lastBg) {
                        outputString += "\u{001B}[\(y + 1);\(x + 1)H" // Move to 1-based coordinates
                        // Reset colors if cursor moved
                        lastFg = .default
                        lastBg = .default
                    }

                    // Set foreground color if changed
                    if currentCell.foregroundColor != lastFg {
                        outputString += "\u{001B}[\(currentCell.foregroundColor.rawValue)m"
                        lastFg = currentCell.foregroundColor
                    }
                    // Set background color if changed
                    if currentCell.backgroundColor != lastBg {
                        outputString += "\u{001B}[\(currentCell.backgroundColor.rawValue)m"
                        lastBg = currentCell.backgroundColor
                    }

                    outputString += String(currentCell.character)
                    lastX = x
                    lastY = y
                }
            }
        }
        // Reset colors and move cursor to a safe place after rendering
        outputString += "\u{001B}[0m" // Reset attributes
        outputString += "\u{001B}[\(currentBuffer.height + 1);1H" // Move cursor below content

        self.write(outputString)

        // After rendering, the current buffer becomes the previous buffer for the next frame
        previousBuffer = currentBuffer
        currentBuffer = ScreenBuffer(width: currentBuffer.width, height: currentBuffer.height) // Reset current buffer
    }

    /// Clears the terminal screen by filling the current buffer with empty cells.
    public func clearScreen() {
        self.currentBuffer.fill(with: Cell())
    }

    /// Moves the cursor to a specific position (row, column).
    /// Rows and columns are 1-based.
    public func moveCursor(to point: Point) {
        cursorPosition = point
        self.write("\u{001B}[\(point.y + 1);\(point.x + 1)H") // ANSI escape code to move cursor (1-based)
    }

    /// Hides the cursor.
    public func hideCursor() {
        isCursorHidden = true
        self.write("\u{001B}[?25l") // ANSI escape code to hide cursor
    }

    /// Shows the cursor.
    public func showCursor() {
        isCursorHidden = false
        self.write("\u{001B}[?25h") // ANSI escape code to show cursor
    }

    /// Retrieves the current terminal window size.
    /// Returns a tuple (width, height) or nil if the size cannot be determined.
    public func getWindowSize() -> Size {
        var size = winsize()
        let fd = STDOUT_FILENO // Use stdout for ioctl

        #if os(Linux)
        if Glibc.ioctl(fd, UInt(TIOCGWINSZ), &size) == 0 {
            return Size(width: Int(size.ws_col), height: Int(size.ws_row))
        }
        #else
        if Darwin.ioctl(fd, UInt(TIOCGWINSZ), &size) == 0 {
            return Size(width: Int(size.ws_col), height: Int(size.ws_row))
        }
        #endif
        return Size(width: 80, height: 24) // Default size if cannot be determined
    }

    public static func getStaticWindowSize() -> (width: Int, height: Int)? {
        var size = winsize()
        let fd = STDOUT_FILENO // Use stdout for ioctl

        #if os(Linux)
        if Glibc.ioctl(fd, UInt(TIOCGWINSZ), &size) == 0 {
            return (width: Int(size.ws_col), height: Int(size.ws_row))
        }
        #else
        if Darwin.ioctl(fd, UInt(TIOCGWINSZ), &size) == 0 {
            return (width: Int(size.ws_col), height: Int(size.ws_row))
        }
        #endif
        return nil
    }

    public enum TerminalError: Error {
        case failedToGetTerminalAttributes(errno: Int32)
        case failedToSetTerminalAttributes(errno: Int32)
        case failedToRestoreTerminalAttributes(errno: Int32)
    }
}