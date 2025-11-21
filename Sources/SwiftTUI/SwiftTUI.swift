import Foundation

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

// A protocol that all UI elements (views) must conform to.
// This defines the basic interface for drawing and handling events.
@MainActor public protocol View: AnyObject { // AnyObject to allow weak references for 'owner'
    // The parent view in the hierarchy.
    var owner: View? { get set }

    // Draws the view on the given canvas.
    func draw(in rect: Rect)

    // Handles a keyboard event. Returns true if the event was handled.
    func handle(keyEvent: KeyEvent) -> Bool

    // Handles a mouse event. Returns true if the event was handled.
    func handle(mouseEvent: MouseEvent) -> Bool

    // Handles a command. Returns true if the command was handled.
    func handle(command: Command) -> Bool

    // The frame of the view relative to its superview.
    var frame: Rect { get set }

    // The subviews contained within this view.
    var subviews: [View] { get }

    // Adds a subview to this view.
    func add(subview: View)

    // Converts a point from the view's local coordinate system to the global screen coordinate system.
    func makeGlobal(point: Point) -> Point

    // Converts a point from the global screen coordinate system to the view's local coordinate system.
    func makeLocal(point: Point) -> Point

    // The current state of the view (e.g., visible, focused).
    var state: ViewState { get set }

    // Options for the view's behavior (e.g., selectable).
    var options: ViewOptions { get set }

    // The mask of events this view is interested in.
    var eventMask: EventMask { get set }

    // Sets or unsets a specific state for the view.
    func setState(_ aState: ViewState, enable: Bool)
    func setNeedsDisplay(_ rect: Rect?)
    func handlePaste(_ text: String) -> Bool
}

public extension View {
    // Default implementations for optional protocol methods or common helpers
    func makeGlobal(point: Point) -> Point {
        var globalPoint = point + frame.origin
        var currentOwner = owner
        while let current = currentOwner {
            globalPoint += current.frame.origin
            currentOwner = current.owner
        }
        return globalPoint
    }

    func makeLocal(point: Point) -> Point {
        var localPoint = point - frame.origin
        var currentOwner = owner
        while let current = currentOwner {
            localPoint -= current.frame.origin
            currentOwner = current.owner
        }
        return localPoint
    }

    func setState(_ aState: ViewState, enable: Bool) {
        if enable {
            state.insert(aState)
        } else {
            state.remove(aState)
        }
    }

    func setNeedsDisplay(_ rect: Rect? = nil) {
        let localRect = rect ?? Rect(origin: .zero, size: frame.size)
        let globalOrigin = makeGlobal(point: localRect.origin)
        let globalRect = Rect(origin: globalOrigin, size: localRect.size)
        Application.shared.setNeedsDisplay(globalRect)
    }

    func handlePaste(_ text: String) -> Bool {
        return owner?.handlePaste(text) ?? false
    }

    func globalFrame() -> Rect {
        return Rect(origin: makeGlobal(point: .zero), size: frame.size)
    }
}

// A basic implementation of a rectangular area on the screen.
public struct Rect: Equatable {
    public var origin: Point
    public var size: Size

    public var x: Int { origin.x }
    public var y: Int { origin.y }
    public var width: Int { size.width }
    public var height: Int { size.height }

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.origin = Point(x: x, y: y)
        self.size = Size(width: width, height: height)
    }

    public init(origin: Point, size: Size) {
        self.origin = origin
        self.size = size
    }

    public func contains(_ point: Point) -> Bool {
        return point.x >= x && point.x < x + width &&
               point.y >= y && point.y < y + height
    }

    public func union(_ other: Rect) -> Rect {
        let minX = min(self.x, other.x)
        let minY = min(self.y, other.y)
        let maxX = max(self.x + self.width, other.x + other.width)
        let maxY = max(self.y + self.height, other.y + other.height)
        return Rect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    public func intersection(_ other: Rect) -> Rect? {
        let newX = max(self.x, other.x)
        let newY = max(self.y, other.y)
        let newWidth = min(self.x + self.width, other.x + other.width) - newX
        let newHeight = min(self.y + self.height, other.y + other.height) - newY
        if newWidth <= 0 || newHeight <= 0 { return nil }
        return Rect(x: newX, y: newY, width: newWidth, height: newHeight)
    }
}

