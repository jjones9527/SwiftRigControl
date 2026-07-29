import Foundation
@testable import RigControl

/// Mock serial transport for testing protocol implementations without hardware.
actor MockTransport: SerialTransport {
    var mockResponses: [Data: Data] = [:]
    var recordedWrites: [Data] = []
    var shouldThrowOnWrite: Bool = false
    var shouldThrowOnRead: Bool = false
    /// Chunks delivered one-per-read to simulate low-baud arrival.
    var chunkedResponse: [Data] = []
    private var _isOpen: Bool = false

    var isOpen: Bool {
        _isOpen
    }

    func open() async throws {
        _isOpen = true
    }

    func close() async {
        _isOpen = false
    }

    func write(_ data: Data) async throws {
        guard _isOpen else {
            throw RigError.notConnected
        }

        if shouldThrowOnWrite {
            throw RigError.serialPortError("Mock write error")
        }

        recordedWrites.append(data)
    }

    func read(timeout: TimeInterval) async throws -> Data {
        guard _isOpen else {
            throw RigError.notConnected
        }

        if shouldThrowOnRead {
            throw RigError.timeout
        }

        if !chunkedResponse.isEmpty {
            return chunkedResponse.removeFirst()
        }

        // Return the most recent mock response
        if let lastWrite = recordedWrites.last,
           let response = mockResponses[lastWrite] {
            return response
        }

        // Default: return ACK
        return Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
    }

    func readUntil(terminator: UInt8, timeout: TimeInterval) async throws -> Data {
        let data = try await read(timeout: timeout)

        // Verify terminator is present
        guard data.last == terminator else {
            throw RigError.invalidResponse
        }

        return data
    }

    func flush() async throws {
        guard _isOpen else {
            throw RigError.notConnected
        }
        // No-op for mock
    }

    func setDTR(_ enabled: Bool) async throws {
        guard _isOpen else {
            throw RigError.notConnected
        }
    }

    func setRTS(_ enabled: Bool) async throws {
        guard _isOpen else {
            throw RigError.notConnected
        }
    }

    func reset() {
        recordedWrites.removeAll()
        mockResponses.removeAll()
        chunkedResponse.removeAll()
        shouldThrowOnWrite = false
        shouldThrowOnRead = false
    }

    func setResponse(for command: Data, response: Data) {
        mockResponses[command] = response
    }

    /// Queue a chunked response — each element is returned on a
    /// successive `read(timeout:)` call. Used to model low-baud
    /// arrival where a fixed-length frame straddles multiple OS reads
    /// (the FT-857 4800-baud `readExact` regression scenario).
    func setChunkedResponse(_ chunks: [Data]) {
        chunkedResponse = chunks
    }

    // Actor-safe property setters for testing
    func setShouldThrowOnRead(_ value: Bool) {
        shouldThrowOnRead = value
    }

    func setShouldThrowOnWrite(_ value: Bool) {
        shouldThrowOnWrite = value
    }
}
