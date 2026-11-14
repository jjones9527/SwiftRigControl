import Foundation
import Testing
@testable import RigControl

@Suite struct KenwoodElecraftTXMeterTests {
    private func makeProtocol(_ radio: RadioDefinition, replies: [String: String] = [:])
        async throws -> (any SupportsTXMeters, MockTransport)
    {
        let mock = MockTransport()
        let proto = try #require(radio.createProtocol(transport: mock) as? any SupportsTXMeters)
        try await proto.connect()
        await mock.reset()
        for (command, reply) in replies {
            await mock.setResponse(for: Data(command.utf8), response: Data(reply.utf8))
        }
        return (proto, mock)
    }

    @Test(arguments: [(0, 0.0), (5, 0.5), (125, 12.5), (1000, 100.0), (1200, 120.0)])
    func k4PowerUsesOneQuery(raw: Int, watts: Double) async throws {
        let (proto, mock) = try await makeProtocol(.Elecraft.k4, replies: [
            "PO;": String(format: "PO%04d;", raw)
        ])
        let reading = try await proto.getRFPowerOut()
        #expect(reading.watts == watts)
        #expect(reading.normalized == Double(raw) / 1000)
        #expect(await mock.recordedWrites == [Data("PO;".utf8)])
    }

    @Test(arguments: ["PO123;", "PO12345;", "PO-123;", "PO12x4;", "PO 123;", "PC0123;", "?;"])
    func k4RejectsMalformedPower(reply: String) async throws {
        let (proto, _) = try await makeProtocol(.Elecraft.k4, replies: ["PO;": reply])
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getRFPowerOut() }
    }

    @Test func k4ReadsTMFields() async throws {
        let (proto, mock) = try await makeProtocol(.Elecraft.k4, replies: ["TM;": "TM003015080025;"])
        #expect(try await proto.getSWR().swrRatio == 2.5)
        #expect(try await proto.getALC().normalized == 3)
        #expect(await mock.recordedWrites == [Data("TM;".utf8), Data("TM;".utf8)])
    }

    @Test(arguments: ["TM00301508002;", "TM0030150800250;", "TM00301x080025;", "TM-03015080025;"])
    func k4RejectsMalformedTM(reply: String) async throws {
        let (proto, _) = try await makeProtocol(.Elecraft.k4, replies: ["TM;": reply])
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getSWR() }
    }

    @Test(arguments: [RadioDefinition.Kenwood.ts590S, .Kenwood.ts590SG])
    func ts590ConsumesAllThreeMeterReplies(radio: RadioDefinition) async throws {
        let (proto, mock) = try await makeProtocol(radio)
        // A second query must start on RM1, not on a leftover RM2 or RM3.
        await mock.setChunkedResponse(
            ["RM10006;", "RM20015;", "RM30030;", "RM10012;", "RM20015;", "RM30006;"].map { Data($0.utf8) }
        )
        #expect(try await proto.getSWR().swrRatio == 1.5)
        #expect(try await proto.getALC().normalized == 1)
        #expect(await mock.recordedWrites == [Data("RM;".utf8), Data("RM;".utf8)])
    }

    @Test func ts590CompressionAndALCAreHamlibUnits() async throws {
        let (proto, mock) = try await makeProtocol(.Kenwood.ts590SG)
        await mock.setChunkedResponse(
            ["RM10000;", "RM20015;", "RM30030;", "RM10000;", "RM20015;", "RM30030;"].map { Data($0.utf8) }
        )
        #expect(try await proto.getComp().dB == 15)
        #expect(try await proto.getALC().normalized == 5)
    }

    @Test(arguments: ["RM1000x;", "RM10031;", "RM20006;", "RM1006;"])
    func ts590DrainsMalformedTriple(reply: String) async throws {
        let (proto, mock) = try await makeProtocol(.Kenwood.ts590SG)
        await mock.setChunkedResponse(
            [reply, "RM20015;", "RM30006;", "RM10012;", "RM20000;", "RM30000;"].map { Data($0.utf8) }
        )
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getSWR() }
        #expect(try await proto.getSWR().swrRatio == 2)
    }

    private func ifReply(transmitting: Bool) -> String {
        // Simulator's 37-character TS-590 IF record with its TX flag set.
        var bytes = Array("IF000503130001000+0000000000030000000".utf8)
        bytes[28] = transmitting ? 49 : 48
        return String(decoding: bytes, as: UTF8.self) + ";"
    }

    @Test(arguments: [(2, 3.3), (6, 10.0), (12, 25.0), (17, 50.0), (30, 100.0)])
    func ts590PowerHasSeparateWattsAndNormalizedScales(raw: Int, watts: Double) async throws {
        let (proto, mock) = try await makeProtocol(.Kenwood.ts590SG, replies: [
            "IF;": ifReply(transmitting: true), "SM0;": String(format: "SM0%04d;", raw)
        ])
        let reading = try await proto.getRFPowerOut()
        #expect(reading.watts == watts)
        #expect(reading.normalized == Double(raw) / 30)
        #expect(await mock.recordedWrites == ["IF;", "SM0;"].map { Data($0.utf8) })
    }

    @Test func ts590ReceiveDoesNotReadSignalAsPower() async throws {
        let (proto, mock) = try await makeProtocol(.Kenwood.ts590SG, replies: ["IF;": ifReply(transmitting: false)])
        #expect(try await proto.getRFPowerOut().watts == 0)
        #expect(await mock.recordedWrites == [Data("IF;".utf8)])
    }

    @Test(arguments: ["IF;", "IF000503130001000+0000000000x30000000;", "?;"])
    func ts590RejectsMalformedTXStatus(reply: String) async throws {
        let (proto, mock) = try await makeProtocol(.Kenwood.ts590SG, replies: ["IF;": reply])
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getRFPowerOut() }
        #expect(await mock.recordedWrites == [Data("IF;".utf8)])
    }

    @Test(arguments: ["SM00031;", "SM0000x;", "SM0001;", "SM10012;"])
    func ts590RejectsMalformedPower(reply: String) async throws {
        let (proto, _) = try await makeProtocol(.Kenwood.ts590SG, replies: [
            "IF;": ifReply(transmitting: true), "SM0;": reply
        ])
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getRFPowerOut() }
    }

    @Test(arguments: [RadioDefinition.Elecraft.k2, .Elecraft.kx3, .Kenwood.ts2000, .Kenwood.ts480SAT])
    func unimplementedModelsSendNoMeterCommands(radio: RadioDefinition) async throws {
        let (proto, mock) = try await makeProtocol(radio)
        await #expect(throws: RigError.self) { _ = try await proto.getRFPowerOut() }
        await #expect(throws: RigError.self) { _ = try await proto.getSWR() }
        #expect(await mock.recordedWrites.isEmpty)
        #expect(!radio.capabilities.supportsRFPowerMeter)
    }

    @Test(arguments: [RadioDefinition.Elecraft.k3, .Elecraft.k3S])
    func k3ReadsPowerALCAndSWR(radio: RadioDefinition) async throws {
        let (proto, mock) = try await makeProtocol(radio, replies: [
            "TM;": "TM0;", "BG;": "BG12T;", "PC;": "PC1001;", "SW;": "SW025;"
        ])
        let power = try await proto.getRFPowerOut()
        #expect(power.watts == 120)
        #expect(power.normalized == 1.2)
        #expect(await mock.recordedWrites == ["TM;", "BG;", "PC;"].map { Data($0.utf8) })
        #expect(try await proto.getSWR().swrRatio == 2.5)
        await mock.setResponse(for: Data("TM;".utf8), response: Data("TM1;".utf8))
        await mock.setResponse(for: Data("BG;".utf8), response: Data("BG07T;".utf8))
        #expect(try await proto.getALC().normalized == 1)
        #expect(radio.capabilities.supportsRFPowerMeter)
        #expect(radio.capabilities.supportsSWRMeter)
        #expect(radio.capabilities.supportsALCMeter)
    }

    @Test(arguments: [("PC0500;", 5.0), ("PC0501;", 50.0), ("PC050;", 50.0)])
    func k3PowerUsesPCRange(reply: String, watts: Double) async throws {
        let (proto, _) = try await makeProtocol(.Elecraft.k3, replies: [
            "TM;": "TM0;", "BG;": "BG05T;", "PC;": reply
        ])
        let power = try await proto.getRFPowerOut()
        #expect(power.watts == watts)
        #expect(power.normalized == watts / 100)
    }

    @Test(arguments: ["TM0;", "TM1;"])
    func k3ReceiveReturnsZeroWithoutPC(selection: String) async throws {
        let (proto, mock) = try await makeProtocol(.Elecraft.k3, replies: [
            "TM;": selection, "BG;": "BG21R;"
        ])
        #expect(try await proto.getRFPowerOut().watts == 0)
        #expect(try await proto.getALC().normalized == 0)
        #expect(await mock.recordedWrites == ["TM;", "BG;", "TM;", "BG;"].map { Data($0.utf8) })
    }

    @Test func k3WrongMeterDoesNotChangeSelection() async throws {
        let (proto, mock) = try await makeProtocol(.Elecraft.k3, replies: [
            "TM;": "TM1;", "BG;": "BG05T;"
        ])
        await #expect(throws: RigError.invalidParameter("Select the power meter to read K3 RF power")) {
            _ = try await proto.getRFPowerOut()
        }
        await mock.setResponse(for: Data("TM;".utf8), response: Data("TM0;".utf8))
        await #expect(throws: RigError.invalidParameter("Select the ALC meter to read K3 ALC")) {
            _ = try await proto.getALC()
        }
        #expect(await mock.recordedWrites == ["TM;", "BG;", "TM;", "BG;"].map { Data($0.utf8) })
    }

    @Test(arguments: ["TM2;", "TM00;", "TM;", "TX0;", "TMx;"])
    func k3RejectsMalformedSelection(reply: String) async throws {
        let (proto, mock) = try await makeProtocol(.Elecraft.k3, replies: ["TM;": reply])
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getALC() }
        #expect(await mock.recordedWrites == [Data("TM;".utf8)])
    }

    @Test(arguments: ["BG13T;", "BG22R;", "BG05X;", "BG5T;", "BG005T;", "BG-1T;", "BG0xT;", "SM05T;"])
    func k3RejectsMalformedGraph(reply: String) async throws {
        let (proto, _) = try await makeProtocol(.Elecraft.k3, replies: ["TM;": "TM0;", "BG;": reply])
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getRFPowerOut() }
    }

    @Test func k3RejectsALCAboveSeven() async throws {
        let (proto, _) = try await makeProtocol(.Elecraft.k3, replies: ["TM;": "TM1;", "BG;": "BG08T;"])
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getALC() }
    }

    @Test(arguments: ["PC0502;", "PC05;", "PC05000;", "PC0x0;", "PC-50;", "PO050;"])
    func k3RejectsMalformedPowerRange(reply: String) async throws {
        let (proto, _) = try await makeProtocol(.Elecraft.k3, replies: [
            "TM;": "TM0;", "BG;": "BG05T;", "PC;": reply
        ])
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getRFPowerOut() }
    }

    @Test(arguments: ["SW25;", "SW0250;", "SW-25;", "SW02x;", "SM025;"])
    func k3RejectsMalformedSWR(reply: String) async throws {
        let (proto, _) = try await makeProtocol(.Elecraft.k3, replies: ["SW;": reply])
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getSWR() }
    }

    @Test func rigctldK3MetersAndWrongSelection() async throws {
        let rig = try RigController(radio: .Elecraft.k3S, connection: .mock)
        try await rig.connect()
        let mock = try #require(await rig.rawProtocol.transport as? MockSerialTransport)
        for (command, reply) in ["TM;": "TM0;", "BG;": "BG05T;", "PC;": "PC0500;", "SW;": "SW015;"] {
            await mock.setResponse(for: Data(command.utf8), response: Data(reply.utf8))
        }
        let handler = RigctldCommandHandler(rigController: rig)
        #expect(await handler.handle(.getLevel(name: "RFPOWER_METER")).data == ["0.050000"])
        #expect(await handler.handle(.getLevel(name: "RFPOWER_METER_WATTS")).data == ["5.000000"])
        #expect(await handler.handle(.getLevel(name: "SWR")).data == ["1.500000"])
        let wrongMeter = await handler.handle(.getLevel(name: "ALC"))
        #expect(wrongMeter.returnCode.rawValue == -1)
    }

    @Test func rigctldTS590ReportsHamlibUnits() async throws {
        let rig = try RigController(radio: .Kenwood.ts590SG, connection: .mock)
        try await rig.connect()
        let mock = try #require(await rig.rawProtocol.transport as? MockSerialTransport)
        // MockSerialTransport returns one configured chunk per readUntil;
        // the serial/TCP transports split at each semicolon.
        let triple = ["RM10006;", "RM20015;", "RM30030;"]
        await mock.setChunkedResponse((triple + triple + triple).map { Data($0.utf8) })
        let handler = RigctldCommandHandler(rigController: rig)
        #expect(await handler.handle(.getLevel(name: "SWR")).data == ["1.500000"])
        #expect(await handler.handle(.getLevel(name: "COMP_METER")).data == ["15.000000"])
        #expect(await handler.handle(.getLevel(name: "ALC")).data == ["5.000000"])
    }

    @Test func rigctldK4PowerUsesBothHamlibScales() async throws {
        let rig = try RigController(radio: .Elecraft.k4, connection: .mock)
        try await rig.connect()
        let mock = try #require(await rig.rawProtocol.transport as? MockSerialTransport)
        await mock.setResponse(for: Data("PO;".utf8), response: Data("PO0125;".utf8))
        let handler = RigctldCommandHandler(rigController: rig)
        #expect(await handler.handle(.getLevel(name: "RFPOWER_METER")).data == ["0.125000"])
        #expect(await handler.handle(.getLevel(name: "RFPOWER_METER_WATTS")).data == ["12.500000"])
    }
}
