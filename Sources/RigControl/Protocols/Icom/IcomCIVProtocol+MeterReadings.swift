import Foundation

extension IcomCIVProtocol {

    // MARK: - Meter Readings (0x15 sub-commands)

    /// Read S-meter level (signal strength).
    ///
    /// Returns the current signal strength reading from the S-meter.
    ///
    /// **Command**: `0x15 0x02`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical, 0-255 scale)
    ///
    /// - Returns: S-meter level (0=S0, 120=S9, 241=S9+60dB)
    /// - Throws: `RigError.invalidResponse` if response is malformed
    ///
    /// - Note: For user-friendly display, use `getSignalStrength()` in base protocol
    public func getSMeterLevel() async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x15, 0x02],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        return UInt8(BCDEncoding.decodePower(response.data))
    }

    /// Read RF power output meter (forward power during TX).
    ///
    /// Returns the current transmit power output reading.
    ///
    /// **Command**: `0x15 0x11`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical, 0-255 scale)
    ///
    /// - Returns: Power meter level (0=0%, 143=50%, 213=100%)
    /// - Throws: `RigError.invalidResponse` if response is malformed
    ///
    /// - Important: Only valid during transmission
    public func getRFPowerMeter() async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x15, 0x11],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        return UInt8(BCDEncoding.decodePower(response.data))
    }

    /// Read SWR (standing wave ratio) meter.
    ///
    /// Returns the current SWR reading during transmission.
    ///
    /// **Command**: `0x15 0x12`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical, 0-255 scale)
    ///
    /// - Returns: SWR meter level (0=SWR 1.0, 48=SWR 1.5, 80=SWR 2.0, 120=SWR 3.0)
    /// - Throws: `RigError.invalidResponse` if response is malformed
    ///
    /// - Important: Only valid during transmission
    public func getSWRMeter() async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x15, 0x12],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        return UInt8(BCDEncoding.decodePower(response.data))
    }

    /// Read ALC (automatic level control) meter.
    ///
    /// Returns the current ALC reading during transmission.
    ///
    /// **Command**: `0x15 0x13`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical, 0-255 scale)
    ///
    /// - Returns: ALC meter level (0=minimum, 120=maximum)
    /// - Throws: `RigError.invalidResponse` if response is malformed
    ///
    /// - Important: Only valid during transmission
    public func getALCMeter() async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x15, 0x13],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        return UInt8(BCDEncoding.decodePower(response.data))
    }

    /// Read COMP (compression) meter.
    ///
    /// Returns the current speech compressor activity during transmission.
    ///
    /// **Command**: `0x15 0x14`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical, 0-255 scale)
    ///
    /// - Returns: COMP meter level (0=0dB, 130=15dB, 241=30dB compression)
    /// - Throws: `RigError.invalidResponse` if response is malformed
    ///
    /// - Important: Only valid during SSB/AM transmission with compressor enabled
    public func getCOMPMeter() async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x15, 0x14],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        return UInt8(BCDEncoding.decodePower(response.data))
    }

    /// Read Vd (supply voltage) meter.
    ///
    /// Returns the current DC supply voltage.
    ///
    /// **Command**: `0x15 0x15`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical, 0-255 scale)
    ///
    /// - Returns: Voltage meter level (0=0V, 13=10V, 241=16V)
    /// - Throws: `RigError.invalidResponse` if response is malformed
    public func getVDMeter() async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x15, 0x15],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        return UInt8(BCDEncoding.decodePower(response.data))
    }

    /// Read Id (supply current) meter.
    ///
    /// Returns the current DC supply current draw.
    ///
    /// **Command**: `0x15 0x16`
    ///
    /// **Radios**: IC-7100, IC-7600, IC-9700 (identical, 0-255 scale)
    ///
    /// - Returns: Current meter level (0=0A, 97=10A, 146=15A, 241=25A)
    /// - Throws: `RigError.invalidResponse` if response is malformed
    public func getIDMeter() async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [0x15, 0x16],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 2 else {
            throw RigError.invalidResponse
        }
        return UInt8(BCDEncoding.decodePower(response.data))
    }

}
