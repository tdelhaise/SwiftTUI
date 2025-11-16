import Foundation

@MainActor
open class StatusLine: BaseView {
    public var message: String = "" {
        didSet {
            if message != oldValue {
                setNeedsDisplay()
            }
        }
    }

    public init(frame: Rect, message: String = "") {
        self.message = message
        super.init(frame: frame)
        // StatusLine typically occupies the full width at the bottom of the screen
        // Its frame should be set accordingly by its owner (e.g., Application or Desktop)
    }

    override open func draw(in rect: Rect) {
        super.draw(in: rect) // Fills background

        let displayX = frame.origin.x
        let displayY = frame.origin.y // Should be the bottom-most row

        let statusLineColors = Application.currentColorTheme.currentPalette[.statusLine]
        let fgColor = statusLineColors.foreground
        let bgColor = statusLineColors.background

        // Draw the message
        let messageToDisplay = String(message.prefix(frame.size.width))
        for (index, char) in messageToDisplay.enumerated() {
            Application.shared.terminal.writeToBuffer(x: displayX + index, y: displayY, char: char, foreground: fgColor, background: bgColor)
        }
        // Fill remaining space with background color
        for charIndex in messageToDisplay.count..<frame.size.width {
            Application.shared.terminal.writeToBuffer(x: displayX + charIndex, y: displayY, char: " ", foreground: fgColor, background: bgColor)
        }
    }
}
