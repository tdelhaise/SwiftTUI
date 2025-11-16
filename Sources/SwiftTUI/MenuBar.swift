import Foundation

@MainActor
open class MenuBar: BaseView {
    public var menuItems: [MenuItem]
    public var activeMenuIndex: Int? {
        didSet {
            if activeMenuIndex != oldValue {
                setNeedsDisplay()
            }
        }
    }

    public init(frame: Rect, menuItems: [MenuItem]) {
        self.menuItems = menuItems
        super.init(frame: frame)
        self.options.insert(.ofSelectable) // MenuBar should be selectable to receive focus
    }

    override open func draw(in rect: Rect) {
        super.draw(in: rect)

        var currentX = frame.origin.x + 1 // Start a little in from the left edge
        let displayY = frame.origin.y

        let normalColors = Application.currentColorTheme.currentPalette[.menuBarNormal]
        let activeColors = Application.currentColorTheme.currentPalette[.menuBarActive]

        for (index, item) in menuItems.enumerated() {
            let itemText = " \(item.title) " // Add padding for visual separation
            let itemWidth = itemText.count

            let colors = (index == activeMenuIndex) ? activeColors : normalColors
            let fgColor = colors.foreground
            let bgColor = colors.background

            for (charIndex, char) in itemText.enumerated() {
                Terminal.writeToBuffer(x: currentX + charIndex, y: displayY, char: char, foreground: fgColor, background: bgColor)
            }
            currentX += itemWidth
        }
    }

    override open func handle(keyEvent: KeyEvent) -> Bool {
        guard state.contains(.sfFocused) else { return false }

        // Handle Alt + shortcut key to activate a menu
        if keyEvent.controlKeyState.contains(.alt), let char = keyEvent.character {
            for (index, item) in menuItems.enumerated() {
                if let shortcut = item.shortcut, Character(char.uppercased()) == Character(String(shortcut).uppercased()) {
                    activeMenuIndex = index
                    print("  MenuBar: Alt+\(char) activated menu '\(item.title)'")
                    // In a real app, this would open the submenu
                    return true
                }
            }
        }

        switch keyEvent.keyCode {
        case KeyEvent.KeyCode.escape:
            if activeMenuIndex != nil {
                activeMenuIndex = nil // Close active menu
                print("  MenuBar: Escape pressed, closing active menu.")
                return true
            }
        case KeyEvent.KeyCode.leftArrow:
            if let activeIndex = activeMenuIndex {
                activeMenuIndex = max(0, activeIndex - 1)
                print("  MenuBar: Left arrow, active menu now \(menuItems[activeMenuIndex!].title)")
                return true
            }
        case KeyEvent.KeyCode.rightArrow:
            if let activeIndex = activeMenuIndex {
                activeMenuIndex = min(menuItems.count - 1, activeIndex + 1)
                print("  MenuBar: Right arrow, active menu now \(menuItems[activeMenuIndex!].title)")
                return true
            }
        case KeyEvent.KeyCode.enter:
            if let activeIndex = activeMenuIndex {
                let item = menuItems[activeIndex]
                if let command = item.command {
                    print("  MenuBar: Activating command \(command) for '\(item.title)'")
                    _ = owner?.handle(command: command) // Pass command up the hierarchy
                    activeMenuIndex = nil // Close menu after command
                    return true
                } else if item.subitems != nil {
                    print("  MenuBar: Opening submenu for '\(item.title)'")
                    // In a real app, this would open the submenu
                    return true
                }
            }
        default:
            break
        }
        return super.handle(keyEvent: keyEvent)
    }

    override open func handle(mouseEvent: MouseEvent) -> Bool {
        guard frame.contains(mouseEvent.position) else { return false }

        if mouseEvent.eventType == .mouseDown {
            var currentX = frame.origin.x + 1
            for (index, item) in menuItems.enumerated() {
                let itemWidth = (" \(item.title) ").count
                if mouseEvent.position.x >= currentX && mouseEvent.position.x < currentX + itemWidth {
                    if activeMenuIndex == index {
                        activeMenuIndex = nil // Click on active menu closes it
                        print("  MenuBar: Mouse click closed menu '\(item.title)'")
                    } else {
                        activeMenuIndex = index // Click on inactive menu opens it
                        print("  MenuBar: Mouse click opened menu '\(item.title)'")
                    }
                    return true
                }
                currentX += itemWidth
            }
        }
        return super.handle(mouseEvent: mouseEvent)
    }
}
