import Foundation

/// Incremental parser for terminal input streams mirroring the
/// responsibilities of TVision's TermIO state machine.
final class TerminalInputParser {
    private var escapeSequenceBuffer: [UInt8] = []
    private let maxEscapeSequenceLength = 256
    private var isBracketPasteMode = false
    private var bracketPasteBuffer: [UInt8] = []

    func reset() {
        escapeSequenceBuffer.removeAll(keepingCapacity: true)
        bracketPasteBuffer.removeAll(keepingCapacity: true)
        isBracketPasteMode = false
    }

    func feed(byte: UInt8) -> [Event] {
        var events: [Event] = []

        if isBracketPasteMode && escapeSequenceBuffer.isEmpty {
            if byte == 0x1B {
                escapeSequenceBuffer = [byte]
            } else {
                bracketPasteBuffer.append(byte)
            }
            return events
        }

        if byte == 0x1B { // ESC
            escapeSequenceBuffer = [byte]
            return events
        }

        if !escapeSequenceBuffer.isEmpty {
            escapeSequenceBuffer.append(byte)
            let result = parseEscapeSequence(buffer: escapeSequenceBuffer)
            switch result {
            case .handled(let producedEvents):
                escapeSequenceBuffer.removeAll(keepingCapacity: true)
                events.append(contentsOf: producedEvents)
            case .pending:
                break
            case .invalid:
                if isBracketPasteMode {
                    bracketPasteBuffer.append(contentsOf: escapeSequenceBuffer)
                }
                escapeSequenceBuffer.removeAll(keepingCapacity: true)
            }
            if escapeSequenceBuffer.count > maxEscapeSequenceLength {
                escapeSequenceBuffer.removeAll(keepingCapacity: true)
            }
            return events
        }

        if let event = parsePrintable(byte: byte) {
            events.append(event)
        }
        return events
    }

    private func parsePrintable(byte: UInt8) -> Event? {
        var controlKeyState: ControlKeyState = []
        var finalChar: String? = nil
        var finalKeyCode = Int(byte)

        if byte >= 0x01 && byte <= 0x1A {
            controlKeyState.insert(.control)
            let scalar = UnicodeScalar(0x60 + Int(byte))!
            finalChar = String(scalar)
            finalKeyCode = Int(scalar.value)
        } else if let scalar = UnicodeScalar(Int(byte)) {
            finalChar = String(scalar)
        }

        let keyEvent = KeyEvent(character: finalChar, keyCode: finalKeyCode, controlKeyState: controlKeyState)
        return .key(keyEvent)
    }

    private enum EscapeParseResult {
        case pending
        case handled([Event])
        case invalid
    }

    private func parseEscapeSequence(buffer: [UInt8]) -> EscapeParseResult {
        guard buffer.first == 0x1B else { return .invalid }

        if buffer.count == 2 {
            let next = buffer[1]
            if next == 0x5B || next == 0x4F { // CSI or SS3, need more bytes
                return .pending
            }
            if let scalar = UnicodeScalar(Int(next)) {
                let keyEvent = KeyEvent(character: String(scalar), keyCode: Int(next), controlKeyState: [.alt])
                return .handled([.key(keyEvent)])
            }
            return .invalid
        }

        switch buffer[1] {
        case 0x5B: // CSI
            return parseCSISequence(buffer)
        case 0x4F: // SS3 (F1-F4, keypad)
            if let event = parseSS3Sequence(buffer) {
                return .handled([event])
            }
            return buffer.count < 3 ? .pending : .invalid
        case 0x5F: // ESC _
            return parseFar2lSequence(buffer)
        case 0x5D: // OSC
            return parseOSCSequence(buffer)
        default:
            return .invalid
        }
    }

