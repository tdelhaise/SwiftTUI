import Foundation

@MainActor
open class FileDialog: Window {
    public var currentPath: String {
        didSet {
            if currentPath != oldValue {
                loadDirectoryContents()
                setNeedsDisplay()
            }
        }
    }
    public private(set) var contents: [String] = []
    public var selectedItem: String? {
        didSet {
            if selectedItem != oldValue {
                setNeedsDisplay()
            }
        }
    }
    public var onFileSelected: ((String) -> Void)?

    private var listFrame: Rect
    private var listbox: ListBox

    public init(frame: Rect, title: String, initialPath: String = FileManager.default.currentDirectoryPath) {
        self.currentPath = initialPath
        
        // Calculate frame for the ListBox within the dialog
        // Assuming a border of 1 on all sides, and space for title/buttons
        let listOrigin = Point(x: 1, y: 1)
        let listSize = Size(width: frame.size.width - 2, height: frame.size.height - 2)
        self.listFrame = Rect(origin: listOrigin, size: listSize)
        
        self.listbox = ListBox(frame: listFrame, items: []) // Initialize with empty items
        
        super.init(frame: frame, title: title, number: 0)
        
        self.flags.insert(.wfModal)
        self.flags.remove([.wfGrow, .wfZoom]) // File dialogs are typically not resizable or zoomable
        
        add(subview: listbox)
        loadDirectoryContents()
    }

    private func loadDirectoryContents() {
        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: currentPath)
            // Filter out hidden files and sort
            contents = items.filter { !$0.hasPrefix(".") }.sorted()
            
            // Add ".." for navigating up
            if currentPath != "/" {
                contents.insert("..", at: 0)
            }
            
            listbox.items = contents
            listbox.selectedIndex = contents.isEmpty ? nil : 0
        } catch {
            print("Error loading directory contents: \(error)")
            contents = []
            listbox.items = []
            listbox.selectedIndex = nil
        }
    }

    override open func handle(keyEvent: KeyEvent) -> Bool {
        if super.handle(keyEvent: keyEvent) { return true } // Let super handle first

        guard state.contains(.sfFocused) else { return false }

        switch keyEvent.keyCode {
        case KeyEvent.KeyCode.enter:
            if let selectedIndex = listbox.selectedIndex, selectedIndex < listbox.items.count {
                let selected = listbox.items[selectedIndex]
                let fullPath = (currentPath as NSString).appendingPathComponent(selected)
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        currentPath = fullPath // Navigate into directory
                    } else {
                        onFileSelected?(fullPath) // Select file
                        close()
                    }
                }
            }
            return true
        case KeyEvent.KeyCode.escape:
            close() // Close dialog on escape
            return true
        default:
            break
        }
        return false
    }
    
    // Override draw to ensure ListBox is drawn correctly
    override open func draw(in rect: Rect) {
        super.draw(in: rect) // Draw window frame and title
        
        // The ListBox is a subview, so it will be drawn by BaseView's draw method.
        // We just need to ensure its frame is correct and it's visible.
        listbox.frame = Rect(origin: Point(x: frame.origin.x + 1, y: frame.origin.y + 1), 
                             size: Size(width: frame.size.width - 2, height: frame.size.height - 2))
        listbox.setNeedsDisplay()
    }
}
