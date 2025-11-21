import Testing
@testable import SwiftTUI

@MainActor final class SwiftTUITests {

    // Mock View to track method calls
    class MockView: BaseView {
        var drawCalled = false
        var handleKeyEventCalled = false
        var handleMouseEventCalled = false
        var handleCommandCalled = false

        override func draw(in rect: Rect) {
            super.draw(in: rect)
            drawCalled = true
        }

        override func handle(keyEvent: KeyEvent) -> Bool {
            handleKeyEventCalled = true
            return true // Indicate that the event was handled
        }

        override func handle(mouseEvent: MouseEvent) -> Bool {
            handleMouseEventCalled = true
            return true // Indicate that the event was handled
        }

        override func handle(command: Command) -> Bool {
            handleCommandCalled = true
            return true // Indicate that the event was handled
        }
    }

    @Test func baseViewHandlesEvents() async throws {
        let mockView = MockView(frame: Rect(x: 0, y: 0, width: 80, height: 24))

        // Test Key Event
        let keyEvent = KeyEvent(character: "a", keyCode: 97, controlKeyState: [])
        _ = mockView.handle(keyEvent: keyEvent)
        #expect(mockView.handleKeyEventCalled == true)

        // Test Mouse Event
        let mouseEvent = MouseEvent(x: 10, y: 10, eventType: .mouseDown, controlKeyState: [])
        _ = mockView.handle(mouseEvent: mouseEvent)
        #expect(mockView.handleMouseEventCalled == true)

        // Test Command Event
        _ = mockView.handle(command: .cmQuit)
        #expect(mockView.handleCommandCalled == true)
    }

    @Test func viewHierarchyCoordinateConversion() async throws {
        let parentView = BaseView(frame: Rect(x: 10, y: 10, width: 100, height: 100))
        let childView = BaseView(frame: Rect(x: 5, y: 5, width: 50, height: 50))
        parentView.add(subview: childView)

        // Test global to local for childView
        let globalPoint = Point(x: 20, y: 20) // Global point (relative to screen origin)
        let expectedLocalPoint = Point(x: 5, y: 5) // Expected local point within childView
        let actualLocalPoint = childView.makeLocal(point: globalPoint)
        #expect(actualLocalPoint == expectedLocalPoint)

        // Test local to global for childView
        let localPoint = Point(x: 10, y: 10) // Local point within childView
        let expectedGlobalPoint = Point(x: 25, y: 25) // Expected global point
        let actualGlobalPoint = childView.makeGlobal(point: localPoint)
        #expect(actualGlobalPoint == expectedGlobalPoint)
    }
}
