import Foundation

/// IC-9700 meter readings and function settings
///
/// This extension contains meter readings and function control commands for the IC-9700.
/// See `IcomCIVProtocol+IC9700.swift` for memory, scan, attenuator/preamp, voice synthesizer,
/// and level controls. See `IcomCIVProtocol+IC9700Advanced.swift` for power control,
/// satellite mode, VFO operations, and helper methods.
extension IcomCIVProtocol {

    // MARK: - Meter Readings (IC-9700 Specific)

    /// Read squelch status (IC-9700)
    /// Command: 0x15 0x01
    /// Returns: 0x00=closed, 0x01=open
    public func getSquelchStatusIC9700() async throws -> Bool {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getSquelchStatusIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x15, 0x01],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    /// Read PO meter level (IC-9700)
    /// Command: 0x15 0x11
    public func getPOMeterLevelIC9700() async throws -> UInt8 {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getPOMeterLevelIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x15, 0x11],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-9700 uses IC-7100 format: subcommand echoed in data field
        if response.command.count == 1 && response.data.count >= 3 {
            guard response.command[0] == 0x15, response.data[0] == 0x11 else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(Array(response.data[1...])))
        } else if response.command.count >= 2 && response.data.count >= 2 {
            // Fallback to standard format
            guard response.command[0] == 0x15, response.command[1] == 0x11 else {
                throw RigError.invalidResponse
            }
            return UInt8(BCDEncoding.decodePower(response.data))
        } else {
            throw RigError.invalidResponse
        }
    }

    // MARK: - Function Settings (IC-9700 Specific)

    /// Set AGC (IC-9700)
    /// Command: 0x16 0x12 [AGC code]
    /// Codes: 0x00=OFF, 0x01=FAST, 0x02=MID, 0x03=SLOW
    public func setAGCIC9700(_ code: UInt8) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setAGCIC9700 is only available on IC-9700")
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

    /// Read AGC setting (IC-9700)
    public func getAGCIC9700() async throws -> UInt8 {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getAGCIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x12],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // Debug logging
        print("DEBUG [getAGCIC9700]: Response received")
        print("  Command bytes: \(response.command.map { String(format: "0x%02X", $0) }.joined(separator: " "))")
        print("  Data bytes: \(response.data.map { String(format: "0x%02X", $0) }.joined(separator: " "))")
        print("  Command count: \(response.command.count), Data count: \(response.data.count)")

        // IC-9700 returns: command=[0x16], data=[0x12, value]
        // The subcommand is in the data field, not command field!
        guard response.command.count == 1,
              response.command[0] == 0x16,
              response.data.count == 2,
              response.data[0] == 0x12 else {
            print("  ERROR: Invalid response format")
            throw RigError.invalidResponse
        }
        return response.data[1]  // Value is second byte in data
    }

    /// Set monitor function (IC-9700)
    /// Command: 0x16 0x45 [MON code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setMonitorIC9700(_ enabled: Bool) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setMonitorIC9700 is only available on IC-9700")
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

    /// Read monitor function setting (IC-9700)
    public func getMonitorIC9700() async throws -> Bool {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getMonitorIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x45],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // Debug logging
        print("DEBUG [getMonitorIC9700]: Response received")
        print("  Command bytes: \(response.command.map { String(format: "0x%02X", $0) }.joined(separator: " "))")
        print("  Data bytes: \(response.data.map { String(format: "0x%02X", $0) }.joined(separator: " "))")
        print("  Command count: \(response.command.count), Data count: \(response.data.count)")

        // IC-9700 returns: command=[0x16], data=[0x45, value]
        // The subcommand is in the data field, not command field!
        guard response.command.count == 1,
              response.command[0] == 0x16,
              response.data.count == 2,
              response.data[0] == 0x45 else {
            print("  ERROR: Invalid response format")
            throw RigError.invalidResponse
        }
        return response.data[1] == 0x01  // Value is second byte in data
    }

    /// Set manual notch (IC-9700)
    /// Command: 0x16 0x48 [notch code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setManualNotchIC9700(_ enabled: Bool) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setManualNotchIC9700 is only available on IC-9700")
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

    /// Read manual notch setting (IC-9700)
    public func getManualNotchIC9700() async throws -> Bool {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getManualNotchIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x48],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // Debug logging
        print("DEBUG [getManualNotchIC9700]: Response received")
        print("  Command bytes: \(response.command.map { String(format: "0x%02X", $0) }.joined(separator: " "))")
        print("  Data bytes: \(response.data.map { String(format: "0x%02X", $0) }.joined(separator: " "))")
        print("  Command count: \(response.command.count), Data count: \(response.data.count)")

        // IC-9700 returns: command=[0x16], data=[0x48, value]
        // The subcommand is in the data field, not command field!
        guard response.command.count == 1,
              response.command[0] == 0x16,
              response.data.count == 2,
              response.data[0] == 0x48 else {
            print("  ERROR: Invalid response format")
            throw RigError.invalidResponse
        }
        return response.data[1] == 0x01  // Value is second byte in data
    }

    /// Set dial lock (IC-9700)
    /// Command: 0x16 0x50 [lock code]
    /// Codes: 0x00=OFF, 0x01=ON
    public func setDialLockIC9700(_ enabled: Bool) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setDialLockIC9700 is only available on IC-9700")
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

    /// Read dial lock setting (IC-9700)
    public func getDialLockIC9700() async throws -> Bool {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getDialLockIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x50],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // Debug logging
        print("DEBUG [getDialLockIC9700]: Response received")
        print("  Command bytes: \(response.command.map { String(format: "0x%02X", $0) }.joined(separator: " "))")
        print("  Data bytes: \(response.data.map { String(format: "0x%02X", $0) }.joined(separator: " "))")
        print("  Command count: \(response.command.count), Data count: \(response.data.count)")

        // IC-9700 returns: command=[0x16], data=[0x50, value]
        // The subcommand is in the data field, not command field!
        guard response.command.count == 1,
              response.command[0] == 0x16,
              response.data.count == 2,
              response.data[0] == 0x50 else {
            print("  ERROR: Invalid response format")
            throw RigError.invalidResponse
        }
        return response.data[1] == 0x01  // Value is second byte in data
    }

    /// Set DSQL/CSQL (DV mode only) - IC-9700 specific
    /// Command: 0x16 0x5B [squelch code]
    /// Codes: 0x00=OFF, 0x01=DSQL ON, 0x02=CSQL ON
    public func setDigitalSquelchIC9700(_ code: UInt8) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("setDigitalSquelchIC9700 is only available on IC-9700")
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

    /// Read DSQL/CSQL setting (DV mode only) (IC-9700)
    public func getDigitalSquelchIC9700() async throws -> UInt8 {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("getDigitalSquelchIC9700 is only available on IC-9700")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [0x16, 0x5B],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count >= 2, response.data.count == 1 else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }
}
