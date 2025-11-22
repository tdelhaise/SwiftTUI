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
    public var onOpenMenu: ((Int) -> Void)?
    public var onCloseMenu: (() -> Void)?

    public init(frame: Rect, menuItems: [MenuItem]) {
        self.menuItems = menuItems
        super.init(frame: frame)
        self.options.insert(.ofSelectable) // MenuBar should be selectable to receive focus
        self.onOpenMenu = { [weak self] index in
            (Application.shared.rootView as? Desktop)?.presentMenuBox(at: index)
            _ = self // silence unused self warning
        }
        self.onCloseMenu = { [weak self] in
            (Application.shared.rootView as? Desktop)?.closeMenuBox()
            self?.activeMenuIndex = nil
        }
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
                Application.shared.terminal.writeToBuffer(x: currentX + charIndex, y: displayY, char: char, foreground: fgColor, background: bgColor)
            }
            currentX += itemWidth
        }
    }

    override open func handle(keyEvent: KeyEvent) -> Bool {
        guard state.contains(.sfFocused) else { return false }

        // Handle Alt + shortcut key to activate a menu
        if keyEvent.controlKeyState.contains(.alt), let char = keyEvent.character {
            if let index = menuItems.firstIndex(where: { $0.shortcut?.uppercased() == char.uppercased() }) {
                activeMenuIndex = index
                onOpenMenu?(index)
                return true
            }
        }

        switch keyEvent.keyCode {
        case KeyEvent.KeyCode.escape:
            if activeMenuIndex != nil {
                activeMenuIndex = nil // Close active menu
                onCloseMenu?()
                return true
            } else {
                // If no menu is active, let the desktop handle returning focus
                return false 
            }
        case KeyEvent.KeyCode.leftArrow:
            if let activeIndex = activeMenuIndex {
                activeMenuIndex = max(0, activeIndex - 1)
                onOpenMenu?(activeMenuIndex!)
                return true
            }
        case KeyEvent.KeyCode.rightArrow:
            if let activeIndex = activeMenuIndex {
                activeMenuIndex = min(menuItems.count - 1, activeIndex + 1)
                onOpenMenu?(activeMenuIndex!)
                return true
            }
        case KeyEvent.KeyCode.enter:
            if let activeIndex = activeMenuIndex {
                let item = menuItems[activeIndex]
                if let command = item.command {
                    Task { await Application.shared.post(event: .command(command)) }
                    activeMenuIndex = nil // Close menu after command
                    onCloseMenu?()
                    return true
                } else if item.subitems != nil {
                    onOpenMenu?(activeIndex)
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

        if mouseEvent.eventType == .mouseDown || mouseEvent.eventType == .mouseMove {
            var currentX = frame.origin.x + 1
            for (index, item) in menuItems.enumerated() {
                let itemWidth = (" \(item.title) ").count
                if mouseEvent.position.x >= currentX && mouseEvent.position.x < currentX + itemWidth {
                    if activeMenuIndex == index && mouseEvent.eventType == .mouseDown {
                        activeMenuIndex = nil
                        onCloseMenu?()
                    } else {
                        activeMenuIndex = index
                        onOpenMenu?(index)
                    }
                    return true
                }
                currentX += itemWidth
            }
        }
        return super.handle(mouseEvent: mouseEvent)
    }
}
