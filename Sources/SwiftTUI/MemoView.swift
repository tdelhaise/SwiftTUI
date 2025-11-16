import Foundation

@MainActor
open class MemoView: BaseView {
    public var text: String {
        didSet {
            // Recalculate lines and adjust cursor/scroll if text changes
            lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            adjustCursorAndScroll()
            validate() // Validate when text changes
            setNeedsDisplay() // Request redraw when text changes
        }
    }
    public var lines: [String] = [] // Changed to public var
    public var cursorPosition: Point = .zero { // x=column, y=line
        didSet {
            adjustCursorAndScroll()
            if cursorPosition != oldValue {
                setNeedsDisplay()
            }
        }
    }
    public var scrollOffset: Point = .zero { // x=horizontal scroll, y=vertical scroll
        didSet {
            if scrollOffset != oldValue {
                setNeedsDisplay()
            }
        }
    }

    public var verticalScrollBar: ScrollBar?
    public var horizontalScrollBar: ScrollBar?

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

    internal let historyManager: HistoryManager // Changed to internal

    public init(frame: Rect, text: String = "", validator: Validator? = nil, historyManager: HistoryManager = HistoryManager()) {
        self.text = text
        self.validator = validator
        self.historyManager = historyManager
        super.init(frame: frame)
        self.options.insert(.ofSelectable)
        self.lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        adjustCursorAndScroll()
        validate() // Initial validation
        self.historyManager.push(entry: HistoryEntry(text: text)) // Push initial state
    }

