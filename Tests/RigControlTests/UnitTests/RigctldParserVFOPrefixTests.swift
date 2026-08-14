import Foundation
import Testing
@testable import RigControl

/// Regression tests for the `vfo_opt=1` extended command syntax
/// (macwinlink-releases#54 followup).
///
/// Real Hamlib rigctld's command table (`tests/rigctl_parse.c`
/// lines ~287-352) marks every command that isn't `ARG_NOVFO` as
/// accepting a leading canonical VFO name — netrigctl clients
/// running `vfo_opt=1` prepend one to every affected command.
/// The client auto-enables `vfo_opt` when the server's
/// `\dump_state` payload advertises more than one VFO (v1.2.12
/// does, for any radio with `hasVFOB: true`).
///
/// Prior behavior: our parser tried to `Int("VFOA")` in the PTT
/// case at `RigctldCommandParser.swift:141` and threw
/// `.invalidParameter`, which came back over the wire as `RPRT -1`.
/// Direwolf's `PTT RIG 2` path logged `rig_set_ptt returning(-1)
/// Invalid parameter` and gave up on PTT for the session.
///
/// Fixed behavior: canonical VFO names (Hamlib `src/misc.c:616`)
/// are stripped off the head of the argument list for every
/// non-`ARG_NOVFO` command before argument parsing. The stripped
/// VFO is discarded — `RigController` operates on a single active
/// VFO — but the wire syntax is accepted.
@Suite struct RigctldParserVFOPrefixTests {
    let parser = RigctldCommandParser()

    // MARK: - PTT — the exact failing case from the bug report

    @Test func setPTTBareEnabledStillParses() throws {
        let cmd = try parser.parse("T 1")
        guard case .setPTT(let enabled) = cmd else {
            Issue.record("expected .setPTT, got \(cmd)")
            return
        }
        #expect(enabled == true)
    }

    @Test func setPTTBareDisabledStillParses() throws {
        let cmd = try parser.parse("T 0")
        guard case .setPTT(let enabled) = cmd else {
            Issue.record("expected .setPTT, got \(cmd)")
            return
        }
        #expect(enabled == false)
    }

    @Test func setPTTWithLeadingVFOA() throws {
        // The exact 9-byte payload Direwolf's netrigctl backend
        // sends under vfo_opt=1: `T VFOA 1\n`.
        let cmd = try parser.parse("T VFOA 1")
        guard case .setPTT(let enabled) = cmd else {
            Issue.record("expected .setPTT, got \(cmd)")
            return
        }
        #expect(enabled == true)
    }

    @Test func setPTTWithLeadingVFOB() throws {
        let cmd = try parser.parse("T VFOB 0")
        guard case .setPTT(let enabled) = cmd else {
            Issue.record("expected .setPTT, got \(cmd)")
            return
        }
        #expect(enabled == false)
    }

    @Test func setPTTWithLeadingCurrVFO() throws {
        // `currVFO` is the "whatever VFO the radio is on right now"
        // sentinel — a common netrigctl choice when the client
        // hasn't decided which VFO to target.
        let cmd = try parser.parse("T currVFO 1")
        guard case .setPTT(let enabled) = cmd else {
            Issue.record("expected .setPTT, got \(cmd)")
            return
        }
        #expect(enabled == true)
    }

