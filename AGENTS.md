# SwiftTUI Swift Framework Documentation

This document provides an overview and usage guide for the `SwiftTUI` Swift framework, a Text User Interface (TUI) toolkit rewritten from a C++ library. This framework is designed to build interactive terminal-based applications using Swift's modern concurrency features and idiomatic patterns.

## Investigation Log (2024-02-15)

### Scope

- Reviewed `Sources/SwiftTUI` (especially `SwiftTUI.swift`, `Terminal.swift`, `ScreenBuffer.swift`, `ANSI.swift`, and widget/layout files) to map the current rendering pipeline, view hierarchy, and input handling.
- Cross-checked against the upstream C++ TVision tree (`../tvision`), focusing on `platform/termio.cpp`, `platform/ncursinp.cpp`, `platform/dispbuff.cpp`, `platform/events.cpp`, `platform/ansiwrit.cpp`, and core UI sources such as `tvision/tview.cpp`, `tvision/tgroup.cpp`, and `tvision/tprogram.cpp`.

### Detailed findings

1. **Input subsystem**
   - SwiftTUI’s `TerminalInputHandler` only handles basic CSI arrows, a handful of tilde-terminated keys, Alt-as-ESC+char, and ASCII control bytes. It never requests enhanced reports from the terminal, so combinations like Shift+Alt+Ctrl+Q collapse down to plain characters.
   - TVision programs the terminal with `modifyOtherKeys`, Kitty keyboard protocol, Win32 input mode, bracketed paste, and SGR/X10 mouse tracking via `TermIO::keyModsOn` and parses every sequence through `TermIO::parseEscapeSeq`. This yields reliable modifier detection (Shift/Alt/Ctrl states preserved even when keys overlap) and robust mouse events without ncurses drawing APIs.
   - **Action**: Port the TermIO state machine to Swift (still using raw `read` + `select` on `/dev/tty`) so SwiftTUI can capture full modifier information and advanced mouse input while remaining ncurses-free.

2. **Display/refresh protocol & invalidation**
   - `Application.setNeedsDisplay` currently calls `redraw()` immediately, and `Terminal.renderBuffer()` rebuilds `currentBuffer` from scratch after each frame. There is no concept of dirty rectangles, caret inversion, or buffered drawing per view.
   - TVision’s `DisplayBuffer`/`AnsiScreenWriter` pair keeps persistent front/back buffers, tracks per-row damage (`rowDamage`), throttles flushes to a target FPS, and inverts the caret without clearing/redrawing the whole screen. Views mark their rectangles dirty, and `TGroup` only redraws exposed areas.
   - **Action**: Introduce persistent screen buffers, dirty-span tracking, and a flush algorithm similar to TVision’s to minimize terminal writes and respect view invalidation semantics.

3. **Terminfo / capability handling**
   - SwiftTUI emits hard-coded ANSI sequences based on simple `$TERM` string checks; there is no terminfo lookup for cursor control, color depth, or “bold is bright” quirks.
   - TVision’s `ConsoleCtl` + `TermCap` layer discovers terminal size, font metrics, and color capabilities, then configures `AnsiScreenWriter` to emit the right escape codes per terminal (even handling Linux console quirks).
   - **Action**: Bind to terminfo/termcap APIs in Swift to query capabilities and drive sequence generation instead of assuming xterm-like behavior.

4. **Event/timer infrastructure**
   - SwiftTUI maintains a simple in-memory `eventQueue` and immediately processes events; there is no idle loop, timer queue, SIGWINCH handling, or polling abstraction.
   - TVision’s `EventWaiter`/`TEventQueue` multiplex OS descriptors, timers, and wake-up events, delivering `cmScreenChanged` on resize and enabling background / idle processing.
   - **Action**: Add a timer + event-wait system similar to TVision’s so the Swift port can react to resizes, integrate timers, and avoid busy loops.