// A basic implementation of a point on the screen.
public struct Point: Equatable, Comparable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    @MainActor public static let zero = Point(x: 0, y: 0)

    public static func +(lhs: Point, rhs: Point) -> Point {
        return Point(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    public static func -(lhs: Point, rhs: Point) -> Point {
        return Point(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    public static func +=(lhs: inout Point, rhs: Point) {
        lhs = Point(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    public static func -=(lhs: inout Point, rhs: Point) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
    }

    // MARK: - Comparable Conformance
    public static func < (lhs: Point, rhs: Point) -> Bool {
        if lhs.y != rhs.y {
            return lhs.y < rhs.y
        }
        return lhs.x < rhs.x
    }
}

// A basic implementation of a size (width and height).
public struct Size: Equatable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    @MainActor public static let zero = Size(width: 0, height: 0)
}

// Represents the state of control keys (Shift, Ctrl, Alt).
public struct ControlKeyState: OptionSet, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let shift = ControlKeyState(rawValue: 1 << 0)
    public static let control = ControlKeyState(rawValue: 1 << 1)
    public static let alt = ControlKeyState(rawValue: 1 << 2)
}

// Defines the type of mouse event.

public enum EventType: UInt8, Sendable {

    case mouseUp

    case mouseDown

    case mouseDrag

    case mouseMove

    case mouseWheel

    case mouseDoubleClick

    case mouseTripleClick

    case mouseQuadrupleClick

    case mouseNone

}

// Represents a mouse event.

public struct MouseEvent: Sendable {

    public let x: Int

    public let y: Int

    public let eventType: EventType

    public let controlKeyState: ControlKeyState



    public var position: Point {

        return Point(x: x, y: y)

    }

}



// Represents a keyboard event.

public struct KeyEvent: Sendable {

    public let character: String?

    public let keyCode: Int

    public let controlKeyState: ControlKeyState



    // Define common key codes as static properties

    public struct KeyCode {

        public static let leftArrow = 1000 // Arbitrary values, should be mapped to actual terminal codes

        public static let rightArrow = 1001

        public static let upArrow = 1002

        public static let downArrow = 1003

        public static let home = 1004

        public static let end = 1005

        public static let pageUp = 1006

        public static let pageDown = 1007

        public static let insert = 1008

        public static let delete = 1009

        public static let backspace = 8 // ASCII Backspace

        public static let tab = 9     // ASCII Tab

        public static let enter = 13  // ASCII Carriage Return (Enter)

        public static let escape = 27 // ASCII Escape

        public static let f1 = 1010

        public static let f2 = 1011

        public static let f3 = 1012

        public static let f4 = 1013

        public static let f5 = 1014

        public static let f6 = 1015

        public static let f7 = 1016

        public static let f8 = 1017

        public static let f9 = 1018

        public static let f10 = 1019

        public static let f11 = 1020

        public static let f12 = 1021

    }

}



// Represents a generic event that can be handled by views.

public enum Event: Sendable {

    case key(KeyEvent)

    case mouse(MouseEvent)

    case command(Command)

    case paste(String)

    case screenResize(Size)

    case timer(TimerToken)

    case none // Represents no event

}

// OptionSet for event masks.
public struct EventMask: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }

    @MainActor public static let none: EventMask = []
    @MainActor public static let mouse = EventMask(rawValue: 1 << 0)
    @MainActor public static let keyboard = EventMask(rawValue: 1 << 1)
    @MainActor public static let command = EventMask(rawValue: 1 << 2)
    @MainActor public static let screenResize = EventMask(rawValue: 1 << 3)
    @MainActor public static let timer = EventMask(rawValue: 1 << 4)
    // Add more event types as needed
}

// Represents a command that can be dispatched and handled.

public enum Command: UInt, CaseIterable, Sendable {

    case cmNone = 0

    case cmQuit

    case cmAbout

    case cmCut

    case cmCopy

    case cmPaste

    case cmUndo

    case cmRedo

    case cmSave

    case cmOpen

    case cmNew

    case cmClose

    case cmCascade

    case cmTile

    case cmZoom

    case cmNext

    case cmPrev

    case cmDosShell // For compatibility with original Tvision

    case cmUser // User-defined command base

    // Add more commands as needed

}

// Represents the result of a validation operation.
public enum ValidationResult: Equatable, Sendable {
    case valid
    case invalid(String) // Associated value for error message
}

// Type alias for a validation closure.
public typealias Validator = (String) -> ValidationResult

// Represents a single entry in the history stack.
public struct HistoryEntry: Equatable, Sendable {
    public let text: String
}

// Token identifying scheduled timers.
public struct TimerToken: Hashable, Sendable {
    fileprivate let id: UUID
    public init() { self.id = UUID() }
}

