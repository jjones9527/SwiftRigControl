import Foundation

// MARK: - PTT Control

extension RigController {

    /// Sets the Push-To-Talk (PTT) state.
    ///
    /// When PTT is enabled, the radio will transmit. When disabled, it will receive.
    ///
    /// - Parameter enabled: True to transmit, false to receive
    /// - Throws: `RigError` if operation fails
    ///
    /// - Important: Always disable PTT when finished transmitting to avoid
    ///   accidentally transmitting when not intended.
    ///
    /// - Example:
    /// ```swift
    /// try await rig.setPTT(true)   // Start transmitting
    /// // ... transmit audio ...
    /// try await rig.setPTT(false)  // Stop transmitting
    /// ```
    public func setPTT(_ enabled: Bool) async throws {
        guard connected else {
            throw RigError.notConnected
        }
        try await proto.setPTT(enabled)
    }

    /// Gets the current PTT state.
    ///
    /// - Returns: True if transmitting, false if receiving
    /// - Throws: `RigError` if operation fails
    public func isPTTEnabled() async throws -> Bool {
        guard connected else {
            throw RigError.notConnected
        }
        return try await proto.getPTT()
    }
}
