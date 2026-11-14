import Foundation

extension KenwoodProtocol: SupportsTXMeters {
    public func getRFPowerOut() async throws -> MeterReading {
        try requireMeter(capabilities.supportsRFPowerMeter)
        // SM0 is an S-meter in receive. Unlike Hamlib's cached PTT check,
        // read IF here because this backend has no coherent PTT cache.
        try await sendCommand("IF")
        let status = Array(try await receiveResponse().utf8)
        guard status.count == 37, status.starts(with: "IF".utf8),
              status[28] == 48 || status[28] == 49 else {
            throw RigError.invalidResponse
        }
        guard status[28] == 49 else {
            return MeterReading(kind: .rfPower, raw: 0, normalized: 0, physicalValue: 0,
                                rfPowerIsCalibrated: levelProfile.txMeterStyle == .ts590)
        }
        try await sendCommand("SM0")
        let raw = try meterDigits(try await receiveResponse(), prefix: "SM0")
        let fullScale = levelProfile.txMeterStyle == .ts480 ? 20 : 30
        guard raw <= fullScale else { throw RigError.invalidResponse }
        if levelProfile.txMeterStyle != .ts590 {
            // Hamlib has no watts calibration for TS-480 or TS-2000.
            // The meter API targets the main receiver (SM0); it has no VFO-C selector.
            return MeterReading(kind: .rfPower, raw: raw, normalized: Double(raw) / Double(fullScale),
                                rfPowerIsCalibrated: false)
        }
        // Hamlib ts590_get_level uses distinct scales for the normalized
        // value and watts; do not derive one from the other.
        let watts = Self.ts590PowerCalibration.value(forRaw: raw)
        let roundedWatts = watts < 10 ? (watts * 10).rounded() / 10 : watts.rounded()
        return MeterReading(kind: .rfPower, raw: raw, normalized: Double(raw) / 30,
                            physicalValue: roundedWatts)
    }

    public func getSWR() async throws -> MeterReading {
        try requireMeter(capabilities.supportsSWRMeter)
        let raw = try await readMeter(number: 1)
        let calibration = levelProfile.txMeterStyle == .ts590 ? Self.ts590SWRCalibration : Self.ts480SWRCalibration
        let ratio = calibration.value(forRaw: raw)
        return MeterReading(kind: .swr, raw: raw,
                            normalized: min(max((ratio - 1) / 9, 0), 1), physicalValue: ratio)
    }

    public func getALC() async throws -> MeterReading {
        try requireMeter(capabilities.supportsALCMeter)
        let raw = try await readMeter(number: 3)
        // Hamlib allows up to 5: TS-590 uses 30/6; TS-480/2000 use 20/4.
        let divisor = levelProfile.txMeterStyle == .ts590 ? 6.0 : 4.0
        return MeterReading(kind: .alc, raw: raw, normalized: Double(raw) / divisor)
    }

    public func getComp() async throws -> MeterReading {
        try requireMeter(capabilities.supportsCompMeter)
        let raw = try await readMeter(number: 2)
        let fullScale = levelProfile.txMeterStyle == .ts590 ? 30.0 : 20.0
        return MeterReading(kind: .comp, raw: raw, normalized: Double(raw) / fullScale,
                            physicalValue: Double(raw))
    }

    public func getVoltage() async throws -> MeterReading {
        throw RigError.unsupportedOperation("Voltage meter is not implemented for this Kenwood")
    }

    public func getCurrent() async throws -> MeterReading {
        throw RigError.unsupportedOperation("Current meter is not implemented for this Kenwood")
    }

    private func requireMeter(_ supported: Bool) throws {
        guard levelProfile.txMeterStyle != .none, supported else {
            throw RigError.unsupportedOperation("TX meter is not implemented for this Kenwood")
        }
    }

    private func readMeter(number: Int) async throws -> Int {
        if levelProfile.txMeterStyle == .ts2000 {
            try await sendCommand("RM")
            let response = try await receiveResponse()
            guard response.utf8.count == 7, response.hasPrefix("RM"),
                  let selection = response.dropFirst(2).first,
                  let selectedMeter = Int(String(selection)), (1...3).contains(selectedMeter) else {
                throw RigError.invalidResponse
            }
            let raw = try meterDigits(response, prefix: "RM" + String(selection))
            guard raw <= 20 else { throw RigError.invalidResponse }
            // ts2000_read_meter returns zero for an unselected meter;
            // do not change the front-panel selection as a side effect of reading.
            return selectedMeter == number ? raw : 0
        }
        let values = try await readTripleMeters()
        switch number {
        case 1: return values.swr
        case 2: return values.comp
        default: return values.alc
        }
    }

    private func readTripleMeters() async throws -> (swr: Int, comp: Int, alc: Int) {
        try await sendCommand("RM")
        // Consume all three frames before validating any field so a bad
        // field does not leave two replies queued for the next command.
        let swrReply = try await receiveResponse()
        let compReply = try await receiveResponse()
        let alcReply = try await receiveResponse()
        let swr = try meterDigits(swrReply, prefix: "RM1")
        let comp = try meterDigits(compReply, prefix: "RM2")
        let alc = try meterDigits(alcReply, prefix: "RM3")
        let fullScale = levelProfile.txMeterStyle == .ts590 ? 30 : 20
        guard swr <= fullScale, comp <= fullScale, alc <= fullScale else { throw RigError.invalidResponse }
        return (swr, comp, alc)
    }

    private func meterDigits(_ response: String, prefix: String) throws -> Int {
        let digits = response.dropFirst(prefix.count)
        guard response.hasPrefix(prefix), digits.utf8.count == 4,
              digits.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
              let value = Int(digits) else {
            throw RigError.invalidResponse
        }
        return value
    }

    // TS480_SWR_CAL and TS2000_SWR_CAL are identical.
    private static let ts480SWRCalibration = FloatCalibrationTable([
        (0, 1), (4, 1.5), (8, 2), (12, 3), (20, 10)
    ])
    private static let ts590SWRCalibration = FloatCalibrationTable([
        (0, 1), (6, 1.5), (12, 2), (18, 3), (30, 10)
    ])
    private static let ts590PowerCalibration = FloatCalibrationTable([
        (0, 0), (3, 5), (6, 10), (8, 15), (12, 25), (17, 50), (30, 100)
    ])
}
