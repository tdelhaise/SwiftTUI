import Foundation

/// Simple message box helper in the style of TVision's messageBox().
@MainActor
public enum MessageBox {
    public static func show(title: String, message: String, buttons: [String] = ["OK"]) -> Dialog {
        let width = max(20, min(60, TextFormatter.displayWidth(of: message) + 4))
        let lines = message.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let height = max(5, lines.count + 4)

        let dialogFrame = Rect(x: 0, y: 0, width: width, height: height)
        let dialog = Dialog(frame: dialogFrame, title: title, message: message)

        // Center message lines
        for (i, line) in lines.enumerated() {
            let fitted = TextFormatter.fit(line, width: width - 4, alignment: .center)
            for (idx, ch) in fitted.enumerated() {
                Application.shared.terminal.writeToBuffer(
                    x: dialogFrame.origin.x + 2 + idx,
                    y: dialogFrame.origin.y + 2 + i,
                    char: ch,
                    foreground: .default,
                    background: .default
                )
            }
        }

        // Add buttons
        let buttonY = dialogFrame.origin.y + height - 2
        var cursorX = dialogFrame.origin.x + 2
        for title in buttons {
            let btnWidth = TextFormatter.displayWidth(of: title) + 4
            let btnFrame = Rect(x: cursorX, y: buttonY, width: btnWidth, height: 1)
            let button = Button(frame: btnFrame, title: title) {
                dialog.close()
            }
            dialog.add(subview: button)
            cursorX += btnWidth + 1
        }

        return dialog
    }
}
