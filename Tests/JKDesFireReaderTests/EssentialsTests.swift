//
//  EssentialsTests.swift
//  JKDesFireReaderTests
//

import Testing
@testable import JKDesFireReader

@Suite("essentials utility")
struct EssentialsTests {

    // MARK: - byteArrayToInt

    @Test func singleByte() {
        #expect(essentials.byteArrayToInt(input: [0x07]) == 7)
    }

    @Test func twoBytesBigEndian() {
        // [0x01, 0x02] big-endian → 0x0102 = 258
        #expect(essentials.byteArrayToInt(input: [0x01, 0x02]) == 258)
    }

    @Test func threeByteApplicationId() {
        #expect(essentials.byteArrayToInt(input: [0x01, 0x02, 0x03]) == 0x010203)
    }

    @Test func fourBytes() {
        #expect(essentials.byteArrayToInt(input: [0x00, 0x00, 0x00, 0xFF]) == 255)
    }

    @Test func emptyArrayReturnsNil() {
        #expect(essentials.byteArrayToInt(input: []) == nil)
    }

    @Test func fiveBytesReturnsNil() {
        #expect(essentials.byteArrayToInt(input: [1, 2, 3, 4, 5]) == nil)
    }

    // MARK: - intToByteArray

    @Test func zeroToBytes() {
        #expect(essentials.intToByteArray(0) == [0x00, 0x00, 0x00, 0x00])
    }

    @Test func knownValueToBytes() {
        #expect(essentials.intToByteArray(0x010203) == [0x00, 0x01, 0x02, 0x03])
    }

    @Test func maxUInt32ToBytes() {
        #expect(essentials.intToByteArray(UInt32.max) == [0xFF, 0xFF, 0xFF, 0xFF])
    }

    // MARK: - Round-trip

    @Test func roundTripSmallValue() {
        let original: UInt32 = 0xABCD
        let bytes = essentials.intToByteArray(original)
        #expect(essentials.byteArrayToInt(input: bytes) == original)
    }

    @Test func roundTripThreeByteAppId() {
        let appId: UInt32 = 0x010203
        let allBytes = essentials.intToByteArray(appId)
        let trimmed = allBytes.filter { $0 != 0 }
        #expect(trimmed.count == 3)
        #expect(essentials.byteArrayToInt(input: trimmed) == appId)
    }

    // MARK: - splitArray

    @Test func splitMiddleSegment() {
        let data: [UInt8] = [0x00, 0x01, 0x02, 0x03, 0x04]
        #expect(essentials.splitArray(data: data, start: 1, end: 4) == [0x01, 0x02, 0x03])
    }

    @Test func splitEntireArray() {
        let data: [UInt8] = [0xAA, 0xBB, 0xCC]
        #expect(essentials.splitArray(data: data, start: 0, end: 3) == [0xAA, 0xBB, 0xCC])
    }
}
