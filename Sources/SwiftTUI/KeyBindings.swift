import Foundation

/// Centralized key bindings to align widget shortcuts.
public enum KeyBindings {
    public static let copy: (character: String?, keyCode: Int, modifiers: ControlKeyState) = ("c", Int(("c" as UnicodeScalar).value), [.control])
    public static let paste: (character: String?, keyCode: Int, modifiers: ControlKeyState) = ("v", Int(("v" as UnicodeScalar).value), [.control])
    public static let cut: (character: String?, keyCode: Int, modifiers: ControlKeyState) = ("x", Int(("x" as UnicodeScalar).value), [.control])
    public static let undo: (character: String?, keyCode: Int, modifiers: ControlKeyState) = ("z", Int(("z" as UnicodeScalar).value), [.control])
    public static let redo: (character: String?, keyCode: Int, modifiers: ControlKeyState) = ("y", Int(("y" as UnicodeScalar).value), [.control])
    public static let history: (character: String?, keyCode: Int, modifiers: ControlKeyState) = (nil, KeyEvent.KeyCode.f3, [])
}
