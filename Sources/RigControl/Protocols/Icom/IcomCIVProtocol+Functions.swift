import Foundation

// MARK: - Function toggles (v1.1 parity)
//
// CI-V command map, cross-checked against Hamlib
// `rigs/icom/icom.c::icom_set_func` (lines 7056-7355) and
// `icom_defs.h` (S_FUNC_* constants):
//
//   0x16 sub-cmd family (C_CTL_FUNC):
//     0x32 — S_FUNC_APF    audio peak filter
//     0x41 — S_FUNC_ANF    auto notch filter
//     0x42 — S_FUNC_TONE   CTCSS tone encode
//     0x43 — S_FUNC_TSQL   CTCSS tone squelch
//     0x44 — S_FUNC_COMP   speech compressor
//     0x45 — S_FUNC_MON    sidetone monitor
//     0x46 — S_FUNC_VOX    voice-operated TX
//     0x48 — S_FUNC_MN     manual notch
//     0x4A — S_FUNC_AFC    auto frequency control
//     0x50 — S_FUNC_DIAL_LK lock
//     0x5A — S_MEM_SATMODE satellite mode (non-IC-910H)
//     0x59 — S_MEM_DUALMODE dual watch (IC-9100/9700/ID-5100)
//
//   0x1C 0x01 — antenna tuner enable (data byte 0x00/0x01;
//     0x02 starts a tune cycle — that's `VFOOperation.tune`).
//
//   0x27 0x10 — spectrum scope on/off (data is status, not
//     0x00/0x01).
//
// Per-radio support is gated by `capabilities.supportedFunctions`
// — RigController checks it before calling, so this code assumes
// the function is valid for the radio.

extension IcomCIVProtocol {

    public func setFunction(_ function: RigFunction, enabled: Bool) async throws {
        let payload = UInt8(enabled ? 0x01 : 0x00)
        let (command, data) = try icomWireCommand(for: function, write: true, payload: payload)
        let frame = CIVFrame(to: civAddress, command: command, data: data)
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed(
                "Radio rejected setFunction '\(function.rawValue)'"
            )
        }
    }

    public func getFunction(_ function: RigFunction) async throws -> Bool {
        let (command, _) = try icomWireCommand(for: function, write: false, payload: nil)
        let frame = CIVFrame(to: civAddress, command: command, data: [])
        try await sendFrame(frame)
        let response = try await receiveFrame()
        // Response echoes the command bytes followed by the data
        // byte. For 0x16 family the data byte is at index 2 of
        // the combined command+data payload.
        let combined = response.command + response.data
        guard let last = combined.last else {
            throw RigError.invalidResponse
        }
        return last != 0x00
    }

    /// Returns the (command, data) pair for the wire frame.
    /// `write == true` includes the on/off payload; `write ==
    /// false` returns the command bytes only, suitable for a
    /// query.
    private func icomWireCommand(
        for function: RigFunction,
        write: Bool,
        payload: UInt8?
    ) throws -> (command: [UInt8], data: [UInt8]) {
        let payloadBytes: [UInt8] = write && payload != nil ? [payload!] : []

        switch function {
        case .compressor:
            return ([0x16, 0x44], payloadBytes)
        case .vox:
            return ([0x16, 0x46], payloadBytes)
        case .ctcssTone:
            return ([0x16, 0x42], payloadBytes)
        case .ctcssSquelch:
            return ([0x16, 0x43], payloadBytes)
        case .lock:
            return ([0x16, 0x50], payloadBytes)
        case .tuner:
            // 0x1C 0x01 — same command as VFOOperation.tune but
            // with 0x00/0x01 data byte (enable/disable) rather
            // than 0x02 (start tune cycle).
            return ([0x1C, 0x01], payloadBytes)
        case .autoNotch:
            return ([0x16, 0x41], payloadBytes)
        case .manualNotch:
            return ([0x16, 0x48], payloadBytes)
        case .monitor:
            return ([0x16, 0x45], payloadBytes)
        case .autoFrequencyControl:
            return ([0x16, 0x4A], payloadBytes)
        case .satelliteMode:
            // Most modern radios use 0x16 0x5A. The IC-910H uses
            // 0x1A 0x07 — we'd need a radioModel switch here for
            // that legacy case. Modeling the IC-910H quirk is
            // deferred until we ship a definition for it.
            return ([0x16, 0x5A], payloadBytes)
        case .dualWatch:
            // IC-9100/IC-9700/ID-5100 use 0x16 0x59. Older
            // dual-VFO Icoms use 0x07 0xC0/0xC1/0xC2 — same
            // deferral note as satelliteMode applies.
            return ([0x16, 0x59], payloadBytes)
        case .audioPeakFilter:
            return ([0x16, 0x32], payloadBytes)
        case .voiceSquelch:
            // Hamlib RIG_FUNC_VSC — Icom S_FUNC_VSC 0x4D.
            return ([0x16, 0x4D], payloadBytes)
        case .scope:
            return ([0x27, 0x10], payloadBytes)
        case .scanResume:
            // RIG_FUNC_RESUME uses dedicated sub-commands rather
            // than an on/off payload: 0x0E 0xD3 (on) / 0x0E 0xD0
            // (off). Special-cased here so callers see a uniform
            // setFunction API.
            return ([0x0E, write ? (payload == 0x01 ? 0xD3 : 0xD0) : 0xD3], [])
        case .reverseSplit, .mute, .beatCancel, .noiseBlanker2, .diversity:
            // No Icom CI-V equivalent. Surface this as an
            // explicit unsupported even when the caller has set
            // the capability flag — the protocol is the
            // authoritative source on what wire commands exist.
            throw RigError.unsupportedOperation(
                "Function '\(function.rawValue)' has no Icom CI-V equivalent"
            )
        }
    }
}
