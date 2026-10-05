import Foundation
import Testing
@testable import RigControl

/// Regression tests for canonical decimal parsing on the rigctld
/// bridge (Hamlib upstream `14f24827` / `55665a83` / `2d19d104`).
///
/// Hamlib's NET rigctl client formats frequencies with
/// `"%"FREQFMT` = `"%lf"` (`include/hamlib/rig.h:505-514`,
/// `rigs/dummy/netrigctl.c:1091-1095`), so a stock client sends
/// `F 14074000.000000`. Prior to v1.2.17 the parser required a bare
/// integer (`UInt64(token)`) and answered those with `RPRT -1`.
///
/// Hamlib's server accepts any complete, finite decimal token with
/// a dot or (for scalar fields) a comma separator
/// (`src/rigctl_protocol.c:25-90`). Non-finite or partial tokens are
/// rejected — on our side that also prevents a malformed client from
/// trapping the host app via `Int(Double.nan)`.
@Suite struct RigctldDecimalParsingTests {
    let parser = RigctldCommandParser()

    // MARK: - Grammar

    @Test(arguments: [
        ("14074000", 14_074_000.0),
        ("14074000.000000", 14_074_000.0),
        ("0.5", 0.5),
        ("0,5", 0.5),
        (".5", 0.5),
        ("5.", 5.0),
        ("+1", 1.0),
        ("-0.25", -0.25),
        ("1e3", 1000.0),
        ("1.5E-1", 0.15),
    ])
    func acceptsCanonicalDecimals(token: String, expected: Double) {
        #expect(RigctldDecimal.parseDouble(token) == expected)
    }

    @Test(arguments: [
        "", ".", ",", "+", "-", "nan", "NaN", "inf", "-inf", "infinity",
        "0x10", "1e", "1e+", "1.2.3", "1,2,3", "1 2", "14074000Hz",
        "1e999", "١٢",
    ])
    func rejectsMalformedOrNonFiniteTokens(token: String) {
        #expect(RigctldDecimal.parseDouble(token) == nil)
    }

    @Test func frequencyRoundsToNearestHertz() {
        #expect(RigctldDecimal.parseFrequency("14074000.4") == 14_074_000)
        #expect(RigctldDecimal.parseFrequency("14074000.6") == 14_074_001)
    }

    @Test func frequencyRejectsNegativeAndHuge() {
        #expect(RigctldDecimal.parseFrequency("-14074000") == nil)
        #expect(RigctldDecimal.parseFrequency("1e300") == nil)
    }

    @Test func unitIntervalClampsInsteadOfTrapping() {
        #expect(RigctldDecimal.parseUnitInterval("1e300") == 1.0)
        #expect(RigctldDecimal.parseUnitInterval("-5") == 0.0)
        #expect(RigctldDecimal.parseUnitInterval("nan") == nil)
    }

    // MARK: - Parser wiring

    @Test func setFrequencyAcceptsNetrigctlDecimalForm() throws {
        let cmd = try parser.parse("F 14074000.000000")
        guard case .setFrequency(let hz) = cmd else {
            Issue.record("expected .setFrequency, got \(cmd)")
            return
        }
        #expect(hz == 14_074_000)
    }

    @Test func setFrequencyAcceptsDecimalWithLeadingVFO() throws {
        let cmd = try parser.parse("F VFOA 7074000.000000")
        guard case .setFrequency(let hz) = cmd else {
            Issue.record("expected .setFrequency, got \(cmd)")
            return
        }
        #expect(hz == 7_074_000)
    }

    @Test func longSetFrequencyAcceptsDecimal() throws {
        let cmd = try parser.parse("\\set_freq 14074000.000000")
        guard case .setFrequency(let hz) = cmd else {
            Issue.record("expected .setFrequency, got \(cmd)")
            return
        }
        #expect(hz == 14_074_000)
    }

    @Test func setSplitFrequencyAcceptsDecimal() throws {
        let cmd = try parser.parse("I 14076000.000000")
        guard case .setSplitFrequency(let hz) = cmd else {
            Issue.record("expected .setSplitFrequency, got \(cmd)")
            return
        }
        #expect(hz == 14_076_000)
    }

    @Test func setFrequencyRejectsNaN() {
        #expect(throws: RigctldCommandParser.ParseError.self) {
            _ = try parser.parse("F nan")
        }
    }

    @Test func power2mWAcceptsDecimalFrequency() throws {
        let cmd = try parser.parse("2 0.5 14074000.000000 USB")
        guard case .power2mW(let power, let freq, let mode) = cmd else {
            Issue.record("expected .power2mW, got \(cmd)")
            return
        }
        #expect(power == 0.5)
        #expect(freq == 14_074_000)
        #expect(mode == "USB")
    }

    @Test func power2mWRejectsOutOfRangePower() {
        // Hamlib rig_power2mW returns -RIG_EINVAL outside 0.0...1.0.
        #expect(throws: RigctldCommandParser.ParseError.self) {
            _ = try parser.parse("2 1e300 14074000 USB")
        }
        #expect(throws: RigctldCommandParser.ParseError.self) {
            _ = try parser.parse("\\power2mW nan 14074000 USB")
        }
    }

    // MARK: - Handler level values

    private func makeHandler() async throws -> RigctldCommandHandler {
        let rig = try RigController(
            radio: .dummy(name: "Test", capabilities: RigCapabilities()),
            connection: .mock
        )
        try await rig.connect()
        return RigctldCommandHandler(rigController: rig)
    }

    @Test func setLevelAFRejectsNaNWithoutTrapping() async throws {
        let handler = try await makeHandler()
        let response = await handler.handle(.setLevel(name: "AF", value: "nan"))
        #expect(response.returnCode == .invalidParam)
    }

    @Test func setLevelAFClampsHugeValueWithoutTrapping() async throws {
        let handler = try await makeHandler()
        let response = await handler.handle(.setLevel(name: "AF", value: "1e300"))
        #expect(response.returnCode == .ok)
    }

    @Test func setLevelAcceptsDecimalComma() async throws {
        let handler = try await makeHandler()
        let response = await handler.handle(.setLevel(name: "MICGAIN", value: "0,5"))
        #expect(response.returnCode == .ok)

        let get = await handler.handle(.getLevel(name: "MICGAIN"))
        #expect(get.data.first == "0.500000")
    }
}
