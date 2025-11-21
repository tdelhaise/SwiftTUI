import Foundation

/// Lightweight clipping wrapper to simplify drawing into a bounded region.
@MainActor
public struct ClipSurface {
    public var surface: Surface
    public let clipRect: Rect

    public init(surface: Surface, clipRect: Rect) {
        self.surface = surface
        self.clipRect = clipRect
    }

    public mutating func put(x: Int, y: Int, char: Character, fg: ANSIColor = .default, bg: ANSIColor = .default) {
        guard clipRect.contains(Point(x: x, y: y)) else { return }
        surface.put(x: x, y: y, char: char, fg: fg, bg: bg)
    }

    public mutating func fillRect(x: Int, y: Int, w: Int, h: Int, char: Character = " ", fg: ANSIColor = .default, bg: ANSIColor = .default) {
        let rect = Rect(x: x, y: y, width: w, height: h)
        guard let intersection = rect.intersection(clipRect) else { return }
        surface.fillRect(x: intersection.origin.x, y: intersection.origin.y, w: intersection.size.width, h: intersection.size.height, char: char, fg: fg, bg: bg)
    }

    public mutating func putString(x: Int, y: Int, text: String, fg: ANSIColor = .default, bg: ANSIColor = .default) {
        guard y >= clipRect.origin.y && y < clipRect.origin.y + clipRect.size.height else { return }
        let startX = max(x, clipRect.origin.x)
        let maxX = clipRect.origin.x + clipRect.size.width
        var cursor = startX
        for ch in text {
            if cursor >= maxX { break }
            surface.put(x: cursor, y: y, char: ch, fg: fg, bg: bg)
            cursor += 1
        }
    }

    public func blit(to terminal: TerminalProtocol, at origin: Point) {
        surface.blit(to: terminal, at: origin)
    }
}
