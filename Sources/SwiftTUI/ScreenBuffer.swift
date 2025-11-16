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

public enum ANSIColor: UInt8, Equatable, Sendable {
    case black = 30
    case red = 31
    case green = 32
    case yellow = 33
    case blue = 34
    case magenta = 35
    case cyan = 36
    case white = 37
    case `default` = 39 // Default foreground/background color

    case brightBlack = 90
    case brightRed = 91
    case brightGreen = 92
    case brightYellow = 93
    case brightBlue = 94
    case brightMagenta = 95
    case brightCyan = 96
    case brightWhite = 97

    // Background colors
    case bgBlack = 40
    case bgRed = 41
    case bgGreen = 42
    case bgYellow = 43
    case bgBlue = 44
    case bgMagenta = 45
    case bgCyan = 46
    case bgWhite = 47
    case bgDefault = 49

    case bgBrightBlack = 100
    case bgBrightRed = 101
    case bgBrightGreen = 102
    case bgBrightYellow = 103
    case bgBrightBlue = 104
    case bgBrightMagenta = 105
    case bgBrightCyan = 106
    case bgBrightWhite = 107

    // Helper to get background color from foreground color
    public var background: ANSIColor {
        switch self {
        case .black: return .bgBlack
        case .red: return .bgRed
        case .green: return .bgGreen
        case .yellow: return .bgYellow
        case .blue: return .bgBlue
        case .magenta: return .bgMagenta
        case .cyan: return .bgCyan
        case .white: return .bgWhite
        case .brightBlack: return .bgBrightBlack
        case .brightRed: return .bgBrightRed
        case .brightGreen: return .bgBrightGreen
        case .brightYellow: return .bgBrightYellow
        case .brightBlue: return .bgBrightBlue
        case .brightMagenta: return .bgBrightMagenta
        case .brightCyan: return .bgBrightCyan
        case .brightWhite: return .bgBrightWhite
        default: return .bgDefault
        }
    }
}

public struct ScreenBuffer {
    public private(set) var width: Int
    public private(set) var height: Int
    private var buffer: [Cell]

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
        buffer[y * width + x] = cell
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
}
