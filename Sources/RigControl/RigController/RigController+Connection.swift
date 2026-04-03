import Foundation

// MARK: - Connection Management

extension RigController {

    /// Connects to the radio.
    ///
    /// This opens the serial port connection and performs any necessary initialization.
    ///
    /// - Throws: `RigError` if connection fails
    public func connect() async throws {
        guard !connected else { return }
        try await proto.connect()
        connected = true
    }

    /// Disconnects from the radio.
    public func disconnect() async {
        guard connected else { return }
        await proto.disconnect()
        connected = false
        // Invalidate cache on disconnect
        await stateCache.invalidate()
    }

    /// Checks if the controller is connected.
    public var isConnected: Bool {
        connected
    }
}
