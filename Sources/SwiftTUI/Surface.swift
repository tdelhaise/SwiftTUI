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
