import Foundation

/// TVision-style HistoryWindow: a simple popup list backed by a HistoryManager.
@MainActor
open class HistoryWindow: BaseView {
    private let listBox: ListBox
    private let historyManager: HistoryManager
    public var onSelect: ((String) -> Void)?

    public init(frame: Rect, historyManager: HistoryManager) {
        self.historyManager = historyManager
        self.listBox = ListBox(frame: Rect(x: 0, y: 0, width: frame.size.width, height: frame.size.height), items: HistoryWindow.historyManagerItems(historyManager))
        super.init(frame: frame)
        add(subview: listBox)
    }

    open func refresh() {
        listBox.items = Self.historyManagerItems(historyManager)
        listBox.selectedIndex = 0
        setNeedsDisplay()
    }

    override open func handle(keyEvent: KeyEvent) -> Bool {
        if listBox.handle(keyEvent: keyEvent) {
            if keyEvent.keyCode == KeyEvent.KeyCode.enter {
                commitSelection()
                return true
            }
            if keyEvent.keyCode == KeyEvent.KeyCode.escape {
                state.remove(.sfVisible)
                setNeedsDisplay()
                return true
            }
            return true
        }
        return super.handle(keyEvent: keyEvent)
    }

    override open func handle(mouseEvent: MouseEvent) -> Bool {
        if listBox.handle(mouseEvent: mouseEvent) {
            if mouseEvent.eventType == .mouseUp {
                commitSelection()
            }
            return true
        }
        return super.handle(mouseEvent: mouseEvent)
    }

    private func commitSelection() {
        guard let sel = listBox.selectedIndex, sel >= 0, sel < listBox.items.count else { return }
        let value = listBox.items[sel]
        onSelect?(value)
        state.remove(.sfVisible)
        setNeedsDisplay()
    }

    private static func historyManagerItems(_ historyManager: HistoryManager) -> [String] {
        return Array(historyManager.allEntries().map { $0.text }.reversed())
    }
}
