import SwiftTUI
import Foundation

// Entry point for the Swifted (tvedit-like) example.
let app = Application()
Application.currentColorTheme = ColorTheme(palette: .defaultBlue)
let desktopFrame = Rect(origin: .zero, size: app.terminal.windowSize)
let desktop = SwiftedDesktop(frame: desktopFrame)
desktop.installMenuBar()
desktop.installStatusLine()
app.setRootView(desktop)
app.run()

// MARK: - Desktop controller
@MainActor
final class SwiftedDesktop: Desktop {
    private var nextWindowId = 1

    func installMenuBar() {
        let w = frame.size.width
        let menuFrame = Rect(x: 0, y: 0, width: w, height: 1)
        let fileMenu = MenuItem(title: "File", shortcut: "F".first, subitems: [
            MenuItem(title: "Open", command: .cmOpen, shortcut: "O".first),
            MenuItem(title: "New", command: .cmNew, shortcut: "N".first),
            MenuItem(title: "Save", command: .cmSave, shortcut: "S".first),
            MenuItem(title: "Close", command: .cmClose, shortcut: "C".first),
            MenuItem(title: "Quit", command: .cmQuit, shortcut: "Q".first)
        ])
        let editMenu = MenuItem(title: "Edit", shortcut: "E".first, subitems: [
            MenuItem(title: "Undo", command: .cmUndo, shortcut: "U".first),
            MenuItem(title: "Cut", command: .cmCut, shortcut: "T".first),
            MenuItem(title: "Copy", command: .cmCopy, shortcut: "C".first),
            MenuItem(title: "Paste", command: .cmPaste, shortcut: "P".first)
        ])
        let searchMenu = MenuItem(title: "Search", shortcut: "S".first, subitems: [
            MenuItem(title: "Find", command: .cmFind, shortcut: "F".first),
            MenuItem(title: "Replace", command: .cmReplace, shortcut: "R".first),
            MenuItem(title: "Search Again", command: .cmSearchAgain, shortcut: "A".first)
        ])
        let windowMenu = MenuItem(title: "Window", shortcut: "W".first, subitems: [
            MenuItem(title: "Zoom", command: .cmZoom, shortcut: "Z".first),
            MenuItem(title: "Next", command: .cmNext, shortcut: "N".first),
            MenuItem(title: "Previous", command: .cmPrev, shortcut: "P".first),
            MenuItem(title: "Tile", command: .cmTile, shortcut: "T".first),
            MenuItem(title: "Cascade", command: .cmCascade, shortcut: "C".first)
        ])
        let menuBar = MenuBar(frame: menuFrame, menuItems: [fileMenu, editMenu, searchMenu, windowMenu])
        set(menuBar: menuBar)
    }

    func installStatusLine() {
        let h = frame.size.height
        let statusFrame = Rect(x: 0, y: h - 1, width: frame.size.width, height: 1)
let status = StatusLine(frame: statusFrame, message: "Swifted - F2 Save, F3 Open, F10 Menu, Ctrl-Q Quit")
        set(statusLine: status)
    }

    private func activeEditorWindow() -> EditorWindow? {
        return windows.last(where: { $0 is EditorWindow }) as? EditorWindow
    }

    private func openNewWindow(path: String?, visible: Bool = true, content: String = "") {
        let winFrame = Rect(x: 2 + windows.count, y: 2 + windows.count, width: max(50, frame.size.width - 4), height: max(15, frame.size.height - 4))
        let number = nextWindowId
        nextWindowId += 1
        let window = EditorWindow(frame: winFrame, number: number, filePath: path, initialText: content)
        add(window: window)
        if !visible { window.state.remove(.sfVisible) }
    }

    private func promptOpenFile() {
        let dialogSize = Size(width: min(60, frame.size.width - 4), height: min(16, frame.size.height - 4))
        let dialogOrigin = Point(x: (frame.size.width - dialogSize.width) / 2, y: (frame.size.height - dialogSize.height) / 2)
        let dialogFrame = Rect(origin: dialogOrigin, size: dialogSize)
        let fileDialog = FileDialog(frame: dialogFrame, title: "Open file")
        fileDialog.onFileSelected = { [weak self] path in
            guard let self else { return }
            let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
            self.openNewWindow(path: path, content: text)
        }
        add(subview: fileDialog)
    }

