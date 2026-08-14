import Foundation
import Network

/// TCP server for rigctld-compatible rig control.
///
/// Provides network access to a RigController using the Hamlib rigctld protocol.
/// Supports multiple simultaneous client connections with both Default and Extended
/// response protocols.
///
/// ## Features
/// - TCP server on configurable port (default: 4532)
/// - Multiple simultaneous clients
/// - Hamlib rigctld protocol compatibility
/// - Both Default and Extended response modes
/// - Thread-safe actor-based concurrency
///
/// ## Usage
/// ```swift
/// let rig = try RigController(
///     radio: .Icom.ic7600(),
///     connection: .serial(path: "/dev/cu.IC-7600", baudRate: 19200)
/// )
/// try await rig.connect()
///
/// let server = RigControlServer(rigController: rig)
/// try await server.start(port: 4532)
///
/// print("rigctld server listening on port 4532")
///
/// // Server runs until stopped
/// await server.stop()
/// ```
///
/// ## Client Connection
/// Clients can connect using any TCP client:
/// ```bash
/// # Using telnet
/// telnet localhost 4532
///
/// # Using netcat
/// nc localhost 4532
///
/// # Using rigctl (Hamlib)
/// rigctl -m 2 -r localhost:4532
/// ```
public actor RigControlServer {
    /// Server state
    private enum State {
        case stopped
        case starting
        case running
        case stopping
    }

    /// The rig controller to serve
    private let rigController: RigController

    /// TCP listener
    private var listener: NWListener?

    /// Active client sessions
    private var sessions: [ClientSession] = []

    /// Server state
    private var state: State = .stopped

    /// Port the server is listening on
    public private(set) var port: UInt16?

    /// Initialize with a rig controller
    ///
    /// - Parameter rigController: The rig controller to serve
    public init(rigController: RigController) {
        self.rigController = rigController
    }

    /// Start the server
    ///
    /// - Parameter port: TCP port to listen on (default: 4532)
    /// - Throws: Error if server cannot start
    public func start(port: UInt16 = RigctldProtocol.defaultPort) async throws {
        guard state == .stopped else {
            throw RigControlServerError.alreadyRunning
        }

        state = .starting

        // Create TCP listener
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true

        guard let listener = try? NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port)) else {
            state = .stopped
            throw RigControlServerError.cannotBind(port: port)
        }

        self.listener = listener
        self.port = port

        // Configure new connection handler
        listener.newConnectionHandler = { [weak self] connection in
            Task {
                await self?.handleNewConnection(connection)
            }
        }

        // Configure state update handler
        listener.stateUpdateHandler = { [weak self] newState in
            Task {
                await self?.handleListenerStateChange(newState)
            }
        }

        // Start listening
        listener.start(queue: .main)

        state = .running
    }

    /// Stop the server
    public func stop() async {
        guard state == .running else { return }

        state = .stopping

        // Close all client sessions
        for session in sessions {
            await session.close()
        }
        sessions.removeAll()

        // Stop listener
        listener?.cancel()
        listener = nil
        port = nil

        state = .stopped
    }

    /// Check if server is running
    public var isRunning: Bool {
        state == .running
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        let session = ClientSession(
            connection: connection,
            rigController: rigController
        )

        sessions.append(session)

        Task {
            await session.start()

            // Remove session when it closes
            removeSession(session)
        }
    }

    private func removeSession(_ session: ClientSession) {
        sessions.removeAll { $0 === session }
    }

    private func handleListenerStateChange(_ newState: NWListener.State) {
        switch newState {
        case .ready:
            break  // Server is ready
        case .failed(let error):
            print("rigctld server failed: \(error)")
            Task {
                await self.stop()
            }
        case .cancelled:
            break  // Server was cancelled
        default:
            break
        }
    }
}

// MARK: - Line buffer

/// Line-buffered feed of bytes off a TCP socket. Handles the
/// three inconvenient realities of TCP:
///
/// 1. **Fragmentation.** A single logical command may arrive in
///    two or more `recv()` chunks (e.g. `T VFOA` then ` 1\n`).
/// 2. **Coalescing.** Multiple logical commands may arrive in a
///    single `recv()` chunk (e.g. `T VFOA 1\nT VFOA 0\n` in one
///    read — Direwolf's rapid PTT toggles under load, or client
///    Nagle aggregation).
/// 3. **Bytes without newlines are still bytes.** They must be
///    buffered, not dropped, or the next chunk's meaning is
///    scrambled.
///
/// Prior to v1.2.14, `ClientSession.receiveLine()` handled case 2
/// wrong (took the first line and discarded everything after) and
/// case 1 catastrophically wrong (returned an empty line and
/// dropped the partial bytes on the floor). Under Direwolf's PTT
/// storm during a MacWinlink Packet session, this manifested as
/// `T VFOA 0` seeing an 8-byte reply and `T VFOA 1` seeing a
/// 9-byte reply, both mapped by Hamlib to warning codes -9 and
/// -10 (macwinlink-releases#54 second followup).
///
/// This buffer is internal to the module for test visibility.
struct LineBuffer {
    private var data: Data = Data()

    /// Append `chunk` to the buffer.
    mutating func append(_ chunk: Data) {
        data.append(chunk)
    }

