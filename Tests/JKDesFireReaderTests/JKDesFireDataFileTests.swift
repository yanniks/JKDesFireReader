//
//  JKDesFireDataFileTests.swift
//  JKDesFireReaderTests
//

import Testing
@testable import JKDesFireReader

@Suite("JKDesFireDataFile")
struct JKDesFireDataFileTests {

    @Test func getRawData_returnsConstructedBytes() {
        let bytes: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
        let file = JKDesFireDataFile(data: bytes)
        #expect(file.getRawData() == bytes)
    }

    @Test func getRawData_returnsEmptyForEmptyInput() {
        let file = JKDesFireDataFile(data: [])
        #expect(file.getRawData().isEmpty)
    }
}

@Suite("JKDesFireFile factory")
struct JKDesFireFileFactoryTests {

    @Test func factory_createsValueFile_forTypeTwo() throws {
        let result = JKDesFireFile.createFileObject(data: [JKDesFireFileTypes.VALUE_FILE, 0x00, 0x00, 0x00])
        let valueFile = try #require(result as? JKDesFireValueFile)
        _ = valueFile // type check is sufficient
    }

    @Test func factory_createsDataFile_forTypeZero() throws {
        let result = JKDesFireFile.createFileObject(data: [JKDesFireFileTypes.DATA_FILE, 0xAA])
        #expect(result is JKDesFireDataFile)
    }

    @Test func factory_createsDataFile_forTypeOne_backupFile() throws {
        let result = JKDesFireFile.createFileObject(data: [JKDesFireFileTypes.BACKUP_FILE, 0xBB])
        #expect(result is JKDesFireDataFile)
    }

    @Test func factory_returnsNil_forUnknownType() {
        let result = JKDesFireFile.createFileObject(data: [0xFF])
        #expect(result == nil)
    }

    @Test func factory_returnsNil_forEmptyData() {
        let result = JKDesFireFile.createFileObject(data: [])
        #expect(result == nil)
    }
}
