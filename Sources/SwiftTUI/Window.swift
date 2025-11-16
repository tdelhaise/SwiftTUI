import Foundation

/// OptionSet for window behavior flags.
public struct WindowFlags: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }

    @MainActor public static let wfMove = WindowFlags(rawValue: 1 << 0)
    @MainActor public static let wfGrow = WindowFlags(rawValue: 1 << 1)
    @MainActor public static let wfClose = WindowFlags(rawValue: 1 << 2)
    @MainActor public static let wfZoom = WindowFlags(rawValue: 1 << 3)
    @MainActor public static let wfModal = WindowFlags(rawValue: 1 << 4)
    // Add more window flags as needed
}

/// Enum for predefined window color palettes.
public enum WindowPalette: UInt, CaseIterable, Sendable {
    case wpBlueWindow = 0
    case wpCyanWindow = 1
    case wpGrayWindow = 2
    // Add more palettes as needed
}

/// A basic window view that can be moved, resized, closed, and zoomed.
@MainActor
open class Window: BaseView {
    public var title: String
    public var number: Int
    public var flags: WindowFlags
    public private(set) var zoomRect: Rect
    public var palette: WindowPalette

    // The frame view is a subview responsible for drawing the border and title bar
    public private(set) var frameView: View?

    private let minWinSize = Size(width: 16, height: 6)

    public init(frame: Rect, title: String, number: Int) {
        self.title = title
        self.number = number
        self.flags = [.wfMove, .wfGrow, .wfClose, .wfZoom] // Default flags
        self.zoomRect = frame
        self.palette = .wpBlueWindow // Default palette

        super.init(frame: frame)

        self.state.insert(.sfShadow) // Windows typically have shadows
        self.options.insert([.ofSelectable, .ofTopSelect]) // Windows are selectable and can be brought to top
        // growMode equivalent will be handled by overriding sizeLimits and drag logic

        // Initialize and insert the frame view
        let frameRect = Rect(origin: Point.zero, size: frame.size)
        let newFrameView = FrameView(frame: frameRect, title: title) // Assuming FrameView exists
        self.add(subview: newFrameView)
        self.frameView = newFrameView
    }

    open func close() {
        // In a real application, this would involve validation and removal from its owner.
        // For now, we'        // print("Window '\(title)' (Number: \(number)) closed.")
        // self.owner?.remove(subview: self) // Placeholder for actual removal
    }

    open func zoom() {
        let maximizedFrame = Rect(x: 0, y: 0, width: 80, height: 24) // Example full screen

        if frame == maximizedFrame {
            // Currently maximized, restore to previous size
            frame = zoomRect
        } else {
            // Not maximized, maximize it
            zoomRect = frame // Save current size
            frame = maximizedFrame
        }
        // Redraw or notify owner to redraw
    }

    override open func handle(command: Command) -> Bool {
        switch command {
        case .cmClose:
            if flags.contains(.wfClose) {
                close()
                return true
            }
        case .cmZoom:
            if flags.contains(.wfZoom) {
                zoom()
                return true
            }
        // Add other window-specific commands like cmResize, cmMove
        default:
            break
        }
        return super.handle(command: command)
    }

    override open func handle(keyEvent: KeyEvent) -> Bool {
        // Handle Tab/Shift+Tab for focus navigation within the window
        if keyEvent.keyCode == 9 /* Tab */ {
            // Implement focus navigation logic
            // print("Window '\(title)' handling Tab key.")
            return true
        } else if keyEvent.keyCode == 25 /* Shift+Tab */ {
            // Implement reverse focus navigation logic
            // print("Window '\(title)' handling Shift+Tab key.")
            return true
        }
        return super.handle(keyEvent: keyEvent)
    }

    override open func draw(in rect: Rect) {
        super.draw(in: rect) // Draw base view content (fills background)

        // Delegate drawing of the frame to the frameView
        frameView?.draw(in: Rect(origin: Point.zero, size: frame.size))

        // Draw title
        let titleToDisplay = " \(title) "
        let titleX = frame.origin.x + (frame.size.width - titleToDisplay.count) / 2
        let titleY = frame.origin.y

        let titleColors = state.contains(.sfFocused) ? Application.currentColorTheme.currentPalette[.windowTitleActive] : Application.currentColorTheme.currentPalette[.windowTitleNormal]

        for (index, char) in titleToDisplay.enumerated() {
            Terminal.writeToBuffer(x: titleX + index, y: titleY, char: char, foreground: titleColors.foreground, background: titleColors.background)
        }
    }

    override open func setState(_ aState: ViewState, enable: Bool) {
        super.setState(aState, enable: enable)

        if aState.contains(.sfSelected) {
            // When selected, activate/deactivate the frame and enable/disable commands
            frameView?.setState(aState, enable: enable) // Propagate state to frame
            // Enable/disable window-specific commands based on 'enable'
            // This would involve interacting with the Application's command manager
        }
    }

    // Placeholder for sizeLimits, will be refined when actual resizing is implemented
    open func sizeLimits(min: inout Size, max: inout Size) {
        min = minWinSize
        max = Size(width: 80, height: 24) // Example max size (e.g., desktop extent)
    }

    // Internal class for drawing the window frame (border and title bar)
    private class FrameView: BaseView {
        var windowTitle: String

        init(frame: Rect, title: String) {
            self.windowTitle = title
            super.init(frame: frame)
        }

        override func draw(in rect: Rect) {
            super.draw(in: rect) // Fill background

            guard let ownerWindow = owner as? Window else { return }

            let colors = ownerWindow.state.contains(.sfFocused) ? Application.currentColorTheme.currentPalette[.windowActive] : Application.currentColorTheme.currentPalette[.windowNormal]
            let fgColor = colors.foreground
            let bgColor = colors.background

            let x = frame.origin.x
            let y = frame.origin.y
            let width = frame.size.width
            let height = frame.size.height

            guard width >= 2 && height >= 2 else { return }

            // Draw corners
            Terminal.writeToBuffer(x: x, y: y, char: "┌", foreground: fgColor, background: bgColor)
            Terminal.writeToBuffer(x: x + width - 1, y: y, char: "┐", foreground: fgColor, background: bgColor)
            Terminal.writeToBuffer(x: x, y: y + height - 1, char: "└", foreground: fgColor, background: bgColor)
            Terminal.writeToBuffer(x: x + width - 1, y: y + height - 1, char: "┘", foreground: fgColor, background: bgColor)

            // Draw horizontal borders
            for i in 1..<(width - 1) {
                Terminal.writeToBuffer(x: x + i, y: y, char: "─", foreground: fgColor, background: bgColor) // Top
                Terminal.writeToBuffer(x: x + i, y: y + height - 1, char: "─", foreground: fgColor, background: bgColor) // Bottom
            }

            // Draw vertical borders
            for i in 1..<(height - 1) {
                Terminal.writeToBuffer(x: x, y: y + i, char: "│", foreground: fgColor, background: bgColor) // Left
                Terminal.writeToBuffer(x: x + width - 1, y: y + i, char: "│", foreground: fgColor, background: bgColor) // Right
            }
        }
    }
}