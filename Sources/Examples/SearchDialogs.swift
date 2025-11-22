import SwiftTUI

@MainActor
final class FindDialog: Dialog {
    private let input: InputLine
    private let onFind: (String) -> Void

    init(onFind: @escaping (String) -> Void) {
        self.onFind = onFind
        let frame = Rect(x: 0, y: 0, width: 30, height: 6)
        self.input = InputLine(frame: Rect(x: 2, y: 2, width: 26, height: 1))
        super.init(frame: frame, title: "Find", message: "")
        add(subview: input)
        let okButton = Button(frame: Rect(x: 2, y: 4, width: 10, height: 1), title: "OK") { [weak self] in
            guard let self else { return }
            onFind(input.text)
            close()
        }
        let cancelButton = Button(frame: Rect(x: 14, y: 4, width: 10, height: 1), title: "Cancel") { [weak self] in
            self?.close()
        }
        add(subview: okButton)
        add(subview: cancelButton)
    }
}

@MainActor
final class ReplaceDialog: Dialog {
    private let findInput: InputLine
    private let replaceInput: InputLine
    private let onReplace: (String, String) -> Void

    init(onReplace: @escaping (String, String) -> Void) {
        self.onReplace = onReplace
        let frame = Rect(x: 0, y: 0, width: 32, height: 9)
        self.findInput = InputLine(frame: Rect(x: 2, y: 2, width: 28, height: 1))
        self.replaceInput = InputLine(frame: Rect(x: 2, y: 4, width: 28, height: 1))
        super.init(frame: frame, title: "Replace", message: "")
        add(subview: findInput)
        add(subview: replaceInput)

        let okButton = Button(frame: Rect(x: 2, y: 6, width: 10, height: 1), title: "OK") { [weak self] in
            guard let self else { return }
            onReplace(findInput.text, replaceInput.text)
            close()
        }
        let cancelButton = Button(frame: Rect(x: 14, y: 6, width: 10, height: 1), title: "Cancel") { [weak self] in
            self?.close()
        }
        add(subview: okButton)
        add(subview: cancelButton)
    }
}
