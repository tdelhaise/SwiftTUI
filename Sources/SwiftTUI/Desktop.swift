import Foundation

@MainActor
open class Desktop: BaseView {
    public private(set) var windows: [Window] = []
    private var lastFocusedWindow: Window?
    public var statusLine: StatusLine? {
        didSet {
            if oldValue != nil {
                // Remove old status line from subviews if it was added
                // (Requires a remove(subview:) method in BaseView or manual management)
            }
            if let newStatusLine = statusLine {
                add(subview: newStatusLine)
            }
        }
    }
    public var menuBar: MenuBar? {
        didSet {
            if oldValue != nil {
                // Remove old menu bar from subviews if it was added
            }
            if let newMenuBar = menuBar {
                add(subview: newMenuBar)
            }
        }
    }

    public override init(frame: Rect) {
        super.init(frame: frame)
        self.options.insert(.ofBuffered) // Desktop might benefit from buffering
    }

    private var activeMenuBox: MenuBox?
    private var submenuBox: MenuBox?

    public func set(statusLine: StatusLine) {
        self.statusLine = statusLine
    }

    public func set(menuBar: MenuBar) {
        self.menuBar = menuBar
    }

    public func add(window: Window) {
        // Add window to the desktop and bring it to front
        add(subview: window)
        windows.append(window)
        bringToFront(window: window)
        if windows.count == 1 {
            window.setState(.sfFocused, enable: true)
            lastFocusedWindow = window
        }
    }

    public func remove(window: Window) {
        if let index = windows.firstIndex(where: { $0 === window }) {
            windows.remove(at: index)
            // Also remove from subviews if BaseView's remove method is implemented
            // For now, we'll just manage the 'windows' array
        }
    }

    public func bringToFront(window: Window) {
        if let index = windows.firstIndex(where: { $0 === window }) {
            let windowToMove = windows.remove(at: index)
            windows.append(windowToMove) // Move to end to draw last (on top)
            
            // Unfocus all other windows
            for w in windows where w !== window {
                w.setState(.sfFocused, enable: false)
            }
            window.setState(.sfFocused, enable: true)
            lastFocusedWindow = window
            menuBar?.setState(.sfFocused, enable: false)

            setNeedsDisplay()
        }
    }
    
    public func tileWindows() {
        guard !windows.isEmpty else { return }
        let cols = Int(Double(windows.count).squareRoot().rounded(.up))
        let rows = Int(ceil(Double(windows.count) / Double(cols)))
        let topMargin = menuBar == nil ? 0 : 1
        let bottomMargin = statusLine == nil ? 0 : 1
        let availWidth = max(1, frame.size.width)
        let availHeight = max(1, frame.size.height - topMargin - bottomMargin)
        let cellWidth = max(20, availWidth / cols)
        let cellHeight = max(8, availHeight / rows)
        for (idx, window) in windows.enumerated() {
            let c = idx % cols
            let r = idx / cols
            window.frame = Rect(x: c * cellWidth, y: topMargin + r * cellHeight, width: cellWidth, height: cellHeight)
            window.setState(.sfVisible, enable: true)
        }
        setNeedsDisplay()
    }

    public func cascadeWindows() {
        let topMargin = menuBar == nil ? 0 : 1
        let bottomMargin = statusLine == nil ? 0 : 1
        let availWidth = max(1, frame.size.width)
        let availHeight = max(1, frame.size.height - topMargin - bottomMargin)
        var offset = 0
        let step = 2
        for window in windows {
            let w = max(40, availWidth - offset * step)
            let h = max(12, availHeight - offset * step)
            window.frame = Rect(x: offset * step, y: topMargin + offset * step, width: w, height: h)
            window.setState(.sfVisible, enable: true)
            offset += 1
        }
        setNeedsDisplay()
    }

    override open func draw(in rect: Rect) {
        super.draw(in: rect) // Draw desktop background (fills with empty cells)

        menuBar?.draw(in: rect)
        activeMenuBox?.draw(in: rect)
        submenuBox?.draw(in: rect)

        // Draw windows from back to front (lowest index to highest index)
        for window in windows {
            if window.state.contains(.sfVisible) {
                window.draw(in: rect) // Windows draw themselves
            }
        }

        // Draw status line last, so it's always on top
        statusLine?.draw(in: rect)
    }