    private func saveActiveWindow(asNew: Bool = false) {
        guard let editorWin = activeEditorWindow() else { return }
        if let path = editorWin.filePath, !asNew {
            editorWin.save(to: path)
        } else {
            let dialogSize = Size(width: min(60, frame.size.width - 4), height: min(16, frame.size.height - 4))
            let dialogOrigin = Point(x: (frame.size.width - dialogSize.width) / 2, y: (frame.size.height - dialogSize.height) / 2)
            let dialogFrame = Rect(origin: dialogOrigin, size: dialogSize)
            let fileDialog = FileDialog(frame: dialogFrame, title: "Save file as")
            fileDialog.onFileSelected = { [weak editorWin] path in
                editorWin?.save(to: path)
            }
            add(subview: fileDialog)
        }
    }

    override func handle(command: Command) -> Bool {
        switch command {
        case .cmOpen:
            promptOpenFile()
            return true
        case .cmNew:
            openNewWindow(path: nil, content: "")
            return true
        case .cmSave:
            saveActiveWindow()
            return true
        case .cmClose:
            activeEditorWindow()?.close()
            return true
        case .cmNext:
            if let first = windows.first {
                bringToFront(window: first)
            }
            return true
        case .cmPrev:
            if let last = windows.last {
                bringToFront(window: last)
            }
            return true
        case .cmFind:
            if let editorWin = activeEditorWindow() {
                let dialog = FindDialog { text in
                    editorWin.doFind(text: text)
                }
                add(subview: dialog)
            }
            return true
        case .cmSearchAgain:
            activeEditorWindow()?.doSearchAgain()
            return true
        case .cmReplace:
            if let editorWin = activeEditorWindow() {
                let dialog = ReplaceDialog { find, replace in
                    editorWin.doReplace(find: find, replace: replace)
                }
                add(subview: dialog)
            }
            return true
        default:
            return super.handle(command: command)
        }
    }
}

// MARK: - Editor window
@MainActor
final class EditorWindow: Window {
    let editor: EditorView
    var filePath: String?
    private var lastSearch: String?
    private var lastReplace: String?
    private var isDirty: Bool = false {
        didSet { updateTitle() }
    }

    init(frame: Rect, number: Int, filePath: String?, initialText: String) {
        self.filePath = filePath
        self.editor = EditorView(frame: Rect(x: 1, y: 1, width: frame.size.width - 2, height: frame.size.height - 2), text: initialText)
        super.init(frame: frame, title: filePath ?? "Untitled", number: number)
        flags.insert(.wfClose)
        add(subview: editor)
    }

    private func updateTitle() {
        let name = filePath.map { ($0 as NSString).lastPathComponent } ?? "Untitled"
        self.title = isDirty ? "\(name)*" : name
    }

    func save(to path: String) {
        do {
            try editor.text.write(toFile: path, atomically: true, encoding: .utf8)
            filePath = path
            isDirty = false
            updateTitle()
        } catch {
            if let desktop = Application.shared.rootView as? Desktop {
                let dialog = MessageBox.show(title: "Save error", message: "\(error)")
                desktop.add(subview: dialog)
            }
        }
    }

    override func handle(keyEvent: KeyEvent) -> Bool {
        if editor.handle(keyEvent: keyEvent) {
            isDirty = true
            return true
        }
        return super.handle(keyEvent: keyEvent)
    }

    func doFind(text: String) {
        lastSearch = text
        if editor.find(text) == false {
            showInfo("Search string not found.")
        }
    }

    func doSearchAgain() {
        guard let query = lastSearch else {
            showInfo("No previous search.")
            return
        }
        if editor.find(query, startAtNext: true) == false {
            showInfo("Search string not found.")
        }
    }

    func doReplace(find: String, replace: String) {
        lastSearch = find
        lastReplace = replace
        if editor.replaceFirst(find: find, replace: replace) == false {
            showInfo("Search string not found.")
        } else {
            isDirty = true
        }
    }

    private func showInfo(_ msg: String) {
        if let desktop = Application.shared.rootView as? Desktop {
            let dialog = MessageBox.show(title: "Info", message: msg)
            desktop.add(subview: dialog)
        }
    }
}
