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
    var inputFileDescriptor: Int32 { get }

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
    private let ownsInputFileDescriptor: Bool
    
    internal var currentBuffer: ScreenBuffer
    internal var previousBuffer: ScreenBuffer
    public let inputFileDescriptor: Int32

    public var cursorPosition: Point = .zero
    public var isCursorHidden: Bool = false
    public var windowSize: Size {
        return self.getWindowSize()
    }

    public let capabilities: TerminalCapabilities
    public private(set) var terminalType: String?
    public private(set) var hasTrueColor: Bool = false

    public init() {
        let inputFDResult = Terminal.openInputFileDescriptor()
        self.inputFileDescriptor = inputFDResult.fd
        self.ownsInputFileDescriptor = inputFDResult.ownsDescriptor

        let defaultSize = Size(width: 80, height: 24)
        let sizeTuple = Terminal.getStaticWindowSize()
        let size = sizeTuple.map { Size(width: $0.width, height: $0.height) } ?? defaultSize
        self.currentBuffer = ScreenBuffer(width: size.width, height: size.height)
        self.previousBuffer = ScreenBuffer(width: size.width, height: size.height)
        self.capabilities = TerminalCapabilities.load()

        // Detect terminal type from TERM environment variable
        if let termTypeC = getenv("TERM") {
            self.terminalType = String(cString: termTypeC)
            // Simple heuristic for true color support
            if let term = self.terminalType?.lowercased() {
                self.hasTrueColor = capabilities.supportsTrueColor || term.contains("256color") || term.contains("xterm-kitty") || term.contains("gnome-terminal")
            }
        } else {
            self.hasTrueColor = capabilities.supportsTrueColor
        }
    }

    deinit {
        if ownsInputFileDescriptor && inputFileDescriptor >= 0 {
            #if os(Linux)
            Glibc.close(inputFileDescriptor)
            #else
            Darwin.close(inputFileDescriptor)
            #endif
        }
    }

    private static func openInputFileDescriptor() -> (fd: Int32, ownsDescriptor: Bool) {
        #if os(Linux)
        let fd = Glibc.open("/dev/tty", O_RDONLY | O_NONBLOCK)
        #else
        let fd = Darwin.open("/dev/tty", O_RDONLY | O_NONBLOCK)
        #endif
        if fd >= 0 {
            return (fd, true)
        }
        return (STDIN_FILENO, false)
    }

    /// Switches the terminal to raw mode.
    /// In raw mode, input is unbuffered and special characters (like Ctrl+C) are not processed by the terminal driver.
    public func enableRawMode() throws {
        var term = termios()

        // Get current terminal attributes
        if tcgetattr(inputFileDescriptor, &term) != 0 {
            throw TerminalError.failedToGetTerminalAttributes(errno: errno)
        }

        // Save original attributes to restore later
        Terminal.originalTerminalAttributes = term

        // Modify attributes for raw mode
        term.c_lflag &= ~(tcflag_t(ICANON) | tcflag_t(ECHO)) // Disable canonical mode and echo
        term.c_cc.6 = 0 // VMIN = 0 (read returns immediately if no input)
        term.c_cc.5 = 1 // VTIME = 1 (timeout of 0.1 seconds for read)

        // Set new terminal attributes
        if tcsetattr(inputFileDescriptor, TCSANOW, &term) != 0 {
            throw TerminalError.failedToSetTerminalAttributes(errno: errno)
        }

        enableMouseTracking()
        enableEnhancedInputReporting()
    }

    /// Restores the terminal to its original (cooked) mode.
    public func disableRawMode() throws {
        guard var originalTerm = Terminal.originalTerminalAttributes else {
            // If original attributes were not saved, something went wrong or raw mode was never enabled.
            return
        }

        if tcsetattr(inputFileDescriptor, TCSANOW, &originalTerm) != 0 {
            throw TerminalError.failedToRestoreTerminalAttributes(errno: errno)
        }
        Terminal.originalTerminalAttributes = nil

        disableMouseTracking()
        disableEnhancedInputReporting()
    }

    public func enableMouseTracking() {
        self.write(TerminalControlSequences.enableMouseReporting)
    }

    public func disableMouseTracking() {
        self.write(TerminalControlSequences.disableMouseReporting)
    }

    private func enableEnhancedInputReporting() {
        self.write(TerminalControlSequences.enableModifierReporting)
    }

    private func disableEnhancedInputReporting() {
        self.write(TerminalControlSequences.disableModifierReporting)
    }

    /// Reads a single character from standard input.
    /// This function is blocking if VMIN > 0 and VTIME = 0, or non-blocking with timeout if VMIN = 0 and VTIME > 0.
    public func readCharacter() -> UInt8? {
        var byte: UInt8 = 0
        #if os(Linux)
        let bytesRead = Glibc.read(inputFileDescriptor, &byte, 1)
        #else
        let bytesRead = Darwin.read(inputFileDescriptor, &byte, 1)
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

    public func snapshot() -> ScreenSnapshot {
        return currentBuffer.snapshot()
    }

    /// Renders the current screen buffer to the actual terminal, optimizing by only writing changed cells.
    public func renderBuffer() {
        var outputString = ""
        var currentFg = ANSIColor.default
        var currentBg = ANSIColor.default
        var currentX = -1
        var currentY = -1

        // Ensure cursor is visible before rendering if it was hidden
        if isCursorHidden {
            outputString += ANSI.showCursor
        }

        var nextPreviousBuffer = previousBuffer
        let cursorX = cursorPosition.x
        let cursorY = cursorPosition.y
        let shouldInvertCursor = !isCursorHidden

        for (row, range) in currentBuffer.dirtyRanges() {
            for x in range {
                guard let currentCell = currentBuffer.getCell(x: x, y: row),
                      let previousCell = previousBuffer.getCell(x: x, y: row) else {
                    continue
                }

                var outputCell = currentCell
                if shouldInvertCursor && x == cursorX && row == cursorY {
                    outputCell = outputCell.withInvertedColors()
                }

                if outputCell != previousCell {
                    if x != currentX + 1 || row != currentY || outputCell.foregroundColor != currentFg || outputCell.backgroundColor != currentBg {
                        outputString += ANSI.cursorPosition(row: row + 1, col: x + 1)
                        if outputCell.foregroundColor != currentFg {
                            outputString += ANSI.foregroundColor(outputCell.foregroundColor)
                            currentFg = outputCell.foregroundColor
                        }
                        if outputCell.backgroundColor != currentBg {
                            outputString += ANSI.backgroundColor(outputCell.backgroundColor)
                            currentBg = outputCell.backgroundColor
                        }
                    }
                    outputString += String(outputCell.character)
                    currentX = x
                    currentY = row
                }

                nextPreviousBuffer.setCell(x: x, y: row, cell: outputCell)
            }
        }
        currentBuffer.clearDirtyRanges()
        // Reset colors and move cursor to its last known position
        outputString += ANSI.resetAttributes
        outputString += ANSI.cursorPosition(row: cursorPosition.y + 1, col: cursorPosition.x + 1)

        self.write(outputString)

        // After rendering, the current buffer becomes the previous buffer for the next frame
        previousBuffer = nextPreviousBuffer
        currentBuffer = ScreenBuffer(width: currentBuffer.width, height: currentBuffer.height) // Reset current buffer
    }

    /// Clears the terminal screen by filling the current buffer with empty cells.
    public func clearScreen() {
        self.currentBuffer.fill(with: Cell())
        if let clearSequence = capabilities.clearSequence {
            self.write(clearSequence)
        } else {
            self.write(ANSI.clearScreen)
        }
    }

    public func resizeBuffers(to size: Size) {
        currentBuffer.resize(width: size.width, height: size.height)
        previousBuffer.resize(width: size.width, height: size.height)
        if cursorPosition.x >= size.width || cursorPosition.y >= size.height {
            cursorPosition = Point(x: min(cursorPosition.x, size.width - 1), y: min(cursorPosition.y, size.height - 1))
        }
    }

    /// Moves the cursor to a specific position (row, column).
    /// Rows and columns are 1-based.
    public func moveCursor(to point: Point) {
        cursorPosition = point
        if let sequence = capabilities.cursorAddress(row: point.y, column: point.x) {
            self.write(sequence)
        } else {
            self.write(ANSI.cursorPosition(row: point.y + 1, col: point.x + 1))
        }
    }

    /// Hides the cursor.
    public func hideCursor() {
        isCursorHidden = true
        if let hideCursorSequence = capabilities.hideCursorSequence {
            self.write(hideCursorSequence)
        } else {
            self.write(ANSI.hideCursor)
        }
    }

    /// Shows the cursor.
    public func showCursor() {
        isCursorHidden = false
        if let showCursorSequence = capabilities.showCursorSequence {
            self.write(showCursorSequence)
        } else {
            self.write(ANSI.showCursor)
        }
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
