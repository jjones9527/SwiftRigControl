import Foundation

// RIT / XIT for Kenwood-protocol radios (RU / RD / RT / XT / RC).

extension KenwoodProtocol {
    // MARK: - RIT/XIT Control

    /// Sets the RIT (Receiver Incremental Tuning) state.
    ///
    /// Kenwood radios use:
    /// - `RT1;` to enable RIT
    /// - `RT0;` to disable RIT
    /// - `RU+nnnn;` or `RD+nnnn;` to set offset (in Hz, -9999 to +9999)
    ///
    /// - Parameter state: The desired RIT state (enabled/disabled and offset)
    /// - Throws: `RigError` if operation fails
    public func setRIT(_ state: RITXITState) async throws {
        // Validate offset range
        guard abs(state.offset) <= 9999 else {
            throw RigError.invalidParameter("RIT offset must be between -9999 and +9999 Hz")
        }

        // Set RIT offset using RU (up) or RD (down) command
        // Format: RU+nnnn; or RD-nnnn;
        let command: String
        if state.offset >= 0 {
            command = String(format: "RU%+05d", state.offset)
        } else {
            command = String(format: "RD%+05d", state.offset)
        }

        try await sendSetCommand(command)

        // Set RIT ON/OFF
        let enableCommand = state.enabled ? "RT1" : "RT0"
        try await sendSetCommand(enableCommand)
    }

    /// Gets the current RIT state.
    ///
    /// Queries both RIT ON/OFF status and frequency offset.
    ///
    /// - Returns: Current RIT state including enabled status and offset
    /// - Throws: `RigError` if operation fails
    public func getRIT() async throws -> RITXITState {
        // Read RIT ON/OFF status
        try await sendCommand("RT")
        let enableResponse = try await receiveResponse()

        // Response format: RTx; where x is 0 or 1
        guard enableResponse.hasPrefix("RT"),
              enableResponse.count >= 3 else {
            throw RigError.invalidResponse
        }

        let enableIndex = enableResponse.index(enableResponse.startIndex, offsetBy: 2)
        let enableChar = enableResponse[enableIndex]
        let enabled = enableChar == "1"

        // Read RIT offset using RC (Read Clarifier) command
        var offset = 0
        do {
            try await sendCommand("RC")
            let offsetResponse = try await receiveResponse()

            // Response format: RC+nnnnn; or RC-nnnnn;
            guard offsetResponse.hasPrefix("RC"),
                  offsetResponse.count >= 8 else {
                throw RigError.invalidResponse
            }

            let startIndex = offsetResponse.index(offsetResponse.startIndex, offsetBy: 2)
            let endIndex = offsetResponse.index(startIndex, offsetBy: 6)
            let offsetString = String(offsetResponse[startIndex..<endIndex])

            offset = Int(offsetString) ?? 0
        } catch {
            // If RC command not supported, default to 0 offset
            offset = 0
        }

        return RITXITState(enabled: enabled, offset: offset)
    }

    /// Sets the XIT (Transmitter Incremental Tuning) state.
    ///
    /// Kenwood radios use:
    /// - `XT1;` to enable XIT
    /// - `XT0;` to disable XIT
    /// - Offset is typically controlled by the same RU/RD commands as RIT
    ///
    /// - Parameter state: The desired XIT state (enabled/disabled and offset)
    /// - Throws: `RigError` if operation fails
    public func setXIT(_ state: RITXITState) async throws {
        // Validate offset range
        guard abs(state.offset) <= 9999 else {
            throw RigError.invalidParameter("XIT offset must be between -9999 and +9999 Hz")
        }

        // Set XIT offset (shares with RIT on most Kenwood radios)
        let command: String
        if state.offset >= 0 {
            command = String(format: "RU%+05d", state.offset)
        } else {
            command = String(format: "RD%+05d", state.offset)
        }

        try await sendSetCommand(command)

        // Set XIT ON/OFF
        let enableCommand = state.enabled ? "XT1" : "XT0"
        try await sendSetCommand(enableCommand)
    }

    /// Gets the current XIT state.
    ///
    /// Queries both XIT ON/OFF status and frequency offset.
    ///
    /// **Note:** On most Kenwood radios, RIT and XIT share the same offset value.
    ///
    /// - Returns: Current XIT state including enabled status and offset
    /// - Throws: `RigError` if operation fails
    public func getXIT() async throws -> RITXITState {
        // Read XIT ON/OFF status
        try await sendCommand("XT")
        let enableResponse = try await receiveResponse()

        // Response format: XTx; where x is 0 or 1
        guard enableResponse.hasPrefix("XT"),
              enableResponse.count >= 3 else {
            throw RigError.invalidResponse
        }

        let enableIndex = enableResponse.index(enableResponse.startIndex, offsetBy: 2)
        let enableChar = enableResponse[enableIndex]
        let enabled = enableChar == "1"

        // Read offset using RC command (shared with RIT)
        var offset = 0
        do {
            try await sendCommand("RC")
            let offsetResponse = try await receiveResponse()

            // Response format: RC+nnnnn; or RC-nnnnn;
            guard offsetResponse.hasPrefix("RC"),
                  offsetResponse.count >= 8 else {
                throw RigError.invalidResponse
            }

            let startIndex = offsetResponse.index(offsetResponse.startIndex, offsetBy: 2)
            let endIndex = offsetResponse.index(startIndex, offsetBy: 6)
            let offsetString = String(offsetResponse[startIndex..<endIndex])

            offset = Int(offsetString) ?? 0
        } catch {
            // If RC command not supported, default to 0 offset
            offset = 0
        }

        return RITXITState(enabled: enabled, offset: offset)
    }
}
