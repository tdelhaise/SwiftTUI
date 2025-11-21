import Foundation

/// Helper to apply selection/highlight styling onto a Surface.
@MainActor
public enum SelectionRenderer {
    public static func highlight(surface: inout Surface, rect: Rect, fg: ANSIColor, bg: ANSIColor) {
        surface.fillRect(x: rect.origin.x, y: rect.origin.y, w: rect.size.width, h: rect.size.height, char: " ", fg: fg, bg: bg)
    }

    public static func invert(surface: inout Surface, rect: Rect) {
        guard rect.size.width > 0, rect.size.height > 0 else { return }
        for y in rect.origin.y..<rect.origin.y + rect.size.height {
            for x in rect.origin.x..<rect.origin.x + rect.size.width {
                guard x >= 0, x < surface.width, y >= 0, y < surface.height else { continue }
                let idx = y * surface.width + x
                var cell = surface.cell(at: idx)
                let oldFg = cell.foregroundColor
                cell.foregroundColor = cell.backgroundColor
                cell.backgroundColor = oldFg
                surface.setCell(at: idx, cell: cell)
            }
        }
    }
}