// Manages a history stack for undo/redo operations.
public class HistoryManager {
    private var history: [HistoryEntry] = []
    private var currentIndex: Int = -1
    private let capacity: Int

    public init(capacity: Int = 100) {
        self.capacity = capacity
    }

    public func push(entry: HistoryEntry) {
        // Remove any "redo" entries if a new action is performed
        if currentIndex < history.count - 1 {
            history.removeSubrange(currentIndex + 1..<history.count)
        }

        history.append(entry)
        if history.count > capacity {
            history.removeFirst()
        } else {
            currentIndex += 1
        }
    }

    public func undo() -> HistoryEntry? {
        guard currentIndex > 0 else { return nil }
        currentIndex -= 1
        return history[currentIndex]
    }

    public func redo() -> HistoryEntry? {
        guard currentIndex < history.count - 1 else { return nil }
        currentIndex += 1
        return history[currentIndex]
    }

    public var canUndo: Bool {
        return currentIndex > 0
    }

    public var canRedo: Bool {
        return currentIndex < history.count - 1
    }

    public func clear() {
        history.removeAll()
        currentIndex = -1
    }

    public func allEntries() -> [HistoryEntry] {
        return history
    }
}

// OptionSet for view states.
public struct ViewState: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }

    @MainActor public static let sfVisible = ViewState(rawValue: 1 << 0)
    @MainActor public static let sfSelected = ViewState(rawValue: 1 << 1)
    @MainActor public static let sfFocused = ViewState(rawValue: 1 << 2)
    @MainActor public static let sfDragging = ViewState(rawValue: 1 << 3)
    @MainActor public static let sfDisabled = ViewState(rawValue: 1 << 4)
    @MainActor public static let sfExposed = ViewState(rawValue: 1 << 5)
    @MainActor public static let sfCursorVis = ViewState(rawValue: 1 << 6)
    @MainActor public static let sfCursorIns = ViewState(rawValue: 1 << 7)
    @MainActor public static let sfShadow = ViewState(rawValue: 1 << 8)
    @MainActor public static let sfModal = ViewState(rawValue: 1 << 9)
    // Add more states as needed
}

// OptionSet for view options.
public struct ViewOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }

    @MainActor public static let ofSelectable = ViewOptions(rawValue: 1 << 0)
    @MainActor public static let ofFirstClick = ViewOptions(rawValue: 1 << 1)
    @MainActor public static let ofTopSelect = ViewOptions(rawValue: 1 << 2)
    @MainActor public static let ofValidate = ViewOptions(rawValue: 1 << 3)
    @MainActor public static let ofBuffered = ViewOptions(rawValue: 1 << 4)
    // Add more options as needed
}

// A base class providing default implementations for the View protocol.
@MainActor
open class BaseView: View {
    public weak var owner: View?
    public var frame: Rect
    public private(set) var subviews: [View] = []
    public var state: ViewState = [.sfVisible]
    public var options: ViewOptions = []
    public var eventMask: EventMask = [.mouse, .keyboard, .command]

    public init(frame: Rect) {
        self.frame = frame
    }

    open func draw(in rect: Rect) {
        guard let drawArea = globalFrame().intersection(rect) else { return }
        let defaultColors = Application.currentColorTheme.currentPalette[.desktop]
        let startY = drawArea.origin.y
        let endY = drawArea.origin.y + drawArea.size.height
        let startX = drawArea.origin.x
        let endX = drawArea.origin.x + drawArea.size.width

        for y in startY..<endY {
            for x in startX..<endX {
                Application.shared.terminal.writeToBuffer(x: x, y: y, char: " ", foreground: defaultColors.foreground, background: defaultColors.background)
            }
        }

        for subview in subviews where subview.state.contains(.sfVisible) {
            subview.draw(in: rect)
        }
    }

    open func handle(keyEvent: KeyEvent) -> Bool {
        // Default: pass to subviews or owner
        for subview in subviews.reversed() {
            if subview.handle(keyEvent: keyEvent) {
                return true // Event handled by subview, stop propagation
            }
        }
        // If no subview handled it, pass to owner
        return owner?.handle(keyEvent: keyEvent) ?? false
    }

