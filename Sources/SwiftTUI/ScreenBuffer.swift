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
    private var rowDamage: [Range<Int>]

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.buffer = Array(repeating: Cell(), count: width * height)
        self.rowDamage = Array(repeating: 0..<0, count: height)
    }

    public mutating func resize(width: Int, height: Int) {
        if self.width == width && self.height == height { return }
        var newBuffer = Array(repeating: Cell(), count: width * height)
        let copyWidth = min(self.width, width)
        let copyHeight = min(self.height, height)
        for y in 0..<copyHeight {
            let oldStart = y * self.width
            let oldEnd = oldStart + copyWidth
            let newStart = y * width
            newBuffer.replaceSubrange(newStart..<(newStart + copyWidth), with: buffer[oldStart..<oldEnd])
        }
        self.width = width
        self.height = height
        self.buffer = newBuffer
        self.rowDamage = Array(repeating: 0..<0, count: height)
    }

    public mutating func setCell(x: Int, y: Int, cell: Cell) {
        guard x >= 0 && x < width && y >= 0 && y < height else { return }
        let index = y * width + x
        if buffer[index] != cell {
            buffer[index] = cell
            markDirty(x: x, y: y)
        }
    }

    public func getCell(x: Int, y: Int) -> Cell? {
        guard x >= 0 && x < width && y >= 0 && y < height else { return nil }
        return buffer[y * width + x]
    }

    public mutating func fill(with cell: Cell) {
        buffer = Array(repeating: cell, count: width * height)
        for y in 0..<height {
            rowDamage[y] = 0..<width
        }
    }

    public func getBuffer() -> [Cell] {
        return buffer
    }

    public func dirtyRanges() -> [(row: Int, range: Range<Int>)] {
        var ranges: [(Int, Range<Int>)] = []
        for (row, range) in rowDamage.enumerated() where !range.isEmpty {
            ranges.append((row, range))
        }
        return ranges
    }

    public mutating func clearDirtyRanges() {
        rowDamage = Array(repeating: 0..<0, count: height)
    }

    private mutating func markDirty(x: Int, y: Int) {
        let range = rowDamage[y]
        if range.isEmpty {
            rowDamage[y] = x..<(x + 1)
        } else {
            let newStart = min(range.lowerBound, x)
            let newEnd = max(range.upperBound, x + 1)
            rowDamage[y] = newStart..<newEnd
        }
    }

    public func snapshot() -> ScreenSnapshot {
        return ScreenSnapshot(width: width, height: height, cells: buffer)
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
