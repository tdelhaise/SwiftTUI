import Testing
@testable import SwiftTUI

@MainActor
struct RenderingHarness {
    let terminal: MockTerminal
    let application: Application

    init(size: Size = Size(width: 80, height: 24)) {
        self.terminal = MockTerminal()
        self.terminal.windowSize = size
        self.application = Application(terminal: terminal)
    }

    func render(view: View) -> ScreenSnapshot {
        application.setRootView(view)
        view.draw(in: Rect(x: 0, y: 0, width: terminal.windowSize.width, height: terminal.windowSize.height))
        return terminal.snapshot()
    }
}

@MainActor
struct InputSimulator {
    private var parser = TerminalInputParser()

    mutating func send(_ string: String, to application: Application) {
        for byte in string.utf8 {
            let events = parser.feed(byte: byte)
            for event in events {
                application._handle(event: event)
            }
        }
    }
}

@MainActor
@Suite struct RenderingTests {
    @Test func inputLineRendersText() async throws {
        let harness = RenderingHarness()
        let input = InputLine(frame: Rect(x: 0, y: 0, width: 10, height: 1), text: "Hello")
        input.state.insert(.sfFocused)

        let snapshot = harness.render(view: input)
        let firstLine = snapshot.asciiRepresentation().first ?? ""
        #expect(firstLine.hasPrefix("Hello"))
    }
}

@MainActor
@Suite struct InputSimulationTests {
    @Test func typingUpdatesInputLine() async throws {
        let harness = RenderingHarness()
        let input = InputLine(frame: Rect(x: 0, y: 0, width: 10, height: 1))
        input.state.insert(.sfFocused)
        harness.application.setRootView(input)

        var simulator = InputSimulator()
        simulator.send("abc", to: harness.application)

        #expect(input.text == "abc")
    }
}