    open func handle(mouseEvent: MouseEvent) -> Bool {
        // Default: pass to subviews or owner
        for subview in subviews.reversed() {
            // Only pass mouse events if they are within the subview's bounds
            let localPoint = subview.makeLocal(point: Point(x: mouseEvent.x, y: mouseEvent.y))
            if subview.frame.contains(localPoint) {
                if subview.handle(mouseEvent: mouseEvent) {
                    return true // Event handled by subview, stop propagation
                }
            }
        }
        // If no subview handled it, pass to owner
        return owner?.handle(mouseEvent: mouseEvent) ?? false
    }

    open func handle(command: Command) -> Bool {
        // Default: pass to subviews or owner
        for subview in subviews.reversed() {
            if subview.handle(command: command) {
                return true // Event handled by subview, stop propagation
            }
        }
        // If no subview handled it, pass to owner
        return owner?.handle(command: command) ?? false
    }

    open func handlePaste(_ text: String) -> Bool {
        for subview in subviews.reversed() {
            if subview.handlePaste(text) {
                return true
            }
        }
        return owner?.handlePaste(text) ?? false
    }

    public func add(subview: View) {
        subview.owner = self
        subviews.append(subview)
        // Sort subviews by some criteria if needed (e.g., z-index)
    }

    open func setState(_ aState: ViewState, enable: Bool) {
        if enable {
            state.insert(aState)
        } else {
            state.remove(aState)
        }
    }
}

// The main application class for the Text UI Toolkit.
// Manages the main event loop and the root view.
@MainActor
public class Application {
    public private(set) var rootView: View?
    private var isRunning: Bool = false
    private var eventQueue: [Event] = [] // Simple event queue
    public static var currentColorTheme: ColorTheme = .default
    
    public let terminal: TerminalProtocol // Dependency injection for Terminal
    private var pendingDirtyRects: [Rect] = []
    private var clipboardStorage: String = ""
    public var clipboardManager: ClipboardManaging = OSC52ClipboardManager()

    private var inputLoop: TerminalInputLoop?
    private var timerHandlers: [TimerToken: @Sendable () -> Void] = [:]
    
    // Shutdown synchronization
    private let shutdownGroup = DispatchGroup()
    private var signalSources: [DispatchSourceSignal] = []

    // Static shared instance for easy access
    public static var shared: Application!

    public init(terminal: TerminalProtocol = Terminal()) {
        self.terminal = terminal
        Application.shared = self // Set the shared instance
        // Enter the DispatchGroup when the application starts.
        // We will leave it when shutdown is complete.
        shutdownGroup.enter()
    }

    private func setupSignalHandlers() {
        let signalQueue = DispatchQueue(label: "com.swifttui.signalhandler")
        
        [SIGTERM, SIGINT, SIGWINCH].forEach { sig in
            let signalSource = DispatchSource.makeSignalSource(signal: sig, queue: signalQueue)
            signalSource.setEventHandler {
                self.handleSignal(sig)
            }
            signalSource.resume()
            self.signalSources.append(signalSource)
        }
    }

    private func handleSignal(_ signal: Int32) {
        switch signal {
        case SIGWINCH:
            Task { await self.post(event: .screenResize(terminal.getWindowSize())) }
        case SIGINT, SIGTERM:
            print("Caught signal \(signal), initiating shutdown...")
            Task { await self.stop() }
        default:
            break
        }
    }

    private func cleanupTerminal() {
        try? terminal.disableRawMode()
        terminal.exitAlternateScreen()
        terminal.showCursor()
        terminal.clearScreen()
    }

    // Sets the root view of the application.
    public func setRootView(_ view: View) {
        self.rootView = view

        // If the root view is a Desktop, create and set a StatusLine
        if let desktop = view as? Desktop {
            let terminalWidth = terminal.windowSize.width
            let terminalHeight = terminal.windowSize.height
            let statusLineFrame = Rect(x: 0, y: terminalHeight - 1, width: terminalWidth, height: 1)
            let statusLine = StatusLine(frame: statusLineFrame, message: "Welcome to SwiftTUI!")
            desktop.set(statusLine: statusLine)
        }
    }

    // Starts the application's main event loop.
    public func run() {
        defer {
            cleanupTerminal()
            print("Application stopped.")
        }

        guard self.rootView != nil else {
            print("Error: No root view set for the application.")
            shutdownGroup.leave()
            return
        }

        do {
            try terminal.enableRawMode()
            terminal.enterAlternateScreen()
            terminal.hideCursor()
            setupSignalHandlers()

            inputLoop = TerminalInputLoop(application: self, fileDescriptor: terminal.inputFileDescriptor)
            inputLoop?.start()
            
            isRunning = true
            print("Application started. Press Ctrl-Q or use the menu to quit.")
            self.redraw()

            // Wait here until stop() is called and shutdown completes.
            shutdownGroup.wait()

        } catch {
            print("Error: \(error)")
            shutdownGroup.leave() // Ensure we leave the group on error
        }
    }

