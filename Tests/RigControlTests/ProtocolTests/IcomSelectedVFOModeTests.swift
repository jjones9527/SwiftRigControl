import Foundation
import Testing
@testable import RigControl

/// Icom mode and DATA-flag wire tests (v1.2.19).
///
/// - IC-7300 / IC-7300MK2 use `0x26 [vfo, mode, data, filter]` for every
///   mode set and `0x26 [vfo]` for reads (Hamlib `x25x26_always = 1`,
///   `ic7300.c:543`, `652`; frame layout `icom.c:2392-2394`). Pre-v1.2.19
///   the VFO byte was missing and voice modes went through `0x06`, which
///   left the DATA flag set.
/// - A NAK to `0x26` falls back to `0x06` + `0x1A 0x06` for the rest of
///   the connection (`icom.c:2604-2609`).
/// - The IC-7700 never gets `0x26` (`ic7700.c:153-158`).
/// - `getMode` reads the DATA flag with `0x1A 0x06` on radios without
///   `0x26` (`icom.c:2904-2952`). Pre-v1.2.19 it guessed from the `0x04`
///   filter byte, so DATA modes read back as voice modes.
@Suite struct IcomSelectedVFOModeTests {

    private static let ack: UInt8 = 0xFB
    private static let nak: UInt8 = 0xFA

    private func make(
        _ model: IcomRadioModel,
        address: UInt8,
        commandSet: StandardIcomCommandSet,
        capabilities: RigCapabilities
    ) async throws -> (MockTransport, IcomCIVProtocol) {
        let mock = MockTransport()
        let proto = IcomCIVProtocol(
            transport: mock, civAddress: address, radioModel: model,
            commandSet: commandSet, capabilities: capabilities
        )
        try await proto.connect()
        await mock.reset()
        return (mock, proto)
    }

    private func ic7300() async throws -> (MockTransport, IcomCIVProtocol) {
        try await make(.ic7300, address: 0x94, commandSet: .ic7300,
                       capabilities: RadioCapabilitiesDatabase.Icom.ic7300)
    }

    /// Controller → radio frame.
    private static func cmd(_ to: UInt8, _ body: [UInt8]) -> Data {
        Data([0xFE, 0xFE, to, 0xE0] + body + [0xFD])
    }

    /// Radio → controller frame.
    private static func reply(_ from: UInt8, _ body: [UInt8]) -> Data {
        Data([0xFE, 0xFE, 0xE0, from] + body + [0xFD])
    }

    // MARK: - IC-7300: 0x26 for every mode

