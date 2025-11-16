import Foundation

@MainActor
open class RadioButton: BaseView {
    public var title: String
    public var isSelected: Bool = false {
        didSet {
            if isSelected != oldValue {
                onSelect?(isSelected)
                setNeedsDisplay()
            }
        }
    }
    public var groupId: AnyHashable // To identify which group it belongs to
    public var onSelect: ((Bool) -> Void)?

    public init(frame: Rect, title: String, isSelected: Bool = false, groupId: AnyHashable) {
        self.title = title
        self.isSelected = isSelected
        self.groupId = groupId
        super.init(frame: frame)
        self.options.insert(.ofSelectable)
    }

    override open func draw(in rect: Rect) {
        super.draw(in: rect) // Fills background

        let radioChar = isSelected ? "◉" : "◯" // Unicode radio button characters
        let displayString = "(\(radioChar)) \(title)"

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
            if !isSelected { // Only select if not already selected
                isSelected = true
                // This should ideally notify the parent Cluster/group to deselect others
                _ = owner?.handle(command: .cmUser) // Placeholder command for group notification
            }
            return true
        }
        return super.handle(keyEvent: keyEvent)
    }

    override open func handle(mouseEvent: MouseEvent) -> Bool {
        guard frame.contains(mouseEvent.position) else { return false }

        if mouseEvent.eventType == .mouseDown {
            if !isSelected { // Only select if not already selected
                isSelected = true
                // This should ideally notify the parent Cluster/group to deselect others
                _ = owner?.handle(command: .cmUser) // Placeholder command for group notification
            }
            return true
        }
        return super.handle(mouseEvent: mouseEvent)
    }
}