5. **Widget parity gaps**
   - SwiftTUI already ships windows, dialogs, menus, status line, editors, checkboxes, etc., but still lacks several TVision components: clipboard integration, help browser, outline/tree viewers, text viewers/scrollers, advanced validators/history windows, resource streaming, and drawing surfaces.
   - **Action**: Continue porting these subsystems (as outlined in the roadmap) and reproduce TVision examples to validate feature parity.

### Immediate next steps

1. Implement a Swift TermIO module that sends TVision’s modifier-enabling sequences and parses Kitty/modifyOtherKeys/SGR mouse output to fully recognize Shift+Alt+Ctrl combinations.
2. Rework rendering around persistent buffers with dirty-region propagation (`DisplayBuffer`/`AnsiScreenWriter` equivalent) instead of redrawing the entire scene each event.
3. Introduce terminfo-driven capability detection plus an event/timer queue modeled after `TEventQueue` to handle resize, idle, and timer events consistently.
4. Plan follow-up milestones to port missing widgets and infrastructure until SwiftTUI matches the C++ feature set.

## 1. Getting Started (Swift Package Manager)

To include `SwiftTUI` in your Swift project, add it as a dependency in your `Package.swift` file:

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "YourProject",
    dependencies: [
        .package(path: "swift/SwiftTUI") // Assuming SwiftTUI is located at swift/SwiftTUI relative to your project root
    ],
    targets: [
        .executableTarget(
            name: "YourProject",
            dependencies: ["SwiftTUI"]
        )
    ]
)
```

Then, run `swift build` or open your project in Xcode/VS Code and let it resolve the package dependencies.

## 2. Core Concepts

The `SwiftTUI` framework is built around a hierarchical view system and an event-driven architecture.

### 2.1. `View` Protocol

The `View` protocol is the fundamental building block for all UI elements. Any object that conforms to `View` can be displayed and interact with events.

```swift
@MainActor public protocol View: AnyObject {
    var owner: View? { get set }
    var frame: Rect { get set }
    var subviews: [View] { get }
    var state: ViewState { get set }
    var options: ViewOptions { get set }
    var eventMask: EventMask { get set }

    func draw(in rect: Rect)
    func handle(keyEvent: KeyEvent) -> Bool
    func handle(mouseEvent: MouseEvent) -> Bool
    func handle(command: Command) -> Bool
    func add(subview: View)
    func makeGlobal(point: Point) -> Point
    func makeLocal(point: Point) -> Point
    func setState(_ aState: ViewState, enable: Bool)
}
```

-   **`owner`**: A weak reference to the parent `View` in the hierarchy.
-   **`frame`**: The position and size of the view relative to its `owner`.
-   **`subviews`**: An array of child `View`s.
-   **`state`**: An `OptionSet` (`ViewState`) representing the current state of the view (e.g., visible, focused).
-   **`options`**: An `OptionSet` (`ViewOptions`) defining the view's behavior (e.g., selectable).
-   **`eventMask`**: An `OptionSet` (`EventMask`) specifying which types of events the view is interested in.
-   **`draw(in rect: Rect)`**: Method for rendering the view's content within a given rectangle.
-   **`handle(...)` methods**: Methods for processing keyboard, mouse, and command events. They return `true` if the event was handled, `false` otherwise.
-   **`add(subview: View)`**: Adds a child view to the current view.
-   **`makeGlobal(point: Point)` / `makeLocal(point: Point)`**: Utility methods for converting coordinates between the view's local system and the global screen system.
-   **`setState(_ aState: ViewState, enable: Bool)`**: Sets or unsets a specific state flag.

### 2.2. `BaseView` Class

`BaseView` is a concrete class that implements the `View` protocol, providing default behaviors for event propagation, subview management, and state handling. All custom UI components should typically inherit from `BaseView`.

```swift
@MainActor
open class BaseView: View {
    public weak var owner: View?
    public var frame: Rect
    public private(set) var subviews: [View] = []
    public var state: ViewState = [.sfVisible]
    public var options: ViewOptions = []
    public var eventMask: EventMask = [.mouse, .keyboard, .command]

