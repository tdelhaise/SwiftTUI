import Foundation

// The Swift Programming Language
// https://docs.swift.org/swift-book

/// A protocol that all UI elements (views) must conform to.
/// This defines the basic interface for drawing and handling events.
@MainActor public protocol View: AnyObject { // AnyObject to allow weak references for 'owner'
    /// The parent view in the hierarchy.
    var owner: View? { get set }

    /// Draws the view on the given canvas.
    func draw(in rect: Rect)

    /// Handles a keyboard event. Returns true if the event was handled.
    func handle(keyEvent: KeyEvent) -> Bool

    /// Handles a mouse event. Returns true if the event was handled.
    func handle(mouseEvent: MouseEvent) -> Bool

    /// Handles a command. Returns true if the command was handled.
    func handle(command: Command) -> Bool

    /// The frame of the view relative to its superview.
    var frame: Rect { get set }

    /// The subviews contained within this view.
    var subviews: [View] { get }

    /// Adds a subview to this view.
    func add(subview: View)

    /// Converts a point from the view's local coordinate system to the global screen coordinate system.
    func makeGlobal(point: Point) -> Point

    /// Converts a point from the global screen coordinate system to the view's local coordinate system.
    func makeLocal(point: Point) -> Point

    /// The current state of the view (e.g., visible, focused).
    var state: ViewState { get set }

    /// Options for the view's behavior (e.g., selectable).
    var options: ViewOptions { get set }

    /// The mask of events this view is interested in.
    var eventMask: EventMask { get set }

    /// Sets or unsets a specific state for the view.
    func setState(_ aState: ViewState, enable: Bool)
    func setNeedsDisplay()
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

    func setNeedsDisplay() {
        // Default implementation: Invalidate the view's area,
        // which will eventually lead to a redraw by the application.
        // For now, we'll just print a message.
        print("  View \(type(of: self)) at \(frame) needs display.")
        // In a real implementation, this would typically involve
        // adding the view to a dirty rect list in the Application.
    }
}

/// A basic implementation of a rectangular area on the screen.
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
}

/// A basic implementation of a point on the screen.
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

/// A basic implementation of a size (width and height).
public struct Size: Equatable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    @MainActor public static let zero = Size(width: 0, height: 0)
}

/// Represents the state of control keys (Shift, Ctrl, Alt).
public struct ControlKeyState: OptionSet, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let shift = ControlKeyState(rawValue: 1 << 0)
    public static let control = ControlKeyState(rawValue: 1 << 1)
    public static let alt = ControlKeyState(rawValue: 1 << 2)
}

/// Defines the type of mouse event.
public enum EventType: UInt8 {
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

/// Represents a mouse event.
public struct MouseEvent {
    public let x: Int
    public let y: Int
    public let eventType: EventType
    public let controlKeyState: ControlKeyState

    public var position: Point {
        return Point(x: x, y: y)
    }
}

/// Represents a keyboard event.
public struct KeyEvent {
    public let character: Character?
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

/// Represents a generic event that can be handled by views.
public enum Event {
    case key(KeyEvent)
    case mouse(MouseEvent)
    case command(Command)
    case none // Represents no event
}

/// OptionSet for event masks.
public struct EventMask: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }

    @MainActor public static let none: EventMask = []
    @MainActor public static let mouse = EventMask(rawValue: 1 << 0)
    @MainActor public static let keyboard = EventMask(rawValue: 1 << 1)
    @MainActor public static let command = EventMask(rawValue: 1 << 2)
    // Add more event types as needed
}

/// Represents a command that can be dispatched and handled.
public enum Command: UInt, CaseIterable {
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

/// Represents the result of a validation operation.
public enum ValidationResult: Equatable, Sendable {
    case valid
    case invalid(String) // Associated value for error message
}

/// Type alias for a validation closure.
public typealias Validator = (String) -> ValidationResult

/// Represents a single entry in the history stack.
public struct HistoryEntry: Equatable, Sendable {
    public let text: String
}

/// Manages a history stack for undo/redo operations.
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
}

/// OptionSet for view states.
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

/// OptionSet for view options.
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