    /// Pop the next `\n`-terminated line from the buffer, if any.
    /// Returns the line WITHOUT its trailing `\n`. Returns `nil`
    /// if the buffer doesn't yet contain a complete line — the
    /// caller must read more bytes and try again.
    ///
    /// The buffer retains any bytes after the consumed `\n` so
    /// subsequent calls see them, which is how case 2 (coalesced
    /// commands) is handled.
    mutating func nextLine() -> String? {
        guard let newlineIdx = data.firstIndex(of: 0x0A) else {
            return nil
        }
        let lineBytes = data[data.startIndex..<newlineIdx]
        let line = String(data: lineBytes, encoding: .utf8) ?? ""
        // Drop the line + its trailing `\n` from the buffer.
        data.removeSubrange(data.startIndex...newlineIdx)
        return line
    }

    /// True if the buffer holds no unconsumed bytes.
    var isEmpty: Bool { data.isEmpty }

    /// Byte count of unconsumed data. Test-visible for
    /// invariant checks.
    var count: Int { data.count }
}

// MARK: - Client Session

/// Represents a single client connection to the rigctld server
private actor ClientSession {
    /// TCP connection
    private let connection: NWConnection

    /// Command handler
    private let handler: RigctldCommandHandler

    /// Command parser
    private let parser = RigctldCommandParser()

    /// Response mode (default or extended)
    private var responseMode: RigctldProtocol.ResponseMode = .default

    /// Whether the session is active
    private var isActive = false

    /// Byte buffer holding data read from the socket but not yet
    /// dispatched as a complete command line. See `LineBuffer`
    /// for the fragmentation/coalescing rationale.
    private var lineBuffer = LineBuffer()

    init(connection: NWConnection, rigController: RigController) {
        self.connection = connection
        self.handler = RigctldCommandHandler(rigController: rigController)
    }

    func start() async {
        isActive = true

        connection.stateUpdateHandler = { [weak self] newState in
            Task {
                await self?.handleConnectionStateChange(newState)
            }
        }

        connection.start(queue: .main)

        // Start receiving commands
        await receiveCommands()
    }

    func close() async {
        isActive = false
        connection.cancel()
    }

    // MARK: - Command Processing

    private func receiveCommands() async {
        while isActive {
            do {
                let line = try await receiveLine()

                guard !line.isEmpty else { continue }

                // Parse and execute command
                let response = await processCommand(line)

                // Send response
                try await send(response)

                // Check for quit command
                if case .quit = try? parser.parse(line) {
                    await close()
                    break
                }
            } catch {
                // Connection error, close session
                await close()
                break
            }
        }
    }

    private func processCommand(_ line: String) async -> RigctldResponse {
        do {
            let command = try parser.parse(line)

            // Handle protocol control commands
            if case .setExtendedResponse(let enabled) = command {
                responseMode = enabled ? .extended : .default
                return .ok(command: command)
            }

            // Execute command
            return await handler.handle(command)
        } catch is RigctldCommandParser.ParseError {
            return .error(.invalidParam)
        } catch {
            return .error(.internalError)
        }
    }

    // MARK: - I/O

    private func receiveLine() async throws -> String {
        // If the buffer already holds a complete line from a
        // previous coalesced read, return it immediately without
        // touching the socket. This is what makes pipelined sends
        // (case 2 in LineBuffer's doc) work.
        while true {
            if let line = lineBuffer.nextLine() {
                return line
            }
            // No complete line yet — pull the next chunk off the
            // wire and append. Loop back to try again.
            let chunk = try await receiveChunk()
            lineBuffer.append(chunk)
        }
    }

    /// Read one chunk of bytes off the socket. Throws
    /// `.connectionClosed` when the peer closes with no more data.
    private func receiveChunk() async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let data = data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(throwing: RigControlServerError.connectionClosed)
                } else {
                    // NWConnection can call the completion with no
                    // data and no isComplete when a receive was
                    // satisfied by an empty flush (rare). Return
                    // an empty chunk so the caller loops and tries
                    // again.
                    continuation.resume(returning: Data())
                }
            }
        }
    }

    private func send(_ response: RigctldResponse) async throws {
        let formatted = response.format(mode: responseMode)
        guard let data = formatted.data(using: .utf8) else {
            throw RigControlServerError.encodingError
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func handleConnectionStateChange(_ newState: NWConnection.State) async {
        switch newState {
        case .ready:
            break  // Connection is ready
        case .waiting:
            break  // Waiting for network
        case .preparing:
            break  // Preparing connection
        case .setup:
            break  // Setting up connection
        case .failed, .cancelled:
            await close()
        @unknown default:
            break
        }
    }
}

// MARK: - Errors

/// Errors that can occur in the rig control server
public enum RigControlServerError: Error, LocalizedError {
    /// Server is already running
    case alreadyRunning

    /// Cannot bind to port
    case cannotBind(port: UInt16)

    /// Connection closed
    case connectionClosed

    /// Encoding error
    case encodingError

    public var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Server is already running"
        case .cannotBind(let port):
            return "Cannot bind to port \(port). Port may already be in use."
        case .connectionClosed:
            return "Connection closed"
        case .encodingError:
            return "Failed to encode response"
        }
    }
}
