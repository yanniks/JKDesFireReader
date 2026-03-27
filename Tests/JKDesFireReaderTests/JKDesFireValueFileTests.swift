//
//  JKDesFireValueFileTests.swift
//  JKDesFireReaderTests
//

import Testing
@testable import JKDesFireReader

@Suite("JKDesFireValueFile")
struct JKDesFireValueFileTests {

    @Test func getValue_parsesPositiveInteger() {
        // 42 in 4-byte little-endian: [0x2A, 0x00, 0x00, 0x00]
        let f = JKDesFireValueFile(data: [0x2A, 0x00, 0x00, 0x00])
        #expect(f.getValue() == 42)
    }

    @Test func getValue_parsesMaxPositiveValue() {
        // 0x7FFFFFFF little-endian
        let f = JKDesFireValueFile(data: [0xFF, 0xFF, 0xFF, 0x7F])
        #expect(f.getValue() == Int(Int32.max))
    }

    @Test func getValue_parsesZero() {
        let f = JKDesFireValueFile(data: [0x00, 0x00, 0x00, 0x00])
        #expect(f.getValue() == 0)
    }

    @Test func getValue_returnsZero_forEmptyData() {
        let f = JKDesFireValueFile(data: [])
        #expect(f.getValue() == 0)
    }

    @Test func getValue_returnsZero_forShortData() {
        let f = JKDesFireValueFile(data: [0x01, 0x02])
        #expect(f.getValue() == 0)
    }

    @Test func getValue_parsesLargeValue() {
        // 1000 = 0x000003E8 little-endian: [0xE8, 0x03, 0x00, 0x00]
        let f = JKDesFireValueFile(data: [0xE8, 0x03, 0x00, 0x00])
        #expect(f.getValue() == 1000)
    }
}
