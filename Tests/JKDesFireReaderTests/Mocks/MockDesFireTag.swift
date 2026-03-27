//
//  MockDesFireTag.swift
//  JKDesFireReaderTests
//
//  A test double for JKDesFireTagProtocol that lets each test prescribe the
//  exact response for any given command byte — or force an error.
//

import Foundation
@testable import JKDesFireReader

// MARK: - Mock tag

final class MockDesFireTag: JKDesFireTagProtocol, @unchecked Sendable {

    var identifier: Data = Data([0xDE, 0xAD, 0xBE, 0xEF])

    // Map command byte → canned result
    var stubbedResponses: [UInt8: Result<Data, Error>] = [:]

    // Full call log for verification
    struct Call: Equatable {
        let command: UInt8
        let parameters: [UInt8]
    }
    private(set) var callLog: [Call] = []

    func sendRequest(_ command: UInt8, _ parameters: [UInt8]) async throws -> Data {
        callLog.append(Call(command: command, parameters: parameters))
        guard let stub = stubbedResponses[command] else {
            return Data()
        }
        switch stub {
        case .success(let data): return data
        case .failure(let error): throw error
        }
    }
}

// MARK: - Helpers for building canned responses

extension MockDesFireTag {
    /// Stubs the given command to return success with `data`.
    func stub(command: UInt8, returning data: Data) {
        stubbedResponses[command] = .success(data)
    }

    /// Stubs the given command to throw `error`.
    func stub(command: UInt8, throwing error: Error) {
        stubbedResponses[command] = .failure(error)
    }
}
