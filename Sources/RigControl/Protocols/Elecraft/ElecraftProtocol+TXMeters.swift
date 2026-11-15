import Foundation

extension ElecraftProtocol: SupportsTXMeters {
    /// K4 uses PO (Hamlib b7a9bfab7). K3/K3S use the selected bar graph
    /// and PC's range flag (Hamlib k3_get_bar_graph_level).
    public func getRFPowerOut() async throws -> MeterReading {
        try requireMeter(capabilities.supportsRFPowerMeter)
        if family == .kx { return try await readKXPower() }
        guard isK4 else { return try await readK3Power() }
        try await sendCommand("PO")
        let response = try await receiveResponse()
        let raw = try meterDigits(response, prefix: "PO", count: 4)
        return MeterReading(kind: .rfPower, raw: raw, normalized: Double(raw) / 1000,
                            physicalValue: Double(raw) / 10)
    }

    public func getSWR() async throws -> MeterReading {
        try requireMeter(capabilities.supportsSWRMeter)
        let raw: Int
        if isK4 {
            raw = try await readK4Meters().swr
        } else {
            try await sendCommand("SW")
            raw = try meterDigits(try await receiveResponse(), prefix: "SW", count: 3)
        }
        let ratio = Double(raw) / 10
        return MeterReading(kind: .swr, raw: raw,
                            normalized: min(max((ratio - 1) / 9, 0), 1), physicalValue: ratio)
    }

    public func getALC() async throws -> MeterReading {
        try requireMeter(capabilities.supportsALCMeter)
        if !isK4 {
            let graph = try await readK3BarGraph()
            guard graph.transmitting else {
                return MeterReading(kind: .alc, raw: 0, normalized: 0)
            }
            guard graph.isALC else {
                // Hamlib returns RIG_EINVAL when the requested meter is not selected.
                throw RigError.invalidParameter("Select the ALC meter to read K3 ALC")
            }
            return MeterReading(kind: .alc, raw: graph.raw, normalized: Double(graph.raw) / 7)
        }
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

    private func requireMeter(_ supported: Bool) throws {
        guard family != .k2, supported else {
            throw RigError.unsupportedOperation("TX meter is not implemented for this Elecraft")
        }
    }

    private func readKXPower() async throws -> MeterReading {
        // Hamlib kx3_get_level uses TQ/BG for normalized power and PO for watts.
        // These are separate measurements, not a single full-scale conversion.
        var normalized = 0.0
        if try await getTXStatus() {
            try await sendCommand("BG")
            let bars = try meterDigits(try await receiveResponse(), prefix: "BG", count: 2)
            switch bars {
            case 0...10: normalized = Double(bars) / 10
            case 12...22: normalized = Double(bars - 12) / 10
            default: throw RigError.invalidResponse
            }
        }
        // OM's P option indicates the KXPA100: PO is whole watts with it,
        // tenths of a watt without it. Read options here to avoid stale scaling.
        try await sendCommand("OM")
        let options = try await receiveResponse()
        guard options.hasPrefix("OM"), options.utf8.count == 15,
              options.utf8.allSatisfy({ $0 >= 32 && $0 <= 126 }) else {
            throw RigError.invalidResponse
        }
        try await sendCommand("PO")
        let raw = try meterDigits(try await receiveResponse(), prefix: "PO", count: 3)
        let watts = Double(raw) / (options.dropFirst(2).contains("P") ? 1 : 10)
        return MeterReading(kind: .rfPower, raw: raw, normalized: normalized, physicalValue: watts)
    }

    private func readK3Power() async throws -> MeterReading {
        let graph = try await readK3BarGraph()
        guard graph.transmitting else {
            return MeterReading(kind: .rfPower, raw: 0, normalized: 0, physicalValue: 0)
        }
        guard !graph.isALC else {
            throw RigError.invalidParameter("Select the power meter to read K3 RF power")
        }
        try await sendCommand("PC")
        let response = try await receiveResponse()
        let digits = response.dropFirst(2)
        guard response.hasPrefix("PC"), (3...4).contains(digits.utf8.count),
              digits.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) else {
            throw RigError.invalidResponse
        }
        var divisor = 10.0
        if digits.count == 4 {
            // K22 extended PCnnnx: x=0 is the low-power range, x=1 high.
            guard digits.last == "0" || digits.last == "1" else {
                throw RigError.invalidResponse
            }
            if digits.last == "0" { divisor = 100 }
        }
        let normalized = Double(graph.raw) / divisor
        return MeterReading(kind: .rfPower, raw: graph.raw, normalized: normalized,
                            physicalValue: normalized * 100)
    }

    private func readK3BarGraph() async throws -> (raw: Int, transmitting: Bool, isALC: Bool) {
        try await sendCommand("TM")
        let selection = try meterDigits(try await receiveResponse(), prefix: "TM", count: 1)
        guard selection == 0 || selection == 1 else { throw RigError.invalidResponse }
        try await sendCommand("BG")
        let response = try await receiveResponse()
        guard response.utf8.count == 5, let mode = response.last,
              mode == "R" || mode == "T" else {
            throw RigError.invalidResponse
        }
        let raw = try meterDigits(String(response.dropLast()), prefix: "BG", count: 2)
        let maximum = mode == "R" ? 21 : (selection == 1 ? 7 : 12)
        guard raw <= maximum else { throw RigError.invalidResponse }
        return (raw, mode == "T", selection == 1)
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