    public init(frame: Rect) { /* ... */ }
    open func draw(in rect: Rect) { /* ... */ }
    open func handle(keyEvent: KeyEvent) -> Bool { /* ... */ }
    open func handle(mouseEvent: MouseEvent) -> Bool { /* ... */ }
    open func handle(command: Command) -> Bool { /* ... */ }
    public func add(subview: View) { /* ... */ }
    open func setState(_ aState: ViewState, enable: Bool) { /* ... */ }
}
```

When overriding `handle` methods in subclasses, remember to call `super.handle(...)` if the event is not fully consumed by the current view, to allow propagation up the hierarchy.

### 2.3. `Application` Class

The `Application` class is the entry point for your TUI application. It manages the main event loop and holds the root view of your UI.

```swift
@MainActor
public class Application {
    public private(set) var rootView: View?
    public init()
    public func setRootView(_ view: View)
    public func run() // Starts the main event loop
    public func stop()
    public func post(event: Event) // Adds an event to the queue
}
```

### 2.4. Geometry and Events

-   **`Rect`**: Represents a rectangular area with `origin` (Point) and `size` (Size).
-   **`Point`**: Represents a 2D coordinate with `x` and `y` integers. Includes `static let zero` and `+=`, `-=` operators.
-   **`Size`**: Represents dimensions with `width` and `height` integers.
-   **`KeyEvent`**: Encapsulates keyboard input, including `character`, `keyCode`, and `controlKeyState`.
-   **`MouseEvent`**: Encapsulates mouse input, including `x`, `y` coordinates, `EventType` (pressed, released, moved, etc.), and `controlKeyState`.
-   **`Event`**: An enum that wraps `KeyEvent`, `MouseEvent`, or `Command`.
-   **`Command`**: An enum representing application-wide actions (e.g., `.cmQuit`, `.cmClose`, `.cmZoom`).

### 2.5. `OptionSet` Types

-   **`EventMask`**: Used by `View`s to declare interest in specific event types.
-   **`ViewState`**: Flags indicating the current state of a `View` (e.g., `.sfVisible`, `.sfFocused`, `.sfShadow`).
-   **`ViewOptions`**: Flags defining behavioral options for a `View` (e.g., `.ofSelectable`, `.ofTopSelect`).

## 3. `Window` Component

The `Window` class is a specialized `BaseView` that provides common windowing features like a title bar, movability, resizability, closing, and zooming.

```swift
@MainActor
open class Window: BaseView {
    public var title: String
    public var number: Int // Unique identifier
    public var flags: WindowFlags // Controls window behavior
    public private(set) var zoomRect: Rect // Stores previous frame for zooming
    public var palette: WindowPalette // Color scheme

    public private(set) var frameView: View? // Internal view for border/title bar

    public init(frame: Rect, title: String, number: Int) { /* ... */ }
    open func close() { /* ... */ }
    open func zoom() { /* ... */ }
    override open func handle(command: Command) -> Bool { /* ... */ }
    override open func handle(keyEvent: KeyEvent) -> Bool { /* ... */ }
    override open func draw(in rect: Rect) { /* ... */ }
    override open func setState(_ aState: ViewState, enable: Bool) { /* ... */ }
    open func sizeLimits(min: inout Size, max: inout Size) { /* ... */ }
}
```

-   **`WindowFlags`**: An `OptionSet` (e.g., `.wfMove`, `.wfGrow`, `.wfClose`, `.wfZoom`) to configure the window's capabilities.
-   **`WindowPalette`**: An enum (e.g., `.wpBlueWindow`, `.wpCyanWindow`) to select the window's color scheme.
-   **`FrameView`**: An internal `BaseView` subclass used by `Window` to draw its border and title bar. It's automatically added as a subview of the `Window`.

## 4. Example Usage

Here's a simple example demonstrating how to create an application with a basic window:

```swift
import TvisionUI
import Foundation // For Thread.sleep and other utilities