    // Stops the application's main event loop.
    public func stop() async {
        guard isRunning else { 
            // If stop is called when not running, ensure we leave the group.
            if isRunning == false {
                shutdownGroup.leave()
            }
            return 
        }
        print("Stopping application...")
        isRunning = false
        
        inputLoop?.stop()
        
        // Leave the group to unblock the main thread
        shutdownGroup.leave()
    }

    // Adds an event to the event queue.
    public func post(event: Event) async {
        await MainActor.run {
            self.eventQueue.append(event)
            self.processEvents()
        }
    }

    /// Schedules a timer that enqueues .timer events on the application queue.
    /// - Parameters:
    ///   - interval: Interval in seconds; must be > 0.
    ///   - repeating: Whether the timer repeats.
    ///   - handler: Invoked on the main actor when the timer fires.
    /// - Returns: A token that can be used to cancel the timer.
    public func scheduleTimer(interval: TimeInterval, repeating: Bool = false, handler: @escaping @Sendable () -> Void) -> TimerToken? {
        guard interval > 0 else { return nil }
        guard let token = inputLoop?.scheduleTimer(interval: interval, repeating: repeating) else { return nil }
        timerHandlers[token] = handler
        return token
    }

    /// Cancels a previously scheduled timer.
    public func cancelTimer(_ token: TimerToken) {
        timerHandlers.removeValue(forKey: token)
        inputLoop?.cancelTimer(token)
    }

    private func processEvents() {
        while let event = _getNextEvent() {
            _handle(event: event)
        }
        // After handling a batch of events, redraw the screen.
        self.redraw()
    }

    private func redraw() {
        guard let rootView = rootView else { return }
        let fullRect = Rect(x: 0, y: 0, width: terminal.windowSize.width, height: terminal.windowSize.height)
        let rects = pendingDirtyRects.isEmpty ? [fullRect] : pendingDirtyRects
        pendingDirtyRects.removeAll()
        for dirtyRect in rects {
            rootView.draw(in: dirtyRect)
        }
        terminal.renderBuffer()
    }

    func setNeedsDisplay(_ rect: Rect) {
        pendingDirtyRects.append(rect)
    }

    // Retrieves the next event from the queue.
    internal func _getNextEvent() -> Event? {
        guard !eventQueue.isEmpty else { return nil }
        return eventQueue.removeFirst()
    }

    // Dispatches an event to the root view.
    internal func _handle(event: Event) {
        guard let rootView = rootView else { return }

        switch event {
        case .key(let keyEvent):
            _ = rootView.handle(keyEvent: keyEvent)
        case .mouse(let mouseEvent):
            _ = rootView.handle(mouseEvent: mouseEvent)
        case .command(let command):
            if command == .cmQuit {
                Task { await self.stop() }
            }
            _ = rootView.handle(command: command)
        case .paste(let text):
            self.handlePaste(text: text)
        case .none:
            break
        case .screenResize(let newSize):
            handleScreenResize(newSize)
        case .timer(let token):
            if let handler = timerHandlers[token] {
                handler()
            }
        }
    }

    private func handlePaste(text: String) {
        guard let rootView = rootView else { return }
        setClipboardText(text)
        if !rootView.handlePaste(text) {
            for scalar in text.unicodeScalars {
                let keyEvent = KeyEvent(character: String(scalar), keyCode: Int(scalar.value), controlKeyState: [])
                _ = rootView.handle(keyEvent: keyEvent)
            }
        }
    }

    private func handleScreenResize(_ newSize: Size) {
        if let terminal = terminal as? Terminal {
            terminal.resizeBuffers(to: newSize)
        }

        // Resize root view to match terminal bounds.
        rootView?.frame = Rect(x: 0, y: 0, width: newSize.width, height: newSize.height)

        if let desktop = rootView as? Desktop, let status = desktop.statusLine {
            status.frame = Rect(x: 0, y: max(0, newSize.height - 1), width: newSize.width, height: 1)
        }

        pendingDirtyRects.append(Rect(x: 0, y: 0, width: newSize.width, height: newSize.height))
    }

    func setClipboardText(_ text: String) {
        clipboardStorage = text
        clipboardManager.set(text)
    }

    func clipboardText() -> String? {
        return clipboardManager.get() ?? clipboardStorage
    }
}
