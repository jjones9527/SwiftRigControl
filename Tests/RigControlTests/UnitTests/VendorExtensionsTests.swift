import Foundation
import Testing
@testable import RigControl

/// Tests for Phase 5.2 — typed `VendorExtensions` discriminator
/// and the `rawProtocol` escape hatch.
///
/// These are mostly type-safety tests: confirming the right enum
/// case fires for each radio family and that `rawProtocol` still
/// returns the same actor when needed.
@Suite struct VendorExtensionsTests {

    // MARK: - vendorExtensions dispatch

    @Test func dummyRadioReportsDummyCase() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        if case .dummy = await rig.vendorExtensions {
            // pass
        } else {
            Issue.record("expected .dummy, got \(await rig.vendorExtensions)")
        }
    }

    @Test func icomRadioReportsIcomCase() async throws {
        let rig = try RigController(radio: .icomIC7600(), connection: .mock)
        try await rig.connect()
        if case .icom(let icom) = await rig.vendorExtensions {
            // Confirm we got the real actor — it should be the
            // same instance the controller holds.
            let raw = await rig.rawProtocol
            #expect((raw as? IcomCIVProtocol) === icom)
        } else {
            Issue.record("expected .icom, got \(await rig.vendorExtensions)")
        }
    }

    @Test func elecraftReportsElecraftCase() async throws {
        let rig = try RigController(radio: .elecraftK2, connection: .mock)
        try await rig.connect()
        if case .elecraft = await rig.vendorExtensions {
            // pass
        } else {
            Issue.record("expected .elecraft, got \(await rig.vendorExtensions)")
        }
    }

    // MARK: - rawProtocol escape hatch

    @Test func rawProtocolReturnsSameActor() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()

        let first = await rig.rawProtocol
        let second = await rig.rawProtocol
        // Two reads should return the same actor instance (just a
        // stored property, not a new construction).
        #expect((first as? DummyCATProtocol) === (second as? DummyCATProtocol))
    }

    @Test func vendorExtensionsAndRawProtocolAgree() async throws {
        let rig = try RigController(radio: .icomIC9700(), connection: .mock)
        try await rig.connect()

        let raw = await rig.rawProtocol as? IcomCIVProtocol
        if case .icom(let icom) = await rig.vendorExtensions {
            #expect(icom === raw)
        } else {
            Issue.record("expected .icom")
        }
    }

    // MARK: - Discriminated enum hygiene

    @Test func vendorExtensionsCaseIsExhaustive() async throws {
        // Compile-time check: a switch over VendorExtensions
        // without a default clause must cover every case. If
        // someone adds a new vendor to the enum and forgets to
        // handle it here, the build fails — that's the whole
        // point of using an enum vs. a typed property.
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        let ext = await rig.vendorExtensions
        switch ext {
        case .icom:        break
        case .elecraft:    break
        case .yaesu:       break
        case .kenwood:     break
        case .thd72:       break
        case .tentecOrion: break
        case .tentecLegacy: break
        case .dummy:       break
        case .unknown:     break
        }
    }
}
