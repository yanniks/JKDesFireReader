//
//  JKNFCReadingSession.swift
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
import os.log

// MARK: - Internal event type

/// Events produced by the NFC reading session (internal to this module).
enum JKNFCTagEvent: Sendable {
    case detected(any JKDesFireTagProtocol)
    case error(JKDesFirePublicError)
}

// MARK: - Session protocol (enables injection / mocking in tests)

/// Internal contract for an NFC reading session.
/// Consumers iterate `tagStream` to receive tag-detection events.
/// Because `tagStream` is an `AsyncStream`, callers can call `.shared()`
/// from swift-async-algorithms to broadcast events to multiple observers.
protocol JKNFCReadingSessionProtocol: AnyObject {
    /// An async sequence of tag-detection events.
    var tagStream: AsyncStream<JKNFCTagEvent> { get }
    func start()
    func stop()
    func stop(errorMessage: String)
}

// MARK: - Concrete implementation

final class JKNFCReadingSession: NSObject, NFCTagReaderSessionDelegate, JKNFCReadingSessionProtocol {

    // MARK: Properties

    private var nfcSession: NFCTagReaderSession?
    private let errorInfoText: String
    private var continuation: AsyncStream<JKNFCTagEvent>.Continuation?

    private(set) var tagStream: AsyncStream<JKNFCTagEvent>

    // MARK: Initialization

    init(
        sessionInfoText: String = "Hold your NFC tag near the top of your iPhone.",
        errorInfoText: String = "Error reading your tag."
    ) {
        self.errorInfoText = errorInfoText

        (tagStream, continuation) = AsyncStream.makeStream(of: JKNFCTagEvent.self)

        super.init()

        nfcSession = NFCTagReaderSession(
            pollingOption: [.iso14443, .iso15693],
            delegate: self
        )
        nfcSession?.alertMessage = sessionInfoText
    }

    // MARK: JKNFCReadingSessionProtocol

    func start() {
        nfcSession?.begin()
    }

    func stop() {
        nfcSession?.invalidate()
        finish()
    }

    func stop(errorMessage: String) {
        nfcSession?.invalidate(errorMessage: errorMessage)
        finish()
    }

    // MARK: Private

    private func finish() {
        continuation?.finish()
        continuation = nil
    }

    // MARK: NFCTagReaderSessionDelegate

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        os_log("NFC session invalidated. Reason: %@", error.localizedDescription)
        continuation?.yield(.error(.ERR_SESSION_INVALIDATED))
        finish()
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let firstTag = tags.first else {
            os_log("No tags detected.")
            session.invalidate(errorMessage: errorInfoText)
            continuation?.yield(.error(.ERR_NO_TAG_FOUND))
            return
        }

        guard case let .miFare(miFareTag) = firstTag else {
            session.invalidate(errorMessage: errorInfoText)
            continuation?.yield(.error(.ERR_MIFARE_ERROR))
            return
        }

        let family = miFareTag.mifareFamily
        guard family == .desfire else {
            let error: JKDesFirePublicError
            switch family {
            case .plus:      error = .ERR_MIFARE_PLUS
            case .ultralight: error = .ERR_MIFARE_ULTRALIGHT
            case .unknown:   error = .ERR_MIFARE_UNKNOWN
            default:         error = .ERR_MIFARE_ERROR
            }
            session.invalidate(errorMessage: errorInfoText)
            continuation?.yield(.error(error))
            return
        }

        session.connect(to: firstTag) { [weak self] connectError in
            guard let self else { return }
            if connectError != nil {
                self.continuation?.yield(.error(.ERR_COMMAND_EXECUTION_ERROR))
                return
            }
            let wrapper = JKNFCMiFareTagWrapper(tag: miFareTag)
            self.continuation?.yield(.detected(wrapper))
        }
    }
}
