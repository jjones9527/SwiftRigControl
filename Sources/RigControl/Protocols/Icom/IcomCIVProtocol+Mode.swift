import Foundation

// MARK: - Mode Control
//
// Icom radios carry DATA modes (DATA-USB / -LSB / -FM) as a flag on top
// of the voice mode, not as separate mode codes. There are two ways to
// set and read that flag, chosen per radio as Hamlib does:
//
// - `0x26` (`C_SEND_SEL_MODE`) carries VFO, mode, DATA flag and filter in
//   one frame: `0x26 [vfo, mode, data, filter]`. Used for every mode on
//   radios whose command set sets `usesSelectedVFOModeCommand` (IC-7300,
//   IC-7300MK2), matching Hamlib `icom_set_mode_x26` /
//   `icom_get_mode_x26` (`icom.c:2246-2409`).
// - `0x06 [mode, filter]` followed by `0x1A 0x06 [data, filter]`, read
//   back with `0x04` then `0x1A 0x06`. Used on every other radio with
//   DATA support (`requiresDataModeSubCommand`), matching Hamlib
//   `icom_set_mode` / `icom_get_mode` (`icom.c:2416-2660`, `2843-2990`).
//
// Before v1.2.19, `getMode` never sent `0x1A 0x06` and treated a `0x04`
// filter byte of `0x00` as DATA. Modern Icoms report FIL1-3 there, so
// DATA modes always read back as voice modes. And the `0x26` frame
// omitted its VFO byte.

extension IcomCIVProtocol {

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        // Select the appropriate VFO first (if radio requires AND supports it)
        if capabilities.requiresVFOSelection, commandSet.selectVFOCommand(vfo) != nil {
            try await selectVFO(vfo)
        }

        let modeCode = try modeToIcomCode(mode)
        let isData = isDataMode(mode)

        if usesSelectedVFOModeCommandNow {
            // Every mode goes through 0x26 so that leaving a DATA mode
            // also clears the flag. Filter FIL1, as the 0x06 path sends.
            let frame = CIVFrame(
                to: civAddress,
                command: [CIVFrame.Command.targetableMode],
                data: [CIVFrame.selectedVFO, modeCode, isData ? 0x01 : 0x00,
                       CIVFrame.FilterCode.fil1]
            )
            try await sendFrame(frame)
            let response = try await receiveFrame()
            if response.isAck { return }
            guard response.isNak else {
                throw RigError.commandFailed("Radio rejected mode \(mode)")
            }
            // Firmware without 0x26: fall back for the rest of the
            // connection, as Hamlib does after a failed 0x26.
            selectedVFOModeCommandRejected = true
        }

        try await setModeWithDataModeFlag(mode, modeCode: modeCode, isData: isData)
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        // Select the appropriate VFO first (if radio requires AND supports it)
        if capabilities.requiresVFOSelection, commandSet.selectVFOCommand(vfo) != nil {
            try await selectVFO(vfo)
        }

        if usesSelectedVFOModeCommandNow {
            let frame = CIVFrame(
                to: civAddress,
                command: [CIVFrame.Command.targetableMode],
                data: [CIVFrame.selectedVFO]
            )
            try await sendFrame(frame)
            let response = try await receiveFrame()
            if response.isNak {
                selectedVFOModeCommandRejected = true
            } else {
                // 0x26 reply: [vfo, mode, data_flag, filter]
                guard response.command == [CIVFrame.Command.targetableMode],
                      response.data.count >= 3,
                      response.data[0] == CIVFrame.selectedVFO else {
                    throw RigError.invalidResponse
                }
                return try icomCodeToMode(response.data[1], isData: response.data[2] != 0x00)
            }
        }

        let frame = CIVFrame(to: civAddress, command: commandSet.readModeCommand())
        try await sendFrame(frame)
        let response = try await receiveFrame()
        let modeCode = try commandSet.parseModeResponse(response)

        guard usesDataModeFlagFrame else {
            // Radios without DATA sub-modes: keep the pre-v1.2.19
            // reading, where filter byte 0x00 marks the legacy
            // `0x06 [mode, 0x00]` DATA shorthand.
            let filterByte = response.data.count >= 2 ? response.data[1] : CIVFrame.FilterCode.fil1
            return try icomCodeToMode(modeCode, isData: filterByte == CIVFrame.FilterCode.data)
        }

