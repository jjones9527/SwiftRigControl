import Foundation

extension IcomCIVProtocol {

    // MARK: - RIT/XIT Control

    /// Sets the RIT (Receiver Incremental Tuning) state.
    ///
    /// RIT allows fine-tuning of the receiver frequency independently from the displayed
    /// VFO frequency. Most Icom radios support ±9999 Hz offset.
    ///
    /// Uses CI-V commands:
    /// - 0x21 0x00: Set RIT frequency offset (±9999 Hz)
    /// - 0x21 0x01: Set RIT ON/OFF
    ///
    /// - Parameter state: The desired RIT state (enabled/disabled and offset)
    /// - Throws: `RigError` if operation fails or radio doesn't support RIT
    public func setRIT(_ state: RITXITState) async throws {
        // Validate offset range
        guard abs(state.offset) <= 9999 else {
            throw RigError.invalidParameter("RIT offset must be between -9999 and +9999 Hz")
        }

        // Set RIT offset first (even if disabling, some radios require this)
        let offsetBCD = BCDEncoding.encodeRITXITOffset(state.offset)
        let offsetFrame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.ritXit, CIVFrame.RITXITCode.ritFrequency],
            data: offsetBCD
        )

        try await sendFrame(offsetFrame)
        let offsetResponse = try await receiveFrame()

        guard offsetResponse.isAck else {
            throw RigError.commandFailed("Radio rejected RIT offset \(state.offset) Hz")
        }

        // Set RIT ON/OFF
        let enableFrame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.ritXit, CIVFrame.RITXITCode.ritOnOff],
            data: [state.enabled ? 0x01 : 0x00]
        )

        try await sendFrame(enableFrame)
        let enableResponse = try await receiveFrame()

        guard enableResponse.isAck else {
            throw RigError.commandFailed("Radio rejected RIT \(state.enabled ? "enable" : "disable")")
        }
    }

    /// Gets the current RIT state.
    ///
    /// Queries both RIT ON/OFF status and frequency offset.
    ///
    /// - Returns: Current RIT state including enabled status and offset
    /// - Throws: `RigError` if operation fails or radio doesn't support RIT
    public func getRIT() async throws -> RITXITState {
        // Read RIT ON/OFF status
        let enableFrame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.ritXit, CIVFrame.RITXITCode.ritOnOff],
            data: []
        )

        try await sendFrame(enableFrame)
        let enableResponse = try await receiveFrame()

        // IC-7100 returns subcommand in data field: command=[21], data=[01 01]
        // Other radios return: command=[21 01], data=[01]
        let enabled: Bool
        if enableResponse.command.count == 1 && enableResponse.data.count == 2 {
            // IC-7100 format: subcommand in first data byte, value in second
            guard enableResponse.command[0] == CIVFrame.Command.ritXit,
                  enableResponse.data[0] == CIVFrame.RITXITCode.ritOnOff else {
                throw RigError.invalidResponse
            }
            enabled = enableResponse.data[1] == 0x01
        } else if enableResponse.command.count >= 2 && enableResponse.data.count >= 1 {
            // Standard format
            guard enableResponse.command[0] == CIVFrame.Command.ritXit,
                  enableResponse.command[1] == CIVFrame.RITXITCode.ritOnOff else {
                throw RigError.invalidResponse
            }
            enabled = enableResponse.data[0] == 0x01
        } else {
            throw RigError.invalidResponse
        }

        // Read RIT frequency offset
        let offsetFrame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.ritXit, CIVFrame.RITXITCode.ritFrequency],
            data: []
        )

        try await sendFrame(offsetFrame)
        let offsetResponse = try await receiveFrame()

        // IC-7100 returns subcommand in data field: command=[21], data=[00 XX XX XX]
        // Other radios return: command=[21 00], data=[XX XX XX]
        let offsetData: [UInt8]
        if offsetResponse.command.count == 1 && offsetResponse.data.count == 4 {
            // IC-7100 format: subcommand in first data byte, offset in remaining bytes
            guard offsetResponse.command[0] == CIVFrame.Command.ritXit,
                  offsetResponse.data[0] == CIVFrame.RITXITCode.ritFrequency else {
                throw RigError.invalidResponse
            }
            offsetData = Array(offsetResponse.data[1...])  // Skip subcommand byte
        } else if offsetResponse.command.count >= 2 && offsetResponse.data.count == 3 {
            // Standard format
            guard offsetResponse.command[0] == CIVFrame.Command.ritXit,
                  offsetResponse.command[1] == CIVFrame.RITXITCode.ritFrequency else {
                throw RigError.invalidResponse
            }
            offsetData = offsetResponse.data
        } else {
            throw RigError.invalidResponse
        }

        let offset = try BCDEncoding.decodeRITXITOffset(offsetData)

        return RITXITState(enabled: enabled, offset: offset)
    }

    /// Sets the XIT (Transmitter Incremental Tuning) state.
    ///
    /// XIT allows fine-tuning of the transmitter frequency independently from the displayed
    /// VFO frequency. Most Icom radios support ±9999 Hz offset.
    ///
    /// **Note:** Not all Icom radios support separate XIT control. Some radios (like IC-7100)
    /// only support RIT, which affects both RX and TX when transmitting.
    ///
    /// Uses CI-V commands:
    /// - 0x21 0x02: Set XIT frequency offset (±9999 Hz) - if supported
    /// - 0x21 0x03: Set XIT ON/OFF - if supported
    ///
    /// - Parameter state: The desired XIT state (enabled/disabled and offset)
    /// - Throws: `RigError` if operation fails or radio doesn't support XIT
    public func setXIT(_ state: RITXITState) async throws {
        // Validate offset range
        guard abs(state.offset) <= 9999 else {
            throw RigError.invalidParameter("XIT offset must be between -9999 and +9999 Hz")
        }

        // Set XIT offset first
        let offsetBCD = BCDEncoding.encodeRITXITOffset(state.offset)
        let offsetFrame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.ritXit, CIVFrame.RITXITCode.xitFrequency],
            data: offsetBCD
        )

        try await sendFrame(offsetFrame)
        let offsetResponse = try await receiveFrame()

        // Check if radio supports XIT
        if offsetResponse.isNak {
            throw RigError.unsupportedOperation("XIT (Transmitter Incremental Tuning) not supported by this radio")
        }

        guard offsetResponse.isAck else {
            throw RigError.commandFailed("Radio rejected XIT offset \(state.offset) Hz")
        }

        // Set XIT ON/OFF
        let enableFrame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.ritXit, CIVFrame.RITXITCode.xitOnOff],
            data: [state.enabled ? 0x01 : 0x00]
        )

        try await sendFrame(enableFrame)
        let enableResponse = try await receiveFrame()

        guard enableResponse.isAck else {
            throw RigError.commandFailed("Radio rejected XIT \(state.enabled ? "enable" : "disable")")
        }
    }

    /// Gets the current XIT state.
    ///
    /// Queries both XIT ON/OFF status and frequency offset.
    ///
    /// **Note:** Not all Icom radios support separate XIT control. This will throw
    /// `unsupportedOperation` for radios that don't support XIT.
    ///
    /// - Returns: Current XIT state including enabled status and offset
    /// - Throws: `RigError` if operation fails or radio doesn't support XIT
    public func getXIT() async throws -> RITXITState {
        // Read XIT ON/OFF status
        let enableFrame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.ritXit, CIVFrame.RITXITCode.xitOnOff],
            data: []
        )

        try await sendFrame(enableFrame)
        let enableResponse = try await receiveFrame()

        // Check if radio supports XIT
        if enableResponse.isNak {
            throw RigError.unsupportedOperation("XIT (Transmitter Incremental Tuning) not supported by this radio")
        }

        guard enableResponse.command.count >= 2,
              enableResponse.command[0] == CIVFrame.Command.ritXit,
              enableResponse.command[1] == CIVFrame.RITXITCode.xitOnOff,
              !enableResponse.data.isEmpty else {
            throw RigError.invalidResponse
        }

        let enabled = enableResponse.data[0] == 0x01

        // Read XIT frequency offset
        let offsetFrame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.ritXit, CIVFrame.RITXITCode.xitFrequency],
            data: []
        )

        try await sendFrame(offsetFrame)
        let offsetResponse = try await receiveFrame()

        guard offsetResponse.command.count >= 2,
              offsetResponse.command[0] == CIVFrame.Command.ritXit,
              offsetResponse.command[1] == CIVFrame.RITXITCode.xitFrequency,
              offsetResponse.data.count == 3 else {
            throw RigError.invalidResponse
        }

        let offset = try BCDEncoding.decodeRITXITOffset(offsetResponse.data)

        return RITXITState(enabled: enabled, offset: offset)
    }
}
