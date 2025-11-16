import Foundation

@MainActor
open class Dialog: Window {
    public var message: String
    public private(set) var buttons: [Button] = []

    public init(frame: Rect, title: String, message: String) {
        self.message = message
        super.init(frame: frame, title: title, number: 0) // Dialogs typically don't need a unique number like regular windows
        self.flags.insert(.wfModal) // Mark as modal
        self.flags.remove(.wfGrow) // Dialogs are usually not resizable
        self.flags.remove(.wfZoom) // Dialogs are usually not zoomable
    }

    public func addButton(_ button: Button) {
        buttons.append(button)
        add(subview: button)
    }

    override open func draw(in rect: Rect) {
        super.draw(in: rect)

        // Draw dialog message
        let messageLines = message.split(separator: "\n", omittingEmptySubsequences: false)
        var currentDisplayY = frame.origin.y + 2 // Start below title bar

        let contentX = frame.origin.x + 2
        let contentWidth = frame.size.width - 4
        let contentHeight = frame.size.height - 3 // Account for title bar and bottom border

        let messageColors = Application.currentColorTheme.currentPalette[.dialogMessage]

        for line in messageLines {
            if currentDisplayY >= frame.origin.y + contentHeight {
                break // Stop drawing if outside the content height
            }

            let lineToDisplay = String(line.prefix(contentWidth)) // Truncate if too long
            for (index, char) in lineToDisplay.enumerated() {
                Application.shared.terminal.writeToBuffer(x: contentX + index, y: currentDisplayY, char: char, foreground: messageColors.foreground, background: messageColors.background)
            }
            // Fill remaining space with background color
            for charIndex in lineToDisplay.count..<contentWidth {
                Application.shared.terminal.writeToBuffer(x: contentX + charIndex, y: currentDisplayY, char: " ", foreground: messageColors.foreground, background: messageColors.background)
            }
            currentDisplayY += 1
        }
    }

    override open func handle(keyEvent: KeyEvent) -> Bool {
        // Dialogs might have default button handling (e.g., Enter for OK, Escape for Cancel)
        if keyEvent.keyCode == KeyEvent.KeyCode.enter {
            // Simulate clicking a default button (e.g., the first button)
            if let defaultButton = buttons.first {
                print("  Dialog '\(title)': Enter pressed, activating default button '\(defaultButton.title)'")
                defaultButton.action?()
                return true
            }
        } else if keyEvent.keyCode == KeyEvent.KeyCode.escape {
            print("  Dialog '\(title)': Escape pressed, closing dialog.")
            close() // Close the dialog
            return true
        }
        return super.handle(keyEvent: keyEvent)
    }
}
