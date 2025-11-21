import Foundation

/// Simple help viewer (read-only) built on TextViewer.
@MainActor
open class HelpViewer: TextViewer {
    public init(frame: Rect, helpText: String, highlightLine: Int? = nil) {
        super.init(frame: frame, text: helpText)
        self.highlightLine = highlightLine
    }

    /// Jump to the first occurrence of a topic string.
    @discardableResult
    public func jump(to topic: String) -> Int? {
        return find(topic, caseInsensitive: true, startAt: 0)
    }
}