        // Only these base modes have a DATA variant (icom.c:2904-2910).
        let dataCapable: Set<UInt8> = [
            CIVFrame.ModeCode.usb, CIVFrame.ModeCode.lsb,
            CIVFrame.ModeCode.fm, CIVFrame.ModeCode.am,
        ]
        guard dataCapable.contains(modeCode) else {
            return try icomCodeToMode(modeCode)
        }
        let flag = try await readDataModeFlag()
        return try icomCodeToMode(modeCode, isData: flag.dataMode != 0x00)
    }

    // MARK: - DATA flag helpers

    /// Whether `0x26` is in use for this connection.
    private var usesSelectedVFOModeCommandNow: Bool {
        commandSet.usesSelectedVFOModeCommand && !selectedVFOModeCommandRejected
    }

    /// Whether DATA is set with `0x06` + `0x1A 0x06` and read with
    /// `0x1A 0x06`: radios built that way, and `0x26` radios after a NAK.
    private var usesDataModeFlagFrame: Bool {
        commandSet.requiresDataModeSubCommand
            || (commandSet.usesSelectedVFOModeCommand && selectedVFOModeCommandRejected)
    }

    /// Sets the mode with `0x06`, then (on radios with DATA sub-modes)
    /// sets or clears the DATA flag with `0x1A 0x06`.
    private func setModeWithDataModeFlag(_ mode: Mode, modeCode: UInt8, isData: Bool) async throws {
        let flagFrame = usesDataModeFlagFrame

        // Radios with neither 0x26 nor 0x1A 0x06 keep the legacy
        // `0x06 [mode, 0x00]` shorthand from `setDataModeCommand`.
        let (command, data) = (isData && !flagFrame)
            ? commandSet.setDataModeCommand(mode: modeCode)
            : commandSet.setModeCommand(mode: modeCode)

        let frame = CIVFrame(to: civAddress, command: command, data: data)
        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected mode \(mode)")
        }

        guard flagFrame else { return }

        // The base mode set above only sets USB / LSB / FM; without this
        // follow-up the radio stays in voice mode even when DATA was
        // requested (and vice versa).
        //
        // When ENTERING a data mode: send [0x01, FIL1].
        // When LEAVING data mode (or setting any non-data mode):
        // both bytes MUST be 0 — per Hamlib `icom_set_mode`
        // (icom.c:2563): "the only good combo possible
        // according to manual". IC-7600 returns NAK otherwise.
        let dataModeFlag: UInt8 = isData ? 0x01 : 0x00
        let filterByte: UInt8   = isData ? CIVFrame.FilterCode.fil1 : 0x00
        let dataModeFrame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.advancedSettings, CIVFrame.AdvancedCode.dataMode],
            data: [dataModeFlag, filterByte]
        )
        try await sendFrame(dataModeFrame)
        let dataModeResponse = try await receiveFrame()
        guard dataModeResponse.isAck else {
            throw RigError.commandFailed("Radio rejected data mode flag for mode \(mode)")
        }
    }

    /// Reads the DATA flag with `0x1A 0x06`.
    ///
    /// `CIVFrame.parse` doesn't split a sub-command off `0x1A`, so the
    /// reply parses as command `[0x1A]`, data `[0x06, flag, filter]`.
    /// Some radios omit the filter byte (Hamlib accepts one or two value
    /// bytes, `icom.c:2933-2952`); it reads as `0x00` then.
    ///
    /// - Returns: The DATA flag (`0x00` off, `0x01`-`0x03` DATA1-3) and
    ///   the filter byte.
    internal func readDataModeFlag() async throws -> (dataMode: UInt8, filter: UInt8) {
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.advancedSettings, CIVFrame.AdvancedCode.dataMode]
        )
        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.command == [CIVFrame.Command.advancedSettings],
              response.data.count >= 2, response.data.count <= 3,
              response.data[0] == CIVFrame.AdvancedCode.dataMode else {
            throw RigError.invalidResponse
        }
        return (dataMode: response.data[1],
                filter: response.data.count == 3 ? response.data[2] : 0x00)
    }

    // MARK: - Mode code mapping

    /// Converts a Mode enum to an Icom mode code byte (CI-V command 0x06 first data byte).
    ///
    /// Data modes (DATA-USB, DATA-LSB, DATA-FM) share their mode byte with the equivalent
    /// voice mode; the DATA flag travels separately (see the top of this file).
    /// FM-Narrow also shares the FM mode byte; filter selection controls bandwidth.
    internal func modeToIcomCode(_ mode: Mode) throws -> UInt8 {
        switch mode {
        case .lsb:     return CIVFrame.ModeCode.lsb
        case .usb:     return CIVFrame.ModeCode.usb
        case .am:      return CIVFrame.ModeCode.am
        case .cw:      return CIVFrame.ModeCode.cw
        case .cwR:     return CIVFrame.ModeCode.cwR
        case .rtty:    return CIVFrame.ModeCode.rtty
        case .rttyR:   return CIVFrame.ModeCode.rttyR
        case .fm:      return CIVFrame.ModeCode.fm
        case .fmN:     return CIVFrame.ModeCode.fm   // FM-Narrow uses same code; filter controls bandwidth
        case .wfm:     return CIVFrame.ModeCode.wfm
        case .dataLSB: return CIVFrame.ModeCode.lsb  // DATA-LSB uses LSB mode code + filter byte 0x00
        case .dataUSB: return CIVFrame.ModeCode.usb  // DATA-USB uses USB mode code + filter byte 0x00
        case .dataFM:  return CIVFrame.ModeCode.fm   // DATA-FM  uses FM  mode code + filter byte 0x00
        }
    }

    /// Returns true for DATA-USB, DATA-LSB and DATA-FM.
    internal func isDataMode(_ mode: Mode) -> Bool {
        switch mode {
        case .dataLSB, .dataUSB, .dataFM: return true
        default: return false
        }
    }

    /// Converts an Icom mode code to a Mode enum.
    ///
    /// The `isData` flag comes from the `0x26` data byte, the `0x1A 0x06`
    /// DATA flag, or (on radios without DATA sub-modes) a `0x04` filter
    /// byte of `0x00`.
    internal func icomCodeToMode(_ code: UInt8, isData: Bool = false) throws -> Mode {
        switch code {
        case CIVFrame.ModeCode.lsb:
            return isData ? .dataLSB : .lsb
        case CIVFrame.ModeCode.usb:
            return isData ? .dataUSB : .usb
        case CIVFrame.ModeCode.am:
            return .am
        case CIVFrame.ModeCode.cw:
            return .cw
        case CIVFrame.ModeCode.cwR:
            return .cwR
        case CIVFrame.ModeCode.rtty:
            return .rtty
        case CIVFrame.ModeCode.rttyR:
            return .rttyR
        case CIVFrame.ModeCode.fm:
            return isData ? .dataFM : .fm
        case CIVFrame.ModeCode.wfm:
            return .wfm
        default:
            throw RigError.invalidResponse
        }
    }
}
