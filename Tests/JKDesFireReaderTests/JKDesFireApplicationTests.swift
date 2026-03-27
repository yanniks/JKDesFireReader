//
//  JKDesFireApplicationTests.swift
//  JKDesFireReaderTests
//

import Testing
@testable import JKDesFireReader

// MARK: - Helper: build a tag stub that hands back a canned file list

private func makeAppWithFiles(_ fileIds: [UInt8]) async throws -> JKDesFireApplication {
    let tag = MockDesFireTag()
    tag.stub(command: JKDesFireCommands.GET_FILES.rawValue, returning: Data(fileIds))
    let app = JKDesFireApplication(id: 0x010203, tag: tag)
    try await app.loadFiles()
    return app
}

// MARK: - Suite

@Suite("JKDesFireApplication")
struct JKDesFireApplicationTests {

    // MARK: loadFiles

    @Test func loadFiles_populatesFilesFromTag() async throws {
        let app = try await makeAppWithFiles([0x01, 0x02, 0x03])
        #expect(app.files == [0x01, 0x02, 0x03])
        #expect(app.getFileCount() == 3)
    }

    @Test func loadFiles_emptyResponse_givesNoFiles() async throws {
        let app = try await makeAppWithFiles([])
        #expect(app.files.isEmpty)
        #expect(app.getFileCount() == 0)
    }

