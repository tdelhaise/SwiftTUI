import Foundation

/// Simplified drawing surface similar to TVision's TDrawBuffer.
@MainActor
public struct Surface {
    public let width: Int
    public let height: Int
    private var cells: [Cell]

    public init(width: Int, height: Int, fill: Cell = Cell()) {
        self.width = width
        self.height = height
        self.cells = Array(repeating: fill, count: width * height)
    }

    public mutating func put(x: Int, y: Int, char: Character, fg: ANSIColor = .default, bg: ANSIColor = .default) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        cells[y * width + x] = Cell(character: char, foregroundColor: fg, backgroundColor: bg)
    }

    public mutating func fillRect(x: Int, y: Int, w: Int, h: Int, char: Character = " ", fg: ANSIColor = .default, bg: ANSIColor = .default) {
        guard w > 0, h > 0 else { return }
        let maxX = min(width, x + w)
        let maxY = min(height, y + h)
        for yy in max(0, y)..<maxY {
            let rowStart = yy * width
            for xx in max(0, x)..<maxX {
                cells[rowStart + xx] = Cell(character: char, foregroundColor: fg, backgroundColor: bg)
            }
        }
    }

    public mutating func putString(x: Int, y: Int, text: String, fg: ANSIColor = .default, bg: ANSIColor = .default) {
        guard y >= 0, y < height else { return }
        let rowStart = y * width
        var cursor = max(0, x)
        for ch in text {
            if cursor >= width { break }
            cells[rowStart + cursor] = Cell(character: ch, foregroundColor: fg, backgroundColor: bg)
            cursor += 1
        }
    }

    public mutating func putAlignedString(x: Int, y: Int, width: Int, text: String, alignment: TextAlignment, fg: ANSIColor = .default, bg: ANSIColor = .default) {
        guard width > 0 else { return }
        let clippedWidth = min(width, self.width - x)
        guard clippedWidth > 0 else { return }
        let truncated = String(text.prefix(clippedWidth))
        let pad = max(0, clippedWidth - truncated.count)
        let offset: Int
        switch alignment {
        case .left:
            offset = 0
        case .center:
            offset = pad / 2
        case .right:
            offset = pad
        }
        putString(x: x + offset, y: y, text: truncated, fg: fg, bg: bg)
        if pad > 0 {
            fillRect(x: x, y: y, w: clippedWidth, h: 1, char: " ", fg: fg, bg: bg)
        }
    }

    public mutating func copy(from source: Surface, srcRect: Rect, dest: Point) {
        for sy in 0..<srcRect.size.height {
            let dy = dest.y + sy
            if dy < 0 || dy >= height { continue }
            let sourceY = srcRect.origin.y + sy
            if sourceY < 0 || sourceY >= source.height { continue }
            for sx in 0..<srcRect.size.width {
                let dx = dest.x + sx
                if dx < 0 || dx >= width { continue }
                let sourceX = srcRect.origin.x + sx
                if sourceX < 0 || sourceX >= source.width { continue }
                let cell = source.cells[sourceY * source.width + sourceX]
                cells[dy * width + dx] = cell
            }
        }
    }

    public mutating func drawBorder(rect: Rect, style: BorderStyle = .single, fg: ANSIColor = .default, bg: ANSIColor = .default) {
        guard let clipped = rect.intersection(Rect(x: 0, y: 0, width: width, height: height)) else { return }
        let chars = style.characters
        for x in clipped.origin.x..<clipped.origin.x + clipped.size.width {
            // top
            put(x: x, y: clipped.origin.y, char: chars.horizontal, fg: fg, bg: bg)
            // bottom
            put(x: x, y: clipped.origin.y + clipped.size.height - 1, char: chars.horizontal, fg: fg, bg: bg)
        }
        for y in clipped.origin.y..<clipped.origin.y + clipped.size.height {
            // left
            put(x: clipped.origin.x, y: y, char: chars.vertical, fg: fg, bg: bg)
            // right
            put(x: clipped.origin.x + clipped.size.width - 1, y: y, char: chars.vertical, fg: fg, bg: bg)
        }
        put(x: clipped.origin.x, y: clipped.origin.y, char: chars.topLeft, fg: fg, bg: bg)
        put(x: clipped.origin.x + clipped.size.width - 1, y: clipped.origin.y, char: chars.topRight, fg: fg, bg: bg)
        put(x: clipped.origin.x, y: clipped.origin.y + clipped.size.height - 1, char: chars.bottomLeft, fg: fg, bg: bg)
        put(x: clipped.origin.x + clipped.size.width - 1, y: clipped.origin.y + clipped.size.height - 1, char: chars.bottomRight, fg: fg, bg: bg)
    }

    public mutating func fillRow(y: Int, char: Character = " ", fg: ANSIColor = .default, bg: ANSIColor = .default) {
        guard y >= 0, y < height else { return }
        let rowStart = y * width
        for i in 0..<width {
            cells[rowStart + i] = Cell(character: char, foregroundColor: fg, backgroundColor: bg)
        }
    }

    public func blit(to terminal: TerminalProtocol, at origin: Point) {
        for y in 0..<height {
            for x in 0..<width {
                let cell = cells[y * width + x]
                terminal.writeToBuffer(
                    x: origin.x + x,
                    y: origin.y + y,
                    char: cell.character,
                    foreground: cell.foregroundColor,
                    background: cell.backgroundColor
                )
            }
        }
    }
}

public enum BorderStyle {
    case single
    case double

    var characters: (horizontal: Character, vertical: Character, topLeft: Character, topRight: Character, bottomLeft: Character, bottomRight: Character) {
        switch self {
        case .single:
            return ("─", "│", "┌", "┐", "└", "┘")
        case .double:
            return ("═", "║", "╔", "╗", "╚", "╝")
        }
    }
}
