import Foundation

@MainActor
open class Cluster: BaseView {
    public var title: String?
    private var radioButtons: [AnyHashable: [RadioButton]] = [:]

    public init(frame: Rect, title: String? = nil) {
        self.title = title
        super.init(frame: frame)
        // Clusters might have a default border or background
    }

    public func add(radioButton: RadioButton) {
        add(subview: radioButton)
        radioButtons[radioButton.groupId, default: []].append(radioButton)
    }

    override open func handle(command: Command) -> Bool {
        if command == .cmUser { // Assuming .cmUser is used for radio button selection
            // Find which radio button sent the command and update its group
            if let selectedRadioButton = subviews.first(where: { ($0 as? RadioButton)?.isSelected == true }) as? RadioButton {
                if let group = radioButtons[selectedRadioButton.groupId] {
                    for radioButton in group {
                        if radioButton !== selectedRadioButton && radioButton.isSelected {
                            radioButton.isSelected = false // Deselect others in the group
                        }
                    }
                }
            }
            return true
        }
        return super.handle(command: command)
    }

    override open func draw(in rect: Rect) {
        super.draw(in: rect)

        let x = frame.origin.x
        let y = frame.origin.y
        let width = frame.size.width
        let height = frame.size.height

        guard width >= 2 && height >= 2 else { return } // Need at least 2x2 for a border

        let clusterColors = Application.currentColorTheme.currentPalette[.clusterNormal]
        let fgColor = clusterColors.foreground
        let bgColor = clusterColors.background

        // Draw corners
        Application.shared.terminal.writeToBuffer(x: x, y: y, char: "┌", foreground: fgColor, background: bgColor)
        Application.shared.terminal.writeToBuffer(x: x + width - 1, y: y, char: "┐", foreground: fgColor, background: bgColor)
        Application.shared.terminal.writeToBuffer(x: x, y: y + height - 1, char: "└", foreground: fgColor, background: bgColor)
        Application.shared.terminal.writeToBuffer(x: x + width - 1, y: y + height - 1, char: "┘", foreground: fgColor, background: bgColor)

        // Draw horizontal borders
        for i in 1..<(width - 1) {
            Application.shared.terminal.writeToBuffer(x: x + i, y: y, char: "─", foreground: fgColor, background: bgColor) // Top
            Application.shared.terminal.writeToBuffer(x: x + i, y: y + height - 1, char: "─", foreground: fgColor, background: bgColor) // Bottom
        }

        // Draw vertical borders
        for i in 1..<(height - 1) {
            Application.shared.terminal.writeToBuffer(x: x, y: y + i, char: "│", foreground: fgColor, background: bgColor) // Left
            Application.shared.terminal.writeToBuffer(x: x + width - 1, y: y + i, char: "│", foreground: fgColor, background: bgColor) // Right
        }

        if let title = title {
            let titleToDisplay = " \(title) "
            let titleStartX = x + 2 // Offset from left border
            for (index, char) in titleToDisplay.enumerated() {
                if titleStartX + index < x + width - 1 { // Ensure title fits within border
                    Application.shared.terminal.writeToBuffer(x: titleStartX + index, y: y, char: char, foreground: fgColor, background: bgColor)
                }
            }
        }
    }
}
