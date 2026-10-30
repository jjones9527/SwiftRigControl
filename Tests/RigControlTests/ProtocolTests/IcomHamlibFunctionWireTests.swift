import Foundation
import Testing
@testable import RigControl

/// Icom function and VFO-op bytes that differed from Hamlib `91e7b97`
/// (found with `Scripts/hamlib-set-matrix.py --tx`, 2026-10-30), and the
/// capabilities synced from Hamlib's caps by `Scripts/hamlib-caps-sync.py`.
@Suite struct IcomHamlibFunctionWireTests {

    private func make(_ radio: RadioDefinition) async throws -> (RigController, IcomCIVProtocol, MockSerialTransport, UInt8) {
        let rig = try RigController(radio: radio, connection: .mock)
        try await rig.connect()
        let proto = try #require(await rig.rawProtocol as? IcomCIVProtocol)
        let mock = await proto.transport as! MockSerialTransport
        await mock.reset()
        return (rig, proto, mock, await proto.civAddress)
    }

    private func frame(_ address: UInt8, _ body: [UInt8]) -> Data {
        Data([0xFE, 0xFE, address, 0xE0] + body + [0xFD])
    }

    private func ack(_ address: UInt8) -> Data {
        Data([0xFE, 0xFE, 0xE0, address, 0xFB, 0xFD])
    }

    /// Sends one operation and returns whether exactly `body` went out.
    private func sends(_ body: [UInt8], on radio: RadioDefinition,
                       _ operation: (IcomCIVProtocol) async throws -> Void) async throws -> Bool {
        let (_, proto, mock, address) = try await make(radio)
        await mock.setResponse(for: frame(address, body), response: ack(address))
        try await operation(proto)
        return await mock.recordedWrites.contains(frame(address, body))
    }

    // MARK: - Wire bytes

    @Test func voiceSquelchIs16_4C() async throws {
        // icom_defs.h:334 S_FUNC_VSC 0x4C; we sent 0x4D.
        #expect(try await sends([0x16, 0x4C, 0x01], on: .Icom.ic7300()) {
            try await $0.setFunction(.voiceSquelch, enabled: true)
        })
    }

    @Test func dualWatchIs07C1ExceptOnThe9100Family() async throws {
        // icom.c:7290-7303.
        #expect(try await sends([0x07, 0xC1], on: .Icom.ic7600()) {
            try await $0.setFunction(.dualWatch, enabled: true)
        })
        #expect(try await sends([0x07, 0xC0], on: .Icom.ic7600()) {
            try await $0.setFunction(.dualWatch, enabled: false)
        })
        #expect(try await sends([0x16, 0x59, 0x01], on: .Icom.ic9700()) {
            try await $0.setFunction(.dualWatch, enabled: true)
        })
    }

    @Test func satelliteModeOnTheIC910HIs1A07() async throws {
        // icom.c:7312-7323 S_MEM_SATMODE910.
        #expect(try await sends([0x1A, 0x07, 0x01], on: .Icom.ic910H()) {
            try await $0.setFunction(.satelliteMode, enabled: true)
        })
        #expect(try await sends([0x16, 0x5A, 0x01], on: .Icom.ic9700()) {
            try await $0.setFunction(.satelliteMode, enabled: true)
        })
    }

    @Test func copyIsMainEqualsSubOnMainSubRadios() async throws {
        // icom.c:8773-8791: S_SUBTOMAIN without A/B VFOs, S_BTOA with them.
        #expect(try await sends([0x07, 0xB1], on: .Icom.ic7600()) {
            try await $0.performVFOOperation(.copyVFO)
        })
        #expect(try await sends([0x07, 0xB1], on: .Icom.ic7851()) {
            try await $0.performVFOOperation(.copyVFO)
        })
        #expect(try await sends([0x07, 0xA0], on: .Icom.ic7300()) {
            try await $0.performVFOOperation(.copyVFO)
        })
        #expect(try await sends([0x07, 0xA0], on: .Icom.ic7700()) {
            try await $0.performVFOOperation(.copyVFO)
        })
    }

    // MARK: - Capabilities synced from Hamlib

    @Test func ic7300AdvertisesWhatHamlibLists() {
        // IC7300_LEVELS / IC7300_SCAN_OPS (ic7300.c:52, :109).
        let caps = RadioDefinition.Icom.ic7300().capabilities
        #expect(caps.supportsCWKeyer && caps.supportsSendCW)
        #expect(caps.supportsSWRMeter && caps.supportsALCMeter && caps.supportsRFPowerMeter)
        #expect(caps.supportsCompMeter && caps.supportsVoltageMeter && caps.supportsCurrentMeter)
        #expect(caps.supportsVFOScan && caps.supportsMemoryScan && caps.supportsProgrammedScan)
        #expect(caps.preampLevels == [1, 2])
    }

    @Test func preampListsComeFromHamlib() {
        #expect(RadioDefinition.Icom.ic7600().capabilities.preampLevels == [10, 16])
        #expect(RadioDefinition.Icom.ic7610().capabilities.preampLevels == [12, 20])
        #expect(RadioDefinition.Xiegu.g90.capabilities.preampLevels == [10])
    }

    @Test func swrMeterReadsThroughRigctld() async throws {
        // Was RPRT -11 because supportsSWRMeter was false.
        let (rig, _, mock, address) = try await make(.Icom.ic7300())
        await mock.setResponse(for: frame(address, [0x15, 0x12]),
                               response: Data([0xFE, 0xFE, 0xE0, address, 0x15, 0x12, 0x00, 0x48, 0xFD]))
        let response = await RigctldCommandHandler(rigController: rig).handle(.getLevel(name: "SWR"))
        #expect(response.returnCode == .ok)
        #expect(await mock.recordedWrites.contains(frame(address, [0x15, 0x12])))
    }

    @Test func preampDBReachesTheIC7600() async throws {
        let (rig, _, mock, address) = try await make(.Icom.ic7600())
        await mock.setResponse(for: frame(address, [0x16, 0x02, 0x02]), response: ack(address))
        let response = await RigctldCommandHandler(rigController: rig).handle(.setLevel(name: "PREAMP", value: "16"))
        #expect(response.returnCode == .ok)
        #expect(await mock.recordedWrites.contains(frame(address, [0x16, 0x02, 0x02])))   // matches Hamlib
    }
}
