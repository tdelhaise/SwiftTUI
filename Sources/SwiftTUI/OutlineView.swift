import Foundation

/// Simple tree node used by OutlineView.
public struct OutlineNode {
    public var title: String
    public var children: [OutlineNode]
    public var expanded: Bool

    public init(title: String, children: [OutlineNode] = [], expanded: Bool = false) {
        self.title = title
        self.children = children
        self.expanded = expanded
    }

    public var isLeaf: Bool { children.isEmpty }
}

/// TVision-style outline/tree viewer using the Scroller container.
@MainActor
open class OutlineView: Scroller {
    public var nodes: [OutlineNode] {
        didSet { rebuildVisible(); setNeedsDisplay() }
    }

    public var selectedIndex: Int = 0 {
        didSet {
            selectedIndex = max(0, min(selectedIndex, visibleNodes.count - 1))
            setNeedsDisplay()
        }
    }

    public var onSelect: ((OutlineNode) -> Void)?

    private struct VisibleEntry {
        var node: OutlineNode
        var depth: Int
        var path: [Int]
    }

    private var visibleNodes: [VisibleEntry] = []

    public init(frame: Rect, nodes: [OutlineNode]) {
        self.nodes = nodes
        super.init(frame: frame, contentSize: Size(width: frame.size.width, height: 0))
        rebuildVisible()
    }

    // MARK: - Rendering
    override open func drawContent(in visible: Rect) {
        let startRow = visible.origin.y
        let endRow = min(visible.origin.y + visible.size.height, visibleNodes.count)
        for index in startRow..<endRow {
            let entry = visibleNodes[index]
            let rowY = frame.origin.y + (index - visible.origin.y)
            let isSelected = (index == selectedIndex)
            let colors = isSelected ? Application.currentColorTheme.currentPalette[.listSelected] : Application.currentColorTheme.currentPalette[.desktop]
            let indent = String(repeating: " ", count: entry.depth * 2)
            let indicator: String
            if entry.node.isLeaf {
                indicator = "•"
            } else {
                indicator = entry.node.expanded ? "▼" : "▶"
            }
            let text = "\(indent)\(indicator) \(entry.node.title)"
            let clipped = String(text.prefix(visible.size.width))

            for (offset, char) in clipped.enumerated() {
                Application.shared.terminal.writeToBuffer(
                    x: frame.origin.x + offset,
                    y: rowY,
                    char: char,
                    foreground: colors.foreground,
                    background: colors.background
                )
            }
            // Fill remainder
            for offset in clipped.count..<visible.size.width {
                Application.shared.terminal.writeToBuffer(
                    x: frame.origin.x + offset,
                    y: rowY,
                    char: " ",
                    foreground: colors.foreground,
                    background: colors.background
                )
            }
        }
    }

    // MARK: - Input
    override open func handle(keyEvent: KeyEvent) -> Bool {
        switch keyEvent.keyCode {
        case KeyEvent.KeyCode.upArrow:
            selectedIndex = max(0, selectedIndex - 1)
            clampSelectionIntoView()
            return true
        case KeyEvent.KeyCode.downArrow:
            selectedIndex = min(visibleNodes.count - 1, selectedIndex + 1)
            clampSelectionIntoView()
            return true
        case KeyEvent.KeyCode.leftArrow:
            collapseSelection()
            return true
        case KeyEvent.KeyCode.rightArrow:
            expandSelection()
            return true
        case KeyEvent.KeyCode.enter, 32:
            toggleSelection()
            if let node = currentSelection() {
                onSelect?(node)
            }
            return true
        default:
            break
        }
        return super.handle(keyEvent: keyEvent)
    }

    override open func handle(mouseEvent: MouseEvent) -> Bool {
        if mouseEvent.eventType == .mouseDown {
            let localY = mouseEvent.y - frame.origin.y
            let targetIndex = origin.y + localY
            if targetIndex >= 0 && targetIndex < visibleNodes.count {
                selectedIndex = targetIndex
                clampSelectionIntoView()
                let entry = visibleNodes[targetIndex]
                let relX = mouseEvent.x - frame.origin.x
                let indicatorCol = entry.depth * 2
                if relX <= indicatorCol + 1 {
                    toggleSelection()
                }
                return true
            }
        }
        return super.handle(mouseEvent: mouseEvent)
    }

    // MARK: - Helpers
    private func rebuildVisible() {
        visibleNodes = []
        for (idx, node) in nodes.enumerated() {
            flatten(node: node, depth: 0, path: [idx])
        }
        contentSize = Size(width: frame.size.width, height: visibleNodes.count)
        selectedIndex = min(selectedIndex, max(visibleNodes.count - 1, 0))
    }

    private func flatten(node: OutlineNode, depth: Int, path: [Int]) {
        visibleNodes.append(VisibleEntry(node: node, depth: depth, path: path))
        if node.expanded {
            for (idx, child) in node.children.enumerated() {
                flatten(node: child, depth: depth + 1, path: path + [idx])
            }
        }
    }

    private func updateNode(at path: [Int], transform: (inout OutlineNode) -> Void) {
        guard !path.isEmpty else { return }
        func apply(_ nodes: inout [OutlineNode], path: ArraySlice<Int>) {
            guard let first = path.first, first < nodes.count else { return }
            if path.count == 1 {
                transform(&nodes[first])
            } else {
                apply(&nodes[first].children, path: path.dropFirst())
            }
        }
        var roots = nodes
        apply(&roots, path: ArraySlice(path))
        nodes = roots
    }

    private func currentSelection() -> OutlineNode? {
        guard selectedIndex >= 0 && selectedIndex < visibleNodes.count else { return nil }
        return visibleNodes[selectedIndex].node
    }

    private func expandSelection() {
        guard selectedIndex >= 0 && selectedIndex < visibleNodes.count else { return }
        let entry = visibleNodes[selectedIndex]
        if !entry.node.isLeaf && !entry.node.expanded {
            updateNode(at: entry.path) { $0.expanded = true }
            rebuildVisible()
        }
    }

    private func collapseSelection() {
        guard selectedIndex >= 0 && selectedIndex < visibleNodes.count else { return }
        let entry = visibleNodes[selectedIndex]
        if entry.node.expanded && !entry.node.isLeaf {
            updateNode(at: entry.path) { $0.expanded = false }
            rebuildVisible()
        } else if entry.depth > 0 {
            // move to parent
            for (idx, visible) in visibleNodes.enumerated().reversed() where visible.depth < entry.depth && idx < selectedIndex {
                selectedIndex = idx
                break
            }
            clampSelectionIntoView()
        }
    }

    private func clampSelectionIntoView() {
        if selectedIndex < origin.y {
            scrollTo(x: origin.x, y: selectedIndex)
        } else if selectedIndex >= origin.y + frame.size.height {
            scrollTo(x: origin.x, y: selectedIndex - frame.size.height + 1)
        }
    }

    private func toggleSelection() {
        guard selectedIndex >= 0 && selectedIndex < visibleNodes.count else { return }
        let entry = visibleNodes[selectedIndex]
        if entry.node.isLeaf { return }
        if entry.node.expanded {
            collapseSelection()
        } else {
            expandSelection()
        }
    }
}
