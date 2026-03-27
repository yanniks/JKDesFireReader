//
//  JKDesFireReaderTests.swift
//  JKDesFireReaderTests
//

import Testing
@testable import JKDesFireReader

// MARK: - Helper: create a reader backed by a mock session

private func makeReader(
    delegate: MockReaderDelegate? = nil
) -> (reader: JKDesFireReader, session: MockNFCReadingSession) {
    let session = MockNFCReadingSession()
    let reader = JKDesFireReader(
        delegate: delegate,
        sessionFactory: { _, _ in session }
    )
    return (reader, session)
}

// MARK: - Suite

@Suite("JKDesFireReader")
struct JKDesFireReaderTests {

    // MARK: Session lifecycle

    @Test func createReaderSession_startsMockSession() {
        let (reader, session) = makeReader()
        let created = reader.createReaderSession()
        #expect(created == true)
        #expect(session.startCalled == true)
    }

    @Test func createReaderSession_returnsFalse_whenAlreadyRunning() {
        let (reader, _) = makeReader()
        _ = reader.createReaderSession()
        let second = reader.createReaderSession()
        #expect(second == false)
    }

    @Test func stopRunningSession_callsSessionStop() {
        let (reader, session) = makeReader()
        reader.createReaderSession()
        reader.stopRunningSession()
        #expect(session.stopCalled == true)
    }

    @Test func stopRunningSession_withMessage_callsSessionStopWithMessage() {
        let (reader, session) = makeReader()
        reader.createReaderSession()
        reader.stopRunningSession(errorMessage: "Cancelled")
        #expect(session.stopErrorMessage == "Cancelled")
    }

    @Test func sessionIsOpen_falseBeforeTagDetected() {
        let (reader, _) = makeReader()
        reader.createReaderSession()
        #expect(reader.sessionIsOpen() == false)
    }

    @Test func getErrorStatus_falseInitially() {
        let (reader, _) = makeReader()
        #expect(reader.getErrorStatus() == false)
    }

    // MARK: Tag detection → delegate callbacks

    @Test func tagDetected_callsDelegate_didDetectDesFireTag() async throws {
        let delegate = MockReaderDelegate()
        let (reader, session) = makeReader(delegate: delegate)
        reader.createReaderSession()

        session.simulateTagDetected()
        // Give the internal Task time to process
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(delegate.detectedCalled == true)
        #expect(reader.sessionIsOpen() == true)
    }

    @Test func tagDetectionError_callsDelegate_tagDetectionError() async throws {
        let delegate = MockReaderDelegate()
        let (reader, session) = makeReader(delegate: delegate)
        reader.createReaderSession()

        session.simulateError(.ERR_MIFARE_PLUS)
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(delegate.receivedError == .ERR_MIFARE_PLUS)
        #expect(reader.getErrorStatus() == true)
        #expect(reader.getErrorReason() == .ERR_MIFARE_PLUS)
    }

    // MARK: Tag detection → sessionEvents stream

    @Test func sessionEvents_emitsTagDetected_onTagArrival() async throws {
        let (reader, session) = makeReader()
        reader.createReaderSession()

        var received: [JKDesFireSessionEvent] = []
        let collectTask = Task {
            for await event in reader.sessionEvents {
                received.append(event)
                if received.count == 1 { break }
            }
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        session.simulateTagDetected()
        try await Task.sleep(nanoseconds: 50_000_000)
        collectTask.cancel()

        #expect(received.count == 1)
        if case .tagDetected = received[0] {} else {
            Issue.record("Expected .tagDetected, got \(received[0])")
        }
    }

    @Test func sessionEvents_emitsError_onTagError() async throws {
        let (reader, session) = makeReader()
        reader.createReaderSession()

        var received: [JKDesFireSessionEvent] = []
        let collectTask = Task {
            for await event in reader.sessionEvents {
                received.append(event)
                if received.count == 1 { break }
            }
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        session.simulateError(.ERR_SESSION_INVALIDATED)
        try await Task.sleep(nanoseconds: 50_000_000)
        collectTask.cancel()

        #expect(received.count == 1)
        if case .error(let e) = received[0] {
            #expect(e == .ERR_SESSION_INVALIDATED)
        } else {
            Issue.record("Expected .error, got \(received[0])")
        }
    }

    // MARK: sessionEvents shared — multiple consumers each receive all events

    @Test func sessionEvents_shared_bothConsumersReceiveEvent() async throws {
        let (reader, session) = makeReader()
        reader.createReaderSession()

        var consumer1: [JKDesFireSessionEvent] = []
        var consumer2: [JKDesFireSessionEvent] = []

        let t1 = Task {
            for await event in reader.sessionEvents {
                consumer1.append(event)
                if consumer1.count == 1 { break }
            }
        }
        let t2 = Task {
            for await event in reader.sessionEvents {
                consumer2.append(event)
                if consumer2.count == 1 { break }
            }
        }

        // Wait for both consumers to be ready
        try await Task.sleep(nanoseconds: 20_000_000)
        session.simulateTagDetected()
        try await Task.sleep(nanoseconds: 80_000_000)
        t1.cancel()
        t2.cancel()

        // Both consumers should have received the event
        #expect(consumer1.count == 1)
        #expect(consumer2.count == 1)
    }

    // MARK: listApplications

    @Test func listApplications_throwsNoTagFound_whenNoTagPresent() async {
        let (reader, _) = makeReader()

        await #expect(throws: JKDesFirePublicError.ERR_NO_TAG_FOUND) {
            _ = try await reader.listApplications()
        }
    }

    @Test func listApplications_returnsIds_afterTagDetection() async throws {
        let (reader, session) = makeReader()
        reader.createReaderSession()

        let tag = MockDesFireTag()
        // Three application IDs: 0x010203, 0x040506, 0x070809
        let payload: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09]
        tag.stub(command: JKDesFireCommands.GET_APPLICATION_DIRECTORY.rawValue,
                 returning: Data(payload))

        session.simulateTagDetected(tag)
        try await Task.sleep(nanoseconds: 50_000_000)

        let ids = try await reader.listApplications()

        #expect(ids.count == 3)
        #expect(ids[0] == 0x010203)
        #expect(ids[1] == 0x040506)
        #expect(ids[2] == 0x070809)
    }

