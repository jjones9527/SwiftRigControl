import Foundation

extension IcomCIVProtocol {

    // MARK: - Function Settings (IC-7100 Specific, NOT in common)

    /// Set AGC (IC-7100)
    /// Command: 0x16 0x12 [AGC code]
    /// Codes: 0x01=FAST, 0x02=MID, 0x03=SLOW
    public func setAGCIC7100(_ code: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setAGCIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x12],
            data: [code]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("AGC command rejected")
        }
    }

    /// Read AGC setting (IC-7100)
    public func getAGCIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getAGCIC7100 is only available on IC-7100")
        }
        return try await getFunctionIC7100(0x12)
    }

    /// Set monitor function (IC-7100)
    /// Command: 0x16 0x45 [MON code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setMonitorIC7100(_ enabled: Bool) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setMonitorIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x45],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Monitor command rejected")
        }
    }

    /// Read monitor function setting (IC-7100)
    public func getMonitorIC7100() async throws -> Bool {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getMonitorIC7100 is only available on IC-7100")
        }
        let value = try await getFunctionIC7100(0x45)
        return value == 0x01
    }

    /// Set break-in function (IC-7100)
    /// Command: 0x16 0x47 [BK-IN code]
    /// Codes: 0x00=OFF, 0x01=Semi BK-IN, 0x02=Full BK-IN
    public func setBreakInIC7100(_ code: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setBreakInIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x47],
            data: [code]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Break-in command rejected")
        }
    }

    /// Read break-in function setting (IC-7100)
    public func getBreakInIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getBreakInIC7100 is only available on IC-7100")
        }
        return try await getFunctionIC7100(0x47)
    }

    /// Set manual notch (IC-7100)
    /// Command: 0x16 0x48 [notch code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setManualNotchIC7100(_ enabled: Bool) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setManualNotchIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x48],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Manual notch command rejected")
        }
    }

    /// Read manual notch setting (IC-7100)
    public func getManualNotchIC7100() async throws -> Bool {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getManualNotchIC7100 is only available on IC-7100")
        }
        let value = try await getFunctionIC7100(0x48)
        return value == 0x01
    }

    /// Set DTCS (IC-7100 specific)
    /// Command: 0x16 0x4B [DTCS code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setDTCSIC7100(_ enabled: Bool) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setDTCSIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x4B],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("DTCS command rejected")
        }
    }

    /// Read DTCS setting (IC-7100)
    public func getDTCSIC7100() async throws -> Bool {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getDTCSIC7100 is only available on IC-7100")
        }
        let value = try await getFunctionIC7100(0x4B)
        return value == 0x01
    }

    /// Set VSC (Voice Squelch Control) - IC-7100 specific
    /// Command: 0x16 0x4C [VSC code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setVSCIC7100(_ enabled: Bool) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setVSCIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x4C],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("VSC command rejected")
        }
    }

    /// Read VSC setting (IC-7100)
    public func getVSCIC7100() async throws -> Bool {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getVSCIC7100 is only available on IC-7100")
        }
        let value = try await getFunctionIC7100(0x4C)
        return value == 0x01
    }

    /// Set twin peak filter (IC-7100)
    /// Command: 0x16 0x4F [TPF code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setTwinPeakFilterIC7100(_ enabled: Bool) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setTwinPeakFilterIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x4F],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Twin peak filter command rejected")
        }
    }

    /// Read twin peak filter setting (IC-7100)
    public func getTwinPeakFilterIC7100() async throws -> Bool {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getTwinPeakFilterIC7100 is only available on IC-7100")
        }
        let value = try await getFunctionIC7100(0x4F)
        return value == 0x01
    }

    /// Set dial lock (IC-7100)
    /// Command: 0x16 0x50 [lock code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setDialLockIC7100(_ enabled: Bool) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setDialLockIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x50],
            data: [enabled ? 0x01 : 0x00]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Dial lock command rejected")
        }
    }

    /// Read dial lock setting (IC-7100)
    public func getDialLockIC7100() async throws -> Bool {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getDialLockIC7100 is only available on IC-7100")
        }
        let value = try await getFunctionIC7100(0x50)
        return value == 0x01
    }

    /// Set DSP filter type (IC-7100)
    /// Command: 0x16 0x56 [filter code]
    /// Codes: 0x00=SHARP, 0x01=SOFT
    public func setDSPFilterTypeIC7100(_ code: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setDSPFilterTypeIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x56],
            data: [code]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("DSP filter type command rejected")
        }
    }

    /// Read DSP filter type setting (IC-7100)
    public func getDSPFilterTypeIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getDSPFilterTypeIC7100 is only available on IC-7100")
        }
        return try await getFunctionIC7100(0x56)
    }

    /// Set manual notch width (IC-7100)
    /// Command: 0x16 0x57 [width code]
    /// Codes: 0x00=WIDE, 0x01=MID, 0x02=NAR
    public func setManualNotchWidthIC7100(_ code: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setManualNotchWidthIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x57],
            data: [code]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Manual notch width command rejected")
        }
    }

    /// Read manual notch width setting (IC-7100)
    public func getManualNotchWidthIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getManualNotchWidthIC7100 is only available on IC-7100")
        }
        return try await getFunctionIC7100(0x57)
    }

    /// Set SSB transmit bandwidth (IC-7100)
    /// Command: 0x16 0x58 [bandwidth code]
    /// Codes: 0x00=WIDE, 0x01=MID, 0x02=NAR
    public func setSSBTransmitBandwidthIC7100(_ code: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setSSBTransmitBandwidthIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x58],
            data: [code]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("SSB transmit bandwidth command rejected")
        }
    }

    /// Read SSB transmit bandwidth setting (IC-7100)
    public func getSSBTransmitBandwidthIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getSSBTransmitBandwidthIC7100 is only available on IC-7100")
        }
        return try await getFunctionIC7100(0x58)
    }

    /// Set DSQL/CSQL (DV mode only) - IC-7100 specific
    /// Command: 0x16 0x5B [squelch code]
    /// Codes: 0x00=OFF, 0x01=DSQL ON, 0x02=CSQL ON
    public func setDigitalSquelchIC7100(_ code: UInt8) async throws {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("setDigitalSquelchIC7100 is only available on IC-7100")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x5B],
            data: [code]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Digital squelch command rejected")
        }
    }

    /// Read DSQL/CSQL setting (DV mode only) (IC-7100)
    public func getDigitalSquelchIC7100() async throws -> UInt8 {
        guard radioModel == .ic7100 else {
            throw RigError.unsupportedOperation("getDigitalSquelchIC7100 is only available on IC-7100")
        }
        return try await getFunctionIC7100(0x5B)
    }

}
