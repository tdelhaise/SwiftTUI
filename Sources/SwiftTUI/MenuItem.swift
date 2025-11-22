import Foundation

public struct MenuItem {
    public let title: String
    public let command: Command?
    public let shortcut: Character? // e.g., 'F' for File menu
    public let subitems: [MenuItem]?
    public let hotkeyHint: String?
    public let isSeparator: Bool

    public init(title: String, command: Command? = nil, shortcut: Character? = nil, subitems: [MenuItem]? = nil, hotkeyHint: String? = nil, isSeparator: Bool = false) {
        self.title = title
        self.command = command
        self.shortcut = shortcut
        self.subitems = subitems
        self.hotkeyHint = hotkeyHint
        self.isSeparator = isSeparator
    }
}
