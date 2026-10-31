import Foundation
import Testing
@testable import RigControl

/// Yaesu newcat TX meters (Hamlib `newcat_get_level`): `RM` reads through
/// each model's Hamlib calibration table, generated into
/// `YaesuCATProtocol+MeterCalibration.swift` by `Scripts/hamlib-meter-cal.py`.
@Suite struct YaesuTXMeterTests {

    private static func ascii(_ s: String) -> Data { Data(s.utf8) }

    private func meters(_ radio: RadioDefinition, replies: [String: String]) async throws
        -> (YaesuCATProtocol, MockTransport)
    {
        let mock = MockTransport()
        let proto = try #require(radio.createProtocol(transport: mock) as? YaesuCATProtocol)
        try await proto.connect()
        await mock.reset()
        for (query, reply) in replies {
            await mock.setResponse(for: Self.ascii(query), response: Self.ascii(reply))
        }
        return (proto, mock)
    }

    @Test func floatTableMatchesRigRaw2valFloat() {
        // src/cal.c rig_raw2val_float: ends clamp, the middle interpolates.
        let table = FloatCalibrationTable([(0, 1.0), (26, 1.2), (52, 1.5)])
        #expect(table.value(forRaw: -5) == 1.0)
        #expect(abs(table.value(forRaw: 39) - 1.35) < 1e-9)
        #expect(table.value(forRaw: 300) == 1.5)
        #expect(FloatCalibrationTable([]).value(forRaw: 42) == 42)
    }

    @Test func ft710SWRUsesItsTable() async throws {
        // FT710_SWR_CAL: raw 52 is 1.5:1.
        let (proto, mock) = try await meters(.Yaesu.ft710, replies: ["RM6;": "RM6052000;"])
        let reading = try await proto.getSWR()
        #expect(reading.swrRatio == 1.5)
        #expect(await mock.recordedWrites == [Self.ascii("RM6;")])
    }

    @Test func ft991CompressionVoltageAndCurrent() async throws {
        // FT991_COMP_CAL 85 -> 7.5 dB, FT991_VD_CAL 192 -> 13.8 V, FT991_ID_CAL 100 -> 10 A.
        let (proto, _) = try await meters(.Yaesu.ft991A, replies: [
            "RM3;": "RM3085;", "RM8;": "RM8192;", "RM7;": "RM7100;",
        ])
        #expect(try await proto.getComp().dB == 7.5)
        #expect(try await proto.getVoltage().volts == 13.8)
        #expect(abs((try await proto.getCurrent().amps ?? 0) - 10) < 1e-9)
    }

    @Test func modelsWithoutATableUseYaesuDefaults() async throws {
        // yaesu_default_swr_cal: raw 89 is 2.0:1 (FT-950 has no SWR table).
        let (proto, _) = try await meters(.Yaesu.ft950, replies: ["RM6;": "RM6089;"])
        #expect(try await proto.getSWR().swrRatio == 2.0)
    }

    @Test func ftdx9000UsesTwoDigitMeterNumbers() async throws {
        // newcat.c:5325: RM09 for SWR, RM07 for ALC. Hamlib's FTDX-9000
        // caps list no power meter, so the record doesn't either.
        let (proto, mock) = try await meters(.Yaesu.ftdx9000, replies: ["RM09;": "RM09089;", "RM07;": "RM07032;"])
        #expect(try await proto.getSWR().swrRatio == 2.0)
        #expect(try await proto.getALC().normalized == 0.5)   // yaesu_default_alc_cal 0-64
        #expect(await mock.recordedWrites == [Self.ascii("RM09;"), Self.ascii("RM07;")])
        #expect(RadioDefinition.Yaesu.ftdx9000.capabilities.supportsRFPowerMeter == false)
    }

    @Test func ft2000HalvesTheFT2000DPowerTable() async throws {
        // newcat.c:5685-5690: FT2000D table, halved on the 100 W FT-2000.
        let (proto, _) = try await meters(.Yaesu.ft2000, replies: ["RM5;": "RM5161;"])
        let reading = try await proto.getRFPowerOut()
        #expect(reading.watts == 50)
        #expect(reading.normalized == 0.5)   // Hamlib RFPOWER_METER: watts / 100
    }

    @Test func rigctldSWRReportsTheCalibratedRatio() async throws {
        let rig = try RigController(radio: .Yaesu.ft710, connection: .mock)
        try await rig.connect()
        let mock = await rig.rawProtocol.transport as! MockSerialTransport
        await mock.setResponse(for: Self.ascii("RM6;"), response: Self.ascii("RM6089000;"))
        let response = await RigctldCommandHandler(rigController: rig).handle(.getLevel(name: "SWR"))
        #expect(response.data == ["2.000000"])   // was RPRT -11: no Yaesu meters
    }
}
