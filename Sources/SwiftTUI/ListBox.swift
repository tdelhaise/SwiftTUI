import Foundation

@MainActor
open class ListBox: BaseView {
    public var items: [String] {
        didSet {
            // Adjust selectedIndex and topIndex if items change
            if let selected = selectedIndex, selected >= items.count {
                selectedIndex = items.isEmpty ? nil : items.count - 1
            }
            if topIndex >= items.count {
                topIndex = 0
            }
            setNeedsDisplay()
        }
    }
    public var selectedIndex: Int? {
        didSet {
            if selectedIndex != oldValue {
                setNeedsDisplay()
            }
        }
    }
    public var topIndex: Int = 0 { // Index of the first visible item
        didSet {
            if topIndex != oldValue {
                setNeedsDisplay()
            }
        }
    }

    public init(frame: Rect, items: [String]) {
        self.items = items
        super.init(frame: frame)
        self.options.insert(.ofSelectable)
        if !items.isEmpty {
            selectedIndex = 0
        }
    }

    override open func draw(in rect: Rect) {
        super.draw(in: rect)

        let visibleHeight = frame.size.height
        let displayX = frame.origin.x
        let displayY = frame.origin.y

        let normalColors = Application.currentColorTheme.currentPalette[.listNormal]
        let selectedColors = Application.currentColorTheme.currentPalette[.listSelected]
        let defaultDesktopColors = Application.currentColorTheme.currentPalette[.desktop]

        for i in 0..<visibleHeight {
            let itemIndex = topIndex + i
            if itemIndex < items.count {
                let itemText = items[itemIndex]
                let fgColor: ANSIColor
                let bgColor: ANSIColor

                if itemIndex == selectedIndex {
                    fgColor = selectedColors.foreground
                    bgColor = selectedColors.background
                } else {
                    fgColor = normalColors.foreground
                    bgColor = normalColors.background
                }

                let lineToDisplay = String(itemText.prefix(frame.size.width))
                for (charIndex, char) in lineToDisplay.enumerated() {
                    Terminal.writeToBuffer(x: displayX + charIndex, y: displayY + i, char: char, foreground: fgColor, background: bgColor)
                }
                // Fill remaining space with background color
                for charIndex in lineToDisplay.count..<frame.size.width {
                    Terminal.writeToBuffer(x: displayX + charIndex, y: displayY + i, char: " ", foreground: fgColor, background: bgColor)
                }
            } else {
                // Draw empty line if no more items
                for charIndex in 0..<frame.size.width {
                    Terminal.writeToBuffer(x: displayX + charIndex, y: displayY + i, char: " ", foreground: defaultDesktopColors.foreground, background: defaultDesktopColors.background)
                }
            }
        }
    }

    override open func handle(keyEvent: KeyEvent) -> Bool {
        guard state.contains(.sfFocused) else { return false }

        switch keyEvent.keyCode {
        case KeyEvent.KeyCode.upArrow:
            if let selected = selectedIndex, selected > 0 {
                selectedIndex = selected - 1
                if selectedIndex! < topIndex {
                    topIndex -= 1
                }
                return true
            }
        case KeyEvent.KeyCode.downArrow:
            if let selected = selectedIndex, selected < items.count - 1 {
                selectedIndex = selected + 1
                if selectedIndex! >= topIndex + frame.size.height {
                    topIndex += 1
                }
                return true
            }
        case KeyEvent.KeyCode.pageUp:
            if items.isEmpty { return true }
            selectedIndex = max(0, (selectedIndex ?? 0) - frame.size.height)
            topIndex = max(0, topIndex - frame.size.height)
            return true
        case KeyEvent.KeyCode.pageDown:
            if items.isEmpty { return true }
            selectedIndex = min(items.count - 1, (selectedIndex ?? 0) + frame.size.height)
            topIndex = min(max(0, items.count - frame.size.height), topIndex + frame.size.height)
            return true
        case KeyEvent.KeyCode.home:
            if items.isEmpty { return true }
            selectedIndex = 0
            topIndex = 0
            return true
        case KeyEvent.KeyCode.end:
            if items.isEmpty { return true }
            selectedIndex = items.count - 1
            topIndex = max(0, items.count - frame.size.height)
            return true
        case KeyEvent.KeyCode.enter:
            if let selected = selectedIndex {
                print("  ListBox: Item \(selected) selected: \"\(items[selected])\"")
                // In a real app, this would trigger an action or command
                return true
            }
        default:
            break
        }
        return super.handle(keyEvent: keyEvent)
    }

    override open func handle(mouseEvent: MouseEvent) -> Bool {
        guard frame.contains(mouseEvent.position) else { return false }

        let localY = mouseEvent.position.y - frame.origin.y
        let clickedIndex = topIndex + localY

        if clickedIndex >= 0 && clickedIndex < items.count {
            if mouseEvent.eventType == .mouseDown {
                selectedIndex = clickedIndex
                setNeedsDisplay()
                return true
            }
            // Handle mouse wheel for scrolling
            // This would require specific mouse event types for wheel up/down
        }
        return super.handle(mouseEvent: mouseEvent)
    }
}
