//
//  JKNFCReadingSessionTests.swift
//  JKDesFireReaderTests
//
//  Tests for MockNFCReadingSession itself and for the event-driven
//  integration via the JKNFCReadingSessionProtocol contract.
//

import Testing
@testable import JKDesFireReader

@Suite("MockNFCReadingSession (protocol contract)")
struct MockNFCReadingSessionTests {

    @Test func start_setsStartedFlag() {
        let session = MockNFCReadingSession()
        session.start()
        #expect(session.startCalled == true)
    }

    @Test func stop_setsStoppedFlag() {
        let session = MockNFCReadingSession()
        session.start()
        session.stop()
        #expect(session.stopCalled == true)
    }

    @Test func stop_withMessage_recordsMessage() {
        let session = MockNFCReadingSession()
        session.stop(errorMessage: "Test error")
        #expect(session.stopErrorMessage == "Test error")
    }

    @Test func simulateTagDetected_emitsDetectedEvent() async throws {
        let session = MockNFCReadingSession()
        var events: [JKNFCTagEvent] = []

        let task = Task {
            for await event in session.tagStream {
                events.append(event)
                if events.count == 1 { break }
            }
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        session.simulateTagDetected()
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        #expect(events.count == 1)
        if case .detected = events[0] {} else {
            Issue.record("Expected .detected event")
        }
    }

    @Test func simulateError_emitsErrorEvent() async throws {
        let session = MockNFCReadingSession()
        var events: [JKNFCTagEvent] = []

        let task = Task {
            for await event in session.tagStream {
                events.append(event)
                if events.count == 1 { break }
            }
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        session.simulateError(.ERR_MIFARE_PLUS)
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        #expect(events.count == 1)
        if case .error(let e) = events[0] {
            #expect(e == .ERR_MIFARE_PLUS)
        } else {
            Issue.record("Expected .error event")
        }
    }

    @Test func simulateSessionEnd_finishesStream() async throws {
        let session = MockNFCReadingSession()
        var finished = false

        let task = Task {
            for await _ in session.tagStream {}
            finished = true
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        session.simulateSessionEnd()
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        #expect(finished == true)
    }

    @Test func multipleEvents_deliveredInOrder() async throws {
        let session = MockNFCReadingSession()
        var events: [JKNFCTagEvent] = []

        let task = Task {
            for await event in session.tagStream {
                events.append(event)
                if events.count == 2 { break }
            }
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        session.simulateTagDetected()
        session.simulateError(.ERR_SESSION_INVALIDATED)
        try await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        #expect(events.count == 2)
        if case .detected = events[0] {} else { Issue.record("First event should be .detected") }
        if case .error = events[1] {} else { Issue.record("Second event should be .error") }
    }
}
