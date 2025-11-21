import Foundation

/// TVision-style scroller container: manages scroll offsets and keeps optional
/// horizontal/vertical scroll bars in sync. Subclasses should override
/// `drawContent(in:)` to render the visible portion of their content.
@MainActor
open class Scroller: BaseView {
    public var contentSize: Size {
        didSet { origin = clamp(origin); updateScrollBars(); setNeedsDisplay() }
    }

    private var _origin: Point = .zero
    public private(set) var origin: Point {
        get { _origin }
        set {
            let clamped = clamp(newValue)
            guard clamped != _origin else { return }
            _origin = clamped
            updateScrollBars()
            setNeedsDisplay()
        }
    }

    public var horizontalScrollBar: ScrollBar?
    public var verticalScrollBar: ScrollBar?

    public init(frame: Rect, contentSize: Size = .zero) {
        self.contentSize = contentSize
        super.init(frame: frame)
        self.options.insert(.ofSelectable)
    }

    /// Attach scroll bars that will be kept in sync with the scroller.
    public func attachScrollBars(horizontal: ScrollBar?, vertical: ScrollBar?) {
        self.horizontalScrollBar = horizontal
        self.verticalScrollBar = vertical

        if let h = horizontal {
            h.onScroll = { [weak self] pos in self?.scrollTo(x: pos, y: self?.origin.y ?? 0) }
            add(subview: h)
        }
        if let v = vertical {
            v.onScroll = { [weak self] pos in self?.scrollTo(x: self?.origin.x ?? 0, y: pos) }
            add(subview: v)
        }
        updateScrollBars()
    }

    /// Scrolls to the given origin (clamped to content bounds).
    public func scrollTo(x: Int, y: Int) {
        origin = Point(x: x, y: y)
    }

    /// Scroll by the provided delta.
    @discardableResult
    public func scrollBy(dx: Int, dy: Int) -> Bool {
        let newX = origin.x + dx
        let newY = origin.y + dy
        let newOrigin = Point(x: newX, y: newY)
        if newOrigin != origin {
            origin = newOrigin
            return true
        }
        return false
    }

    override open func draw(in rect: Rect) {
        super.draw(in: rect)
        let visibleRect = Rect(x: origin.x, y: origin.y, width: frame.size.width, height: frame.size.height)
        drawContent(in: visibleRect)
    }

    /// Override in subclasses to draw the visible content area.
    open func drawContent(in visible: Rect) {
        // Default: no content. Subclasses should render using `visible` as the window into their data.
    }

    override open func handle(keyEvent: KeyEvent) -> Bool {
        let pageHeight = max(1, frame.size.height)
        switch keyEvent.keyCode {
        case KeyEvent.KeyCode.upArrow:
            return scrollBy(dx: 0, dy: -1)
        case KeyEvent.KeyCode.downArrow:
            return scrollBy(dx: 0, dy: 1)
        case KeyEvent.KeyCode.leftArrow:
            return scrollBy(dx: -1, dy: 0)
        case KeyEvent.KeyCode.rightArrow:
            return scrollBy(dx: 1, dy: 0)
        case KeyEvent.KeyCode.pageUp:
            return scrollBy(dx: 0, dy: -pageHeight)
        case KeyEvent.KeyCode.pageDown:
            return scrollBy(dx: 0, dy: pageHeight)
        case KeyEvent.KeyCode.home:
            return scrollBy(dx: -origin.x, dy: -origin.y)
        case KeyEvent.KeyCode.end:
            let maxY = max(0, contentSize.height - frame.size.height)
            return scrollBy(dx: -origin.x, dy: maxY - origin.y)
        default:
            break
        }
        return super.handle(keyEvent: keyEvent)
    }

    override open func handle(mouseEvent: MouseEvent) -> Bool {
        return super.handle(mouseEvent: mouseEvent)
    }

    // MARK: - Helpers

    private func clamp(_ point: Point) -> Point {
        let maxX = max(0, contentSize.width - frame.size.width)
        let maxY = max(0, contentSize.height - frame.size.height)
        let x = max(0, min(point.x, maxX))
        let y = max(0, min(point.y, maxY))
        return Point(x: x, y: y)
    }

    private func updateScrollBars() {
        let maxX = max(0, contentSize.width - 1)
        let maxY = max(0, contentSize.height - 1)
        horizontalScrollBar?.range = 0...maxX
        horizontalScrollBar?.pageSize = frame.size.width
        horizontalScrollBar?.position = origin.x

        verticalScrollBar?.range = 0...maxY
        verticalScrollBar?.pageSize = frame.size.height
        verticalScrollBar?.position = origin.y
    }
}