    @Test func setPTTWithGarbageTokenStillErrors() throws {
        // "INVALID" isn't a canonical VFO name, so it's not
        // consumed as one. It then falls through to the PTT
        // integer parse, which correctly fails.
        #expect(throws: RigctldCommandParser.ParseError.self) {
            _ = try parser.parse("T INVALID 1")
        }
    }

    // MARK: - Frequency

    @Test func setFrequencyBareParses() throws {
        let cmd = try parser.parse("F 14200000")
        guard case .setFrequency(let hz) = cmd else {
            Issue.record("expected .setFrequency, got \(cmd)")
            return
        }
        #expect(hz == 14_200_000)
    }

    @Test func setFrequencyWithLeadingVFOAParses() throws {
        let cmd = try parser.parse("F VFOA 14200000")
        guard case .setFrequency(let hz) = cmd else {
            Issue.record("expected .setFrequency, got \(cmd)")
            return
        }
        #expect(hz == 14_200_000)
    }

    @Test func setFrequencyWithLeadingVFOBParses() throws {
        let cmd = try parser.parse("F VFOB 7100000")
        guard case .setFrequency(let hz) = cmd else {
            Issue.record("expected .setFrequency, got \(cmd)")
            return
        }
        #expect(hz == 7_100_000)
    }

    // MARK: - Mode

    @Test func setModeBareParses() throws {
        let cmd = try parser.parse("M USB 2400")
        guard case .setMode(let mode, let passband) = cmd else {
            Issue.record("expected .setMode, got \(cmd)")
            return
        }
        #expect(mode == "USB")
        #expect(passband == 2400)
    }

    @Test func setModeWithLeadingVFOAParses() throws {
        let cmd = try parser.parse("M VFOA USB 2400")
        guard case .setMode(let mode, let passband) = cmd else {
            Issue.record("expected .setMode, got \(cmd)")
            return
        }
        #expect(mode == "USB")
        #expect(passband == 2400)
    }

    @Test func setModeWithLeadingVFOAAndNoPassbandParses() throws {
        let cmd = try parser.parse("M VFOA USB")
        guard case .setMode(let mode, let passband) = cmd else {
            Issue.record("expected .setMode, got \(cmd)")
            return
        }
        #expect(mode == "USB")
        #expect(passband == nil)
    }

    // MARK: - Split VFO

    @Test func setSplitVFOWithLeadingVFOAParses() throws {
        // `S VFOA 1 VFOB` — the client says "on VFO A, split=1,
        // TX on VFO B". We accept the leading VFO and preserve
        // the split flag + TX VFO.
        let cmd = try parser.parse("S VFOA 1 VFOB")
        guard case .setSplitVFO(let enabled, let txVFO) = cmd else {
            Issue.record("expected .setSplitVFO, got \(cmd)")
            return
        }
        #expect(enabled == true)
        #expect(txVFO == "VFOB")
    }

    // MARK: - Level (2-arg command)

    @Test func setLevelBareParses() throws {
        let cmd = try parser.parse("L AF 0.5")
        guard case .setLevel(let name, let value) = cmd else {
            Issue.record("expected .setLevel, got \(cmd)")
            return
        }
        #expect(name == "AF")
        #expect(value == "0.5")
    }

    @Test func setLevelWithLeadingVFOAParses() throws {
        let cmd = try parser.parse("L VFOA AF 0.5")
        guard case .setLevel(let name, let value) = cmd else {
            Issue.record("expected .setLevel, got \(cmd)")
            return
        }
        #expect(name == "AF")
        #expect(value == "0.5")
    }

    // MARK: - Func toggle

    @Test func setFuncWithLeadingVFOAParses() throws {
        let cmd = try parser.parse("U VFOA COMP 1")
        guard case .setFunc(let name, let enabled) = cmd else {
            Issue.record("expected .setFunc, got \(cmd)")
            return
        }
        #expect(name == "COMP")
        #expect(enabled == true)
    }

    // MARK: - Get-side commands

    @Test func getFrequencyBareParses() throws {
        let cmd = try parser.parse("f")
        guard case .getFrequency = cmd else {
            Issue.record("expected .getFrequency, got \(cmd)")
            return
        }
    }

    @Test func getFrequencyWithLeadingVFOAParses() throws {
        // Netrigctl issues `f VFOA` when vfo_opt=1.
        let cmd = try parser.parse("f VFOA")
        guard case .getFrequency = cmd else {
            Issue.record("expected .getFrequency, got \(cmd)")
            return
        }
    }

    @Test func getPTTWithLeadingVFOAParses() throws {
        let cmd = try parser.parse("t VFOA")
        guard case .getPTT = cmd else {
            Issue.record("expected .getPTT, got \(cmd)")
            return
        }
    }

    // MARK: - Long-form (\set_*) commands

    @Test func setPTTLongFormBareParses() throws {
        let cmd = try parser.parse("\\set_ptt 1")
        guard case .setPTT(let enabled) = cmd else {
            Issue.record("expected .setPTT, got \(cmd)")
            return
        }
        #expect(enabled == true)
    }

    @Test func setPTTLongFormWithLeadingVFOAParses() throws {
        let cmd = try parser.parse("\\set_ptt VFOA 1")
        guard case .setPTT(let enabled) = cmd else {
            Issue.record("expected .setPTT, got \(cmd)")
            return
        }
        #expect(enabled == true)
    }

    @Test func setFrequencyLongFormWithLeadingVFOBParses() throws {
        let cmd = try parser.parse("\\set_freq VFOB 7100000")
        guard case .setFrequency(let hz) = cmd else {
            Issue.record("expected .setFrequency, got \(cmd)")
            return
        }
        #expect(hz == 7_100_000)
    }

    @Test func setModeLongFormWithLeadingVFOAParses() throws {
        let cmd = try parser.parse("\\set_mode VFOA USB 2400")
        guard case .setMode(let mode, let passband) = cmd else {
            Issue.record("expected .setMode, got \(cmd)")
            return
        }
        #expect(mode == "USB")
        #expect(passband == 2400)
    }

    // MARK: - ARG_NOVFO commands must NOT strip

    @Test func vfoOpDoesNotStripLeadingVFOToken() throws {
        // `G` (vfo_op) is ARG_NOVFO in Hamlib — its argument is
        // the operation name (CPY, XCHG, TOGGLE, …). Stripping a
        // leading "VFOA" here would silently drop the operation.
        // Confirm the first token still reaches `.vfoOp`.
        let cmd = try parser.parse("G VFOA")
        guard case .vfoOp(let op) = cmd else {
            Issue.record("expected .vfoOp, got \(cmd)")
            return
        }
        #expect(op == "VFOA",
                "vfo_op is ARG_NOVFO — its first arg is the operation, not a VFO context. Stripping would lose the semantic argument.")
    }

    @Test func setVFOArgumentIsNotStrippedAsPrefix() throws {
        // `V VFOA` says "make VFOA the active VFO". If we treated
        // the VFO as a prefix and stripped it, `.setVFO` would
        // arrive with no argument.
        let cmd = try parser.parse("V VFOA")
        guard case .setVFO(let vfo) = cmd else {
            Issue.record("expected .setVFO, got \(cmd)")
            return
        }
        #expect(vfo == "VFOA")
    }

    // MARK: - Mixed-case VFO names from Hamlib's canonical table

    @Test func setPTTWithMainVFOParses() throws {
        // `Main` (mixed case) is a legitimate Hamlib VFO name for
        // dual-receiver rigs (IC-9700, IC-7610 sub receiver, etc).
        // Case-sensitive match per misc.c:624.
        let cmd = try parser.parse("T Main 1")
        guard case .setPTT(let enabled) = cmd else {
            Issue.record("expected .setPTT, got \(cmd)")
            return
        }
        #expect(enabled == true)
    }

    @Test func setPTTWithLowercaseMainStillErrors() throws {
        // Hamlib is case-sensitive: `main` is NOT in the vfo_str
        // table. Client sending it is out of spec; we treat it
        // as an invalid PTT value (falls through to the Int parse).
        #expect(throws: RigctldCommandParser.ParseError.self) {
            _ = try parser.parse("T main 1")
        }
    }
}
