//
//  MockNFCReadingSession.swift
//  JKDesFireReaderTests
//
//  A test double for JKNFCReadingSessionProtocol.
//  Tests push events into `continuation` to drive the reader under test.
//

import Foundation
@testable import JKDesFireReader

final class MockNFCReadingSession: JKNFCReadingSessionProtocol {

    private(set) var tagStream: AsyncStream<JKNFCTagEvent>
    private(set) var continuation: AsyncStream<JKNFCTagEvent>.Continuation?

    private(set) var startCalled = false
    private(set) var stopCalled = false
    private(set) var stopErrorMessage: String?

    init() {
        (tagStream, continuation) = AsyncStream.makeStream(of: JKNFCTagEvent.self)
    }

    func start() { startCalled = true }

    func stop() {
        stopCalled = true
        continuation?.finish()
        continuation = nil
    }

    func stop(errorMessage: String) {
        stopCalled = true
        stopErrorMessage = errorMessage
        continuation?.finish()
        continuation = nil
    }

    // MARK: - Test helpers

    /// Simulates a successful tag detection.
    func simulateTagDetected(_ tag: any JKDesFireTagProtocol = MockDesFireTag()) {
        continuation?.yield(.detected(tag))
    }

    /// Simulates a session / tag error.
    func simulateError(_ error: JKDesFirePublicError) {
        continuation?.yield(.error(error))
    }

    /// Finishes the stream (session ended normally).
    func simulateSessionEnd() {
        continuation?.finish()
        continuation = nil
    }
}

// MARK: - MockDelegate

/// Collects delegate callbacks for assertion.
final class MockReaderDelegate: JKDesFireReaderDelegate {

    private(set) var detectedCalled = false
    private(set) var receivedError: JKDesFirePublicError?
    private(set) var detectedCount = 0

    func didDetectDesFireTag() {
        detectedCalled = true
        detectedCount += 1
    }

    func tagDetectionError(error: JKDesFirePublicError) {
        receivedError = error
    }
}
