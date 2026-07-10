import Foundation
import Network

/// TCP-backed ``SerialTransport`` that talks to a remote CAT endpoint.
///
/// Used for two distinct scenarios:
///
/// 1. **Flex 6000-series radios** — SmartSDR exposes a Kenwood-derived
///    text CAT surface on TCP port 4992. Pair this transport with
///    ``KenwoodProtocol`` via ``RadioDefinition/Flex/flex6000``.
/// 2. **Remote rigctld bridging** — connect to another machine's
///    `rigctld` (or another SwiftRigControl instance's
///    ``RigControlServer``) and drive it as if it were a local
///    serial port.
///
/// The transport is a byte-stream — the underlying ``CATProtocol``
/// implementations do not know whether their bytes come from a USB
/// serial port or a TCP socket. Any text-based protocol that
/// terminates frames with `;` (Kenwood/Yaesu/Elecraft) or `\r`
/// (TH-D72) works without modification.
///
/// > Hamlib precedent: this is the Swift analogue of Hamlib's
/// > `RIG_PORT_NETWORK`. Hamlib's `flex6xxx.c` declares
/// > `.port_type = RIG_PORT_NETWORK` and reuses the Kenwood text
/// > command set unchanged.
public actor TCPSerialTransport: SerialTransport {

    // MARK: - Configuration

    /// Host to connect to (hostname, IPv4, or IPv6 literal).
    public let host: String

    /// TCP port. Flex SmartSDR uses 4992; Hamlib's `rigctld` defaults
    /// to 4532.
    public let port: UInt16

    /// How long to wait for ``open()`` before throwing.
    public let connectTimeout: TimeInterval

    // MARK: - State

    private var connection: NWConnection?
    private var openState: Bool = false

    /// Buffer of bytes the remote has sent that we have not yet
    /// handed back through ``read(timeout:)`` / ``readUntil(terminator:timeout:)``.
    private var receiveBuffer: Data = Data()

    /// Continuations parked in ``read(timeout:)`` /
    /// ``readUntil(terminator:timeout:)`` waiting for bytes to arrive
    /// or for a terminator to land. Each waiter holds a predicate
    /// that decides when its continuation is ready to resume.
    private var waiters: [PendingRead] = []

    /// Background task draining bytes from the connection's
    /// `receiveMessage` callback into ``receiveBuffer``.
    private var receiveLoop: Task<Void, Never>?

    // MARK: - Init

    /// Creates a new TCP transport.
    ///
    /// - Parameters:
    ///   - host: Hostname, IPv4, or IPv6 literal (e.g. `"10.0.1.42"`,
    ///     `"flex-6400.local"`).
    ///   - port: TCP port. Pass `4992` for Flex SmartSDR; `4532` for
    ///     a remote `rigctld`.
    ///   - connectTimeout: Seconds to wait for the initial TCP
    ///     handshake before failing ``open()``. Defaults to 5 s.
    public init(host: String, port: UInt16, connectTimeout: TimeInterval = 5.0) {
        self.host = host
        self.port = port
        self.connectTimeout = connectTimeout
    }

    // MARK: - SerialTransport

    public var isOpen: Bool { openState }

    public func open() async throws {
        guard !openState else { return }

        let host = NWEndpoint.Host(self.host)
        guard let port = NWEndpoint.Port(rawValue: self.port) else {
            throw RigError.serialPortError("Invalid TCP port \(self.port)")
        }

        let params = NWParameters.tcp
        if let tcpOptions = params.defaultProtocolStack.internetProtocol as? NWProtocolTCP.Options {
            tcpOptions.noDelay = true
        }
        let connection = NWConnection(host: host, port: port, using: params)
        self.connection = connection

        // Wait for the connection to reach `.ready` (or fail) before
        // returning. NWConnection's state handler runs on a private
        // queue, so bridge to async via withCheckedThrowingContinuation.
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let deadline = DispatchTime.now() + connectTimeout
            let resumed = ContinuationGuard()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if resumed.tryResume() {
                        cont.resume()
                    }
                case .failed(let error):
                    if resumed.tryResume() {
                        cont.resume(throwing: RigError.serialPortError(
                            "TCP connect to \(host):\(port) failed: \(error.localizedDescription)"
                        ))
                    }
                case .cancelled:
                    if resumed.tryResume() {
                        cont.resume(throwing: RigError.serialPortError(
                            "TCP connect to \(host):\(port) cancelled before ready"
                        ))
                    }
                default:
                    break
                }
            }
            DispatchQueue.global().asyncAfter(deadline: deadline) {
                if resumed.tryResume() {
                    connection.cancel()
                    cont.resume(throwing: RigError.timeout)
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
        }

        openState = true
        startReceiveLoop()
    }

    public func close() async {
        openState = false
        receiveLoop?.cancel()
        receiveLoop = nil
        connection?.cancel()
        connection = nil
        let pending = waiters
        waiters.removeAll()
        for waiter in pending {
            waiter.continuation.resume(throwing: RigError.serialPortError("TCP transport closed"))
        }
        receiveBuffer.removeAll(keepingCapacity: false)
    }

    public func write(_ data: Data) async throws {
        guard openState, let connection else {
            throw RigError.serialPortError("TCP transport is not open")
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    cont.resume(throwing: RigError.serialPortError(
                        "TCP write failed: \(error.localizedDescription)"
                    ))
                } else {
                    cont.resume()
                }
            })
        }
    }

    public func read(timeout: TimeInterval) async throws -> Data {
        try checkOpen()
        if !receiveBuffer.isEmpty {
            let data = receiveBuffer
            receiveBuffer.removeAll(keepingCapacity: true)
            return data
        }
        return try await waitForBytes(timeout: timeout) { buffer in
            guard !buffer.isEmpty else { return nil }
            let consumed = buffer
            return (consumed, buffer.count)
        }
    }

    public func readUntil(terminator: UInt8, timeout: TimeInterval) async throws -> Data {
        try checkOpen()
        if let idx = receiveBuffer.firstIndex(of: terminator) {
            let endExclusive = receiveBuffer.index(after: idx)
            let frame = Data(receiveBuffer[..<endExclusive])
            receiveBuffer.removeSubrange(..<endExclusive)
            return frame
        }
        return try await waitForBytes(timeout: timeout) { buffer in
            guard let idx = buffer.firstIndex(of: terminator) else { return nil }
            let endExclusive = buffer.index(after: idx)
            let frame = Data(buffer[..<endExclusive])
            return (frame, buffer.distance(from: buffer.startIndex, to: endExclusive))
        }
    }

    public func flush() async throws {
        try checkOpen()
        receiveBuffer.removeAll(keepingCapacity: true)
    }

    // TCP has no modem control lines; PTT over rigctld / Flex SmartSDR
    // is a data-plane concern (T 1 / T 0 for rigctld, ZZTX / ZZRX for
    // Flex). These are documented no-ops so callers can hold a single
    // `SerialTransport` reference regardless of transport type.
    public func setDTR(_ enabled: Bool) async throws {
        try checkOpen()
    }

    public func setRTS(_ enabled: Bool) async throws {
        try checkOpen()
    }

    // MARK: - Private

    private func checkOpen() throws {
        guard openState else {
            throw RigError.serialPortError("TCP transport is not open")
        }
    }

    private func startReceiveLoop() {
        guard let connection else { return }
        receiveLoop = Task { [weak self] in
            while !Task.isCancelled {
                let chunk: Data
                do {
                    chunk = try await Self.receiveOnce(connection)
                } catch {
                    await self?.handleReceiveError(error)
                    return
                }
                if chunk.isEmpty { continue }
                await self?.appendReceived(chunk)
            }
        }
    }

    private static func receiveOnce(_ connection: NWConnection) async throws -> Data {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                if isComplete && (data?.isEmpty ?? true) {
                    cont.resume(throwing: RigError.serialPortError("Remote closed connection"))
                    return
                }
                cont.resume(returning: data ?? Data())
            }
        }
    }

    private func appendReceived(_ chunk: Data) {
        receiveBuffer.append(chunk)
        drainWaiters()
    }

    private func handleReceiveError(_ error: Error) {
        openState = false
        let pending = waiters
        waiters.removeAll()
        for waiter in pending {
            waiter.continuation.resume(throwing: error)
        }
    }

    /// Run every parked waiter against the current buffer. If a
    /// waiter's predicate returns a non-nil frame, resume it and
    /// strip the consumed bytes from the buffer.
    private func drainWaiters() {
        guard !waiters.isEmpty else { return }
        var i = 0
        while i < waiters.count {
            let waiter = waiters[i]
            if let (frame, consumed) = waiter.predicate(receiveBuffer) {
                receiveBuffer.removeSubrange(receiveBuffer.startIndex ..< receiveBuffer.index(receiveBuffer.startIndex, offsetBy: consumed))
                waiter.timeoutTask?.cancel()
                waiter.continuation.resume(returning: frame)
                waiters.remove(at: i)
            } else {
                i += 1
            }
        }
    }

    private func waitForBytes(
        timeout: TimeInterval,
        predicate: @escaping @Sendable (Data) -> (Data, Int)?
    ) async throws -> Data {
        let id = UUID()
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            let timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(max(0, timeout) * 1_000_000_000))
                if !Task.isCancelled {
                    await self?.expireWaiter(id: id)
                }
            }
            waiters.append(PendingRead(
                id: id,
                predicate: predicate,
                continuation: cont,
                timeoutTask: timeoutTask
            ))
            drainWaiters()
        }
    }

    private func expireWaiter(id: UUID) {
        guard let idx = waiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waiters.remove(at: idx)
        waiter.continuation.resume(throwing: RigError.timeout)
    }

    // MARK: - Helper types

    private struct PendingRead {
        let id: UUID
        let predicate: @Sendable (Data) -> (Data, Int)?
        let continuation: CheckedContinuation<Data, Error>
        let timeoutTask: Task<Void, Never>?
    }

    /// Thread-safe one-shot guard so NWConnection's state callback
    /// (which can fire repeatedly during a single connect attempt)
    /// only resumes the connect continuation once.
    private final class ContinuationGuard: @unchecked Sendable {
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
