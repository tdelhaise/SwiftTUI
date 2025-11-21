import Foundation

/// Simple help viewer (read-only) built on TextViewer.
@MainActor
open class HelpViewer: TextViewer {
    public init(frame: Rect, helpText: String) {
        super.init(frame: frame, text: helpText)
    }
}
