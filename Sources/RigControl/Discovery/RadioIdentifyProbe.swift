import Foundation

/// Sends the right vendor identify query for a given radio and
/// matches the response. Used by ``RadioDiscovery``'s default
/// probe; lifted out so the wire bytes (the radio-protocol part)
/// stay separate from the port-enumeration and orchestration
/// logic.
internal struct RadioIdentifyProbe {

    let radio: RadioDefinition

    /// Send identify, read response, decide whether the response
    /// belongs to ``radio``.
    func run(
        transport: any SerialTransport,
        timeout: TimeInterval
    ) async throws -> RadioProbeOutcome {
        switch radio.manufacturer {
        case .icom:
            return try await probeIcom(transport: transport, timeout: timeout)

        case .kenwood, .elecraft, .yaesu, .xiegu, .lab599, .flex:
            // All five families speak Kenwood-derived text CAT with
            // a `;` terminator. The `ID` query and its `IDxxx;`
            // reply shape are common; we accept any well-formed
            // response (model-ID parsing would require a per-radio
            // mapping table we don't yet maintain).
            return try await probeSemicolon(transport: transport, timeout: timeout)

        case .tentec:
            // Ten-Tec Orion/Legacy expose `?V` for firmware
            // version. The response shape varies between Orion
            // and Legacy; conservative: skip auto-detection here
            // and let the user configure manually.
            return .noResponse

        case .dummy:
            // The dummy radio isn't on any serial port. Return
            // noResponse so multi-radio discovery skips it
            // cleanly instead of erroring.
            return .noResponse
        }
    }

    // MARK: - Icom CI-V

    /// Send `0x19 0x00` (read transceiver ID) addressed to the
    /// radio's CI-V address. A correct response echoes the same
    /// CI-V address in the `from` field of the reply frame.
    ///
    /// Frame layout (no echo on most radios):
    ///   send:  FE FE <civAddr> E0 19 00 FD
    ///   reply: FE FE E0 <civAddr> 19 00 <civAddr> FD
    private func probeIcom(
        transport: any SerialTransport,
        timeout: TimeInterval
    ) async throws -> RadioProbeOutcome {
        guard let civ = radio.civAddress else {
            return .error
        }
        let frame = CIVFrame(to: civ, command: [0x19, 0x00])
        try await transport.write(Data(frame.bytes()))

        do {
            let raw = try await readCIVFrame(transport: transport, timeout: timeout)
            // Some Icoms echo the command before replying; if the
            // first frame is the controller echoing back to civ,
            // drop it and read once more.
            var parsed = try CIVFrame.parse(raw)
            if parsed.to == civ && parsed.from == CIVFrame.controllerAddress {
                let raw2 = try await readCIVFrame(transport: transport, timeout: timeout)
                parsed = try CIVFrame.parse(raw2)
            }
            let hex = raw.map { String(format: "%02X", $0) }.joined(separator: " ")
            // A genuine reply has from == civ and the same 0x19 0x00
            // command prefix.
            if parsed.from == civ && parsed.command.first == 0x19 {
                return .matched(identityResponse: hex)
            }
            return .wrongRadio(identityResponse: hex)
        } catch RigError.timeout {
            return .noResponse
        }
    }

    /// Read bytes up to the CI-V terminator (0xFD).
    private func readCIVFrame(
        transport: any SerialTransport,
        timeout: TimeInterval
    ) async throws -> Data {
        try await transport.readUntil(terminator: CIVFrame.terminator, timeout: timeout)
    }

    // MARK: - Kenwood-family text CAT

    /// Send `ID;` and wait for a `;`-terminated reply. Any
    /// response that starts with `ID` and has 4 trailing chars
    /// (e.g. `ID021;`, `ID670;`) is accepted as evidence that
    /// *some* Kenwood-family radio is on the port — we don't
    /// currently maintain a model-ID table, so this confirms the
    /// vendor family rather than the exact model.
    private func probeSemicolon(
        transport: any SerialTransport,
        timeout: TimeInterval
    ) async throws -> RadioProbeOutcome {
        guard let query = "ID;".data(using: .ascii) else {
            return .error
        }
        try await transport.write(query)
        do {
            let data = try await transport.readUntil(terminator: 0x3B, timeout: timeout)
            guard let text = String(data: data, encoding: .ascii) else {
                return .wrongRadio(identityResponse: "")
            }
            if Self.isLikelyKenwoodFamilyID(text) {
                return .matched(identityResponse: text)
            }
            return .wrongRadio(identityResponse: text)
        } catch RigError.timeout {
            return .noResponse
        }
    }

    /// Returns true for responses that look like the Kenwood
    /// `ID###;` shape. Exposed `internal` for tests.
    static func isLikelyKenwoodFamilyID(_ text: String) -> Bool {
        // Strip leading echo if the radio repeats the query (some
        // adapters loop back the TX line).
        var s = text
        if s.hasPrefix("ID;") { s.removeFirst("ID;".count) }
        guard s.hasPrefix("ID"), s.hasSuffix(";") else { return false }
        let payload = s.dropFirst(2).dropLast()
        // Kenwood/Yaesu/Elecraft IDs are 3+ digits; accept any
        // all-digit payload of length 1–5 to cover the variants
        // (K2's `ID017;`, FT-991's `ID0670;`, etc.).
        guard !payload.isEmpty, payload.count <= 5 else { return false }
        return payload.allSatisfy { $0.isASCII && $0.isNumber }
    }
}
