import Foundation

@MainActor
open class EditorView: MemoView {
    public var selectedRange: Range<Point>? {
        didSet {
            if selectedRange != oldValue {
                setNeedsDisplay()
            }
        }
    }

    public override init(frame: Rect, text: String = "", validator: Validator? = nil, historyManager: HistoryManager = HistoryManager()) {
        super.init(frame: frame, text: text, validator: validator, historyManager: historyManager)
    }

    override open func draw(in rect: Rect) {
        super.draw(in: rect) // Draw MemoView content

        // Selection drawing can be added here if selectionRange is set.
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
                    cursorPosition = Point(x: lines[lines.count - 1].count, y: lines.count - 1) // Move cursor to end of restored text
                    handled = true
                }
            } else if keyEvent.character == "y" {
                if let nextState = historyManager.redo() {
                    text = nextState.text
                    cursorPosition = Point(x: lines[lines.count - 1].count, y: lines.count - 1) // Move cursor to end of restored text
                    handled = true
                }
            } else if keyEvent.character == "c" { // Ctrl+C for Copy
                copyCurrentLine()
                handled = true
            } else if keyEvent.character == "v" { // Ctrl+V for Paste
                pasteClipboard()
                handled = true
            } else if keyEvent.character == "x" { // Ctrl+X for Cut
                cutCurrentLine()
                handled = true
            }
        }

        if !handled {
            switch keyEvent.keyCode {
            case KeyEvent.KeyCode.leftArrow:
                if keyEvent.controlKeyState.contains(.control) {
                    // Ctrl+Left: Jump word left
                    // TODO: Implement word jump
                    print("EditorView: Ctrl+Left pressed (Word Jump Left)")
                } else {
                    if cursorPosition.x > 0 {
                        cursorPosition.x -= 1
                    } else if cursorPosition.y > 0 {
                        cursorPosition.y -= 1
                        cursorPosition.x = lines[cursorPosition.y].count // Move to end of previous line
                    }
                }
                handled = true
            case KeyEvent.KeyCode.rightArrow:
                if keyEvent.controlKeyState.contains(.control) {
                    // Ctrl+Right: Jump word right
                    // TODO: Implement word jump
                    print("EditorView: Ctrl+Right pressed (Word Jump Right)")
                } else {
                    if cursorPosition.y < lines.count {
                        let currentLineLength = lines[cursorPosition.y].count
                        if cursorPosition.x < currentLineLength {
                            cursorPosition.x += 1
                        } else if cursorPosition.y < lines.count - 1 {
                            cursorPosition.y += 1
                            cursorPosition.x = 0 // Move to beginning of next line
                        }
                    }
                }
                handled = true
            case KeyEvent.KeyCode.upArrow:
                if cursorPosition.y > 0 {
                    cursorPosition.y -= 1
                    cursorPosition.x = min(cursorPosition.x, lines[cursorPosition.y].count)
                }
                handled = true
            case KeyEvent.KeyCode.downArrow:
                if cursorPosition.y < lines.count - 1 {
                    cursorPosition.y += 1
                    cursorPosition.x = min(cursorPosition.x, lines[cursorPosition.y].count)
                }
                handled = true
            case KeyEvent.KeyCode.home:
                cursorPosition.x = 0
                handled = true
            case KeyEvent.KeyCode.end:
                if cursorPosition.y < lines.count {
                    cursorPosition.x = lines[cursorPosition.y].count
                }
                handled = true
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
                if let str = keyEvent.character, let char = str.first, let ascii = char.asciiValue, ascii >= 32 && ascii <= 126 {
                    let lineIndex = cursorPosition.y
                    var currentLine = lines[lineIndex]
                    currentLine.insert(contentsOf: str, at: currentLine.index(currentLine.startIndex, offsetBy: cursorPosition.x))
                    lines[lineIndex] = currentLine
                    text = lines.joined(separator: "\n") // Update text to trigger didSet
                    cursorPosition.x += str.count
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

    // MARK: - Find/Replace helpers
    public func find(_ query: String, startAtNext: Bool = false) -> Bool {
        guard !query.isEmpty else { return false }
        let startLine = startAtNext ? cursorPosition.y + 1 : cursorPosition.y
        for idx in startLine..<lines.count {
            if lines[idx].contains(query) {
                cursorPosition = Point(x: lines[idx].firstIndex(of: query.first!)?.utf16Offset(in: lines[idx]) ?? 0, y: idx)
                return true
            }
        }
        return false
    }

    public func replaceFirst(find: String, replace: String) -> Bool {
        guard !find.isEmpty else { return false }
        for (idx, line) in lines.enumerated() {
            if let range = line.range(of: find) {
                let newLine = line.replacingCharacters(in: range, with: replace)
                lines[idx] = newLine
                text = lines.joined(separator: "\n")
                cursorPosition = Point(x: range.lowerBound.utf16Offset(in: newLine), y: idx)
                return true
            }
        }
        return false
    }

    // MARK: - Clipboard
    private func copyCurrentLine() {
        guard cursorPosition.y < lines.count else { return }
        Application.shared.setClipboardText(lines[cursorPosition.y])
    }

    private func cutCurrentLine() {
        guard cursorPosition.y < lines.count else { return }
        Application.shared.setClipboardText(lines[cursorPosition.y])
        lines.remove(at: cursorPosition.y)
        if lines.isEmpty { lines = [""] }
        cursorPosition.y = max(0, min(cursorPosition.y, lines.count - 1))
        cursorPosition.x = min(cursorPosition.x, lines[cursorPosition.y].count)
        text = lines.joined(separator: "\n")
    }

    private func pasteClipboard() {
        if let clip = Application.shared.clipboardText() {
            insertText(clip)
        }
    }
}
