import Foundation
import Testing
@testable import RigControl

/// Tests for ``SerialTransport/readExact(count:timeout:)`` — the
/// fixed-length-with-total-elapsed-timeout counterpart to
/// ``SerialTransport/readUntil(terminator:timeout:)``.
///
/// The default protocol-extension implementation loops
/// ``SerialTransport/read(timeout:)`` and accumulates. These tests
/// exercise it through `MockSerialTransport`, which drives the default
/// extension (it does not override `readExact`).
@Suite struct ReadExactTests {

    @Test func readExactReturnsEmptyDataForZeroCount() async throws {
        let mock = MockSerialTransport()
        try await mock.open()
        let data = try await mock.readExact(count: 0, timeout: 1.0)
        #expect(data.isEmpty)
    }

    @Test func readExactAccumulatesAcrossChunks() async throws {
        // The FT-857 4800-baud scenario: a 5-byte fixed-length frame
        // arrives as three chunks (1 + 2 + 2 bytes) across successive
        // OS reads. readExact must reassemble the full frame.
        let mock = MockSerialTransport()
        try await mock.open()

        await mock.setChunkedResponse([
            Data([0x01]),
            Data([0x42, 0x30]),
            Data([0x00, 0x01])
        ])

        let data = try await mock.readExact(count: 5, timeout: 1.0)
        #expect(data == Data([0x01, 0x42, 0x30, 0x00, 0x01]))
    }

    @Test func readExactTrimsOverRead() async throws {
        // If the underlying read hands back more bytes than asked
        // for, readExact must truncate to the requested count so
        // callers never see excess bytes.
        let mock = MockSerialTransport()
        try await mock.open()

        await mock.setChunkedResponse([
            Data([0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF])
        ])

        let data = try await mock.readExact(count: 3, timeout: 1.0)
        #expect(data == Data([0xAA, 0xBB, 0xCC]))
    }

    @Test func readExactThrowsTimeoutWhenReadNeverProducesBytes() async throws {
        // With shouldThrowOnRead == true from the start, no bytes
        // ever arrive, so readExact must throw .timeout inside the
        // deadline budget (not .invalidResponse — callers rely on
        // the distinction between "silent wire" and "wrong bytes").
        let mock = MockSerialTransport()
        try await mock.open()
        await mock.setShouldThrowOnRead(true)

        do {
            _ = try await mock.readExact(count: 5, timeout: 0.05)
            Issue.record("readExact should have thrown")
        } catch let error as RigError {
            if case .timeout = error {
                // expected
            } else {
                Issue.record("expected .timeout, got \(error)")
            }
        }
    }
}
