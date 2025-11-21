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
    public var highlightLine: Int? {
        didSet {
            if let line = highlightLine {
                goToLine(line)
            }
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
        let defaultPalette = Application.currentColorTheme.currentPalette[.desktop]
        let highlightPalette = Application.currentColorTheme.currentPalette[.listSelected]
        let fgColor = defaultPalette.foreground
        let bgColor = defaultPalette.background

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
            let isHighlighted = (highlightLine == idx)
            let activeFg = isHighlighted ? highlightPalette.foreground : fgColor
            let activeBg = isHighlighted ? highlightPalette.background : bgColor

            for (offset, char) in trimmed.enumerated() {
                Application.shared.terminal.writeToBuffer(x: frame.origin.x + offset, y: y, char: char, foreground: activeFg, background: activeBg)
            }
            for offset in trimmed.count..<visible.size.width {
                Application.shared.terminal.writeToBuffer(x: frame.origin.x + offset, y: y, char: " ", foreground: activeFg, background: activeBg)
            }
        }
    }

    private func updateContentSize() {
        let maxWidth = lines.map { $0.count }.max() ?? 0
        contentSize = Size(width: maxWidth, height: lines.count)
    }

    @discardableResult
    public func goToLine(_ line: Int) -> Bool {
        guard !lines.isEmpty else { return false }
        let clamped = max(0, min(line, lines.count - 1))
        scrollTo(x: origin.x, y: clamped)
        return true
    }

    @discardableResult
    public func find(_ query: String, caseInsensitive: Bool = true, startAt: Int = 0) -> Int? {
        guard !query.isEmpty else { return nil }
        let searchSpace = lines.enumerated()
        let comparator: (String, String) -> Bool = caseInsensitive ? { $0.range(of: $1, options: .caseInsensitive) != nil } : { $0.contains($1) }
        for (idx, line) in searchSpace where idx >= startAt {
            if comparator(line, query) {
                highlightLine = idx
                return idx
            }
        }
        return nil
    }
}
