import Foundation

public struct Cell: Equatable {
    public var character: Character
    public var foregroundColor: ANSIColor
    public var backgroundColor: ANSIColor

    public init(character: Character = " ", foregroundColor: ANSIColor = .default, backgroundColor: ANSIColor = .default) {
        self.character = character
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
    }
}

public struct ScreenBuffer {
    public private(set) var width: Int
    public private(set) var height: Int
    private var buffer: [Cell]
    private var changeTrackingEnabled: Bool = false
    private var changedCells: Set<Int> = []

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.buffer = Array(repeating: Cell(), count: width * height)
    }

    public mutating func resize(width: Int, height: Int) {
        if self.width == width && self.height == height { return }

        let newBuffer = Array(repeating: Cell(), count: width * height)
        // TODO: Copy existing content to new buffer if needed, handling size changes
        self.width = width
        self.height = height
        self.buffer = newBuffer
    }

    public mutating func setCell(x: Int, y: Int, cell: Cell) {
        guard x >= 0 && x < width && y >= 0 && y < height else { return }
        let index = y * width + x
        let previous = buffer[index]
        buffer[index] = cell
        if changeTrackingEnabled && previous != cell {
            changedCells.insert(index)
        }
    }

    public func getCell(x: Int, y: Int) -> Cell? {
        guard x >= 0 && x < width && y >= 0 && y < height else { return nil }
        return buffer[y * width + x]
    }

    public mutating func fill(with cell: Cell) {
        buffer = Array(repeating: cell, count: width * height)
    }

    public func getBuffer() -> [Cell] {
        return buffer
    }

    public mutating func enableChangeTracking(_ enabled: Bool) {
        changeTrackingEnabled = enabled
        if !enabled {
            changedCells.removeAll(keepingCapacity: true)
        }
    }

    public func snapshot() -> ScreenSnapshot {
        return ScreenSnapshot(width: width, height: height, cells: buffer)
    }

    public func diffSinceTrackingEnabled() -> [Rect] {
        guard changeTrackingEnabled, !changedCells.isEmpty else { return [] }
        var rectangles: [Rect] = []
        for index in changedCells {
            let y = index / width
            let x = index % width
            rectangles.append(Rect(x: x, y: y, width: 1, height: 1))
        }
        return rectangles
    }
}

public struct ScreenSnapshot {
    public let width: Int
    public let height: Int
    public let cells: [Cell]

    public func asciiRepresentation() -> [String] {
        var lines: [String] = []
        lines.reserveCapacity(height)
        for row in 0..<height {
            let start = row * width
            let end = start + width
            let lineCells = cells[start..<end]
            let line = lineCells.map { String($0.character) }.joined()
            lines.append(line)
        }
        return lines
    }

    public func comparison(with other: ScreenSnapshot) -> [Rect] {
        guard width == other.width, height == other.height else { return [] }
        var differingRects: [Rect] = []
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                if cells[index] != other.cells[index] {
                    differingRects.append(Rect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
        return differingRects
    }

    public func toANSIString() -> String {
        return asciiRepresentation().joined(separator: "\n")
    }
}

public extension Cell {
    func withInvertedColors() -> Cell {
        var copy = self
        let fg = copy.foregroundColor
        copy.foregroundColor = copy.backgroundColor
        copy.backgroundColor = fg
        return copy
    }
}
