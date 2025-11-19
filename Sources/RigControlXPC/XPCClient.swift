import Foundation
import RigControl

/// Client for communicating with the RigControl XPC helper from sandboxed applications.
///
/// XPCClient provides a Swift async/await interface for controlling radios from
/// Mac App Store applications. It communicates with the privileged helper which
/// runs outside the sandbox and has access to serial ports.
///
/// Example usage:
/// ```swift
/// let client = XPCClient.shared
/// try await client.connect()
/// try await client.connectToRadio(radio: "IC-9700", port: "/dev/cu.IC9700")
/// try await client.setFrequency(14_230_000, vfo: .a)
/// ```
public actor XPCClient {
    /// Shared singleton instance
    public static let shared = XPCClient()

    /// The XPC connection to the helper
    private var connection: NSXPCConnection?

    /// Whether the client is connected to the helper
    private var isHelperConnected = false

    private init() {}

    // MARK: - Connection Management

    /// Connects to the XPC helper.
    ///
    /// This establishes the XPC connection to the privileged helper.
    /// The helper must be installed using SMJobBless before calling this.
    ///
    /// - Throws: Error if connection fails
    public func connect() async throws {
        guard connection == nil else {
            return // Already connected
        }

        let newConnection = NSXPCConnection(machServiceName: XPCConstants.machServiceName)
        newConnection.remoteObjectInterface = NSXPCInterface(with: RigControlXPCProtocol.self)

        newConnection.invalidationHandler = { [weak self] in
            Task { [weak self] in
                await self?.handleInvalidation()
            }
        }

        newConnection.interruptionHandler = { [weak self] in
            Task { [weak self] in
                await self?.handleInterruption()
            }
        }

        newConnection.resume()
        connection = newConnection
        isHelperConnected = true
    }

    /// Disconnects from the XPC helper.
    public func disconnect() async {
        guard let conn = connection else { return }

        let proxy = conn.remoteObjectProxy as? RigControlXPCProtocol
        await withCheckedContinuation { continuation in
            proxy?.disconnect {
                continuation.resume()
            }
        }

        conn.invalidate()
        connection = nil
        isHelperConnected = false
    }

    /// Connects to a radio via the helper.
    ///
    /// - Parameters:
    ///   - radio: Radio model identifier (e.g., "IC-9700", "K3")
    ///   - port: Serial port path
    ///   - baudRate: Optional baud rate (uses default if nil)
    /// - Throws: Error if connection fails
    public func connectToRadio(radio: String, port: String, baudRate: Int? = nil) async throws {
        guard isHelperConnected else {
            throw createError(.connectionFailed, message: "Not connected to helper")
        }

        guard let proxy = connection?.remoteObjectProxy as? RigControlXPCProtocol else {
            throw createError(.connectionFailed, message: "Invalid XPC proxy")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            proxy.connectToRadio(
                radioModel: radio,
                serialPort: port,
                baudRate: baudRate.map { NSNumber(value: $0) }
            ) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Disconnects from the currently connected radio.
    public func disconnectRadio() async {
        guard let proxy = connection?.remoteObjectProxy as? RigControlXPCProtocol else {
            return
        }

        await withCheckedContinuation { continuation in
            proxy.disconnect {
                continuation.resume()
            }
        }
    }

    // MARK: - Frequency Control

    /// Sets the operating frequency.
    ///
    /// - Parameters:
    ///   - hz: Frequency in Hertz
    ///   - vfo: VFO to set
    /// - Throws: Error if operation fails
    public func setFrequency(_ hz: UInt64, vfo: VFO = .a) async throws {
        guard let proxy = connection?.remoteObjectProxy as? RigControlXPCProtocol else {
            throw createError(.notConnected, message: "Not connected to helper")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            proxy.setFrequency(hz, vfo: vfo.rawValue) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Gets the current operating frequency.
    ///
    /// - Parameter vfo: VFO to query
    /// - Returns: Frequency in Hertz
    /// - Throws: Error if operation fails
    public func frequency(vfo: VFO = .a) async throws -> UInt64 {
        guard let proxy = connection?.remoteObjectProxy as? RigControlXPCProtocol else {
            throw createError(.notConnected, message: "Not connected to helper")
        }

        return try await withCheckedThrowingContinuation { continuation in
            proxy.getFrequency(vfo: vfo.rawValue) { freq, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: freq)
                }
            }
        }
    }

    // MARK: - Mode Control

    /// Sets the operating mode.
    ///
    /// - Parameters:
    ///   - mode: Mode to set
    ///   - vfo: VFO to set
    /// - Throws: Error if operation fails
    public func setMode(_ mode: Mode, vfo: VFO = .a) async throws {
        guard let proxy = connection?.remoteObjectProxy as? RigControlXPCProtocol else {
            throw createError(.notConnected, message: "Not connected to helper")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            proxy.setMode(mode.rawValue, vfo: vfo.rawValue) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Gets the current operating mode.
    ///
    /// - Parameter vfo: VFO to query
    /// - Returns: Current mode
    /// - Throws: Error if operation fails
    public func mode(vfo: VFO = .a) async throws -> Mode {
        guard let proxy = connection?.remoteObjectProxy as? RigControlXPCProtocol else {
            throw createError(.notConnected, message: "Not connected to helper")
        }

        return try await withCheckedThrowingContinuation { continuation in
            proxy.getMode(vfo: vfo.rawValue) { modeString, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let modeString = modeString,
                          let mode = Mode(rawValue: modeString) {
                    continuation.resume(returning: mode)
                } else {
                    continuation.resume(throwing: self.createError(.operationFailed, message: "Invalid mode"))
                }
            }
        }
    }

    // MARK: - PTT Control

    /// Sets the PTT state.
    ///
    /// - Parameter enabled: True to transmit, false to receive
    /// - Throws: Error if operation fails
    public func setPTT(_ enabled: Bool) async throws {
        guard let proxy = connection?.remoteObjectProxy as? RigControlXPCProtocol else {
            throw createError(.notConnected, message: "Not connected to helper")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            proxy.setPTT(enabled) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Gets the current PTT state.
    ///
    /// - Returns: True if transmitting, false if receiving
    /// - Throws: Error if operation fails
    public func isPTTEnabled() async throws -> Bool {
        guard let proxy = connection?.remoteObjectProxy as? RigControlXPCProtocol else {
            throw createError(.notConnected, message: "Not connected to helper")
        }

        return try await withCheckedThrowingContinuation { continuation in
            proxy.getPTT { enabled, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: enabled)
                }
            }
        }
    }

    // MARK: - VFO Control

    /// Selects the active VFO.
    ///
    /// - Parameter vfo: VFO to select
    /// - Throws: Error if operation fails
    public func selectVFO(_ vfo: VFO) async throws {
        guard let proxy = connection?.remoteObjectProxy as? RigControlXPCProtocol else {
            throw createError(.notConnected, message: "Not connected to helper")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            proxy.selectVFO(vfo.rawValue) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Power Control

    /// Sets the RF power level.
    ///
    /// - Parameter watts: Power level in watts
    /// - Throws: Error if operation fails
    public func setPower(_ watts: Int) async throws {
        guard let proxy = connection?.remoteObjectProxy as? RigControlXPCProtocol else {
            throw createError(.notConnected, message: "Not connected to helper")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            proxy.setPower(watts) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Gets the current RF power level.
    ///
    /// - Returns: Power level in watts
    /// - Throws: Error if operation fails
    public func power() async throws -> Int {
        guard let proxy = connection?.remoteObjectProxy as? RigControlXPCProtocol else {
            throw createError(.notConnected, message: "Not connected to helper")
        }

        return try await withCheckedThrowingContinuation { continuation in
            proxy.getPower { watts, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: watts)
                }
            }
        }
    }

    // MARK: - Split Operation

    /// Enables or disables split operation.
    ///
    /// - Parameter enabled: True to enable split, false to disable
    /// - Throws: Error if operation fails
    public func setSplit(_ enabled: Bool) async throws {
        guard let proxy = connection?.remoteObjectProxy as? RigControlXPCProtocol else {
            throw createError(.notConnected, message: "Not connected to helper")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            proxy.setSplit(enabled) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Gets the current split operation state.
    ///
    /// - Returns: True if split is enabled, false otherwise
    /// - Throws: Error if operation fails
    public func isSplitEnabled() async throws -> Bool {
        guard let proxy = connection?.remoteObjectProxy as? RigControlXPCProtocol else {
            throw createError(.notConnected, message: "Not connected to helper")
        }

        return try await withCheckedThrowingContinuation { continuation in
            proxy.getSplit { enabled, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: enabled)
                }
            }
        }
    }

    // MARK: - Radio Information

    /// Checks if a radio is currently connected.
    ///
    /// - Returns: True if connected, false otherwise
    public func isRadioConnected() async -> Bool {
        guard let proxy = connection?.remoteObjectProxy as? RigControlXPCProtocol else {
            return false
        }

        return await withCheckedContinuation { continuation in
            proxy.isConnected { connected in
                continuation.resume(returning: connected)
            }
        }
    }

    // MARK: - Private Methods

    private func handleInvalidation() {
        connection = nil
        isHelperConnected = false
    }

    private func handleInterruption() {
        // Connection was interrupted, try to reconnect
        isHelperConnected = false
    }

    private func createError(_ code: XPCConstants.ErrorCode, message: String) -> NSError {
        return NSError(
            domain: XPCConstants.errorDomain,
            code: code.rawValue,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
