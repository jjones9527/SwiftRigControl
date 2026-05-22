import Foundation
import Testing
@testable import RigControl

/// Tests for the public `MockSerialTransport`.
///
/// The existing protocol-test suites (IcomProtocolTests, etc.) exercise
/// this transport extensively through the protocols that use it; these
/// tests cover the transport's own contract directly so the surface
/// behavior stays explicit.
@Suite struct MockSerialTransportTests {

    @Test func freshTransportIsClosed() async {
        let mock = MockSerialTransport()
        let open = await mock.isOpen
        #expect(open == false)
    }

    @Test func openAndClose() async throws {
        let mock = MockSerialTransport()
        try await mock.open()
        #expect(await mock.isOpen == true)
        await mock.close()
        #expect(await mock.isOpen == false)
    }

    @Test func writesAreRecordedInOrder() async throws {
        let mock = MockSerialTransport()
        try await mock.open()
        try await mock.write(Data([0x01, 0x02]))
        try await mock.write(Data([0x03, 0x04]))
        let writes = await mock.recordedWrites
        #expect(writes == [Data([0x01, 0x02]), Data([0x03, 0x04])])
    }

    @Test func writeBeforeOpenThrows() async {
        let mock = MockSerialTransport()
        await #expect(throws: RigError.self) {
            try await mock.write(Data([0x01]))
        }
    }

    @Test func scriptedResponseIsServedAfterMatchingWrite() async throws {
        let mock = MockSerialTransport()
        try await mock.open()

        let query = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x03, 0xFD])
        let response = Data([0xFE, 0xFE, 0xE0, 0xA2, 0x03, 0xAA, 0xBB, 0xFD])
        await mock.setResponse(for: query, response: response)

        try await mock.write(query)
        let got = try await mock.read(timeout: 1.0)
        #expect(got == response)
    }

    @Test func defaultResponseIsIcomAckWhenNothingScripted() async throws {
        let mock = MockSerialTransport()
        try await mock.open()
        try await mock.write(Data([0xAA]))
        let got = try await mock.read(timeout: 1.0)
        // Documented default: generic Icom CI-V ACK.
        #expect(got == Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD]))
    }

    @Test func readUntilTerminatorReturnsFullFrame() async throws {
        let mock = MockSerialTransport()
        try await mock.open()
        let q = Data([0x01])
        let r = Data([0xFE, 0xFE, 0xE0, 0xA2, 0x03, 0xFD])
        await mock.setResponse(for: q, response: r)
        try await mock.write(q)
        let frame = try await mock.readUntil(terminator: 0xFD, timeout: 1.0)
        #expect(frame == r)
    }

    @Test func resetClearsRecordedWritesAndScriptedResponses() async throws {
        let mock = MockSerialTransport()
        try await mock.open()
        try await mock.write(Data([0x01]))
        await mock.setResponse(for: Data([0x02]), response: Data([0x99]))

        await mock.reset()

        #expect(await mock.recordedWrites.isEmpty)
        // After reset, the scripted response is gone — falls back to
        // the documented default ACK.
        try await mock.write(Data([0x02]))
        let got = try await mock.read(timeout: 1.0)
        #expect(got == Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD]))
    }

    @Test func shouldThrowOnReadProducesTimeout() async throws {
        let mock = MockSerialTransport()
        try await mock.open()
        await mock.setShouldThrowOnRead(true)
        await #expect(throws: RigError.self) {
            _ = try await mock.read(timeout: 1.0)
        }
    }

    @Test func shouldThrowOnWriteProducesSerialPortError() async throws {
        let mock = MockSerialTransport()
        try await mock.open()
        await mock.setShouldThrowOnWrite(true)
        await #expect(throws: RigError.self) {
            try await mock.write(Data([0x01]))
        }
    }
}