@MainActor
func main() {
    let application = Application()

    // Create a window
    let windowFrame = Rect(x: 5, y: 3, width: 60, height: 15)
    let myWindow = Window(frame: windowFrame, title: "My First SwiftTUI Window", number: 101)

    // Set some window flags (e.g., make it non-resizable)
    myWindow.flags.remove(.wfGrow)

    // Add a simple custom view to the window (inheriting from BaseView)
    class MyContentView: BaseView {
        override func draw(in rect: Rect) {
            super.draw(in: rect)
            // In a real app, you'd draw content here
            // For now, let's simulate drawing some text
            print("  Content of MyContentView in \(rect)")
            print("  Hello from SwiftTUI!")
        }

        override func handle(keyEvent: KeyEvent) -> Bool {
            if keyEvent.character == "x" {
                print("  'x' pressed in MyContentView. Closing window.")
                // In a real app, you'd send a command to close the window
                // For now, we'll just print.
                return true
            }
            return super.handle(keyEvent: keyEvent)
        }
    }

    let contentFrame = Rect(x: 1, y: 1, width: windowFrame.width - 2, height: windowFrame.height - 2)
    let contentView = MyContentView(frame: contentFrame)
    myWindow.add(subview: contentView)

    // Set the window as the root view of the application
    application.setRootView(myWindow)

    // Run the application (this will block until application.stop() is called)
    // For demonstration, we'll run it for a short period and then stop.
    print("Running SwiftTUI application. Press 'q' to quit.")
    // In a real TUI, you'd have a proper event loop reading from stdin.
    // For this example, we'll simulate a short run.
    
    // This part is for demonstration and would typically be replaced by a real event loop
    // that reads user input from the terminal.
    Task {
        await application.run()
    }

    // Simulate some interaction or wait for user input
    // For a real TUI, you'd just wait a bit and then stop.
    Thread.sleep(forTimeInterval: 5.0) // Run for 5 seconds
    application.stop()
    print("Application finished.")
}

