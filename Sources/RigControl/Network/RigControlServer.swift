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
/// let rig = RigController(
///     radio: .icomIC7600,
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
        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, isComplete, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let data = data, !data.isEmpty {
                    let string = String(data: data, encoding: .utf8) ?? ""
                    // Find first newline
                    if let newlineIndex = string.firstIndex(of: "\n") {
                        let line = String(string[..<newlineIndex])
                        continuation.resume(returning: line)
                    } else if isComplete {
                        continuation.resume(returning: string)
                    } else {
                        // Need more data
                        continuation.resume(returning: "")
                    }
                } else if isComplete {
                    continuation.resume(throwing: RigControlServerError.connectionClosed)
                } else {
                    continuation.resume(returning: "")
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
