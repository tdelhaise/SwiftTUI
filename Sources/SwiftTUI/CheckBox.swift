import Foundation

@MainActor
open class CheckBox: BaseView {
    public var title: String
    public var isChecked: Bool = false {
        didSet {
            if isChecked != oldValue {
                onToggle?(isChecked)
                setNeedsDisplay()
            }
        }
    }
    public var onToggle: ((Bool) -> Void)?

    public init(frame: Rect, title: String, isChecked: Bool = false) {
        self.title = title
        self.isChecked = isChecked
        super.init(frame: frame)
        self.options.insert(.ofSelectable)
    }

    override open func draw(in rect: Rect) {
        super.draw(in: rect) // Fills background

        let checkboxChar = isChecked ? "☒" : "☐" // Unicode checkbox characters
        let displayString = "\(checkboxChar) \(title)"

        let displayX = frame.origin.x
        let displayY = frame.origin.y

        let colors = state.contains(.sfFocused) ? Application.currentColorTheme.currentPalette[.buttonFocused] : Application.currentColorTheme.currentPalette[.buttonNormal]
        let fgColor = colors.foreground
        let bgColor = colors.background

        for (index, char) in displayString.enumerated() {
            if displayX + index < frame.origin.x + frame.size.width {
                Application.shared.terminal.writeToBuffer(x: displayX + index, y: displayY, char: char, foreground: fgColor, background: bgColor)
            }
        }
        // Fill remaining space with background color
        for charIndex in displayString.count..<frame.size.width {
            Application.shared.terminal.writeToBuffer(x: displayX + charIndex, y: displayY, char: " ", foreground: fgColor, background: bgColor)
        }
    }

    override open func handle(keyEvent: KeyEvent) -> Bool {
        guard state.contains(.sfFocused) else { return false }

        if keyEvent.keyCode == KeyEvent.KeyCode.enter || keyEvent.character == " " {
            isChecked.toggle()
            return true
        }
        return super.handle(keyEvent: keyEvent)
    }

    override open func handle(mouseEvent: MouseEvent) -> Bool {
        guard frame.contains(mouseEvent.position) else { return false }

        if mouseEvent.eventType == .mouseDown {
            isChecked.toggle()
            return true
        }
        return super.handle(mouseEvent: mouseEvent)
    }
}
