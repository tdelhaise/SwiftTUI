import Foundation

public enum ScrollBarOrientation {
    case vertical
    case horizontal
}

@MainActor
open class ScrollBar: BaseView {
    public var orientation: ScrollBarOrientation
    public var range: ClosedRange<Int> = 0...100 // Min and Max scrollable value
    public var position: Int = 0 { // Current scroll position
        didSet {
            position = max(range.lowerBound, min(range.upperBound, position))
            if position != oldValue {
                onScroll?(position)
                setNeedsDisplay()
            }
        }
    }
    public var pageSize: Int = 10 // Number of units visible at once

    public var onScroll: ((Int) -> Void)? // Callback for scroll events

    public init(frame: Rect, orientation: ScrollBarOrientation) {
        self.orientation = orientation
        super.init(frame: frame)
        self.options.insert(.ofSelectable) // ScrollBar can be interacted with
    }

    override open func draw(in rect: Rect) {
        super.draw(in: rect)

        let displayX = frame.origin.x
        let displayY = frame.origin.y

        let trackColors = Application.currentColorTheme.currentPalette[.scrollBarTrack]
        let thumbColors = Application.currentColorTheme.currentPalette[.scrollBarThumb]

        let totalRange = range.upperBound - range.lowerBound + 1
        guard totalRange > 0 else { return }

        if orientation == .vertical {
            let trackHeight = frame.size.height
            guard trackHeight > 0 else { return }

            // Draw track
            for yOffset in 0..<trackHeight {
                Application.shared.terminal.writeToBuffer(x: displayX, y: displayY + yOffset, char: "│", foreground: trackColors.foreground, background: trackColors.background)
            }

            // Calculate thumb size and position
            let thumbSize = max(1, (pageSize * trackHeight) / totalRange)
            let thumbStart = (position * (trackHeight - thumbSize)) / (totalRange - pageSize + 1) // +1 to prevent division by zero if totalRange == pageSize

            // Draw thumb
            for yOffset in 0..<thumbSize {
                Application.shared.terminal.writeToBuffer(x: displayX, y: displayY + thumbStart + yOffset, char: "█", foreground: thumbColors.foreground, background: thumbColors.background)
            }

            // Draw arrows (optional)
            Application.shared.terminal.writeToBuffer(x: displayX, y: displayY, char: "▲", foreground: trackColors.foreground, background: trackColors.background)
            Application.shared.terminal.writeToBuffer(x: displayX, y: displayY + trackHeight - 1, char: "▼", foreground: trackColors.foreground, background: trackColors.background)

        } else { // Horizontal
            let trackWidth = frame.size.width
            guard trackWidth > 0 else { return }

            // Draw track
            for xOffset in 0..<trackWidth {
                Application.shared.terminal.writeToBuffer(x: displayX + xOffset, y: displayY, char: "─", foreground: trackColors.foreground, background: trackColors.background)
            }

            // Calculate thumb size and position
            let thumbSize = max(1, (pageSize * trackWidth) / totalRange)
            let thumbStart = (position * (trackWidth - thumbSize)) / (totalRange - pageSize + 1)

            // Draw thumb
            for xOffset in 0..<thumbSize {
                Application.shared.terminal.writeToBuffer(x: displayX + thumbStart + xOffset, y: displayY, char: "█", foreground: thumbColors.foreground, background: thumbColors.background)
            }

            // Draw arrows (optional)
            Application.shared.terminal.writeToBuffer(x: displayX, y: displayY, char: "◀", foreground: trackColors.foreground, background: trackColors.background)
            Application.shared.terminal.writeToBuffer(x: displayX + trackWidth - 1, y: displayY, char: "▶", foreground: trackColors.foreground, background: trackColors.background)
        }
    }

    override open func handle(mouseEvent: MouseEvent) -> Bool {
        guard frame.contains(mouseEvent.position) else { return false }

        if mouseEvent.eventType == .mouseDown {
            // Simulate dragging the thumb or clicking on the track/arrows
            print("  ScrollBar: Mouse down at \(mouseEvent.position)")
            // In a real implementation, this would involve calculating new position
            // based on mouse coordinates and updating 'position' property.
            return true
        }
        // Handle mouse wheel events if they are passed to the scrollbar
        return super.handle(mouseEvent: mouseEvent)
    }
}
