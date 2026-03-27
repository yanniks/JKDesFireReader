//
//  MockApplicationTests.swift
//  JKDesFireReaderTests
//
//  Tests for MockApplication, ensuring it correctly implements
//  JKDesFireApplicationProtocol so it can be trusted as a test double.
//

import Testing
@testable import JKDesFireReader

@Suite("MockApplication (protocol conformance)")
struct MockApplicationTests {

    @Test func getFile_returnsStubbed_data() async throws {
        let mock = MockApplication(applicationId: 0xABCDEF, files: [0x01])
        let payload = Data([0x01, 0x02, 0x03])
        mock.stubbedFileData[0x01] = .success(payload)

        let data = try await mock.getFile(fileId: 0x01)
        #expect(data == payload)
    }

    @Test func getFile_throwsFileNotFound_whenNoStub() async {
        let mock = MockApplication()
        await #expect(throws: JKDesFirePublicError.ERR_FILE_NOT_FOUND) {
            _ = try await mock.getFile(fileId: 0x99)
        }
    }

    @Test func getValue_returnsStubbed_valueFile() async throws {
        let mock = MockApplication(files: [0x02])
        let valueFile = JKDesFireValueFile(data: [0x0A, 0x00, 0x00, 0x00])
        mock.stubbedValues[0x02] = .success(valueFile)

        let result = try await mock.getValue(fileId: 0x02)
        #expect(result.getValue() == 10)
    }

    @Test func applicationId_matchesConstructorArgument() {
        let mock = MockApplication(applicationId: 0x112233)
        #expect(mock.applicationId == 0x112233)
    }

    @Test func files_matchConstructorArgument() {
        let mock = MockApplication(files: [0x01, 0x02, 0x03])
        #expect(mock.files == [0x01, 0x02, 0x03])
    }
}
