import Foundation

// MARK: - TX meters
//
// Hamlib `newcat_get_level` (newcat.c:5317-5432 for the commands,
// 5617-5750 for the replies): each meter is an `RM` read, and the first
// three digits of the reply go through the model's calibration table
// (Quirks.meterCalibration, generated from Hamlib by
// Scripts/hamlib-meter-cal.py).
//
//   meter     RM (FTDX-9000)   value
//   SWR       RM6 (RM09)       ratio
//   ALC       RM4 (RM07)       0...1
//   power     RM5 (RM08)       watts; Hamlib's RFPOWER_METER is watts / 100
//   COMP      RM3 (RM06)       dB
//   voltage   RM8 (RM11)       volts
//   current   RM7 (RM10)       amps
//
// The FTDX-3000/5000 read SWR on RM2 when the tuner is on and the meter
// is set to SWR (newcat.c:5327-5345); we always use RM6, Hamlib's
// choice otherwise.

extension YaesuCATProtocol: SupportsTXMeters {

    public func getRFPowerOut() async throws -> MeterReading {
        try requireMeter(capabilities.supportsRFPowerMeter, "RF power")
        let raw = try await readMeter(single: 5, ftdx9000: 8)
        var watts = quirks.meterCalibration.rfPower.value(forRaw: raw)
        if quirks.halvesRFPowerMeter { watts /= 2 }
        return MeterReading(kind: .rfPower, raw: raw, normalized: min(watts / 100, 1), physicalValue: watts)
    }

    public func getSWR() async throws -> MeterReading {
        try requireMeter(capabilities.supportsSWRMeter, "SWR")
        let raw = try await readMeter(single: 6, ftdx9000: 9)
        let ratio = quirks.meterCalibration.swr.value(forRaw: raw)
        return MeterReading(kind: .swr, raw: raw, normalized: min(max((ratio - 1) / 9, 0), 1), physicalValue: ratio)
    }

    public func getALC() async throws -> MeterReading {
        try requireMeter(capabilities.supportsALCMeter, "ALC")
        let raw = try await readMeter(single: 4, ftdx9000: 7)
        let value = quirks.meterCalibration.alc.value(forRaw: raw)
        return MeterReading(kind: .alc, raw: raw, normalized: value, physicalValue: value)
    }

    public func getComp() async throws -> MeterReading {
        try requireMeter(capabilities.supportsCompMeter, "compression")
        let raw = try await readMeter(single: 3, ftdx9000: 6)
        let dB = quirks.meterCalibration.comp.value(forRaw: raw)
        return MeterReading(kind: .comp, raw: raw, normalized: min(dB / 30, 1), physicalValue: dB)
    }

    public func getVoltage() async throws -> MeterReading {
        try requireMeter(capabilities.supportsVoltageMeter, "voltage")
        let raw = try await readMeter(single: 8, ftdx9000: 11)
        let volts = quirks.meterCalibration.voltage.value(forRaw: raw)
        return MeterReading(kind: .voltage, raw: raw, normalized: min(volts / 16, 1), physicalValue: volts)
    }

    public func getCurrent() async throws -> MeterReading {
        try requireMeter(capabilities.supportsCurrentMeter, "current")
        let raw = try await readMeter(single: 7, ftdx9000: 10)
        let amps = quirks.meterCalibration.current.value(forRaw: raw)
        return MeterReading(kind: .current, raw: raw, normalized: min(amps / 25, 1), physicalValue: amps)
    }

    private func requireMeter(_ supported: Bool, _ name: String) throws {
        guard supported else {
            throw RigError.unsupportedOperation("\(name) meter not supported by this radio")
        }
    }

    /// Sends the `RM` read and returns the first three digits of the
    /// value (some radios, the FTDX-101 among them, send six).
    private func readMeter(single: Int, ftdx9000: Int) async throws -> Int {
        let query = quirks.usesTwoDigitMeterNumbers ? String(format: "RM%02d", ftdx9000) : "RM\(single)"
        try await sendCommand(query)
        let response = try await receiveResponse()
        guard response.hasPrefix(query),
              let raw = Int(response.dropFirst(query.count).prefix(3)) else {
            throw RigError.invalidResponse
        }
        return raw
    }
}
