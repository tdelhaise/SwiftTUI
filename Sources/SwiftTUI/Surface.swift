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
