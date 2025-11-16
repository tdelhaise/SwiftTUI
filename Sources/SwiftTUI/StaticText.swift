import Foundation

@MainActor
open class StaticText: BaseView {
    public var text: String

    public init(frame: Rect, text: String) {
        self.text = text
        super.init(frame: frame)
    }

    override open func draw(in rect: Rect) {
        super.draw(in: rect)

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let displayX = frame.origin.x
        var currentDisplayY = frame.origin.y

        let staticTextColors = Application.currentColorTheme.currentPalette[.desktop] // Using desktop colors as a generic default for now

        for line in lines {
            if currentDisplayY >= frame.origin.y + frame.size.height {
                break // Stop drawing if outside the frame height
            }

            let lineToDisplay = String(line.prefix(frame.size.width)) // Truncate if too long
            for (index, char) in lineToDisplay.enumerated() {
                Application.shared.terminal.writeToBuffer(x: displayX + index, y: currentDisplayY, char: char, foreground: staticTextColors.foreground, background: staticTextColors.background)
            }
            currentDisplayY += 1
        }
    }
}
