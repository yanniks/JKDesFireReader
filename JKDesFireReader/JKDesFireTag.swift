//
//  JKDesFireTag.swift
//  JKDesFireReader
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

// MARK: - Protocol

/// Abstracts all DesFire tag communication, allowing full substitution in tests.
public protocol JKDesFireTagProtocol: Sendable {
    /// The raw identifier bytes of the NFC tag.
    var identifier: Data { get }

    /// Sends a DesFire command with optional parameters and returns the response payload.
    /// Handles multi-frame (ADDITIONAL_FRAME) responses transparently.
    func sendRequest(_ command: UInt8, _ parameters: [UInt8]) async throws -> Data
}

// MARK: - Default implementations

public extension JKDesFireTagProtocol {
    /// Convenience: sends a command with no parameters.
    func sendCommand(_ command: UInt8) async throws -> Data {
        try await sendRequest(command, [])
    }

    /// Wraps a DesFire command and its parameters into an ISO-APDU packet.
    func wrapCommand(_ command: UInt8, _ parameters: [UInt8]) -> Data {
        var bytes: [UInt8] = [0x90, command, 0x00, 0x00]
        if !parameters.isEmpty {
            bytes.append(UInt8(parameters.count))
            bytes.append(contentsOf: parameters)
        }
        bytes.append(0x00)
        return Data(bytes)
    }
}

// MARK: - Concrete wrapper around NFCMiFareTag

/// Production implementation that talks to a real `NFCMiFareTag`.
final class JKNFCMiFareTagWrapper: JKDesFireTagProtocol, @unchecked Sendable {

    private let tag: NFCMiFareTag

    init(tag: NFCMiFareTag) {
        self.tag = tag
    }

    var identifier: Data { tag.identifier }

    func sendRequest(_ command: UInt8, _ parameters: [UInt8]) async throws -> Data {
        try await doSendRequest(command, parameters, accumulated: nil)
    }

    // MARK: - Private

    private func doSendRequest(
        _ command: UInt8,
        _ parameters: [UInt8],
        accumulated: Data?
    ) async throws -> Data {
        let packet = wrapCommand(command, parameters)

        let raw: Data = try await withCheckedThrowingContinuation { continuation in
            self.tag.sendMiFareCommand(commandPacket: packet) { data, error in
                if error != nil {
                    continuation.resume(throwing: JKDesFirePublicError.ERR_COMMAND_EXECUTION_ERROR)
                } else {
                    continuation.resume(returning: data)
                }
            }
        }

        // DesFire wraps responses: [payload...] [0x91] [status]
        guard raw.count >= 2, raw[raw.count - 2] == 0x91 else {
            throw JKDesFirePublicError.ERR_UNKNOWN_RESULT
        }

        guard let statusByte = raw.last,
              let status = JKDesFireReturnCodes(rawValue: statusByte) else {
            throw JKDesFirePublicError.ERR_UNKNOWN_RESULT
        }

        // Strip the two trailing status bytes
        var payload = Data(raw[0 ..< raw.count - 2])

        // Prepend any frames received in earlier calls
        if let prior = accumulated {
            payload.insert(contentsOf: prior, at: 0)
        }

        switch status {
        case .SUCCESS:
            return payload
        case .ADDITIONAL_FRAME:
            return try await doSendRequest(
                JKDesFireCommands.GET_ADDITIONAL_FRAME.rawValue,
                [],
                accumulated: payload
            )
        default:
            throw translateStatus(status)
        }
    }

    private func translateStatus(_ code: JKDesFireReturnCodes) -> JKDesFirePublicError {
        switch code {
        case .AUTHENTICATION_ERROR: return .ERR_AUTHENTICATION_ERROR
        case .PERMISSION_DENIED:    return .ERR_PERMISSION_DENIED
        case .INVALID_RESPONSE:     return .ERR_UNKNOWN_RESULT
        default:                    return .ERR_UNKNOWN_ERROR
        }
    }
}