    override open func handle(keyEvent: KeyEvent) -> Bool {
        // Handle Alt + shortcut key to activate a menu globally
        if let menuBar = menuBar, keyEvent.controlKeyState.contains(.alt), let char = keyEvent.character {
            if let index = menuBar.menuItems.firstIndex(where: { $0.shortcut?.uppercased() == char.uppercased() }) {
                // If a menu shortcut matches, activate that menu and give focus to the menu bar
                menuBar.activeMenuIndex = index
                lastFocusedWindow = windows.first(where: { $0.state.contains(.sfFocused) })
                lastFocusedWindow?.setState(.sfFocused, enable: false)
                menuBar.setState(.sfFocused, enable: true)
                return true
            }
        }

        if keyEvent.keyCode == KeyEvent.KeyCode.f10, let menuBar = menuBar {
            if menuBar.state.contains(.sfFocused) {
                menuBar.setState(.sfFocused, enable: false)
                lastFocusedWindow?.setState(.sfFocused, enable: true)
            } else {
                lastFocusedWindow = windows.first(where: { $0.state.contains(.sfFocused) })
                lastFocusedWindow?.setState(.sfFocused, enable: false)
                menuBar.activeMenuIndex = menuBar.activeMenuIndex ?? 0
                menuBar.setState(.sfFocused, enable: true)
            }
            return true
        }

        if let menuBar = menuBar, menuBar.state.contains(.sfFocused) {
            if menuBar.handle(keyEvent: keyEvent) {
                return true
            } else {
                if keyEvent.keyCode == KeyEvent.KeyCode.escape {
                    menuBar.setState(.sfFocused, enable: false)
                    lastFocusedWindow?.setState(.sfFocused, enable: true)
                    return true
                }
            }
        }

        // Pass key events to the top-most (focused) window first
        if let topWindow = windows.last, topWindow.state.contains(.sfVisible) && topWindow.state.contains(.sfFocused) {
            if topWindow.handle(keyEvent: keyEvent) {
                return true
            }
        }
        // If no window handled it, or no window is focused, handle global desktop commands
        if keyEvent.character == "q" && keyEvent.controlKeyState.contains(.control) {
            Task { await Application.shared.post(event: .command(.cmQuit)) }
            return true
        }
        return super.handle(keyEvent: keyEvent) // Pass to BaseView's handler (which passes to owner)
    }

    override open func handle(mouseEvent: MouseEvent) -> Bool {
        if let menuBox = activeMenuBox, menuBox.state.contains(.sfVisible) {
            if menuBox.handle(mouseEvent: mouseEvent) {
                return true
            }
        }
        if let sub = submenuBox, sub.state.contains(.sfVisible) {
            if sub.handle(mouseEvent: mouseEvent) {
                return true
            }
        }

        if mouseEvent.eventType == .mouseWheel {
            if let topWindow = windows.last, topWindow.state.contains(.sfVisible) {
                return topWindow.handle(mouseEvent: mouseEvent)
            }
            return super.handle(mouseEvent: mouseEvent)
        }

        // Pass mouse events to the top-most window that contains the mouse position
        for window in windows.reversed() { // Iterate from top to bottom
            if window.state.contains(.sfVisible) && window.frame.contains(mouseEvent.position) {
                if window.handle(mouseEvent: mouseEvent) {
                    // If a window handled the mouse down event, bring it to front and focus it
                    if mouseEvent.eventType == .mouseDown {
                        bringToFront(window: window)
                        // Also set focus. This will require a focus management system.
                        // For now, just print.
                        print("  Desktop: Mouse down on window '\(window.title)', bringing to front and focusing.")
                    }
                    return true
                }
            }
        }
        return super.handle(mouseEvent: mouseEvent) // Pass to BaseView's handler
    }

    // MARK: - Menu handling
    public func presentMenuBox(at index: Int) {
        guard let menuBar = menuBar else { return }
        guard index >= 0 && index < menuBar.menuItems.count else { return }
        let items = menuBar.menuItems[index].subitems ?? []
        let width = items.map { MenuBox.preferredWidth(for: $0) }.max() ?? 10
        let height = items.count + 2
        let origin = Point(x: 0, y: 1)
        let frame = Rect(x: origin.x, y: origin.y, width: width, height: height)
        let box = MenuBox(frame: frame, menuItems: items)
        box.onItemSelected = { [weak self] item in
            if let command = item.command {
                Task { await Application.shared.post(event: .command(command)) }
            }
            self?.closeMenuBox()
        }
        box.onMenuClosed = { [weak self] in
            self?.closeMenuBox()
        }
        box.onOpenSubmenu = { [weak self] parentBox, idx, item in
            guard let subitems = item.subitems, let self else { return }
            let subWidth = subitems.map { MenuBox.preferredWidth(for: $0) }.max() ?? 10
            let subHeight = subitems.count + 2
            let parentY = parentBox.frame.origin.y + 1 + idx
            let originX = parentBox.frame.origin.x + parentBox.frame.size.width
            let subFrame = Rect(x: originX, y: parentY, width: subWidth, height: subHeight)
            let subBox = MenuBox(frame: subFrame, menuItems: subitems)
            subBox.onItemSelected = { item in
                if let command = item.command {
                    Task { await Application.shared.post(event: .command(command)) }
                }
                self.closeMenuBox()
            }
            subBox.onMenuClosed = { [weak self] in
                self?.submenuBox = nil
                self?.closeMenuBox()
            }
            subBox.onOpenSubmenu = nil
            self.submenuBox = subBox
            subBox.setState(.sfVisible, enable: true)
            subBox.setState(.sfFocused, enable: true)
        }
        box.parentMenuOrigin = origin
        activeMenuBox = box
        box.setState(.sfVisible, enable: true)
        box.setState(.sfFocused, enable: true)
    }

    public func closeMenuBox() {
        activeMenuBox = nil
        submenuBox = nil
        menuBar?.setState(.sfFocused, enable: false)
        lastFocusedWindow?.setState(.sfFocused, enable: true)
    }
}
