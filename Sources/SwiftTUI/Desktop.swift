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

    override open func draw(in rect: Rect) {
        super.draw(in: rect) // Draw desktop background (fills with empty cells)

        menuBar?.draw(in: rect)

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
}
