import Foundation
import Network
import Testing
@testable import RigControl

/// Locks the rigctld client cap ported from Hamlib `2870074`: connections
/// past `maxClients` are closed at once, admitted clients keep working,
/// and a slot frees up when a client leaves.
@Suite(.serialized) struct RigControlServerClientLimitTests {

    @Test func defaultMatchesHamlibRigctld() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        let server = RigControlServer(rigController: rig)
        #expect(server.maxClients == 32)
        #expect(RigControlServer.defaultMaxClients == 32)
    }

    @Test func connectionPastLimitIsClosedAndSlotIsReleased() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        let server = RigControlServer(rigController: rig, maxClients: 1)
        let port = try await startOnFreePort(server)
        defer { Task { await server.stop() } }

        let first = try await TestClient.connect(port: port)
        #expect(try await first.request("f").contains("RPRT 0"))

        // Over the limit: the server closes the connection unanswered.
        let second = try await TestClient.connect(port: port)
        #expect(await second.waitForClose())
        second.close()

        // The admitted client is not disturbed.
        #expect(try await first.request("f").contains("RPRT 0"))

        // Once it leaves, the slot is free again.
        first.close()
        var admitted = false
        for _ in 0..<20 where !admitted {
            try await Task.sleep(for: .milliseconds(50))
            let third = try await TestClient.connect(port: port)
            admitted = (try? await third.request("f").contains("RPRT 0")) ?? false
            third.close()
        }
        #expect(admitted)
    }

    private func startOnFreePort(_ server: RigControlServer) async throws -> UInt16 {
        for _ in 0..<10 {
            let port = UInt16.random(in: 40_000...60_000)
            do {
                try await server.start(port: port)
                try await Task.sleep(for: .milliseconds(100))
                return port
            } catch RigControlServerError.cannotBind {
                continue
            }
        }
        throw RigControlServerError.cannotBind(port: 0)
    }
}

/// Minimal line-oriented TCP client over Network.framework.
private final class TestClient: @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "RigControlServerClientLimitTests.client")

    private init(connection: NWConnection) {
        self.connection = connection
    }

    static func connect(port: UInt16) async throws -> TestClient {
        let connection = NWConnection(
            host: "127.0.0.1",
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )
        let client = TestClient(connection: connection)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = Once()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: once.run { continuation.resume() }
                case .failed(let error): once.run { continuation.resume(throwing: error) }
                case .cancelled: once.run { continuation.resume(throwing: RigControlServerError.connectionClosed) }
                default: break
                }
            }
            connection.start(queue: client.queue)
        }
        return client
    }

    /// Sends `command` and collects the reply through its `RPRT` line.
    func request(_ command: String) async throws -> String {
        try await send(command + "\n")
        var reply = ""
        while !reply.contains("RPRT") {
            guard let chunk = try await receive(timeout: 2) else {
                throw RigControlServerError.connectionClosed
            }
            reply += chunk
        }
        return reply
    }

    /// True if the peer closes or resets the connection without sending
    /// data; false if it stays open (times out) or sends anything.
    func waitForClose() async -> Bool {
        do {
            return try await receive(timeout: 2) == nil
        } catch RigError.timeout {
            return false
        } catch {
            return true
        }
    }

    func close() {
        connection.cancel()
    }

    private func send(_ text: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: Data(text.utf8), completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            })
        }
    }

    /// Next chunk as text, or `nil` when the peer has closed.
    private func receive(timeout: TimeInterval) async throws -> String? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String?, Error>) in
            let once = Once()
            queue.asyncAfter(deadline: .now() + timeout) {
                once.run { continuation.resume(throwing: RigError.timeout) }
            }
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
                once.run {
                    if let data, !data.isEmpty {
                        continuation.resume(returning: String(decoding: data, as: UTF8.self))
                    } else if isComplete {
                        continuation.resume(returning: nil)
                    } else if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: "")
                    }
                }
            }
        }
    }
}

/// Runs a closure at most once across threads.
private final class Once: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func run(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        body()
    }
}
