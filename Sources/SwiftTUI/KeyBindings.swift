import Foundation

/// Centralized key bindings to align widget shortcuts.
public enum KeyBindings {
    public static let copy: (character: String?, keyCode: Int, modifiers: ControlKeyState) = scalarBinding("c", mods: [.control])
    public static let paste: (character: String?, keyCode: Int, modifiers: ControlKeyState) = scalarBinding("v", mods: [.control])
    public static let cut: (character: String?, keyCode: Int, modifiers: ControlKeyState) = scalarBinding("x", mods: [.control])
    public static let undo: (character: String?, keyCode: Int, modifiers: ControlKeyState) = scalarBinding("z", mods: [.control])
    public static let redo: (character: String?, keyCode: Int, modifiers: ControlKeyState) = scalarBinding("y", mods: [.control])
    public static let history: (character: String?, keyCode: Int, modifiers: ControlKeyState) = (nil, KeyEvent.KeyCode.f3, [])

    private static func scalarBinding(_ char: String, mods: ControlKeyState) -> (String?, Int, ControlKeyState) {
        let scalar = char.unicodeScalars.first?.value ?? 0
        return (char, Int(scalar), mods)
    }
}
