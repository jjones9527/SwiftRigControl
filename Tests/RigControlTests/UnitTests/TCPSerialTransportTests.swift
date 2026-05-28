import Foundation
import Network
import Testing
@testable import RigControl

/// Tests for ``TCPSerialTransport`` using a loopback TCP echo server
/// running on a randomly-chosen port. No external network access.
@Suite struct TCPSerialTransportTests {

    // MARK: - Open / close

    @Test func openConnectsToLoopback() async throws {
        let server = try await EchoServer.start()
        defer { server.stop() }

        let transport = TCPSerialTransport(host: "127.0.0.1", port: server.port)
        #expect(await transport.isOpen == false)
        try await transport.open()
        #expect(await transport.isOpen == true)
        await transport.close()
        #expect(await transport.isOpen == false)
    }

    @Test func openFailsWhenRefused() async throws {
        // Pick a port that is almost certainly unbound.
        let transport = TCPSerialTransport(host: "127.0.0.1", port: 1, connectTimeout: 0.5)
        await #expect(throws: RigError.self) {
            try await transport.open()
        }
    }

    @Test func openTimesOutOnUnroutableHost() async throws {
        // 192.0.2.0/24 is reserved for documentation per RFC 5737
        // and never routes anywhere. Connection attempt should
        // exceed the short timeout.
        let transport = TCPSerialTransport(
            host: "192.0.2.1",
            port: 12345,
            connectTimeout: 0.3
        )
        await #expect(throws: RigError.self) {
            try await transport.open()
        }
    }

    // MARK: - Round-trip I/O

    @Test func writeThenReadEchoesBytes() async throws {
        let server = try await EchoServer.start()
        defer { server.stop() }

        let transport = TCPSerialTransport(host: "127.0.0.1", port: server.port)
        try await transport.open()
        defer { Task { await transport.close() } }

        let payload = "FA00014250000;".data(using: .ascii)!
        try await transport.write(payload)

        // The echo server will send the same bytes back. Read until
        // we see Kenwood's `;` terminator.
        let frame = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)
        #expect(frame == payload)
    }

    @Test func readUntilHandlesPartialFrames() async throws {
        let server = try await EchoServer.start()
        defer { server.stop() }

        let transport = TCPSerialTransport(host: "127.0.0.1", port: server.port)
        try await transport.open()
        defer { Task { await transport.close() } }

        // Send three Kenwood frames concatenated; ensure readUntil
        // returns them one at a time without dropping the trailing
        // bytes already in the buffer.
        let multi = "FA00007000000;FB00014250000;MD2;".data(using: .ascii)!
        try await transport.write(multi)

        let first = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)
        let second = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)
        let third = try await transport.readUntil(terminator: 0x3B, timeout: 2.0)

        #expect(String(data: first, encoding: .ascii) == "FA00007000000;")
        #expect(String(data: second, encoding: .ascii) == "FB00014250000;")
        #expect(String(data: third, encoding: .ascii) == "MD2;")
    }

    @Test func readTimesOutWhenNoData() async throws {
        let server = try await EchoServer.start()
        defer { server.stop() }

        let transport = TCPSerialTransport(host: "127.0.0.1", port: server.port)
        try await transport.open()
        defer { Task { await transport.close() } }

        await #expect(throws: RigError.self) {
            _ = try await transport.readUntil(terminator: 0x3B, timeout: 0.2)
        }
    }

    @Test func flushDiscardsBufferedBytes() async throws {
        let server = try await EchoServer.start()
        defer { server.stop() }

        let transport = TCPSerialTransport(host: "127.0.0.1", port: server.port)
        try await transport.open()
        defer { Task { await transport.close() } }

        try await transport.write("ID019;".data(using: .ascii)!)
        // Give the echo server time to send the response back.
        try await Task.sleep(nanoseconds: 200_000_000)
        try await transport.flush()
        // After flush there should be nothing left to read.
        await #expect(throws: RigError.self) {
            _ = try await transport.read(timeout: 0.2)
        }
    }

    // MARK: - Write on closed transport

    @Test func writeThrowsAfterClose() async throws {
        let server = try await EchoServer.start()
        defer { server.stop() }

        let transport = TCPSerialTransport(host: "127.0.0.1", port: server.port)
        try await transport.open()
        await transport.close()

        await #expect(throws: RigError.self) {
            try await transport.write("FA;".data(using: .ascii)!)
        }
    }
}

// MARK: - Loopback echo server

/// Minimal TCP echo server used by the test suite. Listens on
/// `127.0.0.1` on a kernel-assigned port and echoes every byte it
/// receives back to the sender. Stopped via ``stop()`` — typically
/// from a `defer` block in the test.
private actor EchoServer {
    let port: UInt16
    private let listener: NWListener

    private init(port: UInt16, listener: NWListener) {
        self.port = port
        self.listener = listener
    }

    static func start() async throws -> EchoServer {
        let params = NWParameters.tcp
        let listener = try NWListener(using: params)

        listener.newConnectionHandler = { connection in
            connection.start(queue: .global())
            Self.pump(connection)
        }

        // Start the listener and wait for it to enter `.ready` so we
        // know the port is assigned.
        let port: UInt16 = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<UInt16, Error>) in
            let guardObj = ResumeGuard()
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if guardObj.tryResume(), let p = listener.port?.rawValue {
                        cont.resume(returning: p)
                    } else if guardObj.tryResume() {
                        cont.resume(throwing: RigError.serialPortError("Listener has no port"))
                    }
                case .failed(let err):
                    if guardObj.tryResume() {
                        cont.resume(throwing: err)
                    }
                default:
                    break
                }
            }
            listener.start(queue: .global())
        }

        return EchoServer(port: port, listener: listener)
    }

    nonisolated func stop() {
        listener.cancel()
    }

    /// Recursive read/echo loop. Each completion handler schedules
    /// the next read; cancellation tears the chain down.
    private static func pump(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
            if let data, !data.isEmpty {
                connection.send(content: data, completion: .contentProcessed { _ in })
            }
            if error != nil || isComplete {
                connection.cancel()
                return
            }
            pump(connection)
        }
    }

    private final class ResumeGuard: @unchecked Sendable {
        private let lock = NSLock()
        private var fired = false
        func tryResume() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if fired { return false }
            fired = true
            return true
        }
    }
}