    private func parseCSISequence(_ buffer: [UInt8]) -> EscapeParseResult {
        guard buffer.count >= 3 else { return .pending }
        guard let finalByte = buffer.last, finalByte >= 0x40 && finalByte <= 0x7E else { return .pending }

        // SGR mouse
        if buffer.count >= 4 && buffer[2] == 0x3C && (finalByte == 0x4D || finalByte == 0x6D) {
            if let event = parseSGRMouse(buffer) {
                return .handled([event])
            }
            return .invalid
        }

        let parameterBytes = buffer.dropFirst(2).dropLast()

        if finalByte == 0x7E {
            if let parameters = parseCSINumericParameters(parameterBytes) {
                if parameters.count == 1 {
                    switch parameters[0] {
                    case 200:
                        isBracketPasteMode = true
                        bracketPasteBuffer.removeAll()
                        return .handled([])
                    case 201:
                        isBracketPasteMode = false
                        let events = flushBracketPasteBuffer()
                        return .handled(events)
                    default:
                        break
                    }
                } else if parameters.count == 3 && parameters[0] == 27 {
                    if let event = keyEventFromCodepoint(parameters[2], modifiers: parameters[1]) {
                        return .handled([event])
                    }
                    return .invalid
                }

                if let event = mapTildeSequence(parameters) {
                    return .handled([event])
                }
            } else {
                return .invalid
            }
        }

        if finalByte == 0x75 { // Kitty keyboard protocol
            if let event = parseKittySequence(parameterBytes) {
                return .handled([event])
            }
            return .invalid
        }

        if finalByte == 0x5F {
            // Win32 input mode sequences; currently not decoded on Unix.
            return .handled([])
        }

        if finalByte >= 0x41 && finalByte <= 0x44 { // Cursor keys
            if let parameters = parseCSINumericParameters(parameterBytes) {
                if let event = mapCursorKey(finalByte: finalByte, parameters: parameters) {
                    return .handled([event])
                }
            } else if parameterBytes.isEmpty {
                if let event = mapCursorKey(finalByte: finalByte, parameters: []) {
                    return .handled([event])
                }
            } else {
                return .invalid
            }
        }

        return .pending
    }

    private func parseFar2lSequence(_ buffer: [UInt8]) -> EscapeParseResult {
        guard buffer.count >= 2 else { return .pending }
        guard buffer[buffer.count - 2] == 0x1B,
              buffer[buffer.count - 1] == 0x5C else {
            return .pending
        }
        let payload = buffer[2..<(buffer.count - 2)]
        guard let payloadString = String(bytes: payload, encoding: .utf8) else {
            return .handled([])
        }
        if payloadString == "far2l1" || payloadString == "far2l0" {
            return .handled([])
        }
        if payloadString.hasPrefix("far2l:") {
            let base64Part = payloadString.dropFirst("far2l:".count)
            if let decoded = Data(base64Encoded: String(base64Part)),
               let pasteText = decodeFar2lClipboard(from: decoded) {
                return .handled([.paste(pasteText)])
            }
        }
        return .handled([])
    }

    private func parseOSCSequence(_ buffer: [UInt8]) -> EscapeParseResult {
        guard buffer.count >= 3 else { return .pending }
        let terminator = buffer.last!
        var contentSlice: ArraySlice<UInt8>?
        if terminator == 0x07 { // BEL
            contentSlice = buffer[2..<(buffer.count - 1)]
        } else if terminator == 0x5C && buffer[buffer.count - 2] == 0x1B {
            contentSlice = buffer[2..<(buffer.count - 2)]
        } else {
            return .pending
        }

        guard let contentData = contentSlice,
              let content = String(bytes: contentData, encoding: .utf8) else {
            return .handled([])
        }

        if content.hasPrefix("52;") {
            let parts = content.split(separator: ";", omittingEmptySubsequences: false)
            if let base64Part = parts.last,
               let decodedData = Data(base64Encoded: String(base64Part)),
               let text = String(data: decodedData, encoding: .utf8) {
                return .handled([.paste(text)])
            }
        }

        return .handled([])
    }

