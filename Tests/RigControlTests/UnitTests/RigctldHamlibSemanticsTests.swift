import Foundation
import Testing
@testable import RigControl

/// rigctld bridge behavior that the Hamlib differential audit found
/// diverging from Hamlib's own definitions (`include/hamlib/rig.h`,
/// `doc/man1/rigctl.1`). Each of these used to fail or misread a real
/// Hamlib client's command.
@Suite struct RigctldHamlibSemanticsTests {

    private func session() async throws -> (RigctldCommandParser, RigctldCommandHandler, RigController) {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        return (RigctldCommandParser(), RigctldCommandHandler(rigController: rig), rig)
    }

    private func run(_ line: String, _ parser: RigctldCommandParser, _ handler: RigctldCommandHandler) async throws -> [String] {
        let response = await handler.handle(try parser.parse(line))
        return response.formatDefault().split(separator: "\n").map(String.init)
    }

    // MARK: - RIT / XIT (J j Z z)

    @Test func parsesRITAndXITCommands() throws {
        let parser = RigctldCommandParser()
        #expect(try parser.parse("J 500") == .setRIT(hz: 500))
        #expect(try parser.parse("J -120") == .setRIT(hz: -120))
        #expect(try parser.parse("j") == .getRIT)
        #expect(try parser.parse("Z 300") == .setXIT(hz: 300))
        #expect(try parser.parse("z") == .getXIT)
        #expect(try parser.parse("\\set_rit 250") == .setRIT(hz: 250))
        #expect(try parser.parse("\\get_xit") == .getXIT)
        // vfo_opt clients prefix a VFO (Hamlib table has no ARG_NOVFO).
        #expect(try parser.parse("J VFOA 500") == .setRIT(hz: 500))
        #expect(try parser.parse("j VFOA") == .getRIT)
        #expect(throws: RigctldCommandParser.ParseError.self) { try parser.parse("J") }
        #expect(throws: RigctldCommandParser.ParseError.self) { try parser.parse("J abc") }
    }

    @Test func ritRoundTripsAndZeroResets() async throws {
        let (parser, handler, rig) = try await session()
        #expect(try await run("J 500", parser, handler) == ["RPRT 0"])
        #expect(try await rig.getRIT(cached: false) == RITXITState(enabled: true, offset: 500))
        #expect(try await run("j", parser, handler) == ["500", "RPRT 0"])
        #expect(try await run("J 0", parser, handler) == ["RPRT 0"])
        #expect(try await rig.getRIT(cached: false).enabled == false)
        #expect(try await run("j", parser, handler) == ["0", "RPRT 0"])
    }

    // MARK: - Split TX VFO

    @Test func splitOffReportsVFOAAsTXVFO() async throws {
        let (parser, handler, _) = try await session()
        _ = try await run("S 0 VFOA", parser, handler)
        #expect(try await run("s", parser, handler) == ["0", "VFOA", "RPRT 0"])
        _ = try await run("S 1 VFOB", parser, handler)
        #expect(try await run("s", parser, handler) == ["1", "VFOB", "RPRT 0"])
    }

    // MARK: - Levels

    @Test func strengthIsDBRelativeToS9() async throws {
        let (parser, handler, rig) = try await session()
        let strength = try await rig.signalStrength(cached: false)
        let lines = try await run("l STRENGTH", parser, handler)
        #expect(lines == [String(strength.decibels - 54), "RPRT 0"])
        #expect(try await run("l RAWSTR", parser, handler) == [String(strength.raw), "RPRT 0"])
    }

    @Test func noiseBlankerAndReductionLevelsAreFloats() async throws {
        let (parser, handler, _) = try await session()
        #expect(try await run("L NR 0.5", parser, handler) == ["RPRT 0"])
        #expect(try await run("l NR", parser, handler) == ["0.501961", "RPRT 0"])
        #expect(try await run("L NR 0", parser, handler) == ["RPRT 0"])
        #expect(try await run("l NR", parser, handler) == ["0.000000", "RPRT 0"])
        #expect(try await run("L NB 0.25", parser, handler) == ["RPRT 0"])
        let nb = try await run("l NB", parser, handler)
        #expect(nb.last == "RPRT 0")
        #expect(Double(nb[0]).map { abs($0 - 64.0 / 255.0) < 0.000_01 } == true)
        // Out-of-range floats clamp to full scale (RigctldDecimal), never trap.
        #expect(try await run("L NR 1.5", parser, handler) == ["RPRT 0"])
        #expect(try await run("l NR", parser, handler) == ["1.000000", "RPRT 0"])
    }

    @Test func ifShiftAndVOXDelayInHamlibUnitsAreNotSupported() async throws {
        let (parser, handler, _) = try await session()
        // Hamlib IF is +/-Hz and VOXDELAY tenths of a second; we can't
        // honor those units, so say so instead of misreading them.
        let notSupported = "RPRT \(RigctldProtocol.ReturnCode.notSupported.rawValue)"
        #expect(try await run("L IF 100", parser, handler) == [notSupported])
        #expect(try await run("l IF", parser, handler) == [notSupported])
        #expect(try await run("L VOXDELAY 5", parser, handler) == [notSupported])
        #expect(try await run("l VOXDELAY", parser, handler) == [notSupported])
    }
}
