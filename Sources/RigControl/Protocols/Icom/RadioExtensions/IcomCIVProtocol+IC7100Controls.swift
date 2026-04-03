import Foundation

extension IcomCIVProtocol {

    // MARK: - Level Controls (IC-7100 Specific, NOT in common)

    /// Set inner Twin PBT position (0-255) (IC-7100)
    /// Command: 0x14 0x07 [position BCD]
    /// Position: 0=Cut higher, 128=center, 255=Cut lower
    public func setInnerPBTIC7100(_ position: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setInnerPBTIC7100 is only available on IC-7100")
        }
        let bcdPosition = BCDEncoding.encodePower(Int(position))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x07],
            data: bcdPosition
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Inner PBT command rejected")
        }
    }

    /// Read inner Twin PBT position (IC-7100)
    public func getInnerPBTIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getInnerPBTIC7100 is only available on IC-7100")
        }
        let value = try await getLevelIC7100(0x07)
        return UInt8(value)
    }

    /// Set outer Twin PBT position (0-255) (IC-7100)
    /// Command: 0x14 0x08 [position BCD]
    public func setOuterPBTIC7100(_ position: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setOuterPBTIC7100 is only available on IC-7100")
        }
        let bcdPosition = BCDEncoding.encodePower(Int(position))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x08],
            data: bcdPosition
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Outer PBT command rejected")
        }
    }

    /// Read outer Twin PBT position (IC-7100)
    public func getOuterPBTIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getOuterPBTIC7100 is only available on IC-7100")
        }
        let value = try await getLevelIC7100(0x08)
        return UInt8(value)
    }

    /// Set notch position (0-255) (IC-7100)
    /// Command: 0x14 0x0D [position BCD]
    /// Position: 0=lowest, 128=center, 255=highest
    public func setNotchPositionIC7100(_ position: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setNotchPositionIC7100 is only available on IC-7100")
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

    /// Read notch position (IC-7100)
    public func getNotchPositionIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getNotchPositionIC7100 is only available on IC-7100")
        }
        let value = try await getLevelIC7100(0x0D)
        return UInt8(value)
    }

    /// Set compression level (0-255) (IC-7100)
    /// Command: 0x14 0x0E [level BCD]
    /// Level: 0=0, 255=10
    public func setCompLevelIC7100(_ level: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setCompLevelIC7100 is only available on IC-7100")
        }
        let bcdLevel = BCDEncoding.encodePower(Int(level))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x0E],
            data: bcdLevel
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Compression level command rejected")
        }
    }

    /// Read compression level (IC-7100)
    public func getCompLevelIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getCompLevelIC7100 is only available on IC-7100")
        }
        let value = try await getLevelIC7100(0x0E)
        return UInt8(value)
    }

    /// Set break-in delay (0-255) (IC-7100)
    /// Command: 0x14 0x0F [delay BCD]
    /// Delay: 0=2.0d, 255=13.0d
    public func setBreakInDelayIC7100(_ delay: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setBreakInDelayIC7100 is only available on IC-7100")
        }
        let bcdDelay = BCDEncoding.encodePower(Int(delay))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x0F],
            data: bcdDelay
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Break-in delay command rejected")
        }
    }

    /// Read break-in delay (IC-7100)
    public func getBreakInDelayIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getBreakInDelayIC7100 is only available on IC-7100")
        }
        let value = try await getLevelIC7100(0x0F)
        return UInt8(value)
    }

    /// Set NB level (0-255) (IC-7100)
    /// Command: 0x14 0x12 [level BCD]
    public func setNBLevelIC7100(_ level: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setNBLevelIC7100 is only available on IC-7100")
        }
        let bcdLevel = BCDEncoding.encodePower(Int(level))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x12],
            data: bcdLevel
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("NB level command rejected")
        }
    }

    /// Read NB level (IC-7100)
    public func getNBLevelIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getNBLevelIC7100 is only available on IC-7100")
        }
        let value = try await getLevelIC7100(0x12)
        return UInt8(value)
    }

    /// Set monitor gain (0-255) (IC-7100)
    /// Command: 0x14 0x15 [gain BCD]
    public func setMonitorGainIC7100(_ gain: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setMonitorGainIC7100 is only available on IC-7100")
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

    /// Read monitor gain (IC-7100)
    public func getMonitorGainIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getMonitorGainIC7100 is only available on IC-7100")
        }
        let value = try await getLevelIC7100(0x15)
        return UInt8(value)
    }

    /// Set VOX gain (0-255) (IC-7100)
    /// Command: 0x14 0x16 [gain BCD]
    public func setVoxGainIC7100(_ gain: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setVoxGainIC7100 is only available on IC-7100")
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

    /// Read VOX gain (IC-7100)
    public func getVoxGainIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getVoxGainIC7100 is only available on IC-7100")
        }
        let value = try await getLevelIC7100(0x16)
        return UInt8(value)
    }

    /// Set anti-VOX gain (0-255) (IC-7100)
    /// Command: 0x14 0x17 [gain BCD]
    public func setAntiVoxGainIC7100(_ gain: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setAntiVoxGainIC7100 is only available on IC-7100")
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

    /// Read anti-VOX gain (IC-7100)
    public func getAntiVoxGainIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getAntiVoxGainIC7100 is only available on IC-7100")
        }
        let value = try await getLevelIC7100(0x17)
        return UInt8(value)
    }

    /// Set LCD contrast (0-255) (IC-7100)
    /// Command: 0x14 0x18 [contrast BCD]
    public func setLCDContrastIC7100(_ contrast: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setLCDContrastIC7100 is only available on IC-7100")
        }
        let bcdContrast = BCDEncoding.encodePower(Int(contrast))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x18],
            data: bcdContrast
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("LCD contrast command rejected")
        }
    }

    /// Read LCD contrast (IC-7100)
    public func getLCDContrastIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getLCDContrastIC7100 is only available on IC-7100")
        }
        let value = try await getLevelIC7100(0x18)
        return UInt8(value)
    }

    /// Set LCD backlight (0-255) (IC-7100)
    /// Command: 0x14 0x19 [backlight BCD]
    public func setLCDBacklightIC7100(_ backlight: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setLCDBacklightIC7100 is only available on IC-7100")
        }
        let bcdBacklight = BCDEncoding.encodePower(Int(backlight))
        let frame = CIVFrame(
            to: civAddress,
            command: [0x14, 0x19],
            data: bcdBacklight
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("LCD backlight command rejected")
        }
    }

    /// Read LCD backlight (IC-7100)
    public func getLCDBacklightIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getLCDBacklightIC7100 is only available on IC-7100")
        }
        let value = try await getLevelIC7100(0x19)
        return UInt8(value)
    }

    // MARK: - Meter Readings (IC-7100 Specific, NOT in common)

    /// Read squelch status (IC-7100)
    /// Command: 0x15 0x01
    /// Returns: 0x00=closed, 0x01=open
    public func getSquelchStatusIC7100() async throws -> Bool {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getSquelchStatusIC7100 is only available on IC-7100")
        }
        return try await getReadLevelIC7100(0x01)
    }

    /// Read various SQL function status (IC-7100)
    /// Command: 0x15 0x05
    /// Returns: 0x00=closed, 0x01=open
    public func getVariousSQLStatusIC7100() async throws -> Bool {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getVariousSQLStatusIC7100 is only available on IC-7100")
        }
        return try await getReadLevelIC7100(0x05)
    }

    /// Read PO meter level (IC-7100)
    /// Command: 0x15 0x11
    /// Returns: 0000=0%, 0143=50%, 0213=100%
    public func getPOMeterLevelIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getPOMeterLevelIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x15, 0x11],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-7100 format: command=[15], data=[11, bcd_lo, bcd_hi]
        if response.command.count == 1 && response.data.count >= 3 {
            guard response.command[0] == 0x15, response.data[0] == 0x11 else {
                throw RigError.invalidResponse
            }
            let lo = response.data[1] & 0x0F
            let hi = (response.data[1] >> 4) * 10
            let hund = response.data[2] * 100
            return hund + hi + lo
        }
        // Fallback to standard format
        else if response.command.count >= 2 && response.data.count >= 2 {
            guard response.command[0] == 0x15, response.command[1] == 0x11 else {
                throw RigError.invalidResponse
            }
            let lo = response.data[0] & 0x0F
            let hi = (response.data[0] >> 4) * 10
            let hund = response.data[1] * 100
            return hund + hi + lo
        }
        else {
            throw RigError.invalidResponse
        }
    }


}
