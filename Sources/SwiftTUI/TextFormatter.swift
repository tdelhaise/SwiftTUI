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
        var width = 0
        for scalar in text.unicodeScalars {
            width += widthOfScalar(scalar)
        }
        return width
    }

    private static func widthOfScalar(_ scalar: UnicodeScalar) -> Int {
        // Basic heuristics: combining marks width 0, CJK range width 2, else 1.
        if CharacterSet.nonBaseCharacters.contains(scalar) {
            return 0
        }
        switch scalar.value {
        case 0x1100...0x115F, // Hangul Jamo init. consonants
             0x2E80...0xA4CF, // CJK ... Yi
             0xAC00...0xD7A3, // Hangul Syllables
             0xF900...0xFAFF, // CJK Compatibility Ideographs
             0xFE10...0xFE19,
             0xFE30...0xFE6F,
             0xFF00...0xFF60,
             0xFFE0...0xFFE6,
             0x1F300...0x1F64F, // Emojis, etc.
             0x1F900...0x1F9FF:
            return 2
        default:
            return 1
        }
    }
}