// Call the main function to start the application
// main() // Uncomment to run the example
```

**Note on `Application.run()`:** The current `Application.run()` method is a blocking loop that simulates event processing and drawing. In a real terminal UI application, this would involve integrating with a low-level terminal library (like ncurses or termbox) to capture actual user input and render output. The `Thread.sleep` and `readLine()` calls are placeholders for such an integration.

## 5. Future Roadmap: Missing Widgets from C++ Tvision

To achieve full functionality comparable to the original C++ Tvision framework, the following key UI components and functionalities need further development or enhancement in Swift:

### Widget parity (à implémenter 1:1 avant tvedit)
- **Scroller/ScrollView conteneur** : conteneur scrollable générique avec barres.
- **ComboBox / HistoryWindow** : saisie + liste déroulante / rappel d’historique.
- **Outline/Tree viewer** et **Text/Help/Dir viewers** : lecteurs en défilement et arbres navigables.
- **Surface/drawing helpers** requis par ces viewers.
- **Clipboard** : aligner le comportement TVision au-delà d’OSC52.
Priorité à la fidélité TVision; les optimisations Swift viendront après la parité.

### Low-Level System Integration:
-   **Terminal I/O and Rendering (`tscreen.cpp`, `tsurface.cpp`, `tevent.cpp`, `tkey.cpp`, `tmouse.cpp`)**: The current `Application.run()` uses placeholders. Full TUI functionality requires integration with a low-level terminal library (e.g., ncurses or termbox) for efficient screen drawing, cursor positioning, and raw input capture.
-   **Event Queue and Dispatching (`tevent.cpp`, `tkey.cpp`, `tmouse.cpp`)**: While basic event types are defined, the actual reading and queuing of events from the terminal input needs to be implemented.

This roadmap outlines the significant work remaining to bring the Swift `SwiftTUI` framework to parity with its C++ predecessor. Each of these components will require careful design and implementation to ensure Swift-idiomatic architecture and concurrency safety.

## 6. Development Roadmap: Milestones for Completion

To systematically port the remaining C++ Tvision components to Swift, the following milestones are proposed, ordered by logical dependency and foundational importance:

### Milestone 1: Custom Terminal I/O Layer (Completed)

**Goal:** Establish a custom, `ncurses`/`curses`-independent layer for direct terminal interaction. This is a critical prerequisite for a fully functional and portable TUI framework on Unix-like systems.

*   **Why:** The framework explicitly requires independence from `ncurses`/`curses`. This milestone addresses the fundamental need for raw terminal input and output, which all higher-level UI components will depend on for rendering and event handling. Without this, the TUI cannot truly interact with the terminal.
*   **What was done:**
    *   **Terminal Mode Management:** Implemented functions to switch the terminal to raw mode (`enableRawMode()`) and restore it to cooked mode (`disableRawMode()`) using POSIX `termios` functions.
    *   **Raw Input Reading:** Implemented `readCharacter()` for non-blocking reads from standard input, capable of capturing individual key presses.
    *   **ANSI Escape Sequence Parsing:** Enhanced `Application`'s event loop with `parseEscapeSequence()` to recognize and interpret common ANSI escape codes for special keys (arrows, Home, End, etc.) and SGR mouse events.
    *   **Terminal Output Control:** Implemented functions (`write()`, `clearScreen()`, `moveCursor()`, `hideCursor()`, `showCursor()`) using ANSI escape codes.
    *   **Screen Buffer Management:** Implemented `ScreenBuffer` and `Cell` structs to manage an in-memory representation of the terminal screen. `Terminal.writeToBuffer()` writes to this buffer, and `Terminal.renderBuffer()` efficiently updates the physical terminal by only drawing changed cells.
    *   **Terminal Capability Detection (Screen Size):** Implemented `Terminal.getWindowSize()` using `ioctl` to dynamically detect and initialize the screen buffer with the actual terminal dimensions.
    *   **Mouse Tracking:** Enabled SGR mouse tracking in `enableRawMode()` and disabled it in `disableRawMode()`.
*   **Testing Note:** Due to the nature of direct terminal interaction, automated unit tests for functions like `enableRawMode()` and `disableRawMode()` may fail in environments where `stdin` is not connected to a true interactive terminal (e.g., CI/CD pipelines). These functions are best verified through manual testing in an actual terminal environment or with specialized test harnesses that simulate terminal behavior.

*   **Milestone 1.1: Terminal Simulation Layer for Automated Testing (Completed)**

### Milestone 2: Basic Input and Output Controls (Completed)

**Goal:** Implement the most fundamental UI elements for displaying information and basic user interaction, leveraging the new custom terminal layer.

*   **`TLabel` / `StaticText` (Swift: `Label` / `StaticText`)**:
    *   **What was done:** Created `Label` and `StaticText` classes inheriting from `BaseView`. Implemented properties for text content and overridden `draw(in:)` to render text using `Terminal.writeToBuffer`.
*   **`TButton` (Swift: `Button`)**:
    *   **What was done:** Created a `Button` class inheriting from `BaseView`. Implemented properties for title, an `action` closure, and overridden `draw(in:)` for rendering and `handle(mouseEvent:)`/`handle(keyEvent:)` for interaction.
*   **`TInputLine` (Swift: `InputLine`)**:
    *   **What was done:** Created an `InputLine` class inheriting from `BaseView`. Implemented properties for text content, cursor position, and overridden `draw(in:)` to render text and cursor, and `handle(keyEvent:)` to process input.

### Milestone 3: Layout and Grouping (Completed)

**Goal:** Establish mechanisms for organizing and managing multiple UI elements, including top-level application structure and common interaction patterns.

*   **`TDeskTop` (Swift: `Desktop`)**:
    *   **What was done:** Created a `Desktop` class inheriting from `BaseView`. Implemented methods for adding/removing `Window`s, managing their Z-order, and overridden `draw(in:)` and event handlers to dispatch events to appropriate windows.
*   **`TDialog` (Swift: `Dialog`)**:
    *   **What was done:** Created a `Dialog` class inheriting from `Window`. Implemented properties for message and buttons, and overridden `draw(in:)` to render the message and `handle(keyEvent:)` for default actions (Enter/Escape).
*   **`TCluster` (Swift: `Cluster`)**:
    *   **What was done:** Created a `Cluster` class inheriting from `BaseView`. Implemented a `title` property and overridden `draw(in:)` to render a border and title.

### Milestone 4: Advanced Interaction and Display (Completed)

**Goal:** Introduce more complex interactive controls for displaying and manipulating data.

*   **`TListBox` (Swift: `ListBox`)**:
    *   **What was done:** Created a `ListBox` class inheriting from `BaseView`. Implemented properties for `items`, `selectedIndex`, `topIndex` (for scrolling), and overridden `draw(in:)` to render items and `handle(keyEvent:)`/`handle(mouseEvent:)` for navigation and selection.
*   **`TScrollBar` (Swift: `ScrollBar`)**:
    *   **What was done:** Created a `ScrollBar` class inheriting from `BaseView`. Implemented properties for `orientation`, `range`, `position`, `pageSize`, and an `onScroll` callback. Overridden `draw(in:)` to render the track, thumb, and arrows.
*   **`TMemo` (Swift: `MemoView`)**:
    *   **What was done:** Created a `MemoView` class inheriting from `BaseView`. Implemented properties for `text`, `cursorPosition`, `scrollOffset`, and integrated with `ScrollBar`. Overridden `draw(in:)` to render multi-line text and cursor, and `handle(keyEvent:)` for editing and navigation.

### Milestone 5: Menu System (Completed)

**Goal:** Implement a comprehensive menu system for application navigation and command execution.

*   **`TMenuBar` / `TMenuBox` / `TMenuPop` (Swift: `MenuBar` / `MenuBox` / `PopupMenu`)**:
    *   **What was done:**
        *   Created a `MenuItem` struct to define menu entries.
        *   Implemented `MenuBar` inheriting from `BaseView` to display top-level menus, handling keyboard and mouse interaction to activate menus.
        *   Implemented `MenuBox` inheriting from `BaseView` to display dropdown menus, handling item selection and navigation.
        *   Implemented `PopupMenu` inheriting from `MenuBox`, providing similar functionality for context menus.

### Implemented Additional Components

The following components, initially listed under "Future Roadmap: Missing Widgets from C++ Tvision" and "Additional Components (Post-Milestones)", have been implemented in their basic form:

*   **`TStatusLine` (Swift: `StatusLine`)**: A status bar component for displaying messages and indicators at the bottom of the application.
*   **`TCheckBox` (Swift: `CheckBox`)**: A standard checkbox control for boolean selections.
*   **`TRadioButton` (Swift: `RadioButton`)**: A radio button control for exclusive selections within a group, integrated with `Cluster` for group management.
*   **Color Management (Swift: `ColorTheme`, `Palette`, `ColorPair`)**: A system for defining and applying color schemes to various UI elements, replacing hardcoded ANSI colors.
*   **Input Validation (Swift: `Validator`, `ValidationResult`)**: Mechanisms for validating user input in controls like `InputLine` and `MemoView`, providing visual feedback for invalid input.
*   **History Management (Swift: `HistoryManager`, `HistoryEntry`)**: A generic history stack for undo/redo operations, integrated into `InputLine` and `MemoView`.
*   **File Dialogs (Swift: `FileDialog`)**: A basic file selection dialog for browsing directories and selecting files.
*   **`TEditor` (Swift: `EditorView`)**: A basic text editor component inheriting from `MemoView`, with enhanced key event handling for cursor movement, undo/redo, and selection.

### Additional Components (Post-Milestones):
(All components have been implemented in their basic form.)

This structured approach will allow for incremental development and testing, building up the `SwiftTUI` framework layer by layer, with a strong emphasis on the custom terminal interaction layer as the foundation.

## 7. Development Roadmap: Future Milestones for Full C++ Tvision Parity

To achieve full feature parity with the original C++ Tvision framework, the following future milestones are proposed, building upon the already implemented components:

### Milestone 6: Enhanced Terminal Integration & Event Loop

**Goal:** Develop a highly robust and efficient low-level terminal interaction layer and a sophisticated event processing system.

*   **Comprehensive Terminal Capability Detection:** Implement mechanisms to understand and utilize `terminfo`/`termcap` databases for robust feature detection (e.g., advanced color support, character sets, cursor shapes, keyboard remapping) across a wide range of terminal emulators.
*   **Optimized Rendering Strategies:** Implement more sophisticated diffing algorithms for the `ScreenBuffer` to minimize actual terminal writes, potentially handling partial screen updates more efficiently to reduce flicker and improve performance.
*   **Advanced Input Handling:** Develop more robust parsing of complex terminal escape sequences (e.g., for various function keys, modifier combinations beyond basic Ctrl/Alt/Shift), handling of paste events, and potentially support for more terminal-specific input features.
*   **Sophisticated Event Loop (Blocking I/O):** Transition the `Application`'s event loop from a polling-based mechanism to a truly event-driven, blocking I/O model (using `select()` or `poll()`) to significantly reduce CPU usage when the application is idle. This also includes implementing more advanced event dispatching, such as event bubbling/tunneling and global event handlers.

### Milestone 6.1: TVision Widget Parity (prioritaire avant tvedit)

**Goal:** Implémenter en Swift, 1:1 avec TVision, les contrôles manquants avant de porter l'exemple `tvedit`.

*   **Scroller/ScrollView conteneur** : conteneur scrollable générique avec barres de défilement.
*   **ComboBox / HistoryWindow** : saisie + liste déroulante / rappel d'historique.
*   **Outline/Tree viewer** et **Text/Help/Dir viewers** : lecteurs en défilement et arbres navigables.
*   **Surface/drawing helpers** requis par ces viewers.
*   **Clipboard** : aligner le comportement TVision (au-delà d'OSC52).
**Note:** Priorité à la fidélité TVision; optimisations Swift après la parité.

### Milestone 7: Advanced Editor Features

**Goal:** Enhance the `EditorView` component to provide a comprehensive text editing experience.

*   **Syntax Highlighting:** Implement support for highlighting different language constructs based on syntax rules.
*   **Advanced Selection Modes:** Beyond simple character-by-character selection, implement word, line, and block selection.
*   **Find and Replace Functionality:** Develop interactive search and replace capabilities within the editor content.
*   **Line Numbering:** Implement the display of line numbers alongside the text content.
*   **Clipboard Integration:** Provide robust copy, cut, and paste functionality that seamlessly interacts with the system clipboard.
*   **Advanced Cursor Movement:** Implement more intelligent word-based navigation, paragraph navigation, and potentially column-based movement.

### Milestone 8: Advanced Dialogs & Controls

*   **Advanced `FileDialog` Features:** Enhance the `FileDialog` to include file filtering by extension or other criteria, functionality to create new directories directly from the dialog, display of file metadata (sizes, modification dates, permissions), and more intuitive navigation (e.g., quick access to common locations, directory history).
*   **More Comprehensive Input Validation Framework:** Develop a more robust framework offering a library of common validators (e.g., for numbers, dates, email addresses, regular expressions) and more flexible ways to display validation status and error messages (e.g., with tooltips or dedicated error areas).
*   **Advanced Color Management UI:** Implement interactive user interfaces for color customization, allowing users to visually select and define custom color palettes at runtime, along with mechanisms to save and load these custom themes.

### Milestone 9: Tvision C++ Examples Reproduction

**Goal:** Reproduce all example applications from the original Tvision C++ framework within the `Examples` directory of the SwiftTUI framework. This will serve as a comprehensive validation of the framework's robustness, ease of use, and feature parity.

*   **Reproduce All Examples:** Port each example application from the C++ Tvision framework to SwiftTUI.
*   **Create `Examples` Directory:** Establish a dedicated `Examples` directory within the project to house these ported applications.
*   **Documentation and Usage:** Provide clear documentation for each example, explaining its purpose, how to build and run it, and highlighting the SwiftTUI features it demonstrates.
*   **Continuous Integration:** Integrate the building and testing of these examples into the CI/CD pipeline to ensure ongoing compatibility and prevent regressions.
