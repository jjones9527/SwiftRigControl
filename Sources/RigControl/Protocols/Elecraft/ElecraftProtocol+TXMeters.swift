import Foundation

extension ElecraftProtocol: SupportsTXMeters {
    /// K4 PO reports tenths of a watt in both power ranges.
    /// Hamlib b7a9bfab7: one PO query, with no TM or power-range query.
    public func getRFPowerOut() async throws -> MeterReading {
        try requireK4Meter(capabilities.supportsRFPowerMeter)
        try await sendCommand("PO")
        let response = try await receiveResponse()
        let raw = try meterDigits(response, prefix: "PO", count: 4)
        return MeterReading(kind: .rfPower, raw: raw, normalized: Double(raw) / 1000,
                            physicalValue: Double(raw) / 10)
    }

    public func getSWR() async throws -> MeterReading {
        try requireK4Meter(capabilities.supportsSWRMeter)
        let values = try await readK4Meters()
        let ratio = Double(values.swr) / 10
        return MeterReading(kind: .swr, raw: values.swr,
                            normalized: min(max((ratio - 1) / 9, 0), 1), physicalValue: ratio)
    }

    public func getALC() async throws -> MeterReading {
        try requireK4Meter(capabilities.supportsALCMeter)
        let values = try await readK4Meters()
        // Hamlib k4_get_bar_graph_level returns the ALC field directly.
        return MeterReading(kind: .alc, raw: values.alc, normalized: Double(values.alc))
    }

    public func getComp() async throws -> MeterReading {
        throw RigError.unsupportedOperation("Compression meter is not implemented for this Elecraft")
    }

    public func getVoltage() async throws -> MeterReading {
        throw RigError.unsupportedOperation("Voltage meter is not implemented for this Elecraft")
    }

    public func getCurrent() async throws -> MeterReading {
        throw RigError.unsupportedOperation("Current meter is not implemented for this Elecraft")
    }

    private func requireK4Meter(_ supported: Bool) throws {
        guard cwMessageForm == .k4, supported else {
            throw RigError.unsupportedOperation("TX meter is not implemented for this Elecraft")
        }
    }

    private func readK4Meters() async throws -> (alc: Int, swr: Int) {
        try await sendCommand("TM")
        let response = try await receiveResponse()
        // TM has four three-digit fields: ALC, compression, forward power, SWR.
        _ = try meterDigits(response, prefix: "TM", count: 12)
        let digits = response.dropFirst(2)
        guard let alc = Int(digits.prefix(3)), let swr = Int(digits.suffix(3)) else {
            throw RigError.invalidResponse
        }
        return (alc, swr)
    }

    private func meterDigits(_ response: String, prefix: String, count: Int) throws -> Int {
        let digits = response.dropFirst(prefix.count)
        guard response.hasPrefix(prefix), digits.utf8.count == count,
              digits.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
              let value = Int(digits) else {
            throw RigError.invalidResponse
        }
        return value
    }
}
