import Foundation

// MARK: - Split Operation

extension RigController {

    /// Enables or disables split operation.
    ///
    /// In split mode, the radio transmits on one VFO while receiving on another.
    /// This is commonly used for working DX stations that are listening on a different
    /// frequency than they're transmitting on.
    ///
    /// - Parameter enabled: True to enable split, false to disable
    /// - Throws:
    ///   - `RigError.unsupportedOperation` if radio doesn't support split
    ///   - `RigError.notConnected` if not connected
    ///
    /// - Example:
    /// ```swift
    /// // Set up for split operation
    /// try await rig.setFrequency(14_195_000, vfo: .a)  // Receive frequency
    /// try await rig.setFrequency(14_225_000, vfo: .b)  // Transmit frequency
    /// try await rig.setSplit(true)                      // Enable split
    /// // Radio now receives on VFO A, transmits on VFO B
    /// ```
    public func setSplit(_ enabled: Bool) async throws {
        guard connected else {
            throw RigError.notConnected
        }

        guard radio.capabilities.hasSplit else {
            throw RigError.unsupportedOperation("Split operation not supported by \(radio.fullName)")
        }

        try await proto.setSplit(enabled)
    }

    /// Gets the current split operation state.
    ///
    /// - Returns: True if split is enabled, false otherwise
    /// - Throws: `RigError` if operation fails
    public func isSplitEnabled() async throws -> Bool {
        guard connected else {
            throw RigError.notConnected
        }
        return try await proto.getSplit()
    }
}