    internal func validate() { // Changed to internal
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

    public func setupScrollBars(verticalFrame: Rect, horizontalFrame: Rect) {
        verticalScrollBar = ScrollBar(frame: verticalFrame, orientation: .vertical)
        verticalScrollBar?.onScroll = { [weak self] newPosition in
            self?.scrollOffset.y = newPosition
        }
        if let vsb = verticalScrollBar {
            add(subview: vsb)
        }

        horizontalScrollBar = ScrollBar(frame: horizontalFrame, orientation: .horizontal)
        horizontalScrollBar?.onScroll = { [weak self] newPosition in
            self?.scrollOffset.x = newPosition
        }
        if let hsb = horizontalScrollBar {
            add(subview: hsb)
        }
        updateScrollBars()
    }

    private func adjustCursorAndScroll() {
        // Ensure cursor is within valid bounds
        cursorPosition.y = max(0, min(lines.count - 1, cursorPosition.y))
        let currentLine = lines.isEmpty ? "" : lines[cursorPosition.y]
        cursorPosition.x = max(0, min(currentLine.count, cursorPosition.x))

        // Adjust scroll offset to keep cursor in view
        if cursorPosition.y < scrollOffset.y {
            scrollOffset.y = cursorPosition.y
        } else if cursorPosition.y >= scrollOffset.y + frame.size.height {
            scrollOffset.y = cursorPosition.y - frame.size.height + 1
        }

        if cursorPosition.x < scrollOffset.x {
            scrollOffset.x = cursorPosition.x
        } else if cursorPosition.x >= scrollOffset.x + frame.size.width {
            scrollOffset.x = cursorPosition.x - frame.size.width + 1
        }
        updateScrollBars()
    }

    private func updateScrollBars() {
        verticalScrollBar?.range = 0...(max(0, lines.count - 1))
        verticalScrollBar?.pageSize = frame.size.height
        verticalScrollBar?.position = scrollOffset.y

        let maxLineWidth = lines.map { $0.count }.max() ?? 0
        horizontalScrollBar?.range = 0...(max(0, maxLineWidth - 1))
        horizontalScrollBar?.pageSize = frame.size.width
        horizontalScrollBar?.position = scrollOffset.x
    }

    override open func draw(in rect: Rect) {
        super.draw(in: rect)

        let visibleHeight = frame.size.height
        let visibleWidth = frame.size.width
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

        for i in 0..<visibleHeight {
            let lineIndex = scrollOffset.y + i
            if lineIndex >= 0 && lineIndex < lines.count {
                var line = lines[lineIndex]
                if scrollOffset.x < line.count {
                    let startIndex = line.index(line.startIndex, offsetBy: scrollOffset.x)
                    let endIndex = line.index(startIndex, offsetBy: min(visibleWidth, line.count - scrollOffset.x))
                    line = String(line[startIndex..<endIndex])
                } else {
                    line = "" // Line is scrolled past horizontally
                }

                for (charIndex, char) in line.enumerated() {
                    Application.shared.terminal.writeToBuffer(x: displayX + charIndex, y: displayY + i, char: char, foreground: fgColor, background: bgColor)
                }
                // Fill remaining space with background color
                for charIndex in line.count..<visibleWidth {
                    Application.shared.terminal.writeToBuffer(x: displayX + charIndex, y: displayY + i, char: " ", foreground: fgColor, background: bgColor)
                }
            } else {
                // Draw empty line
                for charIndex in 0..<visibleWidth {
                    Application.shared.terminal.writeToBuffer(x: displayX + charIndex, y: displayY + i, char: " ", foreground: fgColor, background: bgColor)
                }
            }
        }

        // Draw cursor if focused
        if state.contains(.sfFocused) {
            let cursorGlobalX = displayX + cursorPosition.x - scrollOffset.x
            let cursorGlobalY = displayY + cursorPosition.y - scrollOffset.y

            if cursorGlobalX >= displayX && cursorGlobalX < displayX + visibleWidth &&
               cursorGlobalY >= displayY && cursorGlobalY < displayY + visibleHeight {

                let cursorChar: Character
                if cursorPosition.y < lines.count && cursorPosition.x < lines[cursorPosition.y].count {
                    let line = lines[cursorPosition.y]
                    let index = line.index(line.startIndex, offsetBy: cursorPosition.x)
                    cursorChar = line[index]
                } else {
                    cursorChar = " " // Draw a space if cursor is at the end of a line or new line
                }
                Application.shared.terminal.writeToBuffer(x: cursorGlobalX, y: cursorGlobalY, char: cursorChar, foreground: bgColor, background: fgColor) // Invert colors for cursor
            }
        }

        // Display error message below the memo view if invalid
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
                    // Adjust cursor position to be at the end of the restored text for simplicity
                    cursorPosition = Point(x: lines[lines.count - 1].count, y: lines.count - 1)
                    handled = true
                }
            } else if keyEvent.character == "y" {
                if let nextState = historyManager.redo() {
                    text = nextState.text
                    // Adjust cursor position to be at the end of the restored text for simplicity
                    cursorPosition = Point(x: lines[lines.count - 1].count, y: lines.count - 1)
                    handled = true
                }
            }
        }

        if !handled {
            switch keyEvent.keyCode {
            case KeyEvent.KeyCode.leftArrow:
                if cursorPosition.x > 0 {
                    cursorPosition.x -= 1
                    handled = true
                } else if cursorPosition.y > 0 {
                    cursorPosition.y -= 1
                    cursorPosition.x = lines[cursorPosition.y].count // Move to end of previous line
                    handled = true
                }
            case KeyEvent.KeyCode.rightArrow:
                if cursorPosition.y < lines.count {
                    let currentLineLength = lines[cursorPosition.y].count
                    if cursorPosition.x < currentLineLength {
                        cursorPosition.x += 1
                        handled = true
                    } else if cursorPosition.y < lines.count - 1 {
                        cursorPosition.y += 1
                        cursorPosition.x = 0 // Move to beginning of next line
                        handled = true
                    }
                }
            case KeyEvent.KeyCode.upArrow:
                if cursorPosition.y > 0 {
                    cursorPosition.y -= 1
                    cursorPosition.x = min(cursorPosition.x, lines[cursorPosition.y].count)
                    handled = true
                }
            case KeyEvent.KeyCode.downArrow:
                if cursorPosition.y < lines.count - 1 {
                    cursorPosition.y += 1
                    cursorPosition.x = min(cursorPosition.x, lines[cursorPosition.y].count)
                    handled = true
                }
            case KeyEvent.KeyCode.home:
                cursorPosition.x = 0
                handled = true
            case KeyEvent.KeyCode.end:
                if cursorPosition.y < lines.count {
                    cursorPosition.x = lines[cursorPosition.y].count
                    handled = true
                }
            case KeyEvent.KeyCode.backspace:
                if cursorPosition.x > 0 {
                    let lineIndex = cursorPosition.y
                    var currentLine = lines[lineIndex]
                    currentLine.remove(at: currentLine.index(currentLine.startIndex, offsetBy: cursorPosition.x - 1))
                    lines[lineIndex] = currentLine
                    text = lines.joined(separator: "\n") // Update text to trigger didSet
                    cursorPosition.x -= 1
                    handled = true
                } else if cursorPosition.y > 0 {
                    let currentLine = lines.remove(at: cursorPosition.y)
                    cursorPosition.y -= 1
                    let previousLineLength = lines[cursorPosition.y].count
                    lines[cursorPosition.y].append(currentLine)
                    text = lines.joined(separator: "\n") // Update text to trigger didSet
                    cursorPosition.x = previousLineLength
                    handled = true
                }
            case KeyEvent.KeyCode.delete:
                if cursorPosition.y < lines.count {
                    let lineIndex = cursorPosition.y
                    var currentLine = lines[lineIndex]
                    if cursorPosition.x < currentLine.count {
                        currentLine.remove(at: currentLine.index(currentLine.startIndex, offsetBy: cursorPosition.x))
                        lines[lineIndex] = currentLine
                        text = lines.joined(separator: "\n") // Update text to trigger didSet
                        handled = true
                    } else if cursorPosition.y < lines.count - 1 {
                        // Merge current line with next line
                        let nextLine = lines.remove(at: cursorPosition.y + 1)
                        lines[lineIndex].append(nextLine)
                        text = lines.joined(separator: "\n") // Update text to trigger didSet
                        handled = true
                    }
                }
            case KeyEvent.KeyCode.enter:
                let lineIndex = cursorPosition.y
                var currentLine = lines[lineIndex]
                let remainingLine = String(currentLine.suffix(from: currentLine.index(currentLine.startIndex, offsetBy: cursorPosition.x)))
                currentLine.removeSubrange(currentLine.index(currentLine.startIndex, offsetBy: cursorPosition.x)...)
                lines[lineIndex] = currentLine
                lines.insert(remainingLine, at: lineIndex + 1)
                text = lines.joined(separator: "\n") // Update text to trigger didSet
                cursorPosition.y += 1
                cursorPosition.x = 0
                handled = true
            default:
                if let char = keyEvent.character, char.isPrintableASCII {
                    let lineIndex = cursorPosition.y
                    var currentLine = lines[lineIndex]
                    currentLine.insert(char, at: currentLine.index(currentLine.startIndex, offsetBy: cursorPosition.x))
                    lines[lineIndex] = currentLine
                    text = lines.joined(separator: "\n") // Update text to trigger didSet
                    cursorPosition.x += 1
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
            setNeedsDisplay()
            return true
        }
        return super.handle(keyEvent: keyEvent)
    }
}