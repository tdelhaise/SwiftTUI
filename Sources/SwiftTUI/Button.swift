import Foundation

@MainActor
open class Button: BaseView {
    public var title: String
    public var action: (() -> Void)?

    public init(frame: Rect, title: String, action: (() -> Void)? = nil) {
        self.title = title
        self.action = action
        super.init(frame: frame)
        self.options.insert(.ofSelectable) // Buttons should be selectable to receive keyboard events
    }

    override open func draw(in rect: Rect) {
        super.draw(in: rect)

        let displayTitle = "[\(title)]"
        let textX = frame.origin.x + (frame.size.width - displayTitle.count) / 2
        let textY = frame.origin.y + frame.size.height / 2

        let colors = state.contains(.sfFocused) ? Application.currentColorTheme.currentPalette[.buttonFocused] : Application.currentColorTheme.currentPalette[.buttonNormal]
        let fgColor = colors.foreground
        let bgColor = colors.background

        for (index, char) in displayTitle.enumerated() {
            Application.shared.terminal.writeToBuffer(x: textX + index, y: textY, char: char, foreground: fgColor, background: bgColor)
        }
    }

    override open func handle(mouseEvent: MouseEvent) -> Bool {
        if mouseEvent.eventType == .mouseUp && frame.contains(mouseEvent.position) {
            print("  Button \"\(title)\" clicked!")
            action?()
            setNeedsDisplay() // Request redraw after action
            return true
        }
        return super.handle(mouseEvent: mouseEvent)
    }

    override open func handle(keyEvent: KeyEvent) -> Bool {
        if state.contains(.sfFocused) {
            if keyEvent.keyCode == KeyEvent.KeyCode.enter || keyEvent.character == " " {
                print("  Button \"\(title)\" activated by keyboard!")
                action?()
                setNeedsDisplay() // Request redraw after action
                return true
            }
        }
        return super.handle(keyEvent: keyEvent)
    }
}