/// A base class providing default implementations for the View protocol.
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
        let defaultColors = Application.currentColorTheme.currentPalette[.desktop] // Use desktop colors as default background

        // Default drawing: fill the view's frame with empty cells
        for y in frame.origin.y..<(frame.origin.y + frame.size.height) {
            for x in frame.origin.x..<(frame.origin.x + frame.size.width) {
                Terminal.writeToBuffer(x: x, y: y, char: " ", foreground: defaultColors.foreground, background: defaultColors.background)
            }
        }

        // Draw subviews
        for subview in subviews {
            if subview.state.contains(.sfVisible) {
                subview.draw(in: rect)
            }
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

/// The main application class for the Text UI Toolkit.
/// Manages the main event loop and the root view.
@MainActor
public class Application {
    public private(set) var rootView: View?
    private var isRunning: Bool = false
    private var eventQueue: [Event] = [] // Simple event queue
    public static var currentColorTheme: ColorTheme = .default

    public init() {}

    /// Sets the root view of the application.
    public func setRootView(_ view: View) {
        self.rootView = view

        // If the root view is a Desktop, create and set a StatusLine
        if let desktop = view as? Desktop {
            let terminalWidth = Terminal.currentBuffer.width
            let terminalHeight = Terminal.currentBuffer.height
            let statusLineFrame = Rect(x: 0, y: terminalHeight - 1, width: terminalWidth, height: 1)
            let statusLine = StatusLine(frame: statusLineFrame, message: "Welcome to SwiftTUI!")
            desktop.set(statusLine: statusLine)
        }
    }

    /// Starts the application's main event loop.
    public func run() {
        guard let rootView = rootView else {
            print("Error: No root view set for the application.")
            return
        }

        do {
            try Terminal.enableRawMode()
            Terminal.hideCursor()
            defer { // Ensure raw mode is disabled and cursor is shown on exit
                try? Terminal.disableRawMode()
                Terminal.showCursor()
                Terminal.clearScreen() // Clear screen on exit
            }

            isRunning = true
            print("Application started. Press 'q' to quit.")

            var escapeSequenceBuffer: [UInt8] = []

            while isRunning {
                // 1. Process Events
                if let char = Terminal.readCharacter() {
                    let byte = char.asciiValue ?? 0

                    if byte == 0x1B { // ESC character
                        escapeSequenceBuffer.append(byte)
                    } else if !escapeSequenceBuffer.isEmpty {
                        escapeSequenceBuffer.append(byte)
                        // Attempt to parse the escape sequence
                        if let event = parseEscapeSequence(escapeSequenceBuffer) {
                            post(event: event)
                            escapeSequenceBuffer.removeAll()
                        } else if escapeSequenceBuffer.count > 5 { // Max reasonable escape sequence length
                            // If it's too long and not recognized, treat as regular input or error
                            print("  Unrecognized escape sequence: \(escapeSequenceBuffer)")
                            escapeSequenceBuffer.removeAll()
                        }
                    } else if char == "q" {
                        isRunning = false
                        break
                    } else {
                        // Regular character input
                        let keyEvent = KeyEvent(character: char, keyCode: Int(byte), controlKeyState: [])
                        post(event: .key(keyEvent))
                    }
                }

                if let event = _getNextEvent() {
                    _handle(event: event)
                }

                // 2. Draw
                rootView.draw(in: Rect(x: 0, y: 0, width: Terminal.currentBuffer.width, height: Terminal.currentBuffer.height)) // Draw the entire root view
                Terminal.renderBuffer() // Render the buffer to the actual terminal

                // Small delay to prevent busy-waiting in a real loop
                // With VTIME=1, readCharacter already provides a small delay/timeout.
                // Thread.sleep(forTimeInterval: 0.01) // Reduced delay for responsiveness
            }
            print("Application stopped.")
        } catch {
            print("Terminal Error: \(error)")
        }
    }

    /// Stops the application's main event loop.
    public func stop() {
        isRunning = false
    }

    /// Adds an event to the event queue.
    public func post(event: Event) {
        eventQueue.append(event)
    }

    /// Retrieves the next event from the queue.
    internal func _getNextEvent() -> Event? {
        if eventQueue.isEmpty {
            // In a real app, this would block and wait for input
            return nil
        }
        return eventQueue.removeFirst()
    }

    /// Dispatches an event to the root view.
    internal func _handle(event: Event) {
        guard let rootView = rootView else { return }

        switch event {
        case .key(let keyEvent):
            _ = rootView.handle(keyEvent: keyEvent)
        case .mouse(let mouseEvent):
            _ = rootView.handle(mouseEvent: mouseEvent)
        case .command(let command):
            _ = rootView.handle(command: command)
        case .none:
            break
        }
    }

    private func parseEscapeSequence(_ sequence: [UInt8]) -> Event? {
        // Common ANSI escape sequences for special keys
        // CSI (Control Sequence Introducer) is ESC [ (0x1B 0x5B)

        if sequence.count >= 3 && sequence[0] == 0x1B && sequence[1] == 0x5B { // ESC [
            // Mouse events in SGR mode: ESC [ < C ; X ; Y (M or m)
            if sequence.count >= 6 && sequence[2] == 0x3C { // Starts with ESC [ <
                if let sequenceString = String(bytes: sequence, encoding: .ascii) {
                    let regex = try? NSRegularExpression(pattern: "\u{001B}\\[<(\\d+);(\\d+);(\\d+)([Mm])")
                    if let match = regex?.firstMatch(in: sequenceString, options: [], range: NSRange(location: 0, length: sequenceString.utf16.count)) {
                        if let buttonRange = Range(match.range(at: 1), in: sequenceString),
                           let xRange = Range(match.range(at: 2), in: sequenceString),
                           let yRange = Range(match.range(at: 3), in: sequenceString),
                           let typeRange = Range(match.range(at: 4), in: sequenceString),
                           let buttonCode = Int(sequenceString[buttonRange]),
                           let x = Int(sequenceString[xRange]),
                           let y = Int(sequenceString[yRange]) {

                            let eventTypeChar = sequenceString[typeRange]
                            var eventType: EventType = .mouseNone
                            var controlKeyState: ControlKeyState = []

                            // Button codes: 0=Left, 1=Middle, 2=Right, 32=ScrollUp, 33=ScrollDown
                            // Add 4 for Shift, 8 for Alt, 16 for Ctrl
                            let actualButton = buttonCode & 0b11 // Mask for actual button (0,1,2)
                            let shiftPressed = (buttonCode & 0b100) != 0
                            let altPressed = (buttonCode & 0b1000) != 0
                            let ctrlPressed = (buttonCode & 0b10000) != 0

                            if shiftPressed { controlKeyState.insert(.shift) }
                            if altPressed { controlKeyState.insert(.alt) }
                            if ctrlPressed { controlKeyState.insert(.control) }

                            if eventTypeChar == "M" { // Mouse down or drag
                                if actualButton == 0 { eventType = .mouseDown }
                                else if actualButton == 1 { eventType = .mouseDown } // Middle
                                else if actualButton == 2 { eventType = .mouseDown } // Right
                                else if actualButton == 32 { eventType = .mouseWheel } // Scroll Up
                                else if actualButton == 33 { eventType = .mouseWheel } // Scroll Down
                                // Need to differentiate drag from down. SGR mode reports drag as M with button held.
                                // For now, treat all M as mouseDown, will refine later.
                            } else if eventTypeChar == "m" { // Mouse up
                                if actualButton == 0 { eventType = .mouseUp }
                                else if actualButton == 1 { eventType = .mouseUp } // Middle
                                else if actualButton == 2 { eventType = .mouseUp } // Right
                            }

                            return .mouse(MouseEvent(x: x - 1, y: y - 1, eventType: eventType, controlKeyState: controlKeyState)) // Convert to 0-based
                        }
                    }
                }
            }

            // Existing keyboard escape sequences
            switch sequence[2] {
            case 0x41: return .key(KeyEvent(character: nil, keyCode: KeyEvent.KeyCode.upArrow, controlKeyState: [])) // Up Arrow
            case 0x42: return .key(KeyEvent(character: nil, keyCode: KeyEvent.KeyCode.downArrow, controlKeyState: [])) // Down Arrow
            case 0x43: return .key(KeyEvent(character: nil, keyCode: KeyEvent.KeyCode.rightArrow, controlKeyState: [])) // Right Arrow
            case 0x44: return .key(KeyEvent(character: nil, keyCode: KeyEvent.KeyCode.leftArrow, controlKeyState: [])) // Left Arrow
            case 0x31: // Home, End, Insert, Delete, PageUp, PageDown often start with ESC [ 1 ~ or ESC [ 1 ; X ~
                if sequence.count >= 4 && sequence[3] == 0x7E { // ESC [ 1 ~ (Home)
                    return .key(KeyEvent(character: nil, keyCode: KeyEvent.KeyCode.home, controlKeyState: []))
                }
            case 0x34: // End (ESC [ 4 ~)
                if sequence.count >= 4 && sequence[3] == 0x7E {
                    return .key(KeyEvent(character: nil, keyCode: KeyEvent.KeyCode.end, controlKeyState: []))
                }
            case 0x33: // Delete (ESC [ 3 ~)
                if sequence.count >= 4 && sequence[3] == 0x7E {
                    return .key(KeyEvent(character: nil, keyCode: KeyEvent.KeyCode.delete, controlKeyState: []))
                }
            case 0x35: // Page Up (ESC [ 5 ~)
                if sequence.count >= 4 && sequence[3] == 0x7E {
                    return .key(KeyEvent(character: nil, keyCode: KeyEvent.KeyCode.pageUp, controlKeyState: []))
                }
            case 0x36: // Page Down (ESC [ 6 ~)
                if sequence.count >= 4 && sequence[3] == 0x7E {
                    return .key(KeyEvent(character: nil, keyCode: KeyEvent.KeyCode.pageDown, controlKeyState: []))
                }
            default:
                break
            }
        }
        // Add more escape sequence parsing for F-keys, etc.

        return nil // Not a recognized escape sequence
    }
}