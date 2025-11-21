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
        p[.desktop] = ColorPair(foreground: ANSIColor.white, background: ANSIColor.blue)
        p[.windowNormal] = ColorPair(foreground: ANSIColor.white, background: ANSIColor.blue)
        p[.windowActive] = ColorPair(foreground: ANSIColor.brightWhite, background: ANSIColor.blue)
        p[.windowFrame] = ColorPair(foreground: ANSIColor.cyan, background: ANSIColor.blue)
        p[.windowTitleNormal] = ColorPair(foreground: ANSIColor.white, background: ANSIColor.blue)
        p[.windowTitleActive] = ColorPair(foreground: ANSIColor.brightWhite, background: ANSIColor.blue)
        p[.buttonNormal] = ColorPair(foreground: ANSIColor.white, background: ANSIColor.blue)
        p[.buttonFocused] = ColorPair(foreground: ANSIColor.brightWhite, background: ANSIColor.brightBlue)
        p[.inputNormal] = ColorPair(foreground: ANSIColor.white, background: ANSIColor.cyan)
        p[.inputFocused] = ColorPair(foreground: ANSIColor.brightWhite, background: ANSIColor.brightCyan)
        p[.listNormal] = ColorPair(foreground: ANSIColor.white, background: ANSIColor.blue)
        p[.listSelected] = ColorPair(foreground: ANSIColor.brightWhite, background: ANSIColor.brightBlue)
        p[.scrollBarTrack] = ColorPair(foreground: ANSIColor.white, background: ANSIColor.blue)
        p[.scrollBarThumb] = ColorPair(foreground: ANSIColor.brightWhite, background: ANSIColor.cyan)
        p[.menuBarNormal] = ColorPair(foreground: ANSIColor.white, background: ANSIColor.default)
        p[.menuBarActive] = ColorPair(foreground: ANSIColor.brightWhite, background: ANSIColor.blue)
        p[.menuBoxNormal] = ColorPair(foreground: ANSIColor.white, background: ANSIColor.blue)
        p[.menuBoxSelected] = ColorPair(foreground: ANSIColor.brightWhite, background: ANSIColor.brightBlue)
        p[.dialogNormal] = ColorPair(foreground: ANSIColor.white, background: ANSIColor.blue)
        p[.dialogMessage] = ColorPair(foreground: ANSIColor.white, background: ANSIColor.blue)
        p[.clusterNormal] = ColorPair(foreground: ANSIColor.white, background: ANSIColor.default)
        p[.statusLine] = ColorPair(foreground: ANSIColor.white, background: ANSIColor.blue)
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
