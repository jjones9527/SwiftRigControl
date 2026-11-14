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

    @Test(arguments: [RadioDefinition.Flex.powerSDR, .Flex.thetis])
    func powerSDRMeters(radio: RadioDefinition) async throws {
        let (proto, mock) = try await makeProtocol(radio, replies: [
            "ZZTX;": "ZZTX1;", "ZZRM5;": "ZZRM5075;", "ZZRM8;": "ZZRM81.75;"
        ])
        let power = try await proto.getRFPowerOut()
        #expect(power.watts == 75)
        #expect(power.normalized == 0.75)
        #expect(try await proto.getSWR().swrRatio == 1.75)
        await mock.setResponse(for: Data("ZZTX;".utf8), response: Data("ZZTX0;".utf8))
        #expect(try await proto.getSWR().swrRatio == 1.75)
        #expect(try await proto.getRFPowerOut().watts == 0)
        #expect(await mock.recordedWrites == ["ZZTX;", "ZZRM5;", "ZZTX;", "ZZTX;", "ZZRM8;", "ZZTX;", "ZZTX;"].map { Data($0.utf8) })
    }

    @Test func powerSDRReceiveStartsAtZero() async throws {
        let (proto, mock) = try await makeProtocol(.Flex.powerSDR, replies: ["ZZTX;": "ZZTX0;"])
        #expect(try await proto.getSWR().swrRatio == 0)
        #expect(try await proto.getRFPowerOut().watts == 0)
        #expect(await mock.recordedWrites == [Data("ZZTX;".utf8), Data("ZZTX;".utf8)])
    }

    @Test func powerSDRPowerChecksEndOfTransmit() async throws {
        let (proto, mock) = try await makeProtocol(.Flex.thetis)
        await mock.setChunkedResponse(["ZZTX1;", "ZZRM5050;", "ZZTX0;"].map { Data($0.utf8) })
        #expect(try await proto.getRFPowerOut().watts == 0)
    }

    @Test(arguments: ["ZZRM5nan;", "ZZRM5-10;", "ZZRM5abc;", "ZZRM51000;", "ZZRM6075;"])
    func powerSDRRejectsInvalidPower(reply: String) async throws {
        let (proto, _) = try await makeProtocol(.Flex.powerSDR, replies: ["ZZTX;": "ZZTX1;", "ZZRM5;": reply])
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getRFPowerOut() }
    }

    @Test(arguments: ["ZZRM8nan;", "ZZRM8inf;", "ZZRM8-1;", "ZZRM81.2x;", "ZZRM8;", "ZZRM71.5;"])
    func powerSDRRejectsInvalidSWR(reply: String) async throws {
        let (proto, _) = try await makeProtocol(.Flex.powerSDR, replies: ["ZZTX;": "ZZTX1;", "ZZRM8;": reply])
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getSWR() }
    }

    @Test(arguments: ["ZZTX2;", "ZZTX;", "TX1;", "ZZTX01;"])
    func powerSDRRejectsInvalidTXStatus(reply: String) async throws {
        let (proto, _) = try await makeProtocol(.Flex.powerSDR, replies: ["ZZTX;": reply])
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getRFPowerOut() }
    }

    @Test(arguments: [RadioDefinition.Flex.powerSDR, .Flex.thetis])
    func rigctldPowerSDRMeters(radio: RadioDefinition) async throws {
        let rig = try RigController(radio: radio, connection: .mock)
        try await rig.connect()
        let mock = try #require(await rig.rawProtocol.transport as? MockSerialTransport)
        for (command, reply) in ["ZZTX;": "ZZTX1;", "ZZRM5;": "ZZRM5120;", "ZZRM8;": "ZZRM82.5;"] {
            await mock.setResponse(for: Data(command.utf8), response: Data(reply.utf8))
        }
        let handler = RigctldCommandHandler(rigController: rig)
        #expect(await handler.handle(.getLevel(name: "RFPOWER_METER")).data == ["1.200000"])
        #expect(await handler.handle(.getLevel(name: "RFPOWER_METER_WATTS")).data == ["120.000000"])
        #expect(await handler.handle(.getLevel(name: "SWR")).data == ["2.500000"])
        #expect(await handler.handle(.getLevel(name: "ALC")).returnCode.rawValue == -11)
    }

    @Test(arguments: [RadioDefinition.Elecraft.kx2, .Elecraft.kx3])
    func kxPowerAndSWR(radio: RadioDefinition) async throws {
        let (proto, mock) = try await makeProtocol(radio, replies: [
            "TQ;": "TQ1;", "BG;": "BG17;", "OM;": "OM           02;",
            "PO;": "PO075;", "SW;": "SW025;"
        ])
        let power = try await proto.getRFPowerOut()
        #expect(power.normalized == 0.5)
        #expect(power.watts == 7.5)
        #expect(try await proto.getSWR().swrRatio == 2.5)
        await mock.reset()
        await #expect(throws: (any Error).self) { _ = try await proto.getALC() }
        #expect(await mock.recordedWrites.isEmpty)
    }

    @Test(arguments: [0, 5, 10, 12, 17, 22])
    func kxAmplifierPower(bars: Int) async throws {
        let (proto, _) = try await makeProtocol(.Elecraft.kx3, replies: [
            "TQ;": "TQ1;", "BG;": String(format: "BG%02d;", bars),
            "OM;": "OMP          02;", "PO;": "PO075;"
        ])
        let power = try await proto.getRFPowerOut()
        #expect(power.normalized == Double(bars > 10 ? bars - 12 : bars) / 10)
        #expect(power.watts == 75)
    }

    @Test func kxReceiveSkipsBarGraphButReadsWatts() async throws {
        let (proto, mock) = try await makeProtocol(.Elecraft.kx2, replies: [
            "TQ;": "TQ0;", "OM;": "OM           01;", "PO;": "PO001;"
        ])
        let power = try await proto.getRFPowerOut()
        #expect(power.normalized == 0)
        #expect(power.watts == 0.1)
        #expect(await mock.recordedWrites == ["TQ;", "OM;", "PO;"].map { Data($0.utf8) })
    }

    @Test(arguments: ["BG11;", "BG23;", "BG99;", "BG05T;", "BG-1;", "BGx5;"])
    func kxRejectsInvalidBars(reply: String) async throws {
        let (proto, _) = try await makeProtocol(.Elecraft.kx3, replies: ["TQ;": "TQ1;", "BG;": reply])
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getRFPowerOut() }
    }

    @Test(arguments: ["PO12;", "PO1234;", "PO-12;", "PO1x2;", "PC123;"])
    func kxRejectsInvalidWatts(reply: String) async throws {
        let (proto, _) = try await makeProtocol(.Elecraft.kx3, replies: [
            "TQ;": "TQ0;", "OM;": "OM           02;", "PO;": reply
        ])
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getRFPowerOut() }
    }

    @Test(arguments: ["OM;", "OM           020;", "XX           02;"])
    func kxRejectsInvalidOptions(reply: String) async throws {
        let (proto, _) = try await makeProtocol(.Elecraft.kx3, replies: ["TQ;": "TQ0;", "OM;": reply])
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getRFPowerOut() }
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

    @Test(arguments: [RadioDefinition.Elecraft.k2, .Kenwood.ts570D, .Kenwood.ts870S, .Flex.flex6000, .Flex.sdrConsole])
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

    @Test(arguments: [RadioDefinition.Kenwood.ts480HX, .Kenwood.ts480SAT])
    func ts480TripleUsesTwentyStepScale(radio: RadioDefinition) async throws {
        let (proto, mock) = try await makeProtocol(radio)
        let triple = ["RM10004;", "RM20010;", "RM30020;"]
        await mock.setChunkedResponse((triple + triple + triple).map { Data($0.utf8) })
        #expect(try await proto.getSWR().swrRatio == 1.5)
        let comp = try await proto.getComp()
        #expect(comp.dB == 10)
        #expect(comp.normalized == 0.5)
        #expect(try await proto.getALC().normalized == 5)
        #expect(await mock.recordedWrites == ["RM;", "RM;", "RM;"].map { Data($0.utf8) })
        #expect(radio.capabilities.supportsRFPowerMeter && radio.capabilities.supportsSWRMeter)
        #expect(radio.capabilities.supportsALCMeter && radio.capabilities.supportsCompMeter)
    }

    @Test(arguments: [(0, 1.0), (4, 1.5), (6, 1.75), (8, 2.0), (12, 3.0), (20, 10.0)])
    func ts2000SWRCalibration(raw: Int, ratio: Double) async throws {
        let (proto, _) = try await makeProtocol(.Kenwood.ts2000, replies: [
            "RM;": String(format: "RM1%04d;", raw)
        ])
        #expect(try await proto.getSWR().swrRatio == ratio)
    }

    @Test func ts2000ReadsOnlySelectedMeter() async throws {
        let (proto, mock) = try await makeProtocol(.Kenwood.ts2000, replies: ["RM;": "RM20010;"])
        #expect(try await proto.getComp().dB == 10)
        #expect(try await proto.getALC().normalized == 0)
        #expect(try await proto.getSWR().swrRatio == 1) // zero raw SWR calibrates to 1:1
        await mock.setResponse(for: Data("RM;".utf8), response: Data("RM30020;".utf8))
        #expect(try await proto.getALC().normalized == 5)
        #expect(try await proto.getComp().dB == 0)
        #expect(await mock.recordedWrites == Array(repeating: Data("RM;".utf8), count: 5))
    }

    @Test(arguments: ["RM1002x;", "RM10021;", "RM00000;", "RM40000;", "RM1001;", "RM100001;", "SM10001;"])
    func ts2000RejectsMalformedMeter(reply: String) async throws {
        let (proto, _) = try await makeProtocol(.Kenwood.ts2000, replies: ["RM;": reply])
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getSWR() }
    }

    @Test(arguments: ["RM10021;", "RM1000x;", "RM1001;", "RM20004;"])
    func ts480DrainsInvalidTriple(reply: String) async throws {
        let (proto, mock) = try await makeProtocol(.Kenwood.ts480SAT)
        await mock.setChunkedResponse(
            [reply, "RM20010;", "RM30020;", "RM10008;", "RM20000;", "RM30000;"].map { Data($0.utf8) }
        )
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getSWR() }
        #expect(try await proto.getSWR().swrRatio == 2)
    }

    @Test(arguments: [RadioDefinition.Kenwood.ts480HX, .Kenwood.ts480SAT, .Kenwood.ts2000])
    func normalizedPowerDoesNotInventWatts(radio: RadioDefinition) async throws {
        let fullScale = radio.model == "TS-2000" ? 30 : 20
        let (proto, mock) = try await makeProtocol(radio, replies: [
            "IF;": ifReply(transmitting: true), "SM0;": String(format: "SM0%04d;", fullScale / 2)
        ])
        let power = try await proto.getRFPowerOut()
        #expect(power.normalized == 0.5)
        #expect(power.watts == nil)
        #expect(!power.rfPowerIsCalibrated)
        #expect(power.description == "RF power 50%")
        #expect(await mock.recordedWrites == ["IF;", "SM0;"].map { Data($0.utf8) })
        await mock.reset()
        await mock.setResponse(for: Data("IF;".utf8), response: Data(ifReply(transmitting: false).utf8))
        let receive = try await proto.getRFPowerOut()
        #expect(receive.normalized == 0)
        #expect(receive.watts == nil)
        #expect(await mock.recordedWrites == [Data("IF;".utf8)])
    }

    @Test(arguments: [RadioDefinition.Kenwood.ts480HX, .Kenwood.ts480SAT, .Kenwood.ts2000])
    func newKenwoodMetersRejectInvalidPowerAndStatus(radio: RadioDefinition) async throws {
        let (proto, mock) = try await makeProtocol(radio, replies: ["IF;": "IF;"])
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getRFPowerOut() }
        await mock.setResponse(for: Data("IF;".utf8), response: Data(ifReply(transmitting: true).utf8))
        for reply in ["SM10010;", "SM0001x;", "SM00031;", "SM0001;"] {
            await mock.setResponse(for: Data("SM0;".utf8), response: Data(reply.utf8))
            await #expect(throws: RigError.invalidResponse) { _ = try await proto.getRFPowerOut() }
        }
        if radio.model != "TS-2000" {
            await mock.setResponse(for: Data("SM0;".utf8), response: Data("SM00021;".utf8))
            await #expect(throws: RigError.invalidResponse) { _ = try await proto.getRFPowerOut() }
        }
    }

    @Test(arguments: [RadioDefinition.Kenwood.ts480HX, .Kenwood.ts480SAT, .Kenwood.ts2000])
    func rigctldNewKenwoodMeters(radio: RadioDefinition) async throws {
        let rig = try RigController(radio: radio, connection: .mock)
        try await rig.connect()
        let mock = try #require(await rig.rawProtocol.transport as? MockSerialTransport)
        let handler = RigctldCommandHandler(rigController: rig)
        if radio.model == "TS-2000" {
            await mock.setResponse(for: Data("RM;".utf8), response: Data("RM10004;".utf8))
        } else {
            await mock.setChunkedResponse(["RM10004;", "RM20010;", "RM30020;"].map { Data($0.utf8) })
        }
        #expect(await handler.handle(.getLevel(name: "SWR")).data == ["1.500000"])
        await mock.setResponse(for: Data("IF;".utf8), response: Data(ifReply(transmitting: true).utf8))
        let powerReply = radio.model == "TS-2000" ? "SM00015;" : "SM00010;"
        await mock.setResponse(for: Data("SM0;".utf8), response: Data(powerReply.utf8))
        #expect(await handler.handle(.getLevel(name: "RFPOWER_METER")).data == ["0.500000"])
        let watts = await handler.handle(.getLevel(name: "RFPOWER_METER_WATTS"))
        #expect(watts.returnCode.rawValue == -11)
        #expect(watts.data.isEmpty)
    }

    @Test(arguments: [RadioDefinition.Kenwood.ts890S, .Kenwood.ts990S])
    func selectedMetersDrainThroughID(radio: RadioDefinition) async throws {
        let (proto, mock) = try await makeProtocol(radio)
        await mock.setChunkedResponse(
            ["ID024;", "RM10035;", "RM20007;", "RM30020;", "ID024;",
             "ID024;", "RM20035;", "ID024;"].map { Data($0.utf8) }
        )
        let first = try await proto.getSWR()
        if radio.model == "TS-990S" { #expect(first.swrRatio == 1.5) }
        else { #expect(abs((first.swrRatio ?? 0) - (1 + 7.0 / 22)) < 1e-9) }
        let second = try await proto.getSWR()
        #expect(second.swrRatio == (radio.model == "TS-990S" ? 2.9 : 3))
        #expect(await mock.recordedWrites == ["RM21;", "ID;", "RM;", "ID;", "RM21;", "ID;", "RM;", "ID;"].map { Data($0.utf8) })
    }

    @Test(arguments: [("RM10035;", 1), ("RM10070;", 2)])
    func ts890ALCUsesHalfScale(reply: String, expected: Int) async throws {
        let (proto, mock) = try await makeProtocol(.Kenwood.ts890S)
        await mock.setChunkedResponse(["ID024;", reply, "ID024;"].map { Data($0.utf8) })
        #expect(try await proto.getALC().normalized == Double(expected))
    }

    @Test(arguments: [(20, 10.0), (35, 15.0), (50, 20.0), (70, 25.0)])
    func ts890CompressionPiecewiseScale(raw: Int, expected: Double) async throws {
        let (proto, mock) = try await makeProtocol(.Kenwood.ts890S)
        await mock.setChunkedResponse(["ID024;", String(format: "RM3%04d;", raw), "ID024;"].map { Data($0.utf8) })
        #expect(try await proto.getComp().dB == expected)
    }

    @Test func ts890VoltageAndCurrent() async throws {
        let (proto, mock) = try await makeProtocol(.Kenwood.ts890S)
        await mock.setChunkedResponse(["ID024;", "RM5065;", "ID024;", "ID024;", "RM4070;", "ID024;"].map { Data($0.utf8) })
        #expect(try await proto.getVoltage().volts == 15)
        #expect(try await proto.getCurrent().amps == 20)
    }

    @Test(arguments: [(5, 5.0), (19, 25.0), (35, 50.0), (59, 100.0), (70, 150.0)])
    func ts890PowerCalibration(raw: Int, watts: Double) async throws {
        let (proto, mock) = try await makeProtocol(.Kenwood.ts890S, replies: [
            "IF;": ifReply(transmitting: true), "EX00011;": "EX00011 001;",
            "SM;": String(format: "SM%04d;", raw)
        ])
        let power = try await proto.getRFPowerOut()
        #expect(power.watts == watts)
        #expect(power.normalized == watts / 100)
        #expect(!power.supportsNormalizedRFPower)
        #expect(await mock.recordedWrites == ["IF;", "EX00011;", "SM;"].map { Data($0.utf8) })
    }

    @Test func ts890ReceiveSkipsMeterQueries() async throws {
        let (proto, mock) = try await makeProtocol(.Kenwood.ts890S, replies: ["IF;": ifReply(transmitting: false)])
        let power = try await proto.getRFPowerOut()
        #expect(power.watts == 0)
        #expect(!power.supportsNormalizedRFPower)
        #expect(await mock.recordedWrites == [Data("IF;".utf8)])
    }

    @Test(arguments: ["EX00011 002;", "EX00011 01;", "XX00011 001;"])
    func ts890RejectsInvalidMeterType(reply: String) async throws {
        let (proto, _) = try await makeProtocol(.Kenwood.ts890S, replies: [
            "IF;": ifReply(transmitting: true), "EX00011;": reply
        ])
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getRFPowerOut() }
    }

    @Test(arguments: ["SM0071;", "SM0x35;", "SM035;", "SM00035;"])
    func ts890RejectsInvalidPower(reply: String) async throws {
        let (proto, _) = try await makeProtocol(.Kenwood.ts890S, replies: [
            "IF;": ifReply(transmitting: true), "EX00011;": "EX000110000;", "SM;": reply
        ])
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getRFPowerOut() }
    }

    @Test(arguments: ["RM2071;", "RM20x1;", "RM20001x;", "RM200;", "RM70001;", "FA00000000;"])
    func selectedMeterRejectsAndDrainsMalformedReplies(reply: String) async throws {
        let (proto, mock) = try await makeProtocol(.Kenwood.ts890S)
        await mock.setChunkedResponse(["ID024;", reply, "RM20011;", "ID024;", "ID024;", "RM20023;", "ID024;"].map { Data($0.utf8) })
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getSWR() }
        #expect(try await proto.getSWR().swrRatio == 2)
    }

    @Test func selectedMeterBoundsAndMissingSelection() async throws {
        let (proto, mock) = try await makeProtocol(.Kenwood.ts990S)
        await mock.setChunkedResponse(["ID024;", "RM10001;", "ID024;"].map { Data($0.utf8) })
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getSWR() }
        await mock.setChunkedResponse((["ID024;"] + Array(repeating: "RM10001;", count: 7)).map { Data($0.utf8) })
        await #expect(throws: RigError.invalidResponse) { _ = try await proto.getSWR() }
    }

    @Test func ts990AdvertisesOnlyImplementedSWR() async throws {
        let (proto, mock) = try await makeProtocol(.Kenwood.ts990S)
        await #expect(throws: RigError.self) { _ = try await proto.getRFPowerOut() }
        await #expect(throws: RigError.self) { _ = try await proto.getALC() }
        await #expect(throws: RigError.self) { _ = try await proto.getComp() }
        await #expect(throws: RigError.self) { _ = try await proto.getVoltage() }
        await #expect(throws: RigError.self) { _ = try await proto.getCurrent() }
        #expect(await mock.recordedWrites.isEmpty)
        #expect(RadioDefinition.Kenwood.ts990S.capabilities.supportsSWRMeter)
        #expect(!RadioDefinition.Kenwood.ts990S.capabilities.supportsRFPowerMeter)
    }

    @Test func rigctldTS890PowerLevels() async throws {
        let rig = try RigController(radio: .Kenwood.ts890S, connection: .mock)
        try await rig.connect()
        let mock = try #require(await rig.rawProtocol.transport as? MockSerialTransport)
        for (command, reply) in ["IF;": ifReply(transmitting: true), "EX00011;": "EX00011 000;", "SM;": "SM0059;"] {
            await mock.setResponse(for: Data(command.utf8), response: Data(reply.utf8))
        }
        let handler = RigctldCommandHandler(rigController: rig)
        #expect(await handler.handle(.getLevel(name: "RFPOWER_METER_WATTS")).data == ["100.000000"])
        #expect(await handler.handle(.getLevel(name: "RFPOWER_METER")).returnCode.rawValue == -11)
        await mock.setChunkedResponse(["ID024;", "RM5065;", "ID024;"].map { Data($0.utf8) })
        #expect(await handler.handle(.getLevel(name: "VD_METER")).data == ["15.000000"])
    }

    @Test(arguments: [RadioDefinition.Elecraft.kx2, .Elecraft.kx3])
    func rigctldKXReportsBothPowerScales(radio: RadioDefinition) async throws {
        let rig = try RigController(radio: radio, connection: .mock)
        try await rig.connect()
        let mock = try #require(await rig.rawProtocol.transport as? MockSerialTransport)
        for (command, reply) in ["TQ;": "TQ1;", "BG;": "BG05;",
                                 "OM;": "OM           02;", "PO;": "PO075;", "SW;": "SW015;"] {
            await mock.setResponse(for: Data(command.utf8), response: Data(reply.utf8))
        }
        let handler = RigctldCommandHandler(rigController: rig)
        #expect(await handler.handle(.getLevel(name: "RFPOWER_METER")).data == ["0.500000"])
        #expect(await handler.handle(.getLevel(name: "RFPOWER_METER_WATTS")).data == ["7.500000"])
        #expect(await handler.handle(.getLevel(name: "SWR")).data == ["1.500000"])
        #expect(await handler.handle(.getLevel(name: "ALC")).returnCode.rawValue == -11)
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
