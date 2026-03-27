//
//  JKDesFireTagProtocolTests.swift
//  JKDesFireReaderTests
//
//  Tests for the default implementations provided by JKDesFireTagProtocol
//  (sendCommand, wrapCommand) using MockDesFireTag.
//

import Testing
@testable import JKDesFireReader

@Suite("JKDesFireTagProtocol defaults")
struct JKDesFireTagProtocolTests {

    // MARK: - sendCommand (default implementation)

    @Test func sendCommand_delegatesToSendRequest_withEmptyParameters() async throws {
        let tag = MockDesFireTag()
        tag.stub(command: 0x6A, returning: Data([0x01, 0x02, 0x03]))

        let result = try await tag.sendCommand(0x6A)

        #expect(result == Data([0x01, 0x02, 0x03]))
        #expect(tag.callLog.count == 1)
        #expect(tag.callLog[0].command == 0x6A)
        #expect(tag.callLog[0].parameters == [])
    }

    @Test func sendCommand_propagatesError() async {
        let tag = MockDesFireTag()
        tag.stub(command: 0x6A, throwing: JKDesFirePublicError.ERR_PERMISSION_DENIED)

        await #expect(throws: JKDesFirePublicError.ERR_PERMISSION_DENIED) {
            _ = try await tag.sendCommand(0x6A)
        }
    }

    @Test func sendCommand_returnsEmptyDataWhenNoStub() async throws {
        let tag = MockDesFireTag()
        let result = try await tag.sendCommand(0xFF)
        #expect(result.isEmpty)
    }

    // MARK: - wrapCommand (default implementation)

    @Test func wrapCommand_noParameters_correctFormat() {
        let tag = MockDesFireTag()
        let data = tag.wrapCommand(0x6A, [])
        // Expected: [0x90, cmd, 0x00, 0x00, 0x00]
        #expect([UInt8](data) == [0x90, 0x6A, 0x00, 0x00, 0x00])
    }

    @Test func wrapCommand_withParameters_includesLengthByte() {
        let tag = MockDesFireTag()
        let data = tag.wrapCommand(0x5A, [0x01, 0x02, 0x03])
        // Expected: [0x90, 0x5A, 0x00, 0x00, len=3, 0x01, 0x02, 0x03, 0x00]
        #expect([UInt8](data) == [0x90, 0x5A, 0x00, 0x00, 0x03, 0x01, 0x02, 0x03, 0x00])
    }

    @Test func wrapCommand_singleParameter() {
        let tag = MockDesFireTag()
        let data = tag.wrapCommand(0xF5, [0x02])
        #expect([UInt8](data) == [0x90, 0xF5, 0x00, 0x00, 0x01, 0x02, 0x00])
    }

    // MARK: - identifier

    @Test func identifier_returnsConfiguredValue() {
        let tag = MockDesFireTag()
        tag.identifier = Data([0xAA, 0xBB, 0xCC, 0xDD])
        #expect(tag.identifier == Data([0xAA, 0xBB, 0xCC, 0xDD]))
    }
}
