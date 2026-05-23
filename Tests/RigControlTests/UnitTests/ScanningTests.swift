import Foundation
import Testing
@testable import RigControl

/// Tests for the Phase 4.3 scanning API.
///
/// Per-radio capability promotion is cross-checked against the
/// Hamlib `IC{model}_SCAN_OPS` macros in `rigs/icom/`.
@Suite struct ScanningTests {

    // MARK: - Dummy roundtrip

    @Test func startThenStopRoundtrip() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        let proto = await rig.rawProtocol as! DummyCATProtocol

        #expect(await proto.activeScan == nil)
        try await rig.startScan(.memory)
        #expect(await proto.activeScan == .memory)
        try await rig.stopScan()
        #expect(await proto.activeScan == nil)
    }

    @Test func startScanReplacesPreviousKind() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        let proto = await rig.rawProtocol as! DummyCATProtocol

        try await rig.startScan(.vfo)
        #expect(await proto.activeScan == .vfo)
        try await rig.startScan(.programmed)
        #expect(await proto.activeScan == .programmed)
    }

    @Test func stopScanIsIdempotent() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        // No scan running — stopping should not throw.
        try await rig.stopScan()
        try await rig.stopScan()
    }

    @Test func scanOperationsBeforeConnectThrow() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        await #expect(throws: RigError.self) {
            try await rig.startScan(.memory)
        }
        await #expect(throws: RigError.self) {
            try await rig.stopScan()
        }
    }

    // MARK: - Capability gating

    @Test func unsupportedScanKindThrowsOnIcom() async throws {
        // Build an IcomCIVProtocol with all-default capabilities
        // (no scan flags). Every scan kind should throw.
        let mock = MockSerialTransport()
        let caps = RigCapabilities()  // no scan support
        let proto = IcomCIVProtocol(
            transport: mock,
            radioModel: .ic7300,
            commandSet: StandardIcomCommandSet(civAddress: 0x94),
            capabilities: caps
        )
        try await proto.connect()

        for kind in ScanKind.allCases {
            await #expect(throws: RigError.self) {
                try await proto.startScan(kind)
            }
        }
        // stopScan should also throw — nothing scans here.
        await #expect(throws: RigError.self) {
            try await proto.stopScan()
        }
    }

    @Test func partialScanSupportGatesPerKind() async throws {
        // A radio that supports only memory scan should accept
        // .memory and reject .vfo / .programmed / etc.
        let mock = MockSerialTransport()
        let caps = RigCapabilities(supportsMemoryScan: true)
        let proto = IcomCIVProtocol(
            transport: mock,
            radioModel: .ic7300,
            commandSet: StandardIcomCommandSet(civAddress: 0x94),
            capabilities: caps
        )
        try await proto.connect()

        // .memory is supported — it tries the wire write. The mock
        // returns the default Icom ACK by default, so this succeeds.
        try await proto.startScan(.memory)

        // Every other kind should throw .unsupportedOperation
        // BEFORE any wire activity.
        for kind in ScanKind.allCases where kind != .memory {
            await #expect(throws: RigError.self) {
                try await proto.startScan(kind)
            }
        }
    }

    // MARK: - Per-radio capability promotion

    @Test func ic7100ScanCapabilities() {
        let caps = RadioCapabilitiesDatabase.icomIC7100
        // Hamlib IC7100_SCAN_OPS: VFO, MEM, SLCT, PRIO
        #expect(caps.supportsVFOScan)
        #expect(caps.supportsMemoryScan)
        #expect(caps.supportsSelectedMemoryScan)
        #expect(caps.supportsPriorityScan)
        #expect(!caps.supportsProgrammedScan)
        #expect(!caps.supportsDeltaFScan)
    }

    @Test func ic7600ScanCapabilities() {
        let caps = RadioCapabilitiesDatabase.icomIC7600
        // Hamlib IC7600_SCAN_OPS: VFO, MEM, PROG, DELTA, PRIO
        #expect(caps.supportsVFOScan)
        #expect(caps.supportsMemoryScan)
        #expect(!caps.supportsSelectedMemoryScan)
        #expect(caps.supportsPriorityScan)
        #expect(caps.supportsProgrammedScan)
        #expect(caps.supportsDeltaFScan)
    }

    @Test func ic9700ScanCapabilities() {
        let caps = RadioCapabilitiesDatabase.icomIC9700
        // Hamlib IC9700_SCAN_OPS: MEM, PROG, SLCT
        #expect(!caps.supportsVFOScan)
        #expect(caps.supportsMemoryScan)
        #expect(caps.supportsSelectedMemoryScan)
        #expect(!caps.supportsPriorityScan)
        #expect(caps.supportsProgrammedScan)
        #expect(!caps.supportsDeltaFScan)
    }

    // MARK: - ScanKind shape

    @Test func scanKindCoversAllHamlibCases() {
        // Sanity: we expose all 6 modes Hamlib defines (excluding
        // RIG_SCAN_STOP which is implicit via stopScan()).
        #expect(ScanKind.allCases.count == 6)
        for kind in ScanKind.allCases {
            // Round-trip through the raw value to confirm String
            // backing is intact (used by event serialisation, etc).
            let raw = kind.rawValue
            let recovered = ScanKind(rawValue: raw)
            #expect(recovered == kind)
        }
    }
}
