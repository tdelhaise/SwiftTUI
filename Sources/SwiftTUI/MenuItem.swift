import Foundation

public struct MenuItem {
    public let title: String
    public let command: Command?
    public let shortcut: Character? // e.g., 'F' for File menu
    public let subitems: [MenuItem]?

    public init(title: String, command: Command? = nil, shortcut: Character? = nil, subitems: [MenuItem]? = nil) {
        self.title = title
        self.command = command
        self.shortcut = shortcut
        self.subitems = subitems
    }
}
