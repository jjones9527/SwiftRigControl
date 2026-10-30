import Foundation

// rigctld `L` / `l` (set/get level) command dispatch. Extracted
// from `RigctldCommandHandler.swift` in the v1.2.4 structural
// refactor to keep the main handler file under the 500-line soft
// cap.
//
// Contains the two entry points (`setLevel`, `getLevel`) plus
// their `normalizeToUnitInterval` / `denormalizeFromUnitInterval`
// helpers. Methods are `internal` rather than `private` because
// they are called from `executeCommand` in the sibling file.

extension RigctldCommandHandler {

    // MARK: - Level Control

    /// Set a level value
    func setLevel(name: String, value: String, command: RigctldCommand) async throws -> RigctldResponse {
        let normalized = name.uppercased()

        switch normalized {
        case "AF":
            // AF gain: Hamlib uses 0.0-1.0 float, we use 0-255
            guard let floatVal = RigctldDecimal.parseUnitInterval(value) else {
                throw RigError.invalidParameter("Invalid AF value: \(value)")
            }
            let level = Int(floatVal * 255.0)
            try await rigController.setAFGain(min(max(level, 0), 255))
            return .ok(command: command)

        case "RF":
            // RF gain: Hamlib uses 0.0-1.0 float, we use 0-255
            guard let floatVal = RigctldDecimal.parseUnitInterval(value) else {
                throw RigError.invalidParameter("Invalid RF value: \(value)")
            }
            let level = Int(floatVal * 255.0)
            try await rigController.setRFGain(min(max(level, 0), 255))
            return .ok(command: command)

        case "SQL":
            // Squelch: Hamlib uses 0.0-1.0 float, we use 0-255
            guard let floatVal = RigctldDecimal.parseUnitInterval(value) else {
                throw RigError.invalidParameter("Invalid SQL value: \(value)")
            }
            let level = Int(floatVal * 255.0)
            try await rigController.setSquelch(min(max(level, 0), 255))
            return .ok(command: command)

        case "PREAMP":
            // Hamlib RIG_LEVEL_PREAMP is a value from the model's preamp
            // list (dB on Icom HF: `L PREAMP 10` on an IC-7600). 0 is off;
            // anything else selects stage = 1-based position in the list,
            // and a value not in the list is RIG_EINVAL (icom.c:3650-3675,
            // kenwood.c:3591-3613, newcat.c:4457-4474). Through v1.3.1 we
            // read it as the stage number, so `L PREAMP 10` failed.
            // Radios with no preampLevels keep the stage reading.
            guard let requested = Int(value) else {
                throw RigError.invalidParameter("Invalid PREAMP value: \(value)")
            }
            try await rigController.setPreamp(try preampStage(forHamlibValue: requested))
            return .ok(command: command)

        case "ATT":
            // Attenuator: dB value (0=off, 6=6dB, 10=10dB, etc.)
            guard let dB = Int(value) else {
                throw RigError.invalidParameter("Invalid ATT value: \(value)")
            }
            try await rigController.setAttenuator(dB)
            return .ok(command: command)

        case "RFPOWER":
            // RF output power: Hamlib uses 0.0-1.0 normalized float, minimum 0.05
            guard let floatVal = RigctldDecimal.parseUnitInterval(value) else {
                throw RigError.invalidParameter("Invalid RFPOWER value: \(value)")
            }
            let caps = await rigController.capabilities
            // Hamlib enforces a 0.05 minimum — radios reject 0W
            let normalized = max(0.05, min(1.0, floatVal))
            // Convert to the radio's own unit. Through v1.3.1 this always
            // sent watts, which CI-V radios read as a percentage: 0.5 on a
            // 200 W IC-7851 asked for "100%", full power, and 1.0 on a
            // 10 W IC-705 asked for 10%. Hamlib sends fraction × 255 on
            // every Icom (icom.c:3558).
            switch caps.powerUnits {
            case .percentage:
                try await rigController.setPower(Int((normalized * 100).rounded()))
            case .watts:
                let watts = Int(normalized * Double(caps.maxPower))
                try await rigController.setPower(min(max(watts, 0), caps.maxPower))
            }
            return .ok(command: command)

        case "AGC":
            // Hamlib CI-V AGC codes: OFF=0, SUPERFAST=1, FAST=2, SLOW=3, USER=4, MID=5, AUTO=6
            // Also accept string names for convenience
            let agcSpeed: AGCSpeed
            switch value {
            case "0", "OFF":
                agcSpeed = .off
            case "1", "SUPERFAST", "2", "FAST":
                agcSpeed = .fast
            case "3", "SLOW":
                agcSpeed = .slow
            case "5", "MID", "MEDIUM":
                agcSpeed = .medium
            case "6", "AUTO":
                agcSpeed = .auto
            default:
                throw RigError.invalidParameter("Invalid AGC value: \(value)")
            }

            try await rigController.setAGC(agcSpeed)
            return .ok(command: command)

        case "NB":
            // Hamlib RIG_LEVEL_NB is a float 0.0-1.0 (rig.h). Through
            // v1.3.1 this parsed an integer 0-255, so a Hamlib client's
            // `L NB 0.5` failed. 0 turns the blanker off; our API can't
            // set the level without enabling it.
            guard let floatVal = RigctldDecimal.parseUnitInterval(value) else {
                throw RigError.invalidParameter("Invalid NB value: \(value)")
            }
            let level = Int((floatVal * 255.0).rounded())
            try await rigController.setNoiseBlanker(level == 0 ? .off : .enabled(level: level))
            return .ok(command: command)

        case "NR":
            // Hamlib RIG_LEVEL_NR is a float 0.0-1.0 (rig.h); same
            // history and caveat as NB.
            guard let floatVal = RigctldDecimal.parseUnitInterval(value) else {
                throw RigError.invalidParameter("Invalid NR value: \(value)")
            }
            let level = Int((floatVal * 255.0).rounded())
            try await rigController.setNoiseReduction(level == 0 ? .off : .enabled(level: level))
            return .ok(command: command)

        case "IF", "VOXDELAY":
            // Hamlib RIG_LEVEL_IF is IF shift in +/-Hz and VOXDELAY is
            // tenths of a second (rig.h). Our setIFShift / setVOXDelay
            // take a per-radio-scaled 0-100, and we don't model each
            // radio's physical range, so we can't honor Hamlib's units.
            // Through v1.3.1 "IF" set the IF *filter* and VOXDELAY
            // expected 0.0-1.0; both misread real Hamlib clients.
            return .error(.notSupported, command: command)

        case "IFFILTER":
            // Parse IF filter value - 1=FIL1, 2=FIL2, 3=FIL3
            guard let filterNum = Int(value) else {
                throw RigError.invalidParameter("Invalid IF filter value: \(value)")
            }

            guard let filter = IFFilter(rawValue: UInt8(filterNum)) else {
                throw RigError.invalidParameter("IF filter must be 1, 2, or 3, got \(filterNum)")
            }

            try await rigController.setIFFilter(filter)
            return .ok(command: command)

        // CW levels (Phase 4.5)
        case "KEYSPD":
            guard let wpm = Int(value) else {
                throw RigError.invalidParameter("Invalid KEYSPD value: \(value)")
            }
            try await rigController.setCWSpeed(CWSpeed(wpm: wpm))
            return .ok(command: command)

        case "CWPITCH":
            guard let hz = Int(value) else {
                throw RigError.invalidParameter("Invalid CWPITCH value: \(value)")
            }
            try await rigController.setCWPitch(CWPitch(hz: hz))
            return .ok(command: command)

        // v1.1 secondary levels (Hamlib: 0.0-1.0 float).
        case "MICGAIN":
            let v = try parseFloatLevel(value, name: "MICGAIN")
            try await rigController.setMicGain(v)
            return .ok(command: command)

        case "COMP":
            let v = try parseFloatLevel(value, name: "COMP")
            try await rigController.setCompressorLevel(v)
            return .ok(command: command)

        case "MONITOR_GAIN":
            let v = try parseFloatLevel(value, name: "MONITOR_GAIN")
            try await rigController.setMonitorGain(v)
            return .ok(command: command)

        case "VOXGAIN":
            let v = try parseFloatLevel(value, name: "VOXGAIN")
            try await rigController.setVOXGain(v)
            return .ok(command: command)

        case "IF_SHIFT":
            // Note: Hamlib's RIG_LEVEL_IF token "IF" is already
            // claimed above for IF filter selection. We expose
            // IF *shift* under a distinct token to avoid the
            // collision.
            let v = try parseFloatLevel(value, name: "IF_SHIFT")
            try await rigController.setIFShift(v)
            return .ok(command: command)

        default:
            return .error(.notImplemented, command: command)
        }
    }

