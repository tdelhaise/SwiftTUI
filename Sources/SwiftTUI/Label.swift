import Foundation

@MainActor
open class Label: BaseView {
    public var text: String

    public init(frame: Rect, text: String) {
        self.text = text
        super.init(frame: frame)
    }

    override open func draw(in rect: Rect) {
        super.draw(in: rect)

        let displayX = frame.origin.x
        let displayY = frame.origin.y

        let labelColors = Application.currentColorTheme.currentPalette[.desktop] // Using desktop colors as a generic default for now

        for (index, char) in text.enumerated() {
            if displayX + index < frame.origin.x + frame.size.width { // Ensure character is within bounds
                Terminal.writeToBuffer(x: displayX + index, y: displayY, char: char, foreground: labelColors.foreground, background: labelColors.background)
            }
        }
    }
}
