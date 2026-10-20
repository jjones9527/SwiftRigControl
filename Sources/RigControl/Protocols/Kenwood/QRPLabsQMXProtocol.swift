import Foundation

/// QRP Labs QMX CAT adapter.
///
/// QMX implements a TS-480-compatible subset for frequency, mode, VFO,
/// split, and PTT. Its `PC` and `SW` replies are model-specific physical
/// meter values, so this adapter delegates the shared CAT subset and decodes
/// those two commands exactly as Hamlib's QMX backend does.
public actor QRPLabsQMXProtocol: CATProtocol, SupportsSplit, SupportsTXMeters {
    public let transport: any SerialTransport
    public let capabilities: RigCapabilities

    private let kenwood: KenwoodProtocol
    private var powerFullScale = 6.0
    private static let terminator: UInt8 = 0x3B
    private static let timeout: TimeInterval = 1.0

    /// Creates a QMX adapter over the radio's USB serial transport.
    /// - Parameter transport: Openable transport connected to the QMX CAT port.
    public init(transport: any SerialTransport) {
        self.transport = transport
        self.capabilities = RadioCapabilitiesDatabase.QRPLabs.qmx
        self.kenwood = KenwoodProtocol(
            transport: transport,
            capabilities: RadioCapabilitiesDatabase.QRPLabs.qmx,
            modeStyle: .qmx
        )
    }

    public func connect() async throws {
        try await kenwood.connect()

        // Firmware with Menu Manager reports `MM6W` or `MM12W`. Older
        // firmware rejects this optional probe, for which Hamlib uses 6 W.
        if let response = try? await transact("MMDisplay/controls|Pwr/SWR display|Power fullscale"),
           response.hasPrefix("MM"),
           let value = Double(response.dropFirst(2).dropLast(response.hasSuffix("W") ? 1 : 0)),
           value > 0 {
            powerFullScale = value
        }
    }

    public func disconnect() async { await kenwood.disconnect() }

    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws {
        try await kenwood.setFrequency(hz, vfo: vfo)
    }

    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        try await kenwood.getFrequency(vfo: vfo)
    }

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        try await kenwood.setMode(mode, vfo: vfo)
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        try await kenwood.getMode(vfo: vfo)
    }

    public func setPTT(_ enabled: Bool) async throws { try await kenwood.setPTT(enabled) }
    public func getPTT() async throws -> Bool { try await kenwood.getPTT() }
    public func selectVFO(_ vfo: VFO) async throws { try await kenwood.selectVFO(vfo) }
    public func setSplit(_ enabled: Bool) async throws { try await kenwood.setSplit(enabled) }
    public func getSplit() async throws -> Bool { try await kenwood.getSplit() }

    public func getRFPowerOut() async throws -> MeterReading {
        let response = try await transact("PC")
        let tenths = try parseMeter(response, prefix: "PC")
        let watts = Double(tenths) / 10.0
        return MeterReading(kind: .rfPower, raw: tenths,
                            normalized: watts / powerFullScale,
                            physicalValue: watts)
    }

    public func getSWR() async throws -> MeterReading {
        let response = try await transact("SW")
        let hundredths = try parseMeter(response, prefix: "SW")
        let ratio = Double(hundredths) / 100.0
        return MeterReading(kind: .swr, raw: hundredths,
                            normalized: max(0, min(1, (ratio - 1) / 9)),
                            physicalValue: ratio)
    }

    public func getALC() async throws -> MeterReading { throw unsupported("ALC") }
    public func getComp() async throws -> MeterReading { throw unsupported("compressor") }
    public func getVoltage() async throws -> MeterReading { throw unsupported("voltage") }
    public func getCurrent() async throws -> MeterReading { throw unsupported("current") }

    private func unsupported(_ name: String) -> RigError {
        .unsupportedOperation("QMX does not expose a \(name) meter")
    }

    private func transact(_ command: String) async throws -> String {
        guard let bytes = "\(command);".data(using: .ascii) else {
            throw RigError.invalidResponse
        }
        try await transport.write(bytes)
        let data = try await transport.readUntil(terminator: Self.terminator,
                                                 timeout: Self.timeout)
        guard let response = String(data: data.dropLast(), encoding: .ascii) else {
            throw RigError.invalidResponse
        }
        return response
    }

    private func parseMeter(_ response: String, prefix: String) throws -> Int {
        guard response.hasPrefix(prefix) else { throw RigError.invalidResponse }
        let payload = response.dropFirst(prefix.count)
        if payload.isEmpty { return 0 } // QMX is receiving, so no live reading.
        guard let value = Int(payload) else { throw RigError.invalidResponse }
        return value
    }
}