    /// Get a level value
    func getLevel(name: String, command: RigctldCommand) async throws -> RigctldResponse {
        let normalized = name.uppercased()

        switch normalized {
        case "AF":
            // AF gain: return 0.0-1.0 float (Hamlib convention)
            let level = try await rigController.afGain()
            return RigctldResponse(value: String(format: "%.6f", Double(level) / 255.0), command: command)

        case "RF":
            // RF gain: return 0.0-1.0 float
            let level = try await rigController.rfGain()
            return RigctldResponse(value: String(format: "%.6f", Double(level) / 255.0), command: command)

        case "SQL":
            // Squelch: return 0.0-1.0 float
            let level = try await rigController.squelch()
            return RigctldResponse(value: String(format: "%.6f", Double(level) / 255.0), command: command)

        case "PREAMP":
            // The list value for the current stage (0 = off), as Hamlib
            // reports it; the bare stage on radios without preampLevels.
            let stage = try await rigController.preamp()
            let levels = await rigController.capabilities.preampLevels
            let reported = stage > 0 && stage <= levels.count ? levels[stage - 1] : stage
            return RigctldResponse(value: String(reported), command: command)

        case "ATT":
            // Attenuator: return dB value
            let dB = try await rigController.attenuator()
            return RigctldResponse(value: String(dB), command: command)

        case "RFPOWER":
            // RF output power: return 0.0-1.0 normalized float, minimum 0.05
            let level = try await rigController.power()
            let caps = await rigController.capabilities
            let fullScale: Int
            switch caps.powerUnits {
            case .percentage: fullScale = 100
            case .watts: fullScale = caps.maxPower
            }
            let normalized = Double(level) / Double(fullScale)
            return RigctldResponse(value: String(format: "%.6f", min(max(normalized, 0.05), 1.0)), command: command)

        case "AGC":
            let agc = try await rigController.agc()
            // Return Hamlib CI-V AGC codes: OFF=0, FAST=2, SLOW=3, MID=5, AUTO=6
            let value: String
            switch agc {
            case .off:    value = "0"
            case .fast:   value = "2"
            case .slow:   value = "3"
            case .medium: value = "5"
            case .auto:   value = "6"
            }
            return RigctldResponse(value: value, command: command)

        case "NB":
            // Hamlib float 0.0-1.0; an enabled blanker without a level
            // reads as full scale.
            let level: Int
            switch try await rigController.noiseBlanker() {
            case .off: level = 0
            case .enabled(let value): level = value ?? 255
            }
            return RigctldResponse(value: String(format: "%.6f", Double(level) / 255.0), command: command)

        case "NR":
            let level: Int
            switch try await rigController.noiseReduction() {
            case .off: level = 0
            case .enabled(let value): level = value
            }
            return RigctldResponse(value: String(format: "%.6f", Double(level) / 255.0), command: command)

        // Hamlib RIG_LEVEL_STRENGTH: calibrated dB relative to S9
        // (S9 = 0, S0 = -54). RAWSTR: the radio's raw reading. Through
        // v1.3.1 neither was implemented, so WSJT-X / fldigi S-meter
        // polls got `RPRT -4`.
        case "STRENGTH":
            let strength = try await rigController.signalStrength(cached: false)
            let dB = strength.calibratedDBRelativeToS9 ?? (strength.decibels - 54)
            return RigctldResponse(value: String(dB), command: command)

        case "RAWSTR":
            let strength = try await rigController.signalStrength(cached: false)
            return RigctldResponse(value: String(strength.raw), command: command)

        case "IF", "VOXDELAY":
            // See setLevel: Hamlib's Hz / tenths-of-a-second units can't
            // be honored.
            return .error(.notSupported, command: command)

        case "IFFILTER":
            let filter = try await rigController.ifFilter()
            // Map IFFilter to numeric value: 1=FIL1, 2=FIL2, 3=FIL3
            let value = String(filter.rawValue)
            return RigctldResponse(value: value, command: command)

        // MARK: TX meters (Phase 4.5)
        // Hamlib expects floats per the RIG_LEVEL_* spec in
        // include/hamlib/rig.h. We return six-digit precision and
        // honor each meter's documented range.

        case "SWR":
            let reading = try await rigController.swr()
            // Hamlib: SWR is the X:1 ratio as a float ≥ 1.0.
            let ratio = reading.swrRatio ?? 1.0
            return RigctldResponse(value: String(format: "%.6f", ratio), command: command)

        case "ALC":
            let reading = try await rigController.alc()
            return RigctldResponse(value: String(format: "%.6f", reading.normalized), command: command)

        case "RFPOWER_METER":
            // Fraction of max output, 0.0…1.0.
            let reading = try await rigController.rfPowerOut()
            return RigctldResponse(value: String(format: "%.6f", reading.normalized), command: command)

        case "RFPOWER_METER_WATTS":
            // Actual watts (Hamlib's RFPOWER_METER_WATTS).
            let reading = try await rigController.rfPowerOut()
            let watts = reading.watts ?? 0
            return RigctldResponse(value: String(format: "%.6f", watts), command: command)

        case "COMP_METER":
            let reading = try await rigController.comp()
            // Hamlib expects dB (float).
            let dB = reading.dB ?? 0
            return RigctldResponse(value: String(format: "%.6f", dB), command: command)

        case "VD_METER":
            let reading = try await rigController.voltage()
            let v = reading.volts ?? 0
            return RigctldResponse(value: String(format: "%.6f", v), command: command)

        case "ID_METER":
            let reading = try await rigController.current()
            let a = reading.amps ?? 0
            return RigctldResponse(value: String(format: "%.6f", a), command: command)

        // MARK: CW levels (Phase 4.5)

        case "KEYSPD":
            let speed = try await rigController.cwSpeed()
            return RigctldResponse(value: String(speed.wpm), command: command)

        case "CWPITCH":
            let pitch = try await rigController.cwPitch()
            return RigctldResponse(value: String(pitch.hz), command: command)

        // v1.1 secondary levels (return Hamlib 0.0-1.0 float).
        case "MICGAIN":
            return floatResponse(try await rigController.micGain(), command: command)
        case "COMP":
            return floatResponse(try await rigController.compressorLevel(), command: command)
        case "MONITOR_GAIN":
            return floatResponse(try await rigController.monitorGain(), command: command)
        case "VOXGAIN":
            return floatResponse(try await rigController.voxGain(), command: command)
        case "IF_SHIFT":
            return floatResponse(try await rigController.ifShift(), command: command)

        default:
            return .error(.notImplemented, command: command)
        }
    }

