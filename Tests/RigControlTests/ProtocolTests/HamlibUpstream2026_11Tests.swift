import Foundation
import Testing
@testable import RigControl

/// Fixes from the Hamlib upstream review `91e7b97` → `9199f8a`
/// (2026-11-05), plus the Elecraft VFO B mode bug the K4 commits
/// surfaced.
@Suite struct HamlibUpstream2026_11Tests {

    private static func ascii(_ s: String) -> Data { Data(s.utf8) }

    // MARK: - Icom select memory scan (Hamlib bba61a9)

    @Test func selectMemoryScanSendsItsOwnSubcommand() async throws {
        let mock = MockTransport()
        let proto = IcomCIVProtocol(
            transport: mock, civAddress: 0x94, radioModel: .ic7300,
            commandSet: StandardIcomCommandSet.ic7300,
            capabilities: RadioCapabilitiesDatabase.Icom.ic7300
        )
        try await proto.connect()
        await mock.reset()
        try await proto.startScan(.selectedMemory)
        try await proto.startScan(.memory)
        #expect(await mock.recordedWrites == [
            Data([0xFE, 0xFE, 0x94, 0xE0, 0x0E, 0x23, 0xFD]),
            Data([0xFE, 0xFE, 0x94, 0xE0, 0x0E, 0x01, 0xFD]),
        ])
    }

    // MARK: - IC-7760 (Hamlib 04f897d, 4197119, dae8f61)

    @Test func ic7760HasNoAGCOffNoPriorityScanAndA12dBPreamp() throws {
        let table = try #require(IcomCIVProtocol.agcTable(for: .ic7760))
        #expect(table.first { $0.speed == .off } == nil)
        let caps = RadioCapabilitiesDatabase.Icom.ic7760
        #expect(caps.supportsPriorityScan == false)
        #expect(caps.preampLevels == [12, 20])
    }

    // MARK: - Elecraft VFO B mode (k3.c:1219-1291, kenwood.c:2945-2948)

    private func elecraft(_ radio: RadioDefinition) async throws -> (MockTransport, ElecraftProtocol) {
        let mock = MockTransport()
        let proto = try #require(radio.createProtocol(transport: mock) as? ElecraftProtocol)
        try await proto.connect()
        await mock.reset()
        await mock.setResponse(for: Self.ascii("ID;"), response: Self.ascii("ID017;"))
        return (mock, proto)
    }

    private func sets(_ mock: MockTransport) async -> [String] {
        await mock.recordedWrites.map { String(decoding: $0, as: UTF8.self) }.filter { $0 != "ID;" }
    }

    @Test func k4SetsVFOBWithMDAndDTDollar() async throws {
        let (mock, k4) = try await elecraft(.Elecraft.k4)
        try await k4.setMode(.dataUSB, vfo: .b)
        #expect(await sets(mock) == ["MD$6;", "DT$0;"])
    }

    @Test func k3SetsVFOBWithMDDollarButPlainDT() async throws {
        let (mock, k3) = try await elecraft(.Elecraft.k3)
        try await k3.setMode(.dataUSB, vfo: .b)
        try await k3.setMode(.usb, vfo: .a)
        #expect(await sets(mock) == ["MD$6;", "DT0;", "MD2;"])
    }

    @Test func k4ReadsVFOBWithDollarCommands() async throws {
        let (mock, k4) = try await elecraft(.Elecraft.k4)
        await mock.setResponse(for: Self.ascii("MD$;"), response: Self.ascii("MD$6;"))
        await mock.setResponse(for: Self.ascii("DT$;"), response: Self.ascii("DT$0;"))
        #expect(try await k4.getMode(vfo: .b) == .dataUSB)
        #expect(await sets(mock) == ["MD$;", "DT$;"])
    }

    @Test func kx3ReadsVFOBWithMDAsHamlibDoes() async throws {
        let (mock, kx3) = try await elecraft(.Elecraft.kx3)
        await mock.setResponse(for: Self.ascii("MD;"), response: Self.ascii("MD2;"))
        #expect(try await kx3.getMode(vfo: .b) == .usb)
        #expect(await sets(mock) == ["MD;"])
    }

    @Test func k2IgnoresTheVFO() async throws {
        let (mock, k2) = try await elecraft(.Elecraft.k2)
        try await k2.setMode(.usb, vfo: .b)
        #expect(await sets(mock).first?.hasPrefix("MD$") == false)
    }

    // MARK: - Icom VOX delay (1A 05 menu item; ic7760.c 720268f)

    private func icom(_ model: IcomRadioModel, _ address: UInt8, _ set: StandardIcomCommandSet,
                      _ caps: RigCapabilities) async throws -> (MockTransport, IcomCIVProtocol) {
        let mock = MockTransport()
        let proto = IcomCIVProtocol(transport: mock, civAddress: address, radioModel: model,
                                    commandSet: set, capabilities: caps)
        try await proto.connect()
        await mock.reset()
        return (mock, proto)
    }

    @Test func voxDelayIsTheMenuItemNotVOXGain() async throws {
        let (mock, proto) = try await icom(.ic7300, 0x94, .ic7300, RadioDefinition.Icom.ic7300().capabilities)
        // 50 -> 1.0 s -> 10 tenths -> BCD 0x10. Through v1.3.1 this was 14 16.
        try await proto.setVOXDelay(50)
        #expect(await mock.recordedWrites == [Data([0xFE, 0xFE, 0x94, 0xE0, 0x1A, 0x05, 0x01, 0x91, 0x10, 0xFD])])
    }

    @Test func ic7760VOXDelayUsesTheCorrectedItem() throws {
        #expect(IcomCIVProtocol.voxDelayMenuItem(for: .ic7760) == [0x03, 0x65])
        #expect(IcomCIVProtocol.voxDelayMenuItem(for: .ic7700) == [0x01, 0x82])
    }

    @Test func voxDelayReadsTenthsBack() async throws {
        let (mock, proto) = try await icom(.ic7600, 0x7A, .ic7600, RadioDefinition.Icom.ic7600().capabilities)
        await mock.setResponse(for: Data([0xFE, 0xFE, 0x7A, 0xE0, 0x1A, 0x05, 0x01, 0x67, 0xFD]),
                               response: Data([0xFE, 0xFE, 0xE0, 0x7A, 0x1A, 0x05, 0x01, 0x67, 0x20, 0xFD]))
        #expect(try await proto.getVOXDelay() == 100)
    }

    @Test func voxDelayThrowsWithoutAKnownItem() async throws {
        let (mock, proto) = try await icom(.ic718, 0x5E, .ic718, RadioDefinition.Icom.ic718().capabilities)
        await #expect(throws: RigError.self) { try await proto.setVOXDelay(50) }
        #expect(await mock.recordedWrites.isEmpty)
    }
}
