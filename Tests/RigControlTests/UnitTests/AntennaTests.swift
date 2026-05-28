import Foundation
import Testing
@testable import RigControl

/// Tests for the Phase 4.4 antenna-selection API.
///
/// Per-radio capability promotion is cross-checked against
/// Hamlib's `IC{model}_ANTS` and `K2_ANTS` macros.
@Suite struct AntennaTests {

    // MARK: - Dummy roundtrip

    @Test func selectAndGetRoundtripsOnMultiAntennaDummy() async throws {
        // Build a dummy with antennaCount=2 to enable the API.
        let caps = RigCapabilities(antennaCount: 2)
        let rig = try RigController(
            radio: .dummy(name: "Test", capabilities: caps),
            connection: .mock
        )
        try await rig.connect()

        try await rig.selectAntenna(1)
        #expect(try await rig.antenna() == 1)

        try await rig.selectAntenna(2)
        #expect(try await rig.antenna() == 2)
    }

    @Test func singleAntennaDummyThrowsUnsupported() async throws {
        // Default dummy has antennaCount=1.
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        await #expect(throws: RigError.self) {
            try await rig.selectAntenna(1)
        }
        await #expect(throws: RigError.self) {
            _ = try await rig.antenna()
        }
    }

    @Test func outOfRangeIndexThrowsInvalidParameter() async throws {
        let caps = RigCapabilities(antennaCount: 2)
        let rig = try RigController(
            radio: .dummy(name: "Test", capabilities: caps),
            connection: .mock
        )
        try await rig.connect()
        await #expect(throws: RigError.self) {
            try await rig.selectAntenna(0)
        }
        await #expect(throws: RigError.self) {
            try await rig.selectAntenna(3)
        }
    }

    @Test func operationsBeforeConnectThrow() async throws {
        let caps = RigCapabilities(antennaCount: 2)
        let rig = try RigController(
            radio: .dummy(name: "Test", capabilities: caps),
            connection: .mock
        )
        await #expect(throws: RigError.self) {
            try await rig.selectAntenna(1)
        }
        await #expect(throws: RigError.self) {
            _ = try await rig.antenna()
        }
    }

    @Test func defaultDummyHasSingleAntenna() {
        let caps = RigCapabilities()
        #expect(caps.antennaCount == 1)
    }

    @Test func antennaCountClampsToOneIfZeroOrNegative() {
        let caps = RigCapabilities(antennaCount: 0)
        #expect(caps.antennaCount == 1)
        let neg = RigCapabilities(antennaCount: -3)
        #expect(neg.antennaCount == 1)
    }

    // MARK: - Per-radio capability promotion (Hamlib cross-check)

    @Test func ic7100HasTwoAntennas() {
        // Hamlib IC7100_HF_ANTS = RIG_ANT_1 | RIG_ANT_2.
        #expect(RadioCapabilitiesDatabase.Icom.ic7100.antennaCount == 2)
    }

    @Test func ic7600HasTwoAntennas() {
        // Hamlib IC7600_ANTS = RIG_ANT_1 | RIG_ANT_2.
        #expect(RadioCapabilitiesDatabase.Icom.ic7600.antennaCount == 2)
    }

    @Test func ic9700HasOneAntenna() {
        // IC-9700 has per-band hardware jacks but no
        // software-selectable antenna routing. Hamlib does not
        // define IC9700_ANTS — we treat as single antenna.
        #expect(RadioCapabilitiesDatabase.Icom.ic9700.antennaCount == 1)
    }

    @Test func k2HasTwoAntennas() {
        // Hamlib K2_ANTS = RIG_ANT_1 | RIG_ANT_2 — requires KAT-2
        // internal or KAT100 external tuner. Capability flag
        // advertises potential support; operators without the
        // tuner installed will see commandFailed at runtime.
        #expect(RadioCapabilitiesDatabase.Elecraft.k2.antennaCount == 2)
    }

    // MARK: - IcomCIVProtocol gating (capability not advertised → throws)

    @Test func icomSingleAntennaThrowsOnSelect() async throws {
        let mock = MockSerialTransport()
        let caps = RigCapabilities()  // antennaCount = 1
        let proto = IcomCIVProtocol(
            transport: mock,
            radioModel: .ic7300,
            commandSet: StandardIcomCommandSet(civAddress: 0x94),
            capabilities: caps
        )
        try await proto.connect()
        await #expect(throws: RigError.self) {
            try await proto.selectAntenna(1)
        }
    }

    @Test func icomOutOfRangeThrowsInvalidParameter() async throws {
        let mock = MockSerialTransport()
        let caps = RigCapabilities(antennaCount: 2)
        let proto = IcomCIVProtocol(
            transport: mock,
            radioModel: .ic7600,
            commandSet: StandardIcomCommandSet(civAddress: 0x7A),
            capabilities: caps
        )
        try await proto.connect()
        await #expect(throws: RigError.self) {
            try await proto.selectAntenna(5)
        }
    }
}
