import Foundation

/// TVision-style ComboBox: text input with dropdown list / history selection.
@MainActor
open class ComboBox: BaseView {
    public var items: [String] {
        didSet { dropdownList.items = items; dropdownList.selectedIndex = 0 }
    }
    public var selectedIndex: Int = -1
    public var text: String {
        get { inputLine.text }
        set { inputLine.text = newValue }
    }

    public let inputLine: InputLine
    private let dropdownList: ListBox
    private var dropdownVisible: Bool = false

    public let historyManager: HistoryManager?
    private var historyWindow: HistoryWindow?

    public init(frame: Rect, items: [String] = [], historyManager: HistoryManager? = nil) {
        self.items = items
        self.inputLine = InputLine(frame: Rect(x: 0, y: 0, width: max(1, frame.size.width - 1), height: 1))
        self.dropdownList = ListBox(frame: Rect(x: 0, y: 1, width: frame.size.width, height: max(1, min(6, items.count))), items: items)
        self.historyManager = historyManager
        super.init(frame: frame)
        inputLine.owner = self
        add(subview: inputLine)
        dropdownList.owner = self
    }

    override open func draw(in rect: Rect) {
        super.draw(in: rect)
        // Draw the input line in place.
        inputLine.frame = Rect(x: frame.origin.x, y: frame.origin.y, width: max(1, frame.size.width - 1), height: 1)
        inputLine.draw(in: rect)

        // Draw the dropdown button
        let buttonX = frame.origin.x + frame.size.width - 1
        let buttonY = frame.origin.y
        Application.shared.terminal.writeToBuffer(x: buttonX, y: buttonY, char: "▼", foreground: .default, background: .default)

        // Draw dropdown if visible
        if dropdownVisible {
            dropdownList.frame = Rect(x: frame.origin.x, y: frame.origin.y + 1, width: frame.size.width, height: dropdownList.frame.size.height)
            dropdownList.draw(in: rect)
        }

        // Draw history window if active
        if let hw = historyWindow, hw.state.contains(.sfVisible) {
            hw.draw(in: rect)
        }
    }

    override open func handle(keyEvent: KeyEvent) -> Bool {
        if dropdownVisible {
            if keyEvent.keyCode == KeyEvent.KeyCode.escape {
                hideDropdown()
                return true
            }
            if dropdownList.handle(keyEvent: keyEvent) {
                if keyEvent.keyCode == KeyEvent.KeyCode.enter {
                    commitSelection(index: dropdownList.selectedIndex ?? -1)
                    return true
                }
                return true
            }
        }

        if keyEvent.keyCode == KeyEvent.KeyCode.downArrow && keyEvent.controlKeyState.contains(.alt) == false {
            toggleDropdown(fromHistory: false)
            return true
        }
        if keyEvent.keyCode == KeyEvent.KeyCode.f3, let _ = historyManager {
            showHistory()
            return true
        }
        if inputLine.handle(keyEvent: keyEvent) {
            return true
        }
        return super.handle(keyEvent: keyEvent)
    }

    override open func handle(mouseEvent: MouseEvent) -> Bool {
        let globalDropButton = Rect(x: frame.origin.x + frame.size.width - 1, y: frame.origin.y, width: 1, height: 1)
        if globalDropButton.contains(mouseEvent.position) && mouseEvent.eventType == .mouseDown {
            toggleDropdown(fromHistory: false)
            return true
        }

        if dropdownVisible && dropdownList.handle(mouseEvent: mouseEvent) {
            if mouseEvent.eventType == .mouseUp {
                commitSelection(index: dropdownList.selectedIndex ?? -1)
            }
            return true
        }

        if inputLine.handle(mouseEvent: mouseEvent) {
            return true
        }

        if let hw = historyWindow, hw.state.contains(.sfVisible) {
            if hw.handle(mouseEvent: mouseEvent) {
                return true
            }
        }

        return super.handle(mouseEvent: mouseEvent)
    }

    private func toggleDropdown(fromHistory: Bool) {
        dropdownVisible.toggle()
        if dropdownVisible {
            dropdownList.items = fromHistory ? (historyManager?.allEntries().map { $0.text }.reversed() ?? []) : items
            dropdownList.selectedIndex = max(0, dropdownList.selectedIndex ?? 0)
        }
        setNeedsDisplay()
    }

    private func hideDropdown() {
        dropdownVisible = false
        setNeedsDisplay()
    }

    private func commitSelection(index: Int) {
        guard index >= 0 else { hideDropdown(); return }
        let source = dropdownList.items
        guard index < source.count else { hideDropdown(); return }
        let value = source[index]
        inputLine.text = value
        selectedIndex = items.firstIndex(of: value) ?? index
        hideDropdown()
    }

    private func showHistory() {
        guard let historyManager = historyManager else { return }
        if historyWindow == nil {
            let hwFrame = Rect(x: frame.origin.x, y: frame.origin.y + 1, width: frame.size.width, height: min(6, max(1, historyManager.allEntries().count)))
            let hw = HistoryWindow(frame: hwFrame, historyManager: historyManager)
            hw.owner = self
            hw.onSelect = { [weak self] value in
                self?.inputLine.text = value
                self?.setNeedsDisplay()
            }
            historyWindow = hw
            add(subview: hw)
        }
        historyWindow?.refresh()
        historyWindow?.setState(.sfVisible, enable: true)
        setNeedsDisplay()
    }
}
