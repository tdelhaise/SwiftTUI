import SwiftTUI

@main
struct HelloWorld {
    static func main() {
        let application = Application()
        let desktop = Desktop(frame: Rect(origin: .zero, size: application.terminal.windowSize))
        
        let fileMenu = MenuItem(title: "File", shortcut: "F", subitems: [
            MenuItem(title: "Quit", command: .cmQuit)
        ])
        let menuBar = MenuBar(frame: Rect(x: 0, y: 0, width: application.terminal.windowSize.width, height: 1), menuItems: [fileMenu])
        desktop.set(menuBar: menuBar)

        let window = Window(frame: Rect(x: 10, y: 5, width: 40, height: 10), title: "Hello World", number: 0)
        let label = Label(frame: Rect(x: 2, y: 2, width: 36, height: 1), text: "Hello, SwiftTUI!")
        window.add(subview: label)
        desktop.add(subview: window)
        
        application.setRootView(desktop)
        application.run()
    }
}
