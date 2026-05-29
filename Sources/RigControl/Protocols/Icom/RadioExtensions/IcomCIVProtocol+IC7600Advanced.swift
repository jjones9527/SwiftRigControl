import Foundation

/// IC-7600 advanced settings, VFO extended commands, helper methods, and DATA mode control
///
/// This extension contains advanced IC-7600-specific commands.
/// See `IcomCIVProtocol+IC7600.swift` for memory, scan, attenuator/preamp, level controls,
/// meter readings, and function controls.
extension IcomCIVProtocol {

    // MARK: - Advanced Settings (IC-7600 Specific)

    /// Set filter width (IC-7600)
    /// Command: 0x1A 0x03 [filter index 0-49]
    public func setFilterWidthIC7600(_ index: UInt8) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setFilterWidthIC7600 is only available on IC-7600")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.advancedSettings, CIVFrame.AdvancedCode.filterWidth],
            data: [index]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Filter width command rejected")
        }
    }

    /// Read filter width (IC-7600)
    public func getFilterWidthIC7600() async throws -> UInt8 {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getFilterWidthIC7600 is only available on IC-7600")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.advancedSettings, CIVFrame.AdvancedCode.filterWidth],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-7600 uses IC-7100 format: subcommand echoed in data field
        if response.command.count == 1 && response.data.count >= 2 {
            // IC-7600/IC-7100 format: command=[1A], data=[03, value]
            guard response.command[0] == CIVFrame.Command.advancedSettings,
                  response.data[0] == CIVFrame.AdvancedCode.filterWidth else {
                throw RigError.invalidResponse
            }
            return response.data[1]
        } else if response.command.count >= 2 && !response.data.isEmpty {
            // Standard format: command=[1A, 03], data=[value]
            guard response.command[0] == CIVFrame.Command.advancedSettings,
                  response.command[1] == CIVFrame.AdvancedCode.filterWidth else {
                throw RigError.invalidResponse
            }
            return response.data[0]
        } else {
            throw RigError.invalidResponse
        }
    }

    /// Set AGC time constant (IC-7600).
    ///
    /// Command: `0x1A 0x04 [icom_level]`.
    ///
    /// **Valid `value` range on the IC-7600 is `1...3`** (FAST=1,
    /// MEDIUM=2, SLOW=3) per Hamlib `ic7600.c`'s `agc_levels`
    /// table. The wider 0–13 range available on the IC-7300/9700/705
    /// is NOT supported by the IC-7600 firmware and will be NAKed.
    /// Values outside `1...3` throw `commandFailed`.
    public func setAGCTimeConstantIC7600(_ value: UInt8) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setAGCTimeConstantIC7600 is only available on IC-7600")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.advancedSettings, CIVFrame.AdvancedCode.agcTimeConstant],
            data: [value]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("AGC time constant command rejected")
        }
    }

    /// Read AGC time constant (IC-7600)
    ///
    /// Real-hardware capture (2026-05-29) shows the reply as
    /// `FE FE E0 7A 1A 04 05 FD`. `CIVFrame.parse` does NOT treat
    /// `0x1A` as a "has sub-command" prefix (only 0x14/0x15/0x1C
    /// are in that list), so the split is
    /// `command=[0x1A], data=[0x04, value]`. Match against that
    /// shape rather than assuming a 2-byte command.
    public func getAGCTimeConstantIC7600() async throws -> UInt8 {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getAGCTimeConstantIC7600 is only available on IC-7600")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.advancedSettings, CIVFrame.AdvancedCode.agcTimeConstant],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.command.count == 1,
              response.command[0] == CIVFrame.Command.advancedSettings,
              response.data.count >= 2,
              response.data[0] == CIVFrame.AdvancedCode.agcTimeConstant else {
            throw RigError.invalidResponse
        }
        return response.data[1]
    }

    // MARK: - VFO Extended Commands (IC-7600 Specific)

    /// Exchange main/sub bands (IC-7600)
    /// Command: 0x07 0xB0
    public func exchangeBandsIC7600() async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("exchangeBandsIC7600 is only available on IC-7600")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.selectVFO],
            data: [CIVFrame.VFOSelect.exchangeBands]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Exchange bands rejected")
        }
    }

    /// Equalize main/sub bands (IC-7600)
    /// Command: 0x07 0xB1
    public func equalizeBandsIC7600() async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("equalizeBandsIC7600 is only available on IC-7600")
        }
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.selectVFO],
            data: [CIVFrame.VFOSelect.equalizeBands]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Equalize bands rejected")
        }
    }

    /// Set dualwatch (IC-7600)
    /// - Parameter enabled: true=ON, false=OFF
    public func setDualwatchIC7600(_ enabled: Bool) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setDualwatchIC7600 is only available on IC-7600")
        }
        let code = enabled ? CIVFrame.VFOSelect.dualwatchOn : CIVFrame.VFOSelect.dualwatchOff
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.selectVFO],
            data: [code]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Dualwatch command rejected")
        }
    }

    // MARK: - Miscellaneous Commands (IC-7600 Specific)

    /// Read band edge frequencies (IC-7600). **Currently unreliable —
    /// returns `.unsupportedOperation`.**
    ///
    /// Command: 0x02
    ///
    /// On the real IC-7600 (verified 2026-05-29), command 0x02
    /// returns a multi-segment payload that does NOT match the
    /// "single lower + single upper, 5-byte BCD each" layout this
    /// parser was written against. A real capture in USB mode at
    /// 14 MHz looked like:
    ///
    ///   FE FE E0 7A 02 00 00 03 00 00 2D 00 00 00 60 00 FD
    ///                  ^^ ^^^^^^^^^^^ ^^ ^^^^^^^^^^^ ^^
    ///                  seg0 lower(4)  seg2D upper(4) ?
    ///
    /// The freq fields appear to be 4-byte BCD rather than 5, and
    /// the response carries per-segment IDs. Hamlib defines
    /// `C_RD_BAND` but doesn't call it from any rig handler —
    /// likely for the same reason.
    ///
    /// Marked as unsupported pending an IC-7600 CI-V manual
    /// cross-check. PRs welcome.
    public func getBandEdgeIC7600() async throws -> (lower: UInt64, upper: UInt64) {
        throw RigError.unsupportedOperation(
            "Band edge read is not reliably parseable without an IC-7600 manual cross-check. See doc comment for the captured frame layout."
        )
    }

    // MARK: - Helper Methods (IC-7600 Specific)

    /// Set a level control value (IC-7600 internal helper)
    /// Command: 0x14 [sub-command] [value BCD]
    func setLevelIC7600(_ subCommand: UInt8, value: Int) async throws {
        let clampedValue = min(max(value, 0), 255)
        let bcd = BCDEncoding.encodePower(clampedValue)
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.settings, subCommand],
            data: bcd
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Level control command rejected")
        }
    }

    /// Read a level control value (IC-7600 internal helper)
    func getLevelIC7600(_ subCommand: UInt8) async throws -> Int {
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.settings, subCommand],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-7600 uses IC-7100 format: subcommand echoed in data field
        if response.command.count == 1 && response.data.count >= 3 {
            // IC-7600/IC-7100 format: command=[14], data=[subCommand, value_bcd...]
            guard response.command[0] == CIVFrame.Command.settings,
                  response.data[0] == subCommand else {
                throw RigError.invalidResponse
            }
            return BCDEncoding.decodePower(Array(response.data[1...]))
        } else if response.command.count >= 2 && response.data.count >= 2 {
            // Standard format: command=[14, subCommand], data=[value_bcd...]
            guard response.command[0] == CIVFrame.Command.settings,
                  response.command[1] == subCommand else {
                throw RigError.invalidResponse
            }
            return BCDEncoding.decodePower(response.data)
        } else {
            throw RigError.invalidResponse
        }
    }

    /// Set a function on/off or to a specific value (IC-7600 internal helper)
    /// Command: 0x16 [sub-command] [value]
    func setFunctionIC7600(_ subCommand: UInt8, value: UInt8) async throws {
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.function, subCommand],
            data: [value]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Function control command rejected")
        }
    }

    /// Read a function setting (IC-7600 internal helper)
    func getFunctionIC7600(_ subCommand: UInt8) async throws -> UInt8 {
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.function, subCommand],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        // IC-7600 may return subcommand in data field like IC-7100: command=[16], data=[subCommand value]
        // OR standard format: command=[16 subCommand], data=[value]

        if response.command.count == 1 && response.data.count == 2 {
            // IC-7600 format: subcommand in first data byte, value in second
            guard response.command[0] == CIVFrame.Command.function,
                  response.data[0] == subCommand else {
                throw RigError.invalidResponse
            }
            return response.data[1]
        } else if response.command.count >= 2 && response.data.count >= 1 {
            // Standard format: subcommand in command field
            guard response.command[0] == CIVFrame.Command.function,
                  response.command[1] == subCommand else {
                throw RigError.invalidResponse
            }
            return response.data[0]
        } else {
            throw RigError.invalidResponse
        }
    }

    // MARK: - DATA Mode Control (IC-7600 Specific)

    /// Set DATA mode and filter (IC-7600)
    /// Command: 0x1A 0x06 [data_mode][filter]
    ///
    /// - Parameters:
    ///   - dataMode: 0x00=OFF, 0x01=D1, 0x02=D2, 0x03=D3
    ///   - filter: 0x00=OFF, 0x01=FIL1, 0x02=FIL2, 0x03=FIL3
    public func setDataModeIC7600(dataMode: UInt8, filter: UInt8) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setDataModeIC7600 is only available on IC-7600")
        }
        guard dataMode <= 0x03 else {
            throw RigError.invalidParameter("Data mode must be 0x00-0x03")
        }
        guard filter <= 0x03 else {
            throw RigError.invalidParameter("Filter must be 0x00-0x03")
        }

        let frame = CIVFrame(
            to: civAddress,
            command: [0x1A, 0x06],
            data: [dataMode, filter]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("DATA mode command rejected")
        }
    }

    /// Get current DATA mode and filter setting (IC-7600)
    /// Returns tuple: (dataMode: 0x00-0x03, filter: 0x00-0x03)
    public func getDataModeIC7600() async throws -> (dataMode: UInt8, filter: UInt8) {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getDataModeIC7600 is only available on IC-7600")
        }

        let frame = CIVFrame(
            to: civAddress,
            command: [0x1A, 0x06],
            data: []
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.command.count >= 2,
              response.command[0] == 0x1A,
              response.command[1] == 0x06,
              response.data.count == 2 else {
            throw RigError.invalidResponse
        }

        return (dataMode: response.data[0], filter: response.data[1])
    }
}
