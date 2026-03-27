//
//  MockApplication.swift
//  JKDesFireReaderTests
//
//  A test double for JKDesFireApplicationProtocol.
//

import Foundation
@testable import JKDesFireReader

final class MockApplication: JKDesFireApplicationProtocol {

    var applicationId: UInt32
    var files: [UInt8]

    var stubbedFileSettings: [UInt8: Result<JKDesFireFileSettingsProtocol, Error>] = [:]
    var stubbedFileData: [UInt8: Result<Data, Error>] = [:]
    var stubbedValues: [UInt8: Result<JKDesFireValueFile, Error>] = [:]

    init(applicationId: UInt32 = 0x010203, files: [UInt8] = []) {
        self.applicationId = applicationId
        self.files = files
    }

    func getFileSettings(fileId: UInt8) async throws -> JKDesFireFileSettingsProtocol {
        guard let result = stubbedFileSettings[fileId] else {
            throw JKDesFirePublicError.ERR_FILE_NOT_FOUND
        }
        switch result {
        case .success(let s): return s
        case .failure(let e): throw e
        }
    }

    func getFile(fileId: UInt8) async throws -> Data {
        guard let result = stubbedFileData[fileId] else {
            throw JKDesFirePublicError.ERR_FILE_NOT_FOUND
        }
        switch result {
        case .success(let d): return d
        case .failure(let e): throw e
        }
    }

    func getValue(fileId: UInt8) async throws -> JKDesFireValueFile {
        guard let result = stubbedValues[fileId] else {
            throw JKDesFirePublicError.ERR_FILE_NOT_FOUND
        }
        switch result {
        case .success(let v): return v
        case .failure(let e): throw e
        }
    }
}