    // MARK: - Level helpers (v1.1)

    /// Hamlib level values arrive as floats in [0.0, 1.0]. Our
    /// secondary-level API uses Int in [0, 100]. Map and clamp.
    func parseFloatLevel(_ raw: String, name: String) throws -> Int {
        guard let v = RigctldDecimal.parseUnitInterval(raw) else {
            throw RigError.invalidParameter("Invalid \(name) value: \(raw)")
        }
        return min(max(Int((v * 100.0).rounded()), 0), 100)
    }

    /// Formats an Int in [0, 100] as the Hamlib 0.0-1.0 float.
    func floatResponse(_ value: Int, command: RigctldCommand) -> RigctldResponse {
        RigctldResponse(value: String(format: "%.6f", Double(value) / 100.0), command: command)
    }

    /// The preamp stage for a Hamlib `L PREAMP` value: 0 is off, otherwise
    /// the value's 1-based position in ``RigCapabilities/preampLevels``.
    /// Without a list, the value is taken as the stage.
    func preampStage(forHamlibValue value: Int) async throws -> Int {
        let levels = await rigController.capabilities.preampLevels
        guard value != 0, !levels.isEmpty else { return value }
        guard let index = levels.firstIndex(of: value) else {
            throw RigError.invalidParameter("PREAMP \(value) is not one of \(levels)")
        }
        return index + 1
    }

}
