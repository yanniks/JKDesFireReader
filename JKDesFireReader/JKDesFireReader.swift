//
//  JKDesFireReader.swift
//  JKDesFireReader
//
//  Created by Johannes Kreutz on 18.06.19.
//  Copyright © 2019 Johannes Kreutz. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import CoreNFC
import AsyncAlgorithms

public class JKDesFireReader {

    // MARK: - Public session-event stream
    //
    // `sessionEvents` is backed by an `AsyncStream` and exposed as an
    // `AsyncSharedSequence` via swift-async-algorithms' `shared()`.
    //
    // This means **multiple concurrent consumers** (e.g. a UI layer and a
    // logging layer) can each `for await event in reader.sessionEvents { … }`
    // independently and both will receive every event — no element is lost to
    // one consumer because another consumed it first.
    //
    // Example:
    //   Task { for await event in reader.sessionEvents { updateUI(event) } }
    //   Task { for await event in reader.sessionEvents { log(event) } }

    public let sessionEvents: AsyncSharedSequence<AsyncStream<JKDesFireSessionEvent>>

    // MARK: - Internal state

    private var _eventsContinuation: AsyncStream<JKDesFireSessionEvent>.Continuation?

    private var nfcSession: (any JKNFCReadingSessionProtocol)?

    /// Injected factory — replaced with a mock factory during unit tests.
    var sessionFactory: (_ sessionInfoText: String, _ errorInfoText: String) -> any JKNFCReadingSessionProtocol

    private var tag: (any JKDesFireTagProtocol)?
    private var status: Int = 0
    private var lastOccuredError: JKDesFirePublicError?
    private var sessionInfoText: String?
    private var errorInfoText: String?

    /// Optional delegate for tag-detection callbacks (runs on the calling task's context).
    public weak var delegate: (any JKDesFireReaderDelegate)?

    // MARK: - Initialization

    /// Creates a reader with an optional delegate.
    /// Call `createReaderSession()` to begin scanning.
    public convenience init(delegate: (any JKDesFireReaderDelegate)? = nil) {
        self.init(delegate: delegate, sessionFactory: { info, error in
            JKNFCReadingSession(sessionInfoText: info, errorInfoText: error)
        })
    }

    /// Designated initialiser — allows injecting a custom session factory for testing.
    init(
        delegate: (any JKDesFireReaderDelegate)? = nil,
        sessionFactory: @escaping (_ sessionInfoText: String, _ errorInfoText: String) -> any JKNFCReadingSessionProtocol
    ) {
        self.delegate = delegate
        self.sessionFactory = sessionFactory

        // Build the backing AsyncStream and expose it as a shared sequence.
        let (stream, continuation) = AsyncStream.makeStream(of: JKDesFireSessionEvent.self)
        _eventsContinuation = continuation
        sessionEvents = stream.shared()
    }

    // MARK: - Session lifecycle

    /// Starts a new NFC reading session.
    /// Returns `false` if a session is already running.
    @discardableResult
    public func createReaderSession() -> Bool {
        guard nfcSession == nil else { return false }

        let info  = sessionInfoText  ?? "Hold your NFC tag near the top of your iPhone."
        let error = errorInfoText    ?? "Error reading your tag."
        let session = sessionFactory(info, error)
        nfcSession = session
        status = 1

        // Consume the NFC session's tag stream in a background Task.
        // Because we call `.shared()` on `session.tagStream` here, any
        // additional observer that calls `.shared()` on the same stream
        // would also receive all events — demonstrating the share() pattern
        // at the NFC session level too.
        let sharedTagStream = session.tagStream.shared()

        Task { [weak self] in
            for await event in sharedTagStream {
                await self?.handle(tagEvent: event)
            }
            // Stream finished — clean up continuation
            self?._eventsContinuation?.finish()
            self?._eventsContinuation = nil
        }

        session.start()
        return true
    }

    public func setSessionInfoText(text: String) { sessionInfoText = text }
    public func setErrorInfoText(text: String)   { errorInfoText = text }

    public func stopRunningSession() {
        nfcSession?.stop()
        nfcSession = nil
    }

    public func stopRunningSession(errorMessage: String) {
        nfcSession?.stop(errorMessage: errorMessage)
        nfcSession = nil
    }

    public func sessionIsOpen() -> Bool { status == 2 }
    public func getErrorStatus() -> Bool { status < 0 }

    public func getErrorReason() -> JKDesFirePublicError {
        lastOccuredError!
    }

    // MARK: - Tag information

    public func getTagId() -> Int {
        guard let tag else { return -1 }
        return Int(littleEndian: tag.identifier.withUnsafeBytes { $0.load(as: Int.self) })
    }

    // MARK: - DesFire commands

    /// Lists all application IDs stored on the currently connected tag.
    public func listApplications() async throws -> [UInt32] {
        guard let tag else { throw JKDesFirePublicError.ERR_NO_TAG_FOUND }

        let data = try await tag.sendCommand(JKDesFireCommands.GET_APPLICATION_DIRECTORY.rawValue)
        let bytes = [UInt8](data)

        guard bytes.count % 3 == 0 else {
            throw JKDesFirePublicError.ERR_UNKNOWN_RESULT
        }

        var ids: [UInt32] = []
        var offset = 0
        while offset < bytes.count {
            let slice = Array(bytes[offset ..< offset + 3])
            guard let id = essentials.byteArrayToInt(input: slice) else {
                throw JKDesFirePublicError.ERR_UNKNOWN_RESULT
            }
            ids.append(id)
            offset += 3
        }
        return ids
    }

    /// Selects an application by its 3-byte ID and returns the application object.
    public func selectApplication(applicationId: UInt32) async throws -> any JKDesFireApplicationProtocol {
        guard let tag else { throw JKDesFirePublicError.ERR_NO_TAG_FOUND }

        // Convert to trimmed 3-byte representation
        let allBytes = essentials.intToByteArray(applicationId).filter { $0 != 0 }
        guard allBytes.count == 3 else {
            throw JKDesFirePublicError.ERR_WRONG_INPUT_LENGTH
        }

        // SELECT_APPLICATION returns nothing useful in the payload
        _ = try await tag.sendRequest(JKDesFireCommands.SELECT_APPLICATION.rawValue, allBytes)

        let application = JKDesFireApplication(id: applicationId, tag: tag)
        try await application.loadFiles()
        return application
    }

    // MARK: - Private event handler

    private func handle(tagEvent event: JKNFCTagEvent) {
        switch event {
        case .detected(let detectedTag):
            status = 2
            tag = detectedTag
            _eventsContinuation?.yield(.tagDetected)
            delegate?.didDetectDesFireTag()

        case .error(let error):
            status = -1
            lastOccuredError = error
            _eventsContinuation?.yield(.error(error))
            delegate?.tagDetectionError(error: error)
        }
    }
}
