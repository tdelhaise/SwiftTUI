import Foundation
import SwiftTUI

// MARK: - MockTerminal

/// A mock implementation of the Terminal protocol for testing purposes.
/// This class allows simulating terminal input and capturing terminal output
/// without interacting with a real terminal.
class MockTerminal: TerminalProtocol {
    // MARK: - Properties

    var capturedOutput: String = ""
    var simulatedInput: [UInt8] = []
    var cursorPosition: Point = .zero
    var isCursorHidden: Bool = false
    let inputFileDescriptor: Int32 = -1
    var windowSize: Size = Size(width: 80, height: 24) {
        didSet {
            screenBuffer.resize(width: windowSize.width, height: windowSize.height)
        }
    }

    private var rawModeEnabled: Bool = false
    private var mouseTrackingEnabled: Bool = false
    private var screenBuffer: ScreenBuffer

    // MARK: - TerminalProtocol Conformance

    func enableRawMode() throws {
        rawModeEnabled = true
    }

    func disableRawMode() throws {
        rawModeEnabled = false
    }

    func enableMouseTracking() {
        mouseTrackingEnabled = true
    }

    func disableMouseTracking() {
        mouseTrackingEnabled = false
    }

    func readCharacter() -> UInt8? {
        guard !simulatedInput.isEmpty else { return nil }
        return simulatedInput.removeFirst()
    }

    func write(_ string: String) {
        capturedOutput += string
    }

    func clearScreen() {
        capturedOutput += ANSI.clearScreen
    }

    func moveCursor(to point: Point) {
        cursorPosition = point
        capturedOutput += ANSI.cursorPosition(row: point.y + 1, col: point.x + 1)
    }

    func hideCursor() {
        isCursorHidden = true
        capturedOutput += ANSI.hideCursor
    }

    func showCursor() {
        isCursorHidden = false
        capturedOutput += ANSI.showCursor
    }

    func getWindowSize() -> Size {
        return windowSize
    }

    func writeToBuffer(x: Int, y: Int, char: Character, foreground: ANSIColor, background: ANSIColor) {
        screenBuffer.setCell(x: x, y: y, cell: Cell(character: char, foregroundColor: foreground, backgroundColor: background))
    }

    func renderBuffer() {
        // No-op for mock
    }

    // MARK: - Mocking Utilities

    /// Feeds a string into the simulated input buffer.
    func feedInput(string: String) {
        simulatedInput.append(contentsOf: string.utf8)
    }

    /// Feeds a KeyEvent into the simulated input buffer.
    func feedInput(keyEvent: KeyEvent) {
        // This is a simplified representation. In a real scenario, you'd
        // convert KeyEvent to its corresponding ANSI escape sequence bytes.
        // For now, we'll just feed the character if available.
        if let scalar = keyEvent.character?.unicodeScalars.first {
            simulatedInput.append(UInt8(scalar.value))
        } else {
            // TODO: Extend with escape-sequence mappings for non-printable keys.
        }
    }

    /// Resets the mock terminal's state.
    func reset() {
        capturedOutput = ""
        simulatedInput = []
        cursorPosition = .zero
        isCursorHidden = false
        rawModeEnabled = false
        mouseTrackingEnabled = false
        windowSize = Size(width: 80, height: 24)
        screenBuffer = ScreenBuffer(width: windowSize.width, height: windowSize.height)
    }

    func snapshot() -> ScreenSnapshot {
        return screenBuffer.snapshot()
    }

    // MARK: - Init

    init() {
        self.screenBuffer = ScreenBuffer(width: windowSize.width, height: windowSize.height)
    }
}
