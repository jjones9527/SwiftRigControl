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
            // Kenwood TH-handhelds (TH-D72, TH-D74, TH-D75) use the
            // CR (`\r`) terminator and reply with an alphabetic
            // model name like `ID TH-D72\r` per Hamlib `thd72.c`
            // and `th.c`. Every other Kenwood-derived radio in this
            // family — Elecraft, Yaesu, Xiegu, Lab599, Flex, and
            // Kenwood HF — uses the `;`-terminated `IDnnn;` shape.
            if Self.isKenwoodTHHandheld(radio) {
                return try await probeCR(transport: transport, timeout: timeout)
            }
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
            var raw = try await readCIVFrame(transport: transport, timeout: timeout)
            // Some Icoms echo the command before replying; if the
            // first frame is the controller echoing back to civ,
            // drop it and read once more. Track the *real reply*
            // bytes for the identity-response field so the validator
            // shows what the radio said, not what we sent.
            var parsed = try CIVFrame.parse(raw)
            if parsed.to == civ && parsed.from == CIVFrame.controllerAddress {
                raw = try await readCIVFrame(transport: transport, timeout: timeout)
                parsed = try CIVFrame.parse(raw)
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

    /// True for the TH-handheld family (TH-D72, TH-D74, TH-D75) —
    /// CR-terminated, alphabetic model-name reply. Hamlib treats
    /// these as a separate backend (`thd72.c` / `th.c`) using
    /// `EOM_TH = '\r'` rather than the HF Kenwood `EOM_KEN = ';'`.
    static func isKenwoodTHHandheld(_ radio: RadioDefinition) -> Bool {
        guard radio.manufacturer == .kenwood else { return false }
        let model = radio.model.uppercased()
        return model.hasPrefix("TH-D72")
            || model.hasPrefix("TH-D74")
            || model.hasPrefix("TH-D75")
    }

    // MARK: - Kenwood TH-handheld CR-terminated CAT

    /// Send `ID\r` and wait for a `\r`-terminated reply. The
    /// TH-handhelds reply with `ID TH-D72\r` (or `ID TH-D74\r`,
    /// etc.) — the model name as text rather than a 3-digit code.
    /// The radio may have buffered APRS / GPS data preceding the
    /// reply; tolerate that by accepting the first frame ending
    /// in `\r` that starts with `ID `.
    private func probeCR(
        transport: any SerialTransport,
        timeout: TimeInterval
    ) async throws -> RadioProbeOutcome {
        guard let query = "ID\r".data(using: .ascii) else {
            return .error
        }
        try await transport.write(query)

        // Tolerate the APRS/GPS preamble: the TH-D72 may have
        // buffered NMEA sentences queued before our `ID` query
        // lands at the radio. Read lines until either we see the
        // `ID TH-Dxx` reply or the per-port timeout expires.
        // Iteration cap is generous (the radio can stream 60+
        // GPS lines per second), but the real bound is the
        // wall-clock deadline.
        let deadline = Date().addingTimeInterval(timeout)
        var sawAnyData = false
        do {
            for _ in 0..<256 {
                let remaining = max(0.05, deadline.timeIntervalSinceNow)
                let data = try await transport.readUntil(
                    terminator: 0x0D, timeout: remaining
                )
                sawAnyData = true
                guard let text = String(data: data, encoding: .ascii) else { continue }
                let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: "\r\n"))
                if let range = trimmed.range(of: "ID TH-D", options: .caseInsensitive) {
                    let identity = String(trimmed[range.lowerBound...])
                    return .matched(identityResponse: identity)
                }
                if trimmed == "?" {
                    return .wrongRadio(identityResponse: trimmed)
                }
                if Date() > deadline { break }
            }
            // Saw data but no ID match within budget.
            return sawAnyData ? .wrongRadio(identityResponse: "no-id-in-stream") : .noResponse
        } catch RigError.timeout {
            return sawAnyData ? .wrongRadio(identityResponse: "timeout-in-stream") : .noResponse
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