    @Test func ic7300DataUSBSendsSelectedVFOModeFrame() async throws {
        let (mock, proto) = try await ic7300()
        try await proto.setMode(.dataUSB, vfo: .a)
        #expect(await mock.recordedWrites == [
            Self.cmd(0x94, [0x07, 0x00]),
            Self.cmd(0x94, [0x26, 0x00, 0x01, 0x01, 0x01]),
        ])
    }

    @Test func ic7300VoiceModeClearsDataFlagVia0x26() async throws {
        // Leaving DATA-USB for USB must clear the flag; 0x06 doesn't.
        let (mock, proto) = try await ic7300()
        try await proto.setMode(.usb, vfo: .a)
        try await proto.setMode(.cw, vfo: .a)
        let writes = await mock.recordedWrites
        #expect(writes[1] == Self.cmd(0x94, [0x26, 0x00, 0x01, 0x00, 0x01]))
        #expect(writes[3] == Self.cmd(0x94, [0x26, 0x00, 0x03, 0x00, 0x01]))
        #expect(!writes.contains { $0.count > 4 && ($0[4] == 0x06 || $0[4] == 0x1A) })
    }

    @Test func ic7300GetModeReads0x26() async throws {
        let (mock, proto) = try await ic7300()
        let query = Self.cmd(0x94, [0x26, 0x00])
        await mock.setResponse(for: query, response: Self.reply(0x94, [0x26, 0x00, 0x00, 0x01, 0x02]))
        #expect(try await proto.getMode(vfo: .a) == .dataLSB)
        await mock.setResponse(for: query, response: Self.reply(0x94, [0x26, 0x00, 0x05, 0x00, 0x01]))
        #expect(try await proto.getMode(vfo: .a) == .fm)
        await mock.setResponse(for: query, response: Self.reply(0x94, [0x26, 0x00, 0x05, 0x01, 0x01]))
        #expect(try await proto.getMode(vfo: .a) == .dataFM)
    }

    // MARK: - IC-7300: NAK fallback

    @Test func ic7300FallsBackAfter0x26Nak() async throws {
        let (mock, proto) = try await ic7300()
        await mock.setResponse(for: Self.cmd(0x94, [0x26, 0x00, 0x01, 0x01, 0x01]),
                               response: Self.reply(0x94, [Self.nak]))
        try await proto.setMode(.dataUSB, vfo: .a)
        try await proto.setMode(.usb, vfo: .a)
        #expect(await mock.recordedWrites == [
            Self.cmd(0x94, [0x07, 0x00]),
            Self.cmd(0x94, [0x26, 0x00, 0x01, 0x01, 0x01]),     // NAK
            Self.cmd(0x94, [0x06, 0x01, 0x01]),
            Self.cmd(0x94, [0x1A, 0x06, 0x01, 0x01]),
            // Second call skips 0x26 entirely.
            Self.cmd(0x94, [0x07, 0x00]),
            Self.cmd(0x94, [0x06, 0x01, 0x01]),
            Self.cmd(0x94, [0x1A, 0x06, 0x00, 0x00]),
        ])
    }

    @Test func ic7300GetModeFallsBackAfter0x26Nak() async throws {
        let (mock, proto) = try await ic7300()
        await mock.setResponse(for: Self.cmd(0x94, [0x26, 0x00]), response: Self.reply(0x94, [Self.nak]))
        await mock.setResponse(for: Self.cmd(0x94, [0x04]), response: Self.reply(0x94, [0x04, 0x01, 0x01]))
        await mock.setResponse(for: Self.cmd(0x94, [0x1A, 0x06]),
                               response: Self.reply(0x94, [0x1A, 0x06, 0x01, 0x01]))
        #expect(try await proto.getMode(vfo: .a) == .dataUSB)
    }

    @Test func reconnectRetries0x26() async throws {
        let (mock, proto) = try await ic7300()
        await mock.setResponse(for: Self.cmd(0x94, [0x26, 0x00, 0x01, 0x00, 0x01]),
                               response: Self.reply(0x94, [Self.nak]))
        try await proto.setMode(.usb, vfo: .a)
        await mock.reset()
        try await proto.connect()
        try await proto.setMode(.usb, vfo: .a)
        let writes = await mock.recordedWrites
        #expect(writes.last == Self.cmd(0x94, [0x26, 0x00, 0x01, 0x00, 0x01]))
    }

    // MARK: - IC-7300MK2

    @Test func mk2CatalogUsesOwnCommandSetAt0xB6() async throws {
        let mock = MockTransport()
        let proto = try #require(
            RadioDefinition.Icom.ic7300MK2().createProtocol(transport: mock) as? IcomCIVProtocol
        )
        try await proto.connect()
        await mock.reset()
        try await proto.setMode(.dataUSB, vfo: .a)
        #expect(await mock.recordedWrites.last == Self.cmd(0xB6, [0x26, 0x00, 0x01, 0x01, 0x01]))
        #expect(StandardIcomCommandSet.ic7300MK2.civAddress == 0xB6)
        #expect(StandardIcomCommandSet.ic7300MK2.supportsTargetableMode)
    }

    @Test func mk2MenuNumbersDifferFromIC7300() {
        // ic7300.c:323-354 and 424-430. Every setting Hamlib lists was
        // renumbered on the MK2, so reusing an IC-7300 number on an MK2
        // would change a different menu item.
        for setting in IcomMenuSetting.allCases {
            let mk1 = IcomRadioModel.ic7300.menuSettingParameter(setting)
            let mk2 = IcomRadioModel.ic7300mk2.menuSettingParameter(setting)
            #expect(mk1 != nil && mk2 != nil, "\(setting)")
            #expect(mk1 != mk2, "\(setting) must differ between IC-7300 and MK2")
        }
        #expect(IcomRadioModel.ic7300.menuSettingParameter(.usbAFLevel) == [0x00, 0x60])
        #expect(IcomRadioModel.ic7300mk2.menuSettingParameter(.usbAFLevel) == [0x00, 0x70])
        #expect(IcomRadioModel.ic7300.menuSettingParameter(.keyerType) == [0x01, 0x64])
        #expect(IcomRadioModel.ic7300mk2.menuSettingParameter(.keyerType) == [0x02, 0x24])
        #expect(IcomRadioModel.ic7300mk2.menuSettingParameter(.clockDate) == [0x01, 0x32])
        #expect(IcomRadioModel.ic7600.menuSettingParameter(.beep) == nil)
    }

    @Test func ic7300AndMK2AdvertiseTheSameModes() {
        // Hamlib ic7300_caps and ic7300mk2_caps share IC7300_ALL_RX_MODES.
        let mk1 = Set(RadioCapabilitiesDatabase.Icom.ic7300.supportedModes)
        let mk2 = Set(RadioCapabilitiesDatabase.Icom.ic7300MK2.supportedModes)
        #expect(mk1.contains(.dataFM))
        #expect(mk2.subtracting([.fmN]) == mk1)
    }

    // MARK: - IC-7700: no 0x26

    @Test func ic7700DataUSBUsesBaseModePlusDataFlag() async throws {
        let (mock, proto) = try await make(.ic7700, address: 0x74, commandSet: .ic7700,
                                           capabilities: RadioCapabilitiesDatabase.Icom.ic7700)
        try await proto.setMode(.dataUSB, vfo: .a)
        #expect(await mock.recordedWrites == [
            Self.cmd(0x74, [0x07, 0x00]),
            Self.cmd(0x74, [0x06, 0x01, 0x01]),
            Self.cmd(0x74, [0x1A, 0x06, 0x01, 0x01]),
        ])
    }

    // MARK: - 0x1A 0x06 readback on non-0x26 radios

    @Test func ic7600GetModeReadsDataFlag() async throws {
        let (mock, proto) = try await make(.ic7600, address: 0x7A, commandSet: .ic7600,
                                           capabilities: RadioCapabilitiesDatabase.Icom.ic7600)
        // 0x04 reports FIL2, not 0x00: the old filter-byte guess said USB.
        await mock.setResponse(for: Self.cmd(0x7A, [0x04]), response: Self.reply(0x7A, [0x04, 0x01, 0x02]))
        await mock.setResponse(for: Self.cmd(0x7A, [0x1A, 0x06]),
                               response: Self.reply(0x7A, [0x1A, 0x06, 0x01, 0x02]))
        #expect(try await proto.getMode(vfo: .a) == .dataUSB)

        await mock.setResponse(for: Self.cmd(0x7A, [0x1A, 0x06]),
                               response: Self.reply(0x7A, [0x1A, 0x06, 0x00, 0x00]))
        #expect(try await proto.getMode(vfo: .a) == .usb)
    }

    @Test func dataFlagNotQueriedForCW() async throws {
        let (mock, proto) = try await make(.ic7600, address: 0x7A, commandSet: .ic7600,
                                           capabilities: RadioCapabilitiesDatabase.Icom.ic7600)
        await mock.setResponse(for: Self.cmd(0x7A, [0x04]), response: Self.reply(0x7A, [0x04, 0x03, 0x01]))
        #expect(try await proto.getMode(vfo: .a) == .cw)
        let writes = await mock.recordedWrites
        #expect(!writes.contains(Self.cmd(0x7A, [0x1A, 0x06])))
    }

    @Test func dataFlagAcceptsSingleValueByte() async throws {
        // Hamlib accepts one or two value bytes (icom.c:2933-2952).
        let (mock, proto) = try await make(.ic7600, address: 0x7A, commandSet: .ic7600,
                                           capabilities: RadioCapabilitiesDatabase.Icom.ic7600)
        await mock.setResponse(for: Self.cmd(0x7A, [0x04]), response: Self.reply(0x7A, [0x04, 0x00, 0x01]))
        await mock.setResponse(for: Self.cmd(0x7A, [0x1A, 0x06]), response: Self.reply(0x7A, [0x1A, 0x06, 0x01]))
        #expect(try await proto.getMode(vfo: .a) == .dataLSB)
    }

    @Test func getDataModeIC7600ParsesReply() async throws {
        // Pre-v1.2.19 this always threw: it expected command [1A, 06].
        let (mock, proto) = try await make(.ic7600, address: 0x7A, commandSet: .ic7600,
                                           capabilities: RadioCapabilitiesDatabase.Icom.ic7600)
        await mock.setResponse(for: Self.cmd(0x7A, [0x1A, 0x06]),
                               response: Self.reply(0x7A, [0x1A, 0x06, 0x02, 0x03]))
        let result = try await proto.getDataModeIC7600()
        #expect(result.dataMode == 0x02)
        #expect(result.filter == 0x03)
    }

    // MARK: - Command-set flags

    @Test func only7300FamilyUses0x26() {
        let users = StandardIcomCommandSetVariantsTests.allVariants
            .filter { $0.make().supportsTargetableMode }
            .map(\.name)
        #expect(users.sorted() == ["ic7300", "ic7300MK2"])
    }

    @Test func targetableRadiosWithoutDataModesSendNoDataFlag() {
        // Hamlib sets data_mode_supported for none of these.
        #expect(!IC706CommandSet.ic706.requiresDataModeSubCommand)
        #expect(!IC746CommandSet.ic746.requiresDataModeSubCommand)
        #expect(!StandardIcomCommandSet.icF8101.requiresDataModeSubCommand)
        #expect(!StandardIcomCommandSet.icF8101.supportsTargetableMode)
        // The IC-7700 does support DATA, through 0x1A 0x06.
        #expect(StandardIcomCommandSet.ic7700.requiresDataModeSubCommand)
    }
}
