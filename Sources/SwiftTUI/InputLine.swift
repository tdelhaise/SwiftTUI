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

    private func finalizeChange(from oldText: String, recordHistory: Bool = true) {
        if recordHistory && oldText != text {
            historyManager.push(entry: HistoryEntry(text: text))
        }
        validate()
        setNeedsDisplay()
    }

    private func insertText(_ newText: String) {
        guard !newText.isEmpty else { return }
        let oldText = text
        let index = text.index(text.startIndex, offsetBy: cursorPosition)
        text.insert(contentsOf: newText, at: index)
        cursorPosition += newText.count
        finalizeChange(from: oldText)
    }

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

        let globalOrigin = makeGlobal(point: .zero)
        let viewRect = Rect(origin: globalOrigin, size: frame.size)
        guard let drawArea = viewRect.intersection(rect) else { return }

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

        for row in 0..<frame.size.height {
            let globalY = globalOrigin.y + row
            guard globalY >= drawArea.origin.y && globalY < drawArea.origin.y + drawArea.size.height else { continue }
            for column in 0..<frame.size.width {
                let globalX = globalOrigin.x + column
                guard globalX >= drawArea.origin.x && globalX < drawArea.origin.x + drawArea.size.width else { continue }
                let char: Character
                if row == 0 && column < visibleText.count {
                    let index = visibleText.index(visibleText.startIndex, offsetBy: column)
                    char = visibleText[index]
                } else {
                    char = " "
                }
                Application.shared.terminal.writeToBuffer(x: globalX, y: globalY, char: char, foreground: fgColor, background: bgColor)
            }
        }

        if state.contains(.sfFocused) {
            let cursorChar: Character
            if cursorPosition < text.count {
                let index = text.index(text.startIndex, offsetBy: cursorPosition)
                cursorChar = text[index]
            } else {
                cursorChar = " "
            }
            let cursorX = globalOrigin.x + cursorPosition
            let cursorY = globalOrigin.y
            if drawArea.contains(Point(x: cursorX, y: cursorY)) {
                Application.shared.terminal.writeToBuffer(x: cursorX, y: cursorY, char: cursorChar, foreground: bgColor, background: fgColor)
            }
        }

        if !isValid, let message = errorMessage {
            let errorY = globalOrigin.y + frame.size.height
            let errorToDisplay = String(message.prefix(frame.size.width))
            for (index, char) in errorToDisplay.enumerated() {
                let globalX = globalOrigin.x + index
                if drawArea.contains(Point(x: globalX, y: errorY)) {
                    Application.shared.terminal.writeToBuffer(x: globalX, y: errorY, char: char, foreground: .brightRed, background: .default)
                }
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
                if let str = keyEvent.character, let char = str.first, let ascii = char.asciiValue, ascii >= 32 && ascii <= 126 {
                    let index = text.index(text.startIndex, offsetBy: cursorPosition)
                    text.insert(contentsOf: str, at: index)
                    cursorPosition += str.count
                    handled = true
                }
                break
            }
        }

        if handled {
            finalizeChange(from: oldTextForHistory, recordHistory: !keyEvent.controlKeyState.contains(.control))
            return true
        }
        return super.handle(keyEvent: keyEvent)
    }

    override open func handle(command: Command) -> Bool {
        switch command {
        case .cmCopy:
            Application.shared.setClipboardText(text)
            return true
        case .cmCut:
            let oldText = text
            Application.shared.setClipboardText(text)
            text = ""
            cursorPosition = 0
            finalizeChange(from: oldText)
            return true
        case .cmPaste:
            if let clipboard = Application.shared.clipboardText() {
                insertText(clipboard)
                return true
            }
        default:
            break
        }
        return super.handle(command: command)
    }

    override open func handlePaste(_ text: String) -> Bool {
        guard state.contains(.sfFocused) else { return super.handlePaste(text) }
        insertText(text)
        return true
    }
}