    @Test func loadFiles_propagatesTagError() async {
        let tag = MockDesFireTag()
        tag.stub(command: JKDesFireCommands.GET_FILES.rawValue,
                 throwing: JKDesFirePublicError.ERR_PERMISSION_DENIED)
        let app = JKDesFireApplication(id: 0x010203, tag: tag)

        await #expect(throws: JKDesFirePublicError.ERR_PERMISSION_DENIED) {
            try await app.loadFiles()
        }
    }

    // MARK: getFileSettings

    @Test func getFileSettings_returnsDataFileSettings() async throws {
        let tag = MockDesFireTag()
        // Simulate a data-file settings response (type=0x00, comm=0x00, rights=0xEEEE, size=0x001000)
        let response: [UInt8] = [0x00, 0x00, 0xEE, 0xEE, 0x00, 0x10, 0x00, 0x00]
        tag.stub(command: JKDesFireCommands.GET_FILE_SETTINGS.rawValue, returning: Data(response))
        let app = JKDesFireApplication(id: 0x01, tag: tag)

        let settings = try await app.getFileSettings(fileId: 0x01)

        #expect(settings.getFileType() == JKDesFireFileTypes.DATA_FILE)
    }

    @Test func getFileSettings_returnsValueFileSettings() async throws {
        let tag = MockDesFireTag()
        // Build a 17-byte value-file settings response
        var response: [UInt8] = Array(repeating: 0x00, count: 17)
        response[0] = JKDesFireFileTypes.VALUE_FILE
        response[16] = 0x01 // limitedCredit enabled
        tag.stub(command: JKDesFireCommands.GET_FILE_SETTINGS.rawValue, returning: Data(response))
        let app = JKDesFireApplication(id: 0x01, tag: tag)

        let settings = try await app.getFileSettings(fileId: 0x02)

        #expect(settings.getFileType() == JKDesFireFileTypes.VALUE_FILE)
        let valueSettings = try #require(settings as? JKDesFireValueFileSettings)
        #expect(valueSettings.getLimitedCredit() == 0x01)
    }

    @Test func getFileSettings_unknownTypeByte_throws() async throws {
        let tag = MockDesFireTag()
        // type byte 0xFF is unknown
        tag.stub(command: JKDesFireCommands.GET_FILE_SETTINGS.rawValue,
                 returning: Data([0xFF, 0x00, 0x00]))
        let app = JKDesFireApplication(id: 0x01, tag: tag)

        await #expect(throws: JKDesFirePublicError.ERR_UNKNOWN_FILE_TYPE) {
            _ = try await app.getFileSettings(fileId: 0x01)
        }
    }

    @Test func getFileSettings_propagatesTagError() async throws {
        let tag = MockDesFireTag()
        tag.stub(command: JKDesFireCommands.GET_FILE_SETTINGS.rawValue,
                 throwing: JKDesFirePublicError.ERR_AUTHENTICATION_ERROR)
        let app = JKDesFireApplication(id: 0x01, tag: tag)

        await #expect(throws: JKDesFirePublicError.ERR_AUTHENTICATION_ERROR) {
            _ = try await app.getFileSettings(fileId: 0x01)
        }
    }

    // MARK: getFile

    @Test func getFile_returnsData_whenFilePresent() async throws {
        let tag = MockDesFireTag()
        let payload = Data([0xDE, 0xAD, 0xBE, 0xEF])
        tag.stub(command: JKDesFireCommands.GET_FILES.rawValue, returning: Data([0x01]))
        tag.stub(command: JKDesFireCommands.READ_DATA.rawValue, returning: payload)
        let app = JKDesFireApplication(id: 0x01, tag: tag)
        try await app.loadFiles()

        let data = try await app.getFile(fileId: 0x01)

        #expect(data == payload)
    }

    @Test func getFile_sendsCorrectParameters() async throws {
        let tag = MockDesFireTag()
        tag.stub(command: JKDesFireCommands.GET_FILES.rawValue, returning: Data([0x03]))
        tag.stub(command: JKDesFireCommands.READ_DATA.rawValue, returning: Data())
        let app = JKDesFireApplication(id: 0x01, tag: tag)
        try await app.loadFiles()

        _ = try await app.getFile(fileId: 0x03)

        let readCall = tag.callLog.first { $0.command == JKDesFireCommands.READ_DATA.rawValue }
        let expectedParams: [UInt8] = [0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        #expect(readCall?.parameters == expectedParams)
    }

    @Test func getFile_throwsFileNotFound_whenFileIdAbsent() async throws {
        let app = try await makeAppWithFiles([0x01, 0x02])

        await #expect(throws: JKDesFirePublicError.ERR_FILE_NOT_FOUND) {
            _ = try await app.getFile(fileId: 0x99)
        }
    }

    @Test func getFile_propagatesTagError() async throws {
        let tag = MockDesFireTag()
        tag.stub(command: JKDesFireCommands.GET_FILES.rawValue, returning: Data([0x01]))
        tag.stub(command: JKDesFireCommands.READ_DATA.rawValue,
                 throwing: JKDesFirePublicError.ERR_COMMAND_EXECUTION_ERROR)
        let app = JKDesFireApplication(id: 0x01, tag: tag)
        try await app.loadFiles()

        await #expect(throws: JKDesFirePublicError.ERR_COMMAND_EXECUTION_ERROR) {
            _ = try await app.getFile(fileId: 0x01)
        }
    }

    // MARK: getValue

    @Test func getValue_returnsValueFile_whenFilePresent() async throws {
        let tag = MockDesFireTag()
        // Value file payload: 4-byte little-endian integer = 42 → [0x2A, 0x00, 0x00, 0x00]
        let valueBytes: [UInt8] = [0x2A, 0x00, 0x00, 0x00]
        tag.stub(command: JKDesFireCommands.GET_FILES.rawValue, returning: Data([0x02]))
        tag.stub(command: JKDesFireCommands.READ_VALUE.rawValue, returning: Data(valueBytes))
        let app = JKDesFireApplication(id: 0x01, tag: tag)
        try await app.loadFiles()

        let valueFile = try await app.getValue(fileId: 0x02)

        #expect(valueFile.getValue() == 42)
    }

    @Test func getValue_throwsFileNotFound_whenFileIdAbsent() async throws {
        let app = try await makeAppWithFiles([0x01])

        await #expect(throws: JKDesFirePublicError.ERR_FILE_NOT_FOUND) {
            _ = try await app.getValue(fileId: 0x05)
        }
    }

    // MARK: Getters

    @Test func applicationId_matchesConstructorArgument() async throws {
        let app = try await makeAppWithFiles([])
        #expect(app.applicationId == 0x010203)
        #expect(app.getApplicationId() == 0x010203)
    }

    @Test func getFiles_returnsFileList() async throws {
        let app = try await makeAppWithFiles([0x01, 0x03, 0x05])
        #expect(app.getFiles() == [0x01, 0x03, 0x05])
    }
}
