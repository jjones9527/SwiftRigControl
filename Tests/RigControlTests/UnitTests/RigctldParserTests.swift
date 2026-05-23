import Foundation
import Testing
@testable import RigControl

/// Parser tests for the Phase 4.5 rigctld command additions.
///
/// Both short (`U` / `Y` / `y` / `g` / `b`) and long
/// (`set_func` / `set_ant` / `get_ant` / `scan` / `send_morse` /
/// `stop_morse`) forms are exercised. Each test asserts the
/// parsed enum case matches exactly what the Hamlib rigctl client
/// emits.
@Suite struct RigctldParserTests {
    let parser = RigctldCommandParser()

    // MARK: - Function toggles

    @Test func parseSetFuncSBKINShort() throws {
        let cmd = try parser.parse("U SBKIN 1")
        guard case .setFunc(let name, let enabled) = cmd else {
            Issue.record("expected .setFunc, got \(cmd)")
            return
        }
        #expect(name == "SBKIN")
        #expect(enabled == true)
    }

    @Test func parseSetFuncFBKINLongOff() throws {
        let cmd = try parser.parse("\\set_func FBKIN 0")
        guard case .setFunc(let name, let enabled) = cmd else {
            Issue.record("expected .setFunc, got \(cmd)")
            return
        }
        #expect(name == "FBKIN")
        #expect(enabled == false)
    }

    @Test func parseGetFuncShort() throws {
        let cmd = try parser.parse("u SBKIN")
        guard case .getFunc(let name) = cmd else {
            Issue.record("expected .getFunc, got \(cmd)")
            return
        }
        #expect(name == "SBKIN")
    }

    // MARK: - Antenna

    @Test func parseSetAntShortNoOption() throws {
        let cmd = try parser.parse("Y 2")
        guard case .setAntenna(let ant, let opt) = cmd else {
            Issue.record("expected .setAntenna, got \(cmd)")
            return
        }
        #expect(ant == 2)
        #expect(opt == nil)
    }

    @Test func parseSetAntLongWithOption() throws {
        let cmd = try parser.parse("\\set_ant 1 5")
        guard case .setAntenna(let ant, let opt) = cmd else {
            Issue.record("expected .setAntenna, got \(cmd)")
            return
        }
        #expect(ant == 1)
        #expect(opt == 5)
    }

    @Test func parseGetAntLong() throws {
        let cmd = try parser.parse("\\get_ant 1")
        guard case .getAntenna(let ant) = cmd else {
            Issue.record("expected .getAntenna, got \(cmd)")
            return
        }
        #expect(ant == 1)
    }

    // MARK: - Scan

    @Test func parseScanMemShort() throws {
        let cmd = try parser.parse("g MEM 0")
        guard case .scan(let fn, let ch) = cmd else {
            Issue.record("expected .scan, got \(cmd)")
            return
        }
        #expect(fn == "MEM")
        #expect(ch == 0)
    }

    @Test func parseScanProgLong() throws {
        let cmd = try parser.parse("\\scan PROG 5")
        guard case .scan(let fn, let ch) = cmd else {
            Issue.record("expected .scan, got \(cmd)")
            return
        }
        #expect(fn == "PROG")
        #expect(ch == 5)
    }

    @Test func parseScanStopWithoutChannel() throws {
        // Hamlib accepts scan STOP without a channel arg.
        let cmd = try parser.parse("\\scan STOP")
        guard case .scan(let fn, let ch) = cmd else {
            Issue.record("expected .scan, got \(cmd)")
            return
        }
        #expect(fn == "STOP")
        #expect(ch == 0)
    }

    // MARK: - CW

    @Test func parseSendMorseShort() throws {
        let cmd = try parser.parse("b CQ")
        guard case .sendMorse(let text) = cmd else {
            Issue.record("expected .sendMorse, got \(cmd)")
            return
        }
        #expect(text == "CQ")
    }

    @Test func parseSendMorseMultiWord() throws {
        // The tokenizer splits on spaces; the parser must rejoin.
        let cmd = try parser.parse("\\send_morse CQ CQ DE VA3ZTF")
        guard case .sendMorse(let text) = cmd else {
            Issue.record("expected .sendMorse, got \(cmd)")
            return
        }
        #expect(text == "CQ CQ DE VA3ZTF")
    }

    @Test func parseStopMorseLong() throws {
        let cmd = try parser.parse("\\stop_morse")
        if case .stopMorse = cmd {
            // OK
        } else {
            Issue.record("expected .stopMorse, got \(cmd)")
        }
    }

    // MARK: - longName round-trip

    @Test func longNameMatchesHamlib() {
        // Hamlib's command names — we must spell them exactly the
        // same so clients see what they expect in extended-mode
        // echoes.
        #expect(RigctldCommand.setFunc(name: "X", enabled: true).longName == "set_func")
        #expect(RigctldCommand.getFunc(name: "X").longName == "get_func")
        #expect(RigctldCommand.setAntenna(antenna: 1, option: nil).longName == "set_ant")
        #expect(RigctldCommand.getAntenna(antenna: 1).longName == "get_ant")
        #expect(RigctldCommand.scan(function: "MEM", channel: 0).longName == "scan")
        #expect(RigctldCommand.sendMorse(text: "x").longName == "send_morse")
        #expect(RigctldCommand.stopMorse.longName == "stop_morse")
    }
}
