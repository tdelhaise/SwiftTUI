import Foundation

/// Helpers for text padding, truncation, and measurement.
public enum TextFormatter {
    /// Truncates a string to fit `width` using ellipsis if needed.
    public static func truncated(_ text: String, width: Int, ellipsis: String = "…") -> String {
        guard width > 0 else { return "" }
        if displayWidth(of: text) <= width {
            return text
        }
        let ellipsisWidth = displayWidth(of: ellipsis)
        let target = max(0, width - ellipsisWidth)
        var result = ""
        var current = 0
        for scalar in text.unicodeScalars {
            let w = displayWidth(of: String(scalar))
            if current + w > target { break }
            result.unicodeScalars.append(scalar)
            current += w
        }
        return result + ellipsis
    }

    /// Pads or truncates text to exactly `width` using the desired alignment.
    public static func fit(_ text: String, width: Int, alignment: TextAlignment = .left, ellipsis: String = "…") -> String {
        guard width > 0 else { return "" }
        let truncatedText = truncated(text, width: width, ellipsis: ellipsis)
        let textWidth = displayWidth(of: truncatedText)
        let pad = max(0, width - textWidth)
        let leftPad: Int
        let rightPad: Int
        switch alignment {
        case .left:
            leftPad = 0
            rightPad = pad
        case .right:
            leftPad = pad
            rightPad = 0
        case .center:
            leftPad = pad / 2
            rightPad = pad - leftPad
        }
        return String(repeating: " ", count: leftPad) + truncatedText + String(repeating: " ", count: rightPad)
    }

    /// Approximates display width (counts simple scalars as width 1; surrogate for future double-width handling).
    public static func displayWidth(of text: String) -> Int {
        // TODO: enhance with proper width computation for wide/combining chars if needed.
        return text.count
    }
}
