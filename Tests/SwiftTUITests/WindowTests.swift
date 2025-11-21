import Testing
@testable import SwiftTUI

@MainActor
final class WindowTests {

    @Test func windowInitialization() async throws {
        let windowFrame = Rect(x: 10, y: 10, width: 50, height: 20)
        let windowTitle = "Test Window"
        let windowNumber = 1

        let window = Window(frame: windowFrame, title: windowTitle, number: windowNumber)

        #expect(window.frame == windowFrame)
        #expect(window.title == windowTitle)
        #expect(window.number == windowNumber)
        #expect(window.flags.contains([.wfMove, .wfGrow, .wfClose, .wfZoom]))
        #expect(window.palette == .wpBlueWindow)
        #expect(window.state.contains(.sfShadow))
        #expect(window.options.contains([.ofSelectable, .ofTopSelect]))
        #expect(window.subviews.count == 1)
        #expect(window.frameView != nil)
        #expect(window.frameView?.owner === window)
    }

    @Test func windowZoomFunctionality() async throws {
        let initialFrame = Rect(x: 10, y: 10, width: 50, height: 20)
        let window = Window(frame: initialFrame, title: "Zoom Window", number: 2)

        // Test zoom to maximized state
        window.zoom()
        #expect(window.frame == Rect(x: 0, y: 0, width: 80, height: 24)) // Example full screen
        #expect(window.zoomRect == initialFrame) // zoomRect should store the initial frame

        // Test zoom back to initial state
        window.zoom()
        #expect(window.frame == initialFrame)
        #expect(window.zoomRect == initialFrame) // Corrected expectation: zoomRect should still hold the initial frame
    }

    @Test func windowCloseFunctionality() async throws {
        let window = Window(frame: Rect(x: 0, y: 0, width: 10, height: 10), title: "Close Window", number: 3)
        // For now, close() just prints. We can't directly test removal from owner without a full Application setup.
        // We'll just call it to ensure it doesn't crash.
        window.close()
        // Future: Add assertions for removal from parent view hierarchy
    }

}
