import Foundation
import Testing
@testable import RigControl

/// Verifies the public Ten-Tec `RadioDefinition` factories are
/// wired correctly — they were added in v1.1.2 after the Hamlib
/// parity audit found the protocol implementations existed but
/// had no factories to reach them.
@Suite struct TenTecRadioDefinitionsTests {

    // MARK: - Existence + basic identity

    @Test func jupiterFactoryExists() {
        let radio = RadioDefinition.TenTec.jupiter
        #expect(radio.manufacturer == .tentec)
        #expect(radio.model == "Jupiter (TT-538)")
    }

    @Test func pegasusFactoryExists() {
        let radio = RadioDefinition.TenTec.pegasus
        #expect(radio.manufacturer == .tentec)
        #expect(radio.model == "Pegasus (TT-550)")
    }

    @Test func orionFactoryExists() {
        let radio = RadioDefinition.TenTec.orion
        #expect(radio.manufacturer == .tentec)
        #expect(radio.model == "Orion (TT-565)")
    }

    @Test func orionIIFactoryExists() {
        let radio = RadioDefinition.TenTec.orionII
        #expect(radio.manufacturer == .tentec)
        #expect(radio.model == "Orion II (TT-599)")
    }

    @Test func eagleFactoryExists() {
        let radio = RadioDefinition.TenTec.eagle
        #expect(radio.manufacturer == .tentec)
        #expect(radio.model == "Eagle")
    }

    // MARK: - Baud rate + serial defaults

    /// Every Ten-Tec radio in scope for v1.1.2 uses 57600 baud per
    /// Hamlib rigs/tentec/{jupiter,pegasus,omnivii}.c and
    /// rigs/tentec/orion.h.
    @Test func allTenTecRadiosUse57600Baud() {
        let radios: [RadioDefinition] = [
            .TenTec.jupiter, .TenTec.pegasus,
            .TenTec.orion, .TenTec.orionII, .TenTec.eagle,
        ]
        for radio in radios {
            #expect(radio.defaultBaudRate == 57600, "\(radio.model): expected 57600 baud")
        }
    }

    /// All Ten-Tec radios use 8-N-1 with RTS/CTS hardware
    /// handshake per Hamlib. Pre-fix code left them at .standard
    /// which would drop bytes on sustained CAT traffic.
    @Test func allTenTecRadiosUseModernProfile() {
        let radios: [RadioDefinition] = [
            .TenTec.jupiter, .TenTec.pegasus,
            .TenTec.orion, .TenTec.orionII, .TenTec.eagle,
        ]
        for radio in radios {
            #expect(radio.serialDefaults.stopBits == 1, "\(radio.model)")
            #expect(radio.serialDefaults.hardwareFlowControl == true, "\(radio.model)")
        }
    }

    // MARK: - Verification honesty

    /// None of these radios have been hardware-verified — the
    /// protocol implementations exist and match Hamlib byte-for-byte
    /// (verified against `tentec_tuning_factor_calc` in the case
    /// of Jupiter/Pegasus), but no one has driven a real radio
    /// with them since the v1.1.2 fixes landed.
    @Test func allTenTecRadiosMarkedDefinitionOnly() {
        let radios: [RadioDefinition] = [
            .TenTec.jupiter, .TenTec.pegasus,
            .TenTec.orion, .TenTec.orionII, .TenTec.eagle,
        ]
        for radio in radios {
            #expect(radio.verificationStatus == .definition, "\(radio.model)")
        }
    }

    // MARK: - Protocol wiring

    /// The Jupiter/Pegasus factories must produce a
    /// `TenTecLegacyProtocol` (not the Orion protocol) so the
    /// tuning-factor frequency encoding actually fires.
    @Test func legacyRadiosProduceTenTecLegacyProtocol() async throws {
        for radio in [RadioDefinition.TenTec.jupiter, .TenTec.pegasus] {
            let rig = try RigController(radio: radio, connection: .mock)
            #expect(await rig.proto is TenTecLegacyProtocol, "\(radio.model)")
        }
    }

    @Test func orionRadiosProduceTenTecOrionProtocol() async throws {
        let radios = [
            RadioDefinition.TenTec.orion,
            .TenTec.orionII,
            .TenTec.eagle,
        ]
        for radio in radios {
            let rig = try RigController(radio: radio, connection: .mock)
            #expect(await rig.proto is TenTecOrionProtocol, "\(radio.model)")
        }
    }
}

/// Verifies the Elecraft K2's response timeout is bumped to 2s per
/// Hamlib `k2.c:139`, while K3 and later stay at 1s. This fixes a
/// class of spurious timeout errors on the K2 during band-change
/// frequency sets (which the K2 can take up to 500ms to complete).
@Suite struct ElecraftResponseTimeoutTests {

    @Test func k2UsesTwoSecondTimeout() async throws {
        let rig = try RigController(radio: .Elecraft.k2, connection: .mock)
        guard let proto = await rig.proto as? ElecraftProtocol else {
            Issue.record("K2 factory did not produce an ElecraftProtocol")
            return
        }
        #expect(await proto.responseTimeout == 2.0)
    }

    @Test func k3UsesOneSecondTimeout() async throws {
        let rig = try RigController(radio: .Elecraft.k3, connection: .mock)
        guard let proto = await rig.proto as? ElecraftProtocol else {
            Issue.record("K3 factory did not produce an ElecraftProtocol")
            return
        }
        #expect(await proto.responseTimeout == 1.0)
    }

    @Test func k3SUsesOneSecondTimeout() async throws {
        let rig = try RigController(radio: .Elecraft.k3S, connection: .mock)
        guard let proto = await rig.proto as? ElecraftProtocol else {
            Issue.record("K3S factory did not produce an ElecraftProtocol")
            return
        }
        #expect(await proto.responseTimeout == 1.0)
    }
}
