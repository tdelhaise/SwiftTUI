import Foundation

/// Directory viewer built on OutlineView. Builds a simple file tree up to a given depth.
@MainActor
open class DirViewer: OutlineView {
    public init(frame: Rect, rootPath: String, maxDepth: Int = 3) {
        let nodes = DirViewer.buildNodes(path: rootPath, depth: 0, maxDepth: maxDepth)
        super.init(frame: frame, nodes: nodes)
    }

    private static func buildNodes(path: String, depth: Int, maxDepth: Int) -> [OutlineNode] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: path) else { return [] }
        var result: [OutlineNode] = []
        for entry in entries.sorted() {
            let full = (path as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: full, isDirectory: &isDir)
            if isDir.boolValue {
                let children: [OutlineNode]
                if depth < maxDepth {
                    children = buildNodes(path: full, depth: depth + 1, maxDepth: maxDepth)
                } else {
                    children = []
                }
                result.append(OutlineNode(title: entry + "/", children: children, expanded: false))
            } else {
                result.append(OutlineNode(title: entry, children: [], expanded: false))
            }
        }
        return result
    }
}
