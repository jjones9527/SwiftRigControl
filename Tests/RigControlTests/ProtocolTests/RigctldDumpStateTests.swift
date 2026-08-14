import Foundation
import Testing
@testable import RigControl

/// Regression tests for the `\dump_state` netrigctl handshake
/// (jjones9527/macwinlink-releases#54).
///
/// Hamlib's netrigctl backend (`-m 2`) parses the `\dump_state`
/// response positionally with a fixed sequence of `read_string`
/// + `num_sscanf` calls (see `rigs/dummy/netrigctl.c:249`
/// `netrigctl_open`). If any expected line is missing or malformed
/// — or if any *extra* line is present — the client returns
/// `-8 Protocol error` at connection open, or corrupts the very
/// next command's response.
///
/// Prior behavior: our `dumpState()` emitted ~6 lines (version,
/// model, region, one RX range, RX terminator, VFO list). netrigctl
/// bailed after reading the RX terminator into the TX-range slot.
///
/// Fixed behavior: we emit the full canonical Hamlib
/// `rigctl_parse.c:4685` layout — RX ranges + terminator, TX ranges
/// + terminator, tuning steps + terminator, filter widths +
/// terminator, scalar limits, preamp/attenuator lists, six
/// hex bitmask lines, and (protocol 1) `setting=value` extension
/// lines closed by `done`.
@Suite struct RigctldDumpStateTests {

    // MARK: - Helpers

    private func makeHandler(
        detailedFrequencyRanges: [DetailedFrequencyRange] = []
    ) async throws -> RigctldCommandHandler {
        let caps = RigCapabilities(
            hasVFOB: true,
            frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
            detailedFrequencyRanges: detailedFrequencyRanges
        )
        let rig = try RigController(
            radio: .dummy(name: "Test", capabilities: caps),
            connection: .mock
        )
        try await rig.connect()
        return RigctldCommandHandler(rigController: rig)
    }

    private func dumpStateLines(handler: RigctldCommandHandler) async -> [String] {
        let response = await handler.handle(.dumpState)
        return response.data
    }

    /// Split a wire-format string exactly as netrigctl does, then
    /// discard the trailing empty tail from the last "\n".
    private func wireLines(_ formatted: String) -> [String] {
        var lines = formatted.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if lines.last == "" { lines.removeLast() }
        return lines
    }

    // MARK: - No trailing `RPRT 0` — the load-bearing fix