    @Test func listApplications_throwsUnknownResult_whenByteCountNotMultipleOfThree() async throws {
        let (reader, session) = makeReader()
        reader.createReaderSession()

        let tag = MockDesFireTag()
        tag.stub(command: JKDesFireCommands.GET_APPLICATION_DIRECTORY.rawValue,
                 returning: Data([0x01, 0x02])) // 2 bytes — not divisible by 3
        session.simulateTagDetected(tag)
        try await Task.sleep(nanoseconds: 50_000_000)

        await #expect(throws: JKDesFirePublicError.ERR_UNKNOWN_RESULT) {
            _ = try await reader.listApplications()
        }
    }

    // MARK: selectApplication

    @Test func selectApplication_throwsNoTagFound_whenNoTagPresent() async {
        let (reader, _) = makeReader()

        await #expect(throws: JKDesFirePublicError.ERR_NO_TAG_FOUND) {
            _ = try await reader.selectApplication(applicationId: 0x010203)
        }
    }

    @Test func selectApplication_throwsWrongInputLength_forInvalidAppId() async throws {
        let (reader, session) = makeReader()
        reader.createReaderSession()
        session.simulateTagDetected()
        try await Task.sleep(nanoseconds: 50_000_000)

        // 0x000000 would produce empty bytes after filtering, then 0 bytes ≠ 3
        await #expect(throws: JKDesFirePublicError.ERR_WRONG_INPUT_LENGTH) {
            _ = try await reader.selectApplication(applicationId: 0x00000000)
        }
    }

    @Test func selectApplication_returnsApplication_afterTagDetection() async throws {
        let (reader, session) = makeReader()
        reader.createReaderSession()

        let tag = MockDesFireTag()
        tag.stub(command: JKDesFireCommands.SELECT_APPLICATION.rawValue, returning: Data())
        tag.stub(command: JKDesFireCommands.GET_FILES.rawValue, returning: Data([0x01, 0x02]))
        session.simulateTagDetected(tag)
        try await Task.sleep(nanoseconds: 50_000_000)

        let app = try await reader.selectApplication(applicationId: 0x010203)

        #expect(app.applicationId == 0x010203)
        #expect(app.files == [0x01, 0x02])
    }

    @Test func selectApplication_sendsCorrectCommandAndParameters() async throws {
        let (reader, session) = makeReader()
        reader.createReaderSession()

        let tag = MockDesFireTag()
        tag.stub(command: JKDesFireCommands.SELECT_APPLICATION.rawValue, returning: Data())
        tag.stub(command: JKDesFireCommands.GET_FILES.rawValue, returning: Data())
        session.simulateTagDetected(tag)
        try await Task.sleep(nanoseconds: 50_000_000)

        _ = try await reader.selectApplication(applicationId: 0x010203)

        let selectCall = tag.callLog.first {
            $0.command == JKDesFireCommands.SELECT_APPLICATION.rawValue
        }
        #expect(selectCall?.parameters == [0x01, 0x02, 0x03])
    }
}
