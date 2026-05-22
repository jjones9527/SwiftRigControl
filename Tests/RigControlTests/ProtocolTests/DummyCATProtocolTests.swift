import Testing
@testable import RigControl

/// Tests for `DummyCATProtocol` and the `.dummy(...)` factory.
///
/// These tests double as living documentation of the contract app
/// developers can rely on when wiring a dummy radio into a SwiftUI
/// preview or demo app: state set through a public API is the state
/// the next read returns.
@Suite struct DummyCATProtocolTests {

    // MARK: - Identity

    @Test func dummyFactoryProducesDummyManufacturer() {
        let radio = RadioDefinition.dummy()
        #expect(radio.manufacturer == .dummy)
        #expect(radio.model == "Dummy")
        #expect(radio.fullName == "Dummy Dummy")
        #expect(radio.verificationStatus == .definition)
    }

    @Test func customNameFlowsThrough() {
        let radio = RadioDefinition.dummy(name: "Preview Radio")
        #expect(radio.model == "Preview Radio")
    }

    @Test func customCapabilitiesAreEnforced() async throws {
        let vhfOnly = RigCapabilities(
            supportedModes: [.fm, .usb],
            frequencyRange: FrequencyRange(min: 144_000_000, max: 148_000_000)
        )
        let rig = try RigController(
            radio: .dummy(name: "VHF Dummy", capabilities: vhfOnly),
            connection: .mock
        )
        try await rig.connect()

        // In-range succeeds.
        try await rig.setFrequency(146_520_000, vfo: .a)
        let f = try await rig.frequency()
        #expect(f == 146_520_000)

        // Out-of-range fails.
        await #expect(throws: RigError.self) {
            try await rig.setFrequency(14_230_000, vfo: .a)
        }

        // Unsupported mode fails.
        await #expect(throws: RigError.self) {
            try await rig.setMode(.cw, vfo: .a)
        }
    }

    // MARK: - Connection lifecycle

    @Test func operationsBeforeConnectThrow() async throws {
        let proto = DummyCATProtocol(transport: MockSerialTransport())
        await #expect(throws: RigError.self) {
            try await proto.setFrequency(14_230_000, vfo: .a)
        }
    }

    @Test func disconnectStopsAcceptingOperations() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        try await rig.setFrequency(14_230_000, vfo: .a)
        await rig.disconnect()

        await #expect(throws: RigError.self) {
            _ = try await rig.frequency(cached: false)
        }
    }

    // MARK: - Frequency / Mode / PTT (the core SwiftUI preview path)

    @Test func setThenGetFrequencyRoundtrips() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        try await rig.setFrequency(7_074_000, vfo: .a)
        let f = try await rig.frequency(cached: false)
        #expect(f == 7_074_000)
    }

    @Test func setThenGetModeRoundtrips() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        try await rig.setMode(.cw, vfo: .a)
        let m = try await rig.mode(cached: false)
        #expect(m == .cw)
    }

    @Test func pttToggles() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        try await rig.setPTT(true)
        #expect(try await rig.isPTTEnabled() == true)
        try await rig.setPTT(false)
        #expect(try await rig.isPTTEnabled() == false)
    }

    @Test func perVFOFrequenciesAreIndependent() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        try await rig.setFrequency(14_230_000, vfo: .a)
        try await rig.setFrequency(14_195_000, vfo: .b)
        #expect(try await rig.frequency(vfo: .a, cached: false) == 14_230_000)
        #expect(try await rig.frequency(vfo: .b, cached: false) == 14_195_000)
    }

    // MARK: - Defaults sensible enough for previews

    @Test func freshDummyReportsPlausibleDefaults() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()

        let f = try await rig.frequency()
        let m = try await rig.mode()
        let ptt = try await rig.isPTTEnabled()
        let signal = try await rig.signalStrength()

        // The actual default values are implementation details, but
        // they must at least be sensible — a SwiftUI preview should
        // render something believable, not zeros across the board.
        #expect(f > 0)
        #expect(Mode.allCases.contains(m))
        #expect(ptt == false)
        #expect(signal.sUnits >= 0 && signal.sUnits <= 9)
    }

    // MARK: - Memory channels

    @Test func memoryChannelRoundtrip() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()

        let original = MemoryChannel(number: 5, frequency: 7_074_000, mode: .dataUSB, name: "FT8 40m")
        try await rig.setMemoryChannel(original)

        let recalled = try await rig.getMemoryChannel(5)
        #expect(recalled.number == 5)
        #expect(recalled.frequency == 7_074_000)
        #expect(recalled.mode == .dataUSB)
        #expect(recalled.name == "FT8 40m")
    }

    @Test func emptyMemoryChannelThrows() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        await #expect(throws: RigError.self) {
            _ = try await rig.getMemoryChannel(99)
        }
    }
}
