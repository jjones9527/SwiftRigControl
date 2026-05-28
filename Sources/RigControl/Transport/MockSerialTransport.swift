import Foundation

/// In-memory serial transport for testing protocol implementations
/// without real hardware.
///
/// `MockSerialTransport` records every write and serves canned responses
/// keyed by the most recent write. It is the right choice when you want
/// to verify that a `CATProtocol` implementation produces the correct
/// bytes on the wire — for example, when adding support for a new radio
/// or asserting that a specific CI-V command sequence matches the
/// manufacturer manual.
///
/// For higher-level testing — driving a `RigController` from a SwiftUI
/// preview or demo app — use `DummyCATProtocol` via
/// `RadioDefinition.dummy(name:capabilities:)` instead. That path lets
/// you skip the byte protocol entirely and operate against an in-memory
/// radio that behaves like the real thing.
///
/// ## Example
///
/// ```swift
/// // Pre-script the radio's response to a frequency query.
/// let mock = MockSerialTransport()
/// let civQuery = Data([0xFE, 0xFE, 0xA2, 0xE0, 0x03, 0xFD])
/// let civResponse = Data([0xFE, 0xFE, 0xE0, 0xA2, 0x03,
///                          0x00, 0x00, 0x30, 0x14, 0x00, 0xFD])
/// await mock.setResponse(for: civQuery, response: civResponse)
///
/// let proto = IcomCIVProtocol(
///     transport: mock,
///     radioModel: .ic9700,
///     commandSet: IC9700CommandSet(),
///     capabilities: RadioCapabilitiesDatabase.Icom.ic9700
/// )
/// try await proto.connect()
/// let freq = try await proto.getFrequency(vfo: .a)   // → 14_300_000
///
/// // Inspect what the protocol actually wrote.
/// let writes = await mock.recordedWrites
/// #expect(writes.first == civQuery)
/// ```
///
/// ## Default response
///
/// If no scripted response matches the last write, the transport
/// returns a generic Icom CI-V ACK frame
/// (`0xFE 0xFE 0xE0 0xA2 0xFB 0xFD`). This default keeps simple
/// "command succeeded" tests short, but for any test that asserts on
/// returned data — or for non-Icom protocols — you should script
/// explicit responses.
public actor MockSerialTransport: SerialTransport {

    /// Map of write payload → canned response. The most recent write
    /// is used as the lookup key.
    private var mockResponses: [Data: Data] = [:]

    /// Every byte sequence written through the transport, in order.
    /// Inspect this from tests to verify the on-wire protocol.
    public private(set) var recordedWrites: [Data] = []

    /// When `true`, the next `write(_:)` call throws
    /// `RigError.serialPortError`. Resets to `false` after firing —
    /// use ``setShouldThrowOnWrite(_:)`` to control persistently.
    private var shouldThrowOnWrite: Bool = false

    /// When `true`, the next `read(timeout:)` (or `readUntil`) call
    /// throws `RigError.timeout`.
    private var shouldThrowOnRead: Bool = false

    private var _isOpen: Bool = false

    public var isOpen: Bool {
        _isOpen
    }

    /// Creates a new mock transport in the closed state. Call
    /// ``open()`` before using it (or rely on the `CATProtocol` /
    /// `RigController` `connect()` to do so).
    public init() {}

    public func open() async throws {
        _isOpen = true
    }

    public func close() async {
        _isOpen = false
    }

    public func write(_ data: Data) async throws {
        guard _isOpen else {
            throw RigError.notConnected
        }
        if shouldThrowOnWrite {
            throw RigError.serialPortError("Mock write error")
        }
        recordedWrites.append(data)
    }

    public func read(timeout: TimeInterval) async throws -> Data {
        guard _isOpen else {
            throw RigError.notConnected
        }
        if shouldThrowOnRead {
            throw RigError.timeout
        }
        if let lastWrite = recordedWrites.last,
           let response = mockResponses[lastWrite] {
            return response
        }
        // Default: generic Icom CI-V ACK. Override per-test via
        // setResponse(for:response:) when you need anything else.
        return Data([0xFE, 0xFE, 0xE0, 0xA2, 0xFB, 0xFD])
    }

    public func readUntil(terminator: UInt8, timeout: TimeInterval) async throws -> Data {
        let data = try await read(timeout: timeout)
        guard data.last == terminator else {
            throw RigError.invalidResponse
        }
        return data
    }

    public func flush() async throws {
        guard _isOpen else {
            throw RigError.notConnected
        }
        // No buffered data; flush is a no-op.
    }

    // MARK: - Test scripting

    /// Wipes all recorded writes, scripted responses, and error flags.
    /// Useful between independent test cases that share a transport.
    public func reset() {
        recordedWrites.removeAll()
        mockResponses.removeAll()
        shouldThrowOnWrite = false
        shouldThrowOnRead = false
    }

    /// Scripts the response that should be returned the next time the
    /// transport reads after a write of `command`.
    ///
    /// - Parameters:
    ///   - command: The exact write payload to match.
    ///   - response: The bytes to return on the following read.
    public func setResponse(for command: Data, response: Data) {
        mockResponses[command] = response
    }

    /// Causes the next `read(timeout:)` (or `readUntil`) call to throw
    /// `RigError.timeout`. Useful for testing timeout handling.
    public func setShouldThrowOnRead(_ value: Bool) {
        shouldThrowOnRead = value
    }

    /// Causes the next `write(_:)` call to throw
    /// `RigError.serialPortError`. Useful for testing write-failure
    /// handling.
    public func setShouldThrowOnWrite(_ value: Bool) {
        shouldThrowOnWrite = value
    }
}
