import Foundation

/// Read-only text viewer built on the Scroller container.
@MainActor
open class TextViewer: Scroller {
    public var lines: [String] {
        didSet {
            updateContentSize()
            setNeedsDisplay()
        }
    }

    public init(frame: Rect, text: String) {
        self.lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        super.init(frame: frame, contentSize: .zero)
        updateContentSize()
    }

    public init(frame: Rect, lines: [String]) {
        self.lines = lines
        super.init(frame: frame, contentSize: .zero)
        updateContentSize()
    }

    override open func drawContent(in visible: Rect) {
        let startRow = visible.origin.y
        let endRow = min(visible.origin.y + visible.size.height, lines.count)
        let fgColor = Application.currentColorTheme.currentPalette[.desktop].foreground
        let bgColor = Application.currentColorTheme.currentPalette[.desktop].background

        for idx in startRow..<endRow {
            let line = lines[idx]
            let trimmed: String
            if visible.origin.x < line.count {
                let start = line.index(line.startIndex, offsetBy: visible.origin.x)
                let slice = line[start...]
                trimmed = String(slice.prefix(visible.size.width))
            } else {
                trimmed = ""
            }

            let y = frame.origin.y + (idx - visible.origin.y)
            for (offset, char) in trimmed.enumerated() {
                Application.shared.terminal.writeToBuffer(x: frame.origin.x + offset, y: y, char: char, foreground: fgColor, background: bgColor)
            }
            for offset in trimmed.count..<visible.size.width {
                Application.shared.terminal.writeToBuffer(x: frame.origin.x + offset, y: y, char: " ", foreground: fgColor, background: bgColor)
            }
        }
    }

    private func updateContentSize() {
        let maxWidth = lines.map { $0.count }.max() ?? 0
        contentSize = Size(width: maxWidth, height: lines.count)
    }
}
