import Foundation

public struct ColorPair: Equatable, Sendable {
    public var foreground: ANSIColor
    public var background: ANSIColor

    public init(foreground: ANSIColor, background: ANSIColor) {
        self.foreground = foreground
        self.background = background
    }

    public static let `default` = ColorPair(foreground: ANSIColor.default, background: ANSIColor.default)
}

public enum PaletteEntry: CaseIterable, Hashable, Sendable {
    case desktop
    case windowNormal
    case windowActive
    case windowFrame
    case windowTitleNormal
    case windowTitleActive
    case buttonNormal
    case buttonFocused
    case inputNormal
    case inputFocused
    case listNormal
    case listSelected
    case scrollBarTrack
    case scrollBarThumb
    case menuBarNormal
    case menuBarActive
    case menuBoxNormal
    case menuBoxSelected
    case dialogNormal
    case dialogMessage
    case clusterNormal
    case statusLine
    // Add more entries for other UI elements and states
}

public struct Palette: Sendable {
    private var colors: [PaletteEntry: ColorPair]

    public init(colors: [PaletteEntry: ColorPair]) {
        self.colors = colors
    }

    public subscript(entry: PaletteEntry) -> ColorPair {
        get {
            return colors[entry] ?? .default // Return default if not found
        }
        set {
            colors[entry] = newValue
        }
    }

    // Predefined palettes
    public static let defaultBlue: Palette = {
        var p = Palette(colors: [:])
        // TVision-like palette
        p[.desktop] = ColorPair(foreground: .brightWhite, background: .blue)
        p[.windowNormal] = ColorPair(foreground: .brightWhite, background: .blue)
        p[.windowActive] = ColorPair(foreground: .brightWhite, background: .blue)
        p[.windowFrame] = ColorPair(foreground: .brightCyan, background: .blue)
        p[.windowTitleNormal] = ColorPair(foreground: .brightWhite, background: .blue)
        p[.windowTitleActive] = ColorPair(foreground: .brightWhite, background: .blue)
        p[.buttonNormal] = ColorPair(foreground: .brightWhite, background: .blue)
        p[.buttonFocused] = ColorPair(foreground: .brightWhite, background: .brightBlue)
        p[.inputNormal] = ColorPair(foreground: .black, background: .brightWhite)
        p[.inputFocused] = ColorPair(foreground: .black, background: .brightCyan)
        p[.listNormal] = ColorPair(foreground: .brightWhite, background: .blue)
        p[.listSelected] = ColorPair(foreground: .brightWhite, background: .brightBlue)
        p[.scrollBarTrack] = ColorPair(foreground: .white, background: .blue)
        p[.scrollBarThumb] = ColorPair(foreground: .brightWhite, background: .cyan)
        p[.menuBarNormal] = ColorPair(foreground: .brightWhite, background: .brightBlue)
        p[.menuBarActive] = ColorPair(foreground: .brightWhite, background: .cyan)
        p[.menuBoxNormal] = ColorPair(foreground: .brightWhite, background: .blue)
        p[.menuBoxSelected] = ColorPair(foreground: .brightWhite, background: .brightBlue)
        p[.dialogNormal] = ColorPair(foreground: .brightWhite, background: .blue)
        p[.dialogMessage] = ColorPair(foreground: .brightWhite, background: .blue)
        p[.clusterNormal] = ColorPair(foreground: .brightWhite, background: .blue)
        p[.statusLine] = ColorPair(foreground: .brightWhite, background: .cyan)
        return p
    }()
}

public struct ColorTheme: Sendable {
    public var currentPalette: Palette

    public init(palette: Palette) {
        self.currentPalette = palette
    }

    public static let `default` = ColorTheme(palette: .defaultBlue)
}
