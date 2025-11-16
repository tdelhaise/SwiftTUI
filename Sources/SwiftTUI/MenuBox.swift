import Foundation

@MainActor
open class MenuBox: BaseView {
    public var menuItems: [MenuItem]
    public var selectedItemIndex: Int? {
        didSet {
            if selectedItemIndex != oldValue {
                setNeedsDisplay()
            }
        }
    }
    public var onItemSelected: ((MenuItem) -> Void)?
    public var onMenuClosed: (() -> Void)?

    public init(frame: Rect, menuItems: [MenuItem]) {
        self.menuItems = menuItems
        super.init(frame: frame)
        self.options.insert(.ofSelectable) // MenuBox should be selectable to receive focus
        self.state.insert(.sfModal) // MenuBox is typically modal
        if !menuItems.isEmpty {
            selectedItemIndex = 0 // Select first item by default
        }
    }

    override open func draw(in rect: Rect) {
        super.draw(in: rect)

        let x = frame.origin.x
        let y = frame.origin.y
        let width = frame.size.width
        let height = frame.size.height

        guard width >= 2 && height >= 2 else { return } // Need at least 2x2 for a border

        let normalColors = Application.currentColorTheme.currentPalette[.menuBoxNormal]
        let selectedColors = Application.currentColorTheme.currentPalette[.menuBoxSelected]

        // Draw border
        Terminal.writeToBuffer(x: x, y: y, char: "┌", foreground: normalColors.foreground, background: normalColors.background)
        Terminal.writeToBuffer(x: x + width - 1, y: y, char: "┐", foreground: normalColors.foreground, background: normalColors.background)
        Terminal.writeToBuffer(x: x, y: y + height - 1, char: "└", foreground: normalColors.foreground, background: normalColors.background)
        Terminal.writeToBuffer(x: x + width - 1, y: y + height - 1, char: "┘", foreground: normalColors.foreground, background: normalColors.background)

        for i in 1..<(width - 1) {
            Terminal.writeToBuffer(x: x + i, y: y, char: "─", foreground: normalColors.foreground, background: normalColors.background)
            Terminal.writeToBuffer(x: x + i, y: y + height - 1, char: "─", foreground: normalColors.foreground, background: normalColors.background)
        }

        for i in 1..<(height - 1) {
            Terminal.writeToBuffer(x: x, y: y + i, char: "│", foreground: normalColors.foreground, background: normalColors.background)
            Terminal.writeToBuffer(x: x + width - 1, y: y + i, char: "│", foreground: normalColors.foreground, background: normalColors.background)
        }

        // Draw menu items
        for (index, item) in menuItems.enumerated() {
            let displayY = frame.origin.y + 1 + index // +1 for top border
            let displayX = frame.origin.x + 1 // Indent a bit

            var itemText = item.title
            if let shortcut = item.shortcut {
                itemText += " (\(shortcut))"
            }

            let colors = (index == selectedItemIndex) ? selectedColors : normalColors
            let currentFg = colors.foreground
            let currentBg = colors.background

            let lineToDisplay = String(itemText.prefix(width - 2)) // Account for borders
            for (charIndex, char) in lineToDisplay.enumerated() {
                Terminal.writeToBuffer(x: displayX + charIndex, y: displayY, char: char, foreground: currentFg, background: currentBg)
            }
            // Fill remaining space with background color
            for charIndex in lineToDisplay.count..<(width - 2) {
                Terminal.writeToBuffer(x: displayX + charIndex, y: displayY, char: " ", foreground: currentFg, background: currentBg)
            }
        }
    }

    override open func handle(keyEvent: KeyEvent) -> Bool {
        guard state.contains(.sfFocused) else { return false }

        switch keyEvent.keyCode {
        case KeyEvent.KeyCode.upArrow:
            if let selected = selectedItemIndex, selected > 0 {
                selectedItemIndex = selected - 1
                return true
            }
        case KeyEvent.KeyCode.downArrow:
            if let selected = selectedItemIndex, selected < menuItems.count - 1 {
                selectedItemIndex = selected + 1
                return true
            }
        case KeyEvent.KeyCode.enter:
            if let selected = selectedItemIndex {
                let item = menuItems[selected]
                onItemSelected?(item)
                onMenuClosed?()
                return true
            }
        case KeyEvent.KeyCode.escape:
            onMenuClosed?()
            return true
        default:
            break
        }
        return super.handle(keyEvent: keyEvent)
    }

    override open func handle(mouseEvent: MouseEvent) -> Bool {
        guard frame.contains(mouseEvent.position) else { return false }

        if mouseEvent.eventType == .mouseDown {
            let localY = mouseEvent.position.y - frame.origin.y
            if localY >= 0 && localY < menuItems.count {
                selectedItemIndex = localY
                let item = menuItems[localY]
                onItemSelected?(item)
                onMenuClosed?()
                return true
            }
        }
        return super.handle(mouseEvent: mouseEvent)
    }
}
