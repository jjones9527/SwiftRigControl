import Foundation

// MARK: - Connection Management

extension RigController {

    /// Connects to the radio.
    ///
    /// This opens the serial port connection and performs any necessary initialization.
    /// Emits `.connectionStateChanged(.connecting)` immediately and
    /// `.connectionStateChanged(.connected)` on success. On failure
    /// the state reverts to `.disconnected` and the error is rethrown.
    ///
    /// - Throws: `RigError` if connection fails
    public func connect() async throws {
        guard !connected else { return }
        transition(to: .connecting)
        do {
            try await proto.connect()
        } catch {
            transition(to: .disconnected)
            throw error
        }
        connected = true
        transition(to: .connected)
    }

    /// Disconnects from the radio.
    /// Stops the periodic poller (if running) since polling a closed
    /// transport is pointless, then emits
    /// `.connectionStateChanged(.disconnected)` after the underlying
    /// transport closes and the cache is cleared.
    public func disconnect() async {
        guard connected else { return }
        stopPollingInternal()
        await proto.disconnect()
        connected = false
        await stateCache.invalidate()
        transition(to: .disconnected)
    }

    /// Checks if the controller is connected.
    public var isConnected: Bool {
        connected
    }
}
