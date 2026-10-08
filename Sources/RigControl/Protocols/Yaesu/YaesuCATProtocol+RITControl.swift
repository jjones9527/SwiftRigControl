import Foundation

// MARK: - RIT / XIT
//
// Moved out of YaesuCATProtocol.swift in v1.2.19. Set commands go through
// `sendSetCommand` (YaesuCATProtocol+SetCommand.swift).

extension YaesuCATProtocol {

    // MARK: - RIT/XIT Control

    /// Sets the RIT (Receiver Incremental Tuning) state.
    ///
    /// Per Hamlib `rigs/yaesu/newcat.c` `newcat_set_rit`:
    /// - `RC;` (clarifier-clear) prelude — clears any accumulated
    ///   offset so the new value is absolute, not relative.
    /// - `RUnnnn;` (positive offset) or `RDnnnn;` (negative offset) —
    ///   4-digit **unsigned** decimal, direction encoded in the
    ///   command letter (`RU` = up / positive, `RD` = down /
    ///   negative). Hamlib uses `%04ld` with `labs()`.
    /// - `RT1;` to enable, `RT0;` to disable.
    ///
    /// Prior to the v1.2.0 audit fix Swift emitted signed 5-digit
    /// values (`RU+0100;`) which real newcat radios reject — the
    /// `+` sign character is not part of the on-wire format.
    ///
    /// - Parameter state: The desired RIT state (enabled/disabled
    ///   and offset in Hz, -9999 to +9999)
    /// - Throws: `RigError` if operation fails
    public func setRIT(_ state: RITXITState) async throws {
        // Validate offset range
        guard abs(state.offset) <= 9999 else {
            throw RigError.invalidParameter("RIT offset must be between -9999 and +9999 Hz")
        }

        // Clear any accumulated offset before setting a new one.
        try await sendSetCommand("RC")

        // Direction encoded in command letter; value is unsigned.
        let magnitude = abs(state.offset)
        let command: String
        if state.offset >= 0 {
            command = String(format: "RU%04d", magnitude)
        } else {
            command = String(format: "RD%04d", magnitude)
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

        // Read the RIT offset from the IF; status record, as Hamlib
        // `newcat_get_rit` does (newcat.c:3011-3070): "IF", a 3-digit
        // memory channel, the frequency (`frequencyDigits` digits),
        // then the signed 5-character clarifier offset ("+0100").
        // Pre-v1.2.19 this sent `RC;`, which is the clarifier-CLEAR
        // command (Hamlib newcat_set_rit), so reading RIT reset it.
        try await sendCommand("IF")
        let status = try await receiveResponse()
        let offset = try Self.ritOffset(fromIF: status, frequencyDigits: quirks.frequencyDigits)

        return RITXITState(enabled: enabled, offset: offset)
    }

    /// Sets the XIT (Transmitter Incremental Tuning) state.
    ///
    /// Yaesu radios using Kenwood-compatible CAT commands use:
    /// - `XT1;` to enable XIT
    /// - `XT0;` to disable XIT
    /// - Offset is typically shared with RIT
    ///
    /// **Note:** Many Yaesu radios don't support separate XIT control.
    /// They use RIT for both receive and transmit offset.
    ///
    /// - Parameter state: The desired XIT state (enabled/disabled and offset)
    /// - Throws: `RigError` if operation fails or unsupported
    public func setXIT(_ state: RITXITState) async throws {
        // Try to set XIT - many radios don't support this
        let enableCommand = state.enabled ? "XT1" : "XT0"

        do {
            try await sendSetCommand(enableCommand)
        } catch {
            // If XIT command not supported, throw unsupported error
            throw RigError.unsupportedOperation("XIT (Transmitter Incremental Tuning) not supported by this radio - use RIT instead")
        }
    }

    /// Gets the current XIT state.
    ///
    /// **Note:** Many Yaesu radios don't support separate XIT control.
    ///
    /// - Returns: Current XIT state including enabled status and offset
    /// - Throws: `RigError.unsupportedOperation` if XIT not supported
    public func getXIT() async throws -> RITXITState {
        // Try to read XIT status
        do {
            try await sendCommand("XT")
            let response = try await receiveResponse()

            // Response format: XTx; where x is 0 or 1
            guard response.hasPrefix("XT"),
                  response.count >= 3 else {
                throw RigError.invalidResponse
            }

            let enableIndex = response.index(response.startIndex, offsetBy: 2)
            let enableChar = response[enableIndex]
            let enabled = enableChar == "1"

            // XIT typically shares offset with RIT on Yaesu radios
            return RITXITState(enabled: enabled, offset: 0)
        } catch {
            throw RigError.unsupportedOperation("XIT (Transmitter Incremental Tuning) not supported by this radio")
        }
    }

    /// Parses the RIT/XIT clarifier offset from an `IF` reply (read
    /// without its `;`).
    ///
    /// Layout: `IF`, 3-digit memory channel, `frequencyDigits` frequency
    /// digits, then a signed 5-character offset such as `+0100` (Hamlib
    /// `newcat_get_rit` offsets 13 / 14 for 8 / 9 frequency digits,
    /// `newcat.c:3044-3066`).
    ///
    /// - Parameters:
    ///   - reply: The `IF` reply.
    ///   - frequencyDigits: Frequency field width for this radio.
    /// - Returns: The offset in Hz.
    /// - Throws: `RigError.invalidResponse` if the reply is too short or
    ///   the field isn't a signed number.
    static func ritOffset(fromIF reply: String, frequencyDigits: Int) throws -> Int {
        let start = 2 + 3 + frequencyDigits
        let chars = Array(reply)
        guard reply.hasPrefix("IF"), chars.count >= start + 5,
              let offset = Int(String(chars[start..<(start + 5)])) else {
            throw RigError.invalidResponse
        }
        return offset
    }
}
