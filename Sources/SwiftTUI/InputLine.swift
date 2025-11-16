import Foundation

@MainActor
open class InputLine: BaseView {
    public var text: String {
        didSet {
            // Ensure cursor position is valid after text changes
            cursorPosition = min(cursorPosition, text.count)
            validate() // Validate when text changes
            setNeedsDisplay() // Request redraw when text changes
        }
    }
    public var cursorPosition: Int = 0
    public var validator: Validator?
    public private(set) var isValid: Bool = true {
        didSet {
            if isValid != oldValue {
                setNeedsDisplay()
            }
        }
    }
    public private(set) var errorMessage: String? {
        didSet {
            if errorMessage != oldValue {
                setNeedsDisplay()
            }
        }
    }

    private let historyManager: HistoryManager

    public init(frame: Rect, text: String = "", validator: Validator? = nil, historyManager: HistoryManager = HistoryManager()) {
        self.text = text
        self.validator = validator
        self.historyManager = historyManager
        super.init(frame: frame)
        self.options.insert(.ofSelectable) // InputLine should be selectable to receive keyboard events
        validate() // Initial validation
        self.historyManager.push(entry: HistoryEntry(text: text)) // Push initial state
    }

    private func validate() {
        if let validator = validator {
            let result = validator(text)
            switch result {
            case .valid:
                isValid = true
                errorMessage = nil
            case .invalid(let message):
                isValid = false
                errorMessage = message
            }
        } else {
            isValid = true
            errorMessage = nil
        }
    }

    override open func draw(in rect: Rect) {
        super.draw(in: rect)

        let displayX = frame.origin.x
        let displayY = frame.origin.y

        var fgColor: ANSIColor
        var bgColor: ANSIColor

        if state.contains(.sfFocused) {
            let colors = Application.currentColorTheme.currentPalette[.inputFocused]
            fgColor = colors.foreground
            bgColor = colors.background
        } else {
            let colors = Application.currentColorTheme.currentPalette[.inputNormal]
            fgColor = colors.foreground
            bgColor = colors.background
        }

        // Override colors if invalid
        if !isValid {
            fgColor = .brightRed // Example error color
            bgColor = .default
        }

        let visibleText = String(text.prefix(frame.size.width))

        for (index, char) in visibleText.enumerated() {
            Application.shared.terminal.writeToBuffer(x: displayX + index, y: displayY, char: char, foreground: fgColor, background: bgColor)
        }

        // Fill remaining space with background color
        for charIndex in visibleText.count..<frame.size.width {
            Application.shared.terminal.writeToBuffer(x: displayX + charIndex, y: displayY, char: " ", foreground: fgColor, background: bgColor)
        }

        // Draw cursor if focused
        if state.contains(.sfFocused) {
            let cursorChar: Character
            if cursorPosition < text.count {
                let index = text.index(text.startIndex, offsetBy: cursorPosition)
                cursorChar = text[index]
            } else {
                cursorChar = " " // Draw a space if cursor is at the end of the text
            }
            Application.shared.terminal.writeToBuffer(x: displayX + cursorPosition, y: displayY, char: cursorChar, foreground: bgColor, background: fgColor) // Invert colors for cursor
        }

        // Display error message below the input line if invalid
        if !isValid, let message = errorMessage {
            let errorX = frame.origin.x
            let errorY = frame.origin.y + frame.size.height
            let errorToDisplay = String(message.prefix(frame.size.width))
            for (index, char) in errorToDisplay.enumerated() {
                Application.shared.terminal.writeToBuffer(x: errorX + index, y: errorY, char: char, foreground: .brightRed, background: .default)
            }
            // Clear rest of the line
            for charIndex in errorToDisplay.count..<frame.size.width {
                Application.shared.terminal.writeToBuffer(x: errorX + charIndex, y: errorY, char: " ", foreground: .brightRed, background: .default)
            }
        }
    }

    override open func handle(keyEvent: KeyEvent) -> Bool {
        guard state.contains(.sfFocused) else { return false }

        var handled = false
        let oldTextForHistory = text // Capture text before any modifications

        // Handle Undo (Ctrl+Z) and Redo (Ctrl+Y)
        if keyEvent.controlKeyState.contains(.control) {
            if keyEvent.character == "z" {
                if let previousState = historyManager.undo() {
                    text = previousState.text
                    cursorPosition = text.count // Move cursor to end of restored text
                    handled = true
                }
            } else if keyEvent.character == "y" {
                if let nextState = historyManager.redo() {
                    text = nextState.text
                    cursorPosition = text.count // Move cursor to end of restored text
                    handled = true
                }
            }
        }

        if !handled {
            switch keyEvent.keyCode {
            case KeyEvent.KeyCode.leftArrow:
                if cursorPosition > 0 {
                    cursorPosition -= 1
                    handled = true
                }
            case KeyEvent.KeyCode.rightArrow:
                if cursorPosition < text.count {
                    cursorPosition += 1
                    handled = true
                }
            case KeyEvent.KeyCode.backspace:
                if cursorPosition > 0 {
                    text.remove(at: text.index(text.startIndex, offsetBy: cursorPosition - 1))
                    cursorPosition -= 1
                    handled = true
                }
            case KeyEvent.KeyCode.delete:
                if cursorPosition < text.count {
                    text.remove(at: text.index(text.startIndex, offsetBy: cursorPosition))
                    handled = true
                }
            case KeyEvent.KeyCode.home:
                cursorPosition = 0
                handled = true
            case KeyEvent.KeyCode.end:
                cursorPosition = text.count
                handled = true
            case KeyEvent.KeyCode.enter: // Enter key
                // In a real application, this might trigger an action or submit the input
                print("  InputLine: Enter pressed. Current text: \(text)")
                // If validation is critical on submit, you might check isValid here
                handled = true
            default:
                if let char = keyEvent.character, char.isPrintableASCII {
                    text.insert(char, at: text.index(text.startIndex, offsetBy: cursorPosition))
                    cursorPosition += 1
                    handled = true
                }
            }
        }

        if handled {
            // Only push to history if text actually changed due to user input
            // This check is important to avoid pushing undo/redo actions themselves
            if oldTextForHistory != text && !keyEvent.controlKeyState.contains(.control) {
                historyManager.push(entry: HistoryEntry(text: text))
            }
            validate() // Re-validate after text modification
            setNeedsDisplay() // Request redraw to update cursor/text/validation
            return true
        }
        return super.handle(keyEvent: keyEvent)
    }
}

// Extension to Character to add isPrintableASCII property
extension Character {
    var isPrintableASCII: Bool {
        let asciiValue = self.asciiValue ?? 0
        return asciiValue >= 32 && asciiValue <= 126
    }
}