    @Test func dumpStateOmitsRPRTTrailerInDefaultMode() async throws {
        let handler = try await makeHandler()
        let response = await handler.handle(.dumpState)
        let formatted = response.formatDefault()

        #expect(!formatted.hasSuffix("RPRT 0\n"),
                "`\\dump_state` mirrors Hamlib's ARG_OUT path — netrigctl reads a fixed number of fields and stops. An RPRT trailer orphans in the socket buffer and corrupts the next command.")
        #expect(response.suppressRPRTTrailer,
                "The response must carry the suppression flag so RigControlServer sends it to the socket without appending RPRT.")
    }

    @Test func dumpStateFormattedEndsWithDoneLine() async throws {
        let handler = try await makeHandler()
        let response = await handler.handle(.dumpState)
        let formatted = response.formatDefault()
        #expect(formatted.hasSuffix("done\n"),
                "Protocol 1 extension section must be closed by a `done\\n` line — that's what tells netrigctl the payload is complete (see `netrigctl.c:647`).")
    }

    // MARK: - Fixed-order preamble

    @Test func dumpStateFirstThreeLinesAreProtocolModelRegion() async throws {
        let handler = try await makeHandler()
        let lines = await dumpStateLines(handler: handler)

        #expect(lines.count > 3, "dump_state must be at minimum a preamble + ranges + terminators + bitmasks; short output means netrigctl won't get past the header.")
        #expect(lines[0] == "1", "Protocol version must be 1 — advertises protocol 1 extension support to netrigctl.")
        #expect(lines[1] == "2", "Rig model must be 2 (RIG_MODEL_NETRIGCTL) — netrigctl uses this only for logging.")
        #expect(lines[2] == "0", "Deprecated ITU region: Hamlib emits `0` for backward compat (rigctl_parse.c:4702).")
    }

    // MARK: - Range terminators + 7-field wire format

    @Test func dumpStateContainsBothRangeTerminators() async throws {
        let handler = try await makeHandler()
        let lines = await dumpStateLines(handler: handler)

        // The RX + TX terminators are the same 7-zero line and appear
        // in that order. Both must be present or netrigctl_open bails
        // (it reads HAMLIB_FRQRANGESIZ = 30 slots looking for one).
        let terminators = lines.enumerated().filter { $0.element == "0 0 0 0 0 0 0" }.map(\.offset)
        #expect(terminators.count == 2,
                "dump_state must emit exactly two `0 0 0 0 0 0 0` lines — RX terminator, then TX terminator. Got \(terminators.count).")
    }

    @Test func dumpStateRXRangeLineHasSevenFields() async throws {
        let handler = try await makeHandler()
        let lines = await dumpStateLines(handler: handler)

        // First range line is index 3 (after version/model/region).
        // netrigctl parses this with num_sscanf against 7 fields;
        // a wrong field count is `-RIG_EPROTO`.
        let rxLine = lines[3]
        let fields = rxLine.split(separator: " ").map(String.init)
        #expect(fields.count == 7,
                "RX range line must have exactly 7 fields (startf endf modes lowP highP vfo ant). Got \(fields.count): `\(rxLine)`.")
        #expect(UInt64(fields[0]) == 30_000, "start = min freq")
        #expect(UInt64(fields[1]) == 60_000_000, "end = max freq")
    }

    @Test func dumpStateDetailedRangesEmitOneLinePerBand() async throws {
        let ranges: [DetailedFrequencyRange] = [
            DetailedFrequencyRange(min: 1_800_000, max: 2_000_000, modes: [.usb, .cw], canTransmit: true, bandName: "160m"),
            DetailedFrequencyRange(min: 3_500_000, max: 4_000_000, modes: [.usb, .cw], canTransmit: true, bandName: "80m"),
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb, .cw], canTransmit: true, bandName: "20m"),
        ]
        let handler = try await makeHandler(detailedFrequencyRanges: ranges)
        let lines = await dumpStateLines(handler: handler)

        // Preamble (3) + 3 RX + terminator + 3 TX + terminator + ...
        let rxSlice = Array(lines[3..<6])
        for (i, line) in rxSlice.enumerated() {
            let fields = line.split(separator: " ").map(String.init)
            #expect(fields.count == 7)
            #expect(UInt64(fields[0]) == ranges[i].min)
            #expect(UInt64(fields[1]) == ranges[i].max)
        }
        // Terminator sits right after the last RX range.
        #expect(lines[6] == "0 0 0 0 0 0 0")
    }

    @Test func dumpStateTXRangesFilterToCanTransmit() async throws {
        // Some HF radios receive above 30 MHz but can't transmit
        // there. That's exactly what `canTransmit: false` models,
        // and TX ranges must reflect the truth.
        let ranges: [DetailedFrequencyRange] = [
            DetailedFrequencyRange(min: 14_000_000, max: 14_350_000, modes: [.usb], canTransmit: true, bandName: "20m"),
            DetailedFrequencyRange(min: 88_000_000, max: 108_000_000, modes: [.wfm], canTransmit: false, bandName: "FM broadcast"),
        ]
        let handler = try await makeHandler(detailedFrequencyRanges: ranges)
        let lines = await dumpStateLines(handler: handler)

        // Locate the two terminators; the TX ranges live between them.
        let terminatorIdxs = lines.enumerated().compactMap { $0.element == "0 0 0 0 0 0 0" ? $0.offset : nil }
        #expect(terminatorIdxs.count == 2)
        let txRangeLines = Array(lines[(terminatorIdxs[0] + 1)..<terminatorIdxs[1]])
        #expect(txRangeLines.count == 1,
                "Only the 20m band should appear in TX ranges. Got: \(txRangeLines)")
        let fields = txRangeLines[0].split(separator: " ").map(String.init)
        #expect(UInt64(fields[0]) == 14_000_000)
        #expect(UInt64(fields[1]) == 14_350_000)
    }

    // MARK: - Tuning step + filter terminators

    @Test func dumpStateContainsTuningStepAndFilterTerminators() async throws {
        let handler = try await makeHandler()
        let lines = await dumpStateLines(handler: handler)

        // "0 0" terminates both the tuning-step and the filter lists.
        // netrigctl_open reads up to HAMLIB_TSLSTSIZ = 20 tuning-step
        // slots and HAMLIB_FLTLSTSIZ = 60 filter slots. Two matching
        // terminators must be present, in order.
        let ts = lines.enumerated().filter { $0.element == "0 0" }.map(\.offset)
        #expect(ts.count == 2,
                "Expected exactly two `0 0` terminators (tuning steps, then filters). Got \(ts.count).")
        #expect(ts[0] < ts[1], "TS terminator must precede filter terminator.")
    }

    @Test func dumpStateTuningStepAndFilterLinesHaveTwoFields() async throws {
        let handler = try await makeHandler()
        let lines = await dumpStateLines(handler: handler)

        // Every non-terminator line in the TS / filter sections must
        // parse as `<modes-hex> <int>` — two fields, exactly.
        let terminatorIdxs = lines.enumerated().compactMap { $0.element == "0 0 0 0 0 0 0" ? $0.offset : nil }
        let tsTerminatorIdxs = lines.enumerated().compactMap { $0.element == "0 0" ? $0.offset : nil }

        // Between last freq terminator and first "0 0" is the TS block.
        let tsLines = Array(lines[(terminatorIdxs[1] + 1)..<tsTerminatorIdxs[0]])
        // Between first "0 0" and second "0 0" is the filter block.
        let fltLines = Array(lines[(tsTerminatorIdxs[0] + 1)..<tsTerminatorIdxs[1]])

        for line in tsLines + fltLines {
            let fields = line.split(separator: " ").map(String.init)
            #expect(fields.count == 2, "TS/filter line must have exactly 2 fields (modes-hex, integer). Got `\(line)`.")
            #expect(fields[0].hasPrefix("0x"), "Modes mask must be hex-prefixed. Got `\(fields[0])`.")
        }
    }

    // MARK: - Six mandatory bitmask lines

    @Test func dumpStateHasSixHexBitmaskLinesAfterAttenuator() async throws {
        let handler = try await makeHandler()
        let lines = await dumpStateLines(handler: handler)

        // Format section (from `rigctl_parse.c:4780`):
        //   has_get_func
        //   has_set_func
        //   has_get_level
        //   has_set_level
        //   has_get_parm
        //   has_set_parm
        // Each parsed by `strtoll(..., 0)` — hex or decimal works.
        // We locate them by scanning for the first 6 consecutive
        // lines that start with `0x` after the second (filter) `0 0`.
        let filterTermIdxs = lines.enumerated().compactMap { $0.element == "0 0" ? $0.offset : nil }
        #expect(filterTermIdxs.count == 2)
        let afterFilter = filterTermIdxs[1] + 1

        // After the filter terminator: max_rit, max_xit, max_ifshift,
        // announces (all "0"), preamp list (""), attenuator list (""),
        // then the 6 bitmasks — that's 6+6 = 12 lines minimum.
        #expect(lines.count >= afterFilter + 6 + 6)

        // Verify the 6 bitmask lines exist by parsing each.
        let bitmaskLines = Array(lines[(afterFilter + 6)..<(afterFilter + 12)])
        for line in bitmaskLines {
            // Must be a valid integer literal (hex or dec).
            let cleaned = line.hasPrefix("0x") ? String(line.dropFirst(2)) : line
            #expect(UInt64(cleaned, radix: line.hasPrefix("0x") ? 16 : 10) != nil,
                    "Bitmask line must parse as an integer. Got `\(line)`.")
        }
    }

    // MARK: - Protocol 1 extension section

    @Test func dumpStateProtocolOneExtensionEndsWithDone() async throws {
        let handler = try await makeHandler()
        let lines = await dumpStateLines(handler: handler)

        // Extension section keys are `key=value`; ends with "done".
        // netrigctl parses these until it sees "done" (`netrigctl.c:647`).
        #expect(lines.last == "done", "Protocol 1 extension must terminate with `done`. Got `\(lines.last ?? "<nil>")`.")

        // Spot-check a couple of keys that Direwolf / WSJT-X probe.
        let hasSetFreq = lines.contains { $0.hasPrefix("has_set_freq=") }
        let hasGetFreq = lines.contains { $0.hasPrefix("has_get_freq=") }
        let pttType = lines.contains { $0.hasPrefix("ptt_type=") }
        #expect(hasSetFreq)
        #expect(hasGetFreq)
        #expect(pttType)
    }

    // MARK: - Round-trip: parse our output the way netrigctl does

    @Test func dumpStateOutputRoundTripsAsNetrigctlWouldParseIt() async throws {
        let handler = try await makeHandler()
        let response = await handler.handle(.dumpState)
        let formatted = response.formatDefault()
        var lines = wireLines(formatted)

        // Mirror `netrigctl_open()` at rigs/dummy/netrigctl.c:249.
        // Any missing/malformed line is `-RIG_EPROTO`; we must be
        // able to run the whole gauntlet without underflowing.

        // 1. protocol version, 2. model, 3. deprecated region
        _ = Int(lines.removeFirst())
        _ = Int(lines.removeFirst())
        _ = Int(lines.removeFirst())

        // 4. RX ranges up to terminator (7 fields each).
        while lines.first != "0 0 0 0 0 0 0" {
            let fields = lines.removeFirst().split(separator: " ")
            #expect(fields.count == 7)
        }
        lines.removeFirst()                                              // consume RX terminator

        // 5. TX ranges up to terminator (7 fields each).
        while lines.first != "0 0 0 0 0 0 0" {
            let fields = lines.removeFirst().split(separator: " ")
            #expect(fields.count == 7)
        }
        lines.removeFirst()                                              // consume TX terminator

        // 6. Tuning steps (2 fields) up to "0 0".
        while lines.first != "0 0" {
            let fields = lines.removeFirst().split(separator: " ")
            #expect(fields.count == 2)
        }
        lines.removeFirst()                                              // consume TS terminator

        // 7. Filters (2 fields) up to "0 0".
        while lines.first != "0 0" {
            let fields = lines.removeFirst().split(separator: " ")
            #expect(fields.count == 2)
        }
        lines.removeFirst()                                              // consume filter terminator

        // 8. Four scalar lines (max_rit, max_xit, max_ifshift, announces).
        _ = Int(lines.removeFirst())
        _ = Int(lines.removeFirst())
        _ = Int(lines.removeFirst())
        _ = Int(lines.removeFirst())

        // 9. Preamp + attenuator (may be blank).
        lines.removeFirst()
        lines.removeFirst()

        // 10. Six bitmask lines. Each must parse via strtoll.
        for _ in 0..<6 {
            let line = lines.removeFirst()
            let cleaned = line.hasPrefix("0x") ? String(line.dropFirst(2)) : line
            #expect(UInt64(cleaned, radix: line.hasPrefix("0x") ? 16 : 10) != nil)
        }

        // 11. Everything else is protocol-1 extension, terminated
        //     by "done". Every intermediate line must be `key=value`.
        var sawDone = false
        while !lines.isEmpty {
            let line = lines.removeFirst()
            if line == "done" {
                sawDone = true
                break
            }
            #expect(line.contains("="),
                    "Protocol-1 extension line must be key=value. Got `\(line)`.")
        }
        #expect(sawDone, "Extension section must end with `done` — that's what tells netrigctl the payload is complete.")
    }

    // MARK: - RigControlServer wire-format round-trip

    @Test func dumpStateWireOutputStartsWithProtocolAndEndsWithDone() async throws {
        let handler = try await makeHandler()
        let response = await handler.handle(.dumpState)
        let wire = response.formatDefault()
        // The raw bytes going to Direwolf must start `1\n2\n0\n` and
        // end with `done\n`. Direwolf's netrigctl reads until it
        // consumes `done` — anything after that is orphaned.
        #expect(wire.hasPrefix("1\n2\n0\n"),
                "Wire prefix must be `1\\n2\\n0\\n` (protocol/model/region). Got prefix `\(String(wire.prefix(20)))…`.")
        #expect(wire.hasSuffix("done\n"),
                "Wire suffix must be `done\\n`. Got suffix `\(String(wire.suffix(20)))`.")
    }
}
