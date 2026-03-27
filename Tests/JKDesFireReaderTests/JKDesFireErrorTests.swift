//
//  JKDesFireErrorTests.swift
//  JKDesFireReaderTests
//

import Testing
@testable import JKDesFireReader

@Suite("JKDesFirePublicError")
struct JKDesFirePublicErrorTests {

    @Test func localizedDescription_notEmpty_forAllCases() {
        let cases: [JKDesFirePublicError] = [
            .ERR_MIFARE_PLUS, .ERR_MIFARE_ULTRALIGHT, .ERR_MIFARE_UNKNOWN,
            .ERR_MIFARE_ERROR, .ERR_NO_TAG_FOUND, .ERR_PERMISSION_DENIED,
            .ERR_AUTHENTICATION_ERROR, .ERR_UNKNOWN_RESULT, .ERR_COMMAND_EXECUTION_ERROR,
            .ERR_UNKNOWN_COMMAND, .ERR_UNKNOWN_ERROR, .ERR_WRONG_INPUT_LENGTH,
            .ERR_UNKNOWN_FILE_TYPE, .ERR_FILE_NOT_FOUND, .ERR_SESSION_INVALIDATED,
        ]
        for c in cases {
            #expect(!c.localizedDescription.isEmpty, "Empty description for \(c)")
        }
    }

    @Test func errMifareError_hasDistinctDescription_fromOthers() {
        let a = JKDesFirePublicError.ERR_MIFARE_PLUS.localizedDescription
        let b = JKDesFirePublicError.ERR_MIFARE_ULTRALIGHT.localizedDescription
        #expect(a != b)
    }

    @Test func equatability_sameCase() {
        #expect(JKDesFirePublicError.ERR_NO_TAG_FOUND == .ERR_NO_TAG_FOUND)
    }

    @Test func equatability_differentCases() {
        #expect(JKDesFirePublicError.ERR_NO_TAG_FOUND != .ERR_UNKNOWN_ERROR)
    }
}