    private func decodeFar2lClipboard(from data: Data) -> String? {
        guard data.count >= 5 else { return nil }
        guard let lastByte = data.last, lastByte == 0xA0 else { return nil }
        let lengthStart = data.count - 5
        let lengthData = data[lengthStart..<(lengthStart + 4)]
        var length: UInt32 = 0
        for (shift, byte) in lengthData.enumerated() {
            length |= UInt32(byte) << (8 * shift)
        }
        guard length <= UInt32(data.count - 5) else { return nil }
        let textStart = Int(data.count - 5) - Int(length)
        guard textStart >= 0 else { return nil }
        var textSlice = data[textStart..<(textStart + Int(length))]
        if let last = textSlice.last, last == 0 {
            textSlice = textSlice.dropLast()
        }
        return String(data: textSlice, encoding: .utf8)
    }

    private func parseSS3Sequence(_ buffer: [UInt8]) -> Event? {
        guard buffer.count >= 3 else { return nil }
        switch buffer[2] {
        case 0x50: return .key(KeyEvent(character: nil, keyCode: KeyEvent.KeyCode.f1, controlKeyState: []))
        case 0x51: return .key(KeyEvent(character: nil, keyCode: KeyEvent.KeyCode.f2, controlKeyState: []))
        case 0x52: return .key(KeyEvent(character: nil, keyCode: KeyEvent.KeyCode.f3, controlKeyState: []))
        case 0x53: return .key(KeyEvent(character: nil, keyCode: KeyEvent.KeyCode.f4, controlKeyState: []))
        default: return nil
        }
    }

    private func parseSGRMouse(_ buffer: [UInt8]) -> Event? {
        guard let terminator = buffer.last, terminator == 0x4D || terminator == 0x6D else {
            return nil
        }

        let body = buffer.dropFirst(3).dropLast()
        let components = body.split(separator: 0x3B)
        guard components.count == 3,
              let buttonCode = parseDigits(components[0]),
              let xValue = parseDigits(components[1]),
              let yValue = parseDigits(components[2]) else {
            return nil
        }

        var controlKeyState: ControlKeyState = []
        if (buttonCode & 0b100) != 0 { controlKeyState.insert(.shift) }
        if (buttonCode & 0b1000) != 0 { controlKeyState.insert(.alt) }
        if (buttonCode & 0b10000) != 0 { controlKeyState.insert(.control) }

        var eventType: EventType = .mouseDown
        if terminator == 0x6D {
            eventType = .mouseUp
        } else if (buttonCode & 0b1100000) == 0b1000000 || (buttonCode & 0b1100000) == 0b1010000 {
            eventType = .mouseWheel
        } else if (buttonCode & 0b100000) != 0 {
            eventType = .mouseDrag
        }

        let event = MouseEvent(x: max(0, xValue - 1), y: max(0, yValue - 1), eventType: eventType, controlKeyState: controlKeyState)
        return .mouse(event)
    }

    private func parseCSINumericParameters(_ bytes: ArraySlice<UInt8>) -> [Int]? {
        if bytes.isEmpty { return [] }
        let string = String(decoding: bytes, as: UTF8.self)
        let parts = string.split(separator: ";", omittingEmptySubsequences: false)
        var values: [Int] = []
        for part in parts {
            if part.isEmpty {
                values.append(0)
            } else if let value = Int(part) {
                values.append(value)
            } else {
                return nil
            }
        }
        return values
    }

