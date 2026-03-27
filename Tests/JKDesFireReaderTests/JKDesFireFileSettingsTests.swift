//
//  JKDesFireFileSettingsTests.swift
//  JKDesFireReaderTests
//

import Testing
@testable import JKDesFireReader

@Suite("JKDesFireFileSettings factory")
struct JKDesFireFileSettingsTests {

    // MARK: - createFileSettingsObject

    @Test func factory_createsDataFileSettings_forTypeZero() throws {
        // type=0x00, comm=0x00, rights[2 bytes], size[3 bytes] = 8 bytes minimum
        let data: [UInt8] = [0x00, 0x00, 0xEE, 0xEE, 0x00, 0x10, 0x00, 0x00]
        let settings = try #require(JKDesFireFileSettings.createFileSettingsObject(data: data))
        #expect(settings.getFileType() == JKDesFireFileTypes.DATA_FILE)
        let dataSettings = try #require(settings as? JKDesFireDataFileSettings)
        #expect(dataSettings.getFileSize() == 0x1000)
    }

    @Test func factory_createsDataFileSettings_forTypeOne_backupFile() throws {
        let data: [UInt8] = [0x01, 0x00, 0xEE, 0xEE, 0x00, 0x08, 0x00, 0x00]
        let settings = try #require(JKDesFireFileSettings.createFileSettingsObject(data: data))
        #expect(settings.getFileType() == JKDesFireFileTypes.BACKUP_FILE)
        #expect(settings is JKDesFireDataFileSettings)
    }

    @Test func factory_createsValueFileSettings_forTypeTwo() throws {
        var data: [UInt8] = Array(repeating: 0x00, count: 17)
        data[0] = JKDesFireFileTypes.VALUE_FILE
        data[16] = 0x01
        let settings = try #require(JKDesFireFileSettings.createFileSettingsObject(data: data))
        #expect(settings.getFileType() == JKDesFireFileTypes.VALUE_FILE)
        let vs = try #require(settings as? JKDesFireValueFileSettings)
        #expect(vs.getLimitedCredit() == 0x01)
    }

    @Test func factory_createsRecordFileSettings_forTypeThree_linearRecord() throws {
        var data: [UInt8] = Array(repeating: 0x00, count: 16)
        data[0] = JKDesFireFileTypes.LINEAR_RECORD_FILE
        let settings = try #require(JKDesFireFileSettings.createFileSettingsObject(data: data))
        #expect(settings.getFileType() == JKDesFireFileTypes.LINEAR_RECORD_FILE)
        #expect(settings is JKDesFireRecordFileSettings)
    }

    @Test func factory_createsRecordFileSettings_forTypeFour_cyclicRecord() throws {
        var data: [UInt8] = Array(repeating: 0x00, count: 16)
        data[0] = JKDesFireFileTypes.CYCLIC_RECORD_FILE
        let settings = try #require(JKDesFireFileSettings.createFileSettingsObject(data: data))
        #expect(settings.getFileType() == JKDesFireFileTypes.CYCLIC_RECORD_FILE)
    }

    @Test func factory_returnsNil_forUnknownTypeByte() {
        let settings = JKDesFireFileSettings.createFileSettingsObject(data: [0xFF, 0x00, 0x00])
        #expect(settings == nil)
    }

    @Test func factory_returnsNil_forEmptyData() {
        let settings = JKDesFireFileSettings.createFileSettingsObject(data: [])
        #expect(settings == nil)
    }
}

// MARK: -

@Suite("JKDesFireDataFileSettings")
struct JKDesFireDataFileSettingsTests {

    @Test func getFileSize_decodesLittleEndianThreeBytes() {
        // size bytes at positions [4..6] little-endian: [0x00, 0x10, 0x00] → 0x001000 = 4096
        let data: [UInt8] = [0x00, 0x00, 0xEE, 0xEE, 0x00, 0x10, 0x00, 0x00]
        let settings = JKDesFireDataFileSettings(data: data)
        #expect(settings.getFileSize() == 0x1000)
    }

    @Test func getFileSize_returnsZero_forInvalidData() {
        let settings = JKDesFireDataFileSettings(data: [0x00, 0x00])
        #expect(settings.getFileSize() == 0)
    }
}

// MARK: -

@Suite("JKDesFireValueFileSettings")
struct JKDesFireValueFileSettingsTests {

    private func makeSettings(
        lower: UInt32 = 0,
        upper: UInt32 = 100,
        value: UInt32 = 50,
        limitedCredit: UInt8 = 0
    ) -> JKDesFireValueFileSettings {
        // Layout: [type, comm, rights(2), lower(4), upper(4), value(4), limitedCredit]
        // All multi-byte fields are little-endian in the response
        func le(_ v: UInt32) -> [UInt8] {
            var out = [UInt8](repeating: 0, count: 4)
            out[0] = UInt8(v & 0xFF)
            out[1] = UInt8((v >> 8) & 0xFF)
            out[2] = UInt8((v >> 16) & 0xFF)
            out[3] = UInt8((v >> 24) & 0xFF)
            return out
        }
        var data: [UInt8] = [JKDesFireFileTypes.VALUE_FILE, 0x00, 0xEE, 0xEE]
        data += le(lower)
        data += le(upper)
        data += le(value)
        data += [limitedCredit]
        return JKDesFireValueFileSettings(data: data)
    }

    @Test func getLowerLimit_decodesCorrectly() {
        let s = makeSettings(lower: 10)
        #expect(s.getLowerLimit() == 10)
    }

    @Test func getUpperLimit_decodesCorrectly() {
        let s = makeSettings(upper: 9999)
        #expect(s.getUpperLimit() == 9999)
    }

    @Test func getValue_decodesCorrectly() {
        let s = makeSettings(value: 42)
        #expect(s.getValue() == 42)
    }

    @Test func getLimitedCredit_returnsFlag() {
        let s = makeSettings(limitedCredit: 0x01)
        #expect(s.getLimitedCredit() == 0x01)
    }

    @Test func invalidData_givesZeroDefaults() {
        let s = JKDesFireValueFileSettings(data: [0x02, 0x00])
        #expect(s.getLowerLimit() == 0)
        #expect(s.getUpperLimit() == 0)
        #expect(s.getValue() == 0)
    }
}

// MARK: -

@Suite("JKDesFireRecordFileSettings")
struct JKDesFireRecordFileSettingsTests {

    private func makeSettings(
        recordSize: UInt32 = 128,
        maxRecords: UInt32 = 10,
        currentRecords: UInt32 = 3
    ) -> JKDesFireRecordFileSettings {
        func le(_ v: UInt32) -> [UInt8] {
            [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)]
        }
        var data: [UInt8] = [JKDesFireFileTypes.LINEAR_RECORD_FILE, 0x00, 0xEE, 0xEE]
        data += le(recordSize)
        data += le(maxRecords)
        data += le(currentRecords)
        return JKDesFireRecordFileSettings(data: data)
    }

    @Test func getRecordSize() {
        #expect(makeSettings(recordSize: 128).getRecordSize() == 128)
    }

    @Test func getMaxRecords() {
        #expect(makeSettings(maxRecords: 10).getMaxRecords() == 10)
    }

    @Test func getCurrentRecords() {
        #expect(makeSettings(currentRecords: 3).getCurrentRecords() == 3)
    }

    @Test func invalidData_givesZeroDefaults() {
        let s = JKDesFireRecordFileSettings(data: [0x03, 0x00])
        #expect(s.getRecordSize() == 0)
        #expect(s.getMaxRecords() == 0)
        #expect(s.getCurrentRecords() == 0)
    }
}
