import Foundation

/// Hamgeek uSDX's deliberately small TS-480-compatible CAT subset.
///
/// The firmware exposes only VFO A and `MD1`…`MD5`, does not support the
/// Kenwood `ID` set-command verification sequence, and returns an `RX0` reply
/// only when PTT is released. This actor models those wire semantics directly.
public actor HamgeekUSDXProtocol: CATProtocol {
    public let transport: any SerialTransport
    public let capabilities = RadioCapabilitiesDatabase.Hamgeek.usdx

    private static let terminator: UInt8 = 0x3B
    private static let timeout: TimeInterval = 2.0
    private static let postWriteDelay: UInt64 = 50_000_000

    /// Creates a Hamgeek uSDX adapter over USB serial or serial Bluetooth.
    /// - Parameter transport: Openable transport connected to the radio.
    public init(transport: any SerialTransport) {
        self.transport = transport
    }

    public func connect() async throws {
        try await transport.open()
        try await transport.flush()
    }

    public func disconnect() async { await transport.close() }

    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws {
        try requireVFOA(vfo)
        try await writeOnly(String(format: "FA%011llu", hz))
    }

    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        try requireVFOA(vfo)
        let response = try await transact("FA")
        guard response.hasPrefix("FA"), response.count >= 13,
              let frequency = UInt64(response.dropFirst(2).prefix(11)) else {
            throw RigError.invalidResponse
        }
        return frequency
    }

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        try requireVFOA(vfo)
        let code: Int
        switch mode {
        case .lsb, .dataLSB: code = 1
        case .usb, .dataUSB, .rtty: code = 2
        case .cw, .cwR: code = 3
        case .fm, .dataFM: code = 4
        case .am: code = 5
        case .rttyR: code = 1
        default:
            throw RigError.unsupportedOperation("Mode \(mode.rawValue) is not supported by Hamgeek uSDX")
        }
        try await writeOnly("MD\(code)")
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        try requireVFOA(vfo)
        let response = try await transact("MD")
        guard response.count >= 3 else { throw RigError.invalidResponse }
        switch Array(response)[2] {
        case "1": return .lsb
        case "2": return .usb
        case "3": return .cw
        case "4": return .fm
        case "5": return .am
        default: throw RigError.invalidResponse
        }
    }

    public func setPTT(_ enabled: Bool) async throws {
        if enabled {
            try await writeOnly("TX")
        } else {
            let response = try await transact("RX")
            guard response == "RX0" else { throw RigError.invalidResponse }
        }
    }

    /// Hamlib reports receive because the firmware exposes no reliable TX query.
    public func getPTT() async throws -> Bool { false }

    public func selectVFO(_ vfo: VFO) async throws {
        try requireVFOA(vfo) // VFO A is permanently selected; send nothing.
    }

    private func requireVFOA(_ vfo: VFO) throws {
        guard vfo == .a || vfo == .main else {
            throw RigError.unsupportedOperation("Hamgeek uSDX exposes only VFO A")
        }
    }

    private func writeOnly(_ command: String) async throws {
        try await write(command)
        try await Task.sleep(nanoseconds: Self.postWriteDelay)
    }

    private func transact(_ command: String) async throws -> String {
        try await write(command)
        let data = try await transport.readUntil(terminator: Self.terminator,
                                                 timeout: Self.timeout)
        // Hamlib strips occasional non-printable garbage emitted by uSDX.
        let printable = data.filter { $0 >= 0x20 && $0 <= 0x7E }
        guard let text = String(data: Data(printable), encoding: .ascii),
              text.hasSuffix(";") else {
            throw RigError.invalidResponse
        }
        return String(text.dropLast())
    }

    private func write(_ command: String) async throws {
        guard let data = "\(command);".data(using: .ascii) else {
            throw RigError.invalidResponse
        }
        try await transport.write(data)
    }
}
