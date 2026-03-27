//
//  JKDesFireApplication.swift
//  JKDesFireReader
//
//  Created by Johannes Kreutz on 17.08.19.
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

// MARK: - Protocol

/// Public contract for a DesFire application, enabling full substitution in tests.
public protocol JKDesFireApplicationProtocol {
    /// The 3-byte application identifier.
    var applicationId: UInt32 { get }
    /// The list of file identifiers belonging to this application.
    var files: [UInt8] { get }

    /// Returns the settings object for the given file.
    func getFileSettings(fileId: UInt8) async throws -> JKDesFireFileSettingsProtocol
    /// Returns the raw data of a standard or backup data file.
    func getFile(fileId: UInt8) async throws -> Data
    /// Returns a value-file object for the given file ID.
    func getValue(fileId: UInt8) async throws -> JKDesFireValueFile
}

// MARK: - Concrete implementation

public class JKDesFireApplication: JKDesFireApplicationProtocol {

    // MARK: Properties

    let id: UInt32
    let tag: any JKDesFireTagProtocol
    private(set) public var files: [UInt8] = []

    // MARK: Initialization (internal — created by JKDesFireReader.selectApplication)

    init(id: UInt32, tag: any JKDesFireTagProtocol) {
        self.id = id
        self.tag = tag
    }

    // MARK: JKDesFireApplicationProtocol

    public var applicationId: UInt32 { id }

    /// Loads the file-ID list from the card. Called internally by `selectApplication`.
    func loadFiles() async throws {
        let data = try await tag.sendCommand(JKDesFireCommands.GET_FILES.rawValue)
        files = [UInt8](data)
    }

    public func getFileSettings(fileId: UInt8) async throws -> JKDesFireFileSettingsProtocol {
        let data = try await tag.sendRequest(
            JKDesFireCommands.GET_FILE_SETTINGS.rawValue,
            [fileId]
        )
        guard let settings = JKDesFireFileSettings.createFileSettingsObject(data: [UInt8](data)) else {
            throw JKDesFirePublicError.ERR_UNKNOWN_FILE_TYPE
        }
        return settings
    }

    public func getFile(fileId: UInt8) async throws -> Data {
        guard files.contains(fileId) else {
            throw JKDesFirePublicError.ERR_FILE_NOT_FOUND
        }
        return try await tag.sendRequest(
            JKDesFireCommands.READ_DATA.rawValue,
            [fileId, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        )
    }

    public func getValue(fileId: UInt8) async throws -> JKDesFireValueFile {
        guard files.contains(fileId) else {
            throw JKDesFirePublicError.ERR_FILE_NOT_FOUND
        }
        let data = try await tag.sendRequest(
            JKDesFireCommands.READ_VALUE.rawValue,
            [fileId]
        )
        return JKDesFireValueFile(data: [UInt8](data))
    }

    // MARK: Legacy getters (preserve source compatibility)

    public func getApplicationId() -> UInt32 { id }
    public func getFileCount() -> Int { files.count }
    public func getFiles() -> [UInt8] { files }
}