    private func mapTildeSequence(_ values: [Int]) -> Event? {
        guard let code = values.first else { return nil }
        let keyCode: Int?
        switch code {
        case 1, 7: keyCode = KeyEvent.KeyCode.home
        case 4, 8: keyCode = KeyEvent.KeyCode.end
        case 5: keyCode = KeyEvent.KeyCode.pageUp
        case 6: keyCode = KeyEvent.KeyCode.pageDown
        case 2: keyCode = KeyEvent.KeyCode.insert
        case 3: keyCode = KeyEvent.KeyCode.delete
        case 11...15: keyCode = KeyEvent.KeyCode.f1 + (code - 11)
        case 17...21: keyCode = KeyEvent.KeyCode.f6 + (code - 17)
        case 23, 24: keyCode = KeyEvent.KeyCode.f11 + (code - 23)
        default: keyCode = nil
        }

        guard let resolvedKeyCode = keyCode else { return nil }
        var modifiers: ControlKeyState = []
        if values.count > 1 {
            modifiers = controlState(fromXtermModifier: values[1])
        }
        return .key(KeyEvent(character: nil, keyCode: resolvedKeyCode, controlKeyState: modifiers))
    }

    private func mapCursorKey(finalByte: UInt8, parameters: [Int]) -> Event? {
        let keyCode: Int
        switch finalByte {
        case 0x41: keyCode = KeyEvent.KeyCode.upArrow
        case 0x42: keyCode = KeyEvent.KeyCode.downArrow
        case 0x43: keyCode = KeyEvent.KeyCode.rightArrow
        case 0x44: keyCode = KeyEvent.KeyCode.leftArrow
        default: return nil
        }
        var modifiers: ControlKeyState = []
        if let modValue = parameters.last, parameters.count >= 2 {
            modifiers = controlState(fromXtermModifier: modValue)
        }
        return .key(KeyEvent(character: nil, keyCode: keyCode, controlKeyState: modifiers))
    }

    private func parseKittySequence(_ bytes: ArraySlice<UInt8>) -> Event? {
        let sanitized = bytes.map { $0 == 0x3A ? UInt8(0x3B) : $0 } // Treat ':' as ';'
        let string = String(decoding: sanitized, as: UTF8.self)
        let parts = string.split(separator: ";", omittingEmptySubsequences: false)
        guard let keyPart = parts.first, let key = Int(keyPart) else { return nil }
        let modifiers = parts.count > 1 ? (Int(parts[1]) ?? 1) : 1
        let eventType = parts.count > 2 ? (Int(parts[2]) ?? 1) : 1
        let textCode = parts.count > 3 ? (Int(parts[3]) ?? 0) : 0
        guard eventType == 1 else { return nil }
        let codepoint = textCode != 0 ? textCode : key
        return keyEventFromCodepoint(codepoint, modifiers: modifiers)
    }

    private func keyEventFromCodepoint(_ codepoint: Int, modifiers: Int) -> Event? {
        guard let scalar = UnicodeScalar(codepoint) else { return nil }
        let controlState = controlState(fromXtermModifier: modifiers)
        let keyEvent = KeyEvent(character: String(scalar), keyCode: Int(scalar.value), controlKeyState: controlState)
        return .key(keyEvent)
    }

    private func controlState(fromXtermModifier value: Int) -> ControlKeyState {
        if value <= 1 { return [] }
        let mask = value - 1
        var state: ControlKeyState = []
        if (mask & 0b001) != 0 { state.insert(.shift) }
        if (mask & 0b010) != 0 { state.insert(.alt) }
        if (mask & 0b100) != 0 { state.insert(.control) }
        return state
    }

    private func flushBracketPasteBuffer() -> [Event] {
        guard !bracketPasteBuffer.isEmpty else { return [] }
        let pastedString = String(decoding: bracketPasteBuffer, as: UTF8.self)
        bracketPasteBuffer.removeAll(keepingCapacity: true)
        var events: [Event] = []
        for scalar in pastedString.unicodeScalars {
            let keyEvent = KeyEvent(character: String(scalar), keyCode: Int(scalar.value), controlKeyState: [])
            events.append(.key(keyEvent))
        }
        return events
    }

    private func parseDigits(_ bytes: ArraySlice<UInt8>) -> Int? {
        var value = 0
        for byte in bytes {
            guard byte >= 0x30 && byte <= 0x39 else { return nil }
            value = value * 10 + Int(byte - 0x30)
        }
        return value
    }
}
