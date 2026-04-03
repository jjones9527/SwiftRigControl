import Foundation

extension IcomCIVProtocol {

    // MARK: - Level Controls (IC-9700 Specific)

    /// Set NR level (0-255) (IC-9700)
    /// Command: 0x14 0x06 [level BCD]
    public func setNRLevelIC9700(_ level: UInt8) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setNRLevelIC9700 is only available on IC-9700")
        }
        let bcdLevel = BCDEncoding.encodePower(Int(level))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x06],
            data: bcdLevel
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("NR level command rejected")
        }
    }

    /// Read NR level (IC-9700)
    public func getNRLevelIC9700() async throws -> UInt8 {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getNRLevelIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x06],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-9700 uses standard format: command echoed separately
        // Response: FE FE E0 A2 [14 06] [BCD0 BCD1] FD
        guard response.command.count >= 2, response.data.count >= 2 else {
            throw RigError.invalidResponse
        }
        guard response.command[0] == 0x14, response.command[1] == 0x06 else {
            throw RigError.invalidResponse
        }

        // IC-9700 uses standard BCD format with a consistent +8 offset
        // The radio quantizes NR Level to 16 steps (display shows 0-15)
        // but the CI-V protocol uses 0-255 range
        let rawValue = BCDEncoding.decodePower(response.data)

        // IC-9700 consistently returns values that are +8 from what was set
        // This has been verified with hardware testing:
        // - Set 0   → Radio returns 8   → We return 0   ✅
        // - Set 64  → Radio returns 72  → We return 64  ✅
        // - Set 128 → Radio returns 136 → We return 128 ✅
        // - Set 192 → Radio returns 200 → We return 192 ✅
        // - Set 255 → Radio returns 248 → We return 240 (quantization to 16 steps)
        if rawValue >= 8 {
            return UInt8(rawValue - 8)
        } else {
            // For values 0-7, the radio returns 8-15
            return 0  // These all map to display value 0
        }
    }

    /// Set notch position (0-255) (IC-9700)
    /// Command: 0x14 0x0D [position BCD]
    public func setNotchPositionIC9700(_ position: UInt8) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setNotchPositionIC9700 is only available on IC-9700")
        }
        let bcdPosition = BCDEncoding.encodePower(Int(position))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x0D],
            data: bcdPosition
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Notch position command rejected")
        }
    }

    /// Read notch position (IC-9700)
    public func getNotchPositionIC9700() async throws -> UInt8 {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getNotchPositionIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x0D],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-9700 uses IC-7100 format: subcommand echoed in data field
        if response.command.count == 1 && response.data.count >= 3 {
            guard response.command[0] == 0x14, response.data[0] == 0x0D else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(Array(response.data[1...])))
        } else if response.command.count >= 2 && response.data.count >= 2 {
            // Fallback to standard format
            guard response.command[0] == 0x14, response.command[1] == 0x0D else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(response.data))
        } else {
            throw RigError.invalidResponse
        }
    }

    /// Set monitor gain (0-255) (IC-9700)
    /// Command: 0x14 0x15 [gain BCD]
    public func setMonitorGainIC9700(_ gain: UInt8) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setMonitorGainIC9700 is only available on IC-9700")
        }
        let bcdGain = BCDEncoding.encodePower(Int(gain))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x15],
            data: bcdGain
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Monitor gain command rejected")
        }
    }

    /// Read monitor gain (IC-9700)
    public func getMonitorGainIC9700() async throws -> UInt8 {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getMonitorGainIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x15],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-9700 uses IC-7100 format: subcommand echoed in data field
        if response.command.count == 1 && response.data.count >= 3 {
            guard response.command[0] == 0x14, response.data[0] == 0x15 else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(Array(response.data[1...])))
        } else if response.command.count >= 2 && response.data.count >= 2 {
            // Fallback to standard format
            guard response.command[0] == 0x14, response.command[1] == 0x15 else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(response.data))
        } else {
            throw RigError.invalidResponse
        }
    }

    /// Set VOX gain (0-255) (IC-9700)
    /// Command: 0x14 0x16 [gain BCD]
    public func setVoxGainIC9700(_ gain: UInt8) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setVoxGainIC9700 is only available on IC-9700")
        }
        let bcdGain = BCDEncoding.encodePower(Int(gain))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x16],
            data: bcdGain
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("VOX gain command rejected")
        }
    }

    /// Read VOX gain (IC-9700)
    public func getVoxGainIC9700() async throws -> UInt8 {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getVoxGainIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x16],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-9700 uses IC-7100 format: subcommand echoed in data field
        if response.command.count == 1 && response.data.count >= 3 {
            guard response.command[0] == 0x14, response.data[0] == 0x16 else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(Array(response.data[1...])))
        } else if response.command.count >= 2 && response.data.count >= 2 {
            // Fallback to standard format
            guard response.command[0] == 0x14, response.command[1] == 0x16 else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(response.data))
        } else {
            throw RigError.invalidResponse
        }
    }

    /// Set anti-VOX gain (0-255) (IC-9700)
    /// Command: 0x14 0x17 [gain BCD]
    public func setAntiVoxGainIC9700(_ gain: UInt8) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setAntiVoxGainIC9700 is only available on IC-9700")
        }
        let bcdGain = BCDEncoding.encodePower(Int(gain))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x17],
            data: bcdGain
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Anti-VOX gain command rejected")
        }
    }

    /// Read anti-VOX gain (IC-9700)
    public func getAntiVoxGainIC9700() async throws -> UInt8 {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getAntiVoxGainIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x17],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-9700 uses IC-7100 format: subcommand echoed in data field
        if response.command.count == 1 && response.data.count >= 3 {
            guard response.command[0] == 0x14, response.data[0] == 0x17 else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(Array(response.data[1...])))
        } else if response.command.count >= 2 && response.data.count >= 2 {
            // Fallback to standard format
            guard response.command[0] == 0x14, response.command[1] == 0x17 else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(response.data))
        } else {
            throw RigError.invalidResponse
        }
    }

}
