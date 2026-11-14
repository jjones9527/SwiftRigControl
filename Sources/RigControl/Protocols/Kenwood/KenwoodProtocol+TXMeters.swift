import Foundation

extension KenwoodProtocol: SupportsTXMeters {
    public func getRFPowerOut() async throws -> MeterReading {
        try requireTS590Meter(capabilities.supportsRFPowerMeter)
        // SM0 is an S-meter in receive. Unlike Hamlib's cached PTT check,
        // read IF here because this backend has no coherent PTT cache.
        try await sendCommand("IF")
        let status = Array(try await receiveResponse().utf8)
        guard status.count == 37, status.starts(with: "IF".utf8),
              status[28] == 48 || status[28] == 49 else {
            throw RigError.invalidResponse
        }
        guard status[28] == 49 else {
            return MeterReading(kind: .rfPower, raw: 0, normalized: 0, physicalValue: 0)
        }
        try await sendCommand("SM0")
        let raw = try meterDigits(try await receiveResponse(), prefix: "SM0")
        guard raw <= 30 else { throw RigError.invalidResponse }
        // Hamlib ts590_get_level uses distinct scales for the normalized
        // value and watts; do not derive one from the other.
        let watts = Self.ts590PowerCalibration.value(forRaw: raw)
        let roundedWatts = watts < 10 ? (watts * 10).rounded() / 10 : watts.rounded()
        return MeterReading(kind: .rfPower, raw: raw, normalized: Double(raw) / 30,
                            physicalValue: roundedWatts)
    }

    public func getSWR() async throws -> MeterReading {
        try requireTS590Meter(capabilities.supportsSWRMeter)
        let raw = try await readTS590Meters().swr
        let ratio = Self.ts590SWRCalibration.value(forRaw: raw)
        return MeterReading(kind: .swr, raw: raw,
                            normalized: min(max((ratio - 1) / 9, 0), 1), physicalValue: ratio)
    }

    public func getALC() async throws -> MeterReading {
        try requireTS590Meter(capabilities.supportsALCMeter)
        let raw = try await readTS590Meters().alc
        // Hamlib allows up to 5 here (30 / 6), rather than clamping to 1.
        return MeterReading(kind: .alc, raw: raw, normalized: Double(raw) / 6)
    }

    public func getComp() async throws -> MeterReading {
        try requireTS590Meter(capabilities.supportsCompMeter)
        let raw = try await readTS590Meters().comp
        return MeterReading(kind: .comp, raw: raw, normalized: Double(raw) / 30,
                            physicalValue: Double(raw))
    }

    public func getVoltage() async throws -> MeterReading {
        throw RigError.unsupportedOperation("Voltage meter is not implemented for this Kenwood")
    }

    public func getCurrent() async throws -> MeterReading {
        throw RigError.unsupportedOperation("Current meter is not implemented for this Kenwood")
    }

    private func requireTS590Meter(_ supported: Bool) throws {
        guard levelProfile.txMeterStyle == .ts590, supported else {
            throw RigError.unsupportedOperation("TX meter is not implemented for this Kenwood")
        }
    }

    private func readTS590Meters() async throws -> (swr: Int, comp: Int, alc: Int) {
        try await sendCommand("RM")
        // Consume all three frames before validating any field so a bad
        // field does not leave two replies queued for the next command.
        let swrReply = try await receiveResponse()
        let compReply = try await receiveResponse()
        let alcReply = try await receiveResponse()
        let swr = try meterDigits(swrReply, prefix: "RM1")
        let comp = try meterDigits(compReply, prefix: "RM2")
        let alc = try meterDigits(alcReply, prefix: "RM3")
        guard swr <= 30, comp <= 30, alc <= 30 else { throw RigError.invalidResponse }
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

    private static let ts590SWRCalibration = FloatCalibrationTable([
        (0, 1), (6, 1.5), (12, 2), (18, 3), (30, 10)
    ])
    private static let ts590PowerCalibration = FloatCalibrationTable([
        (0, 0), (3, 5), (6, 10), (8, 15), (12, 25), (17, 50), (30, 100)
    ])
}
