import Foundation
import Testing
@testable import RigControl

/// Verifies that per-radio ``RadioDefinition/SerialDefaults`` values
/// match the Hamlib reference and that ``RigController`` propagates
/// them through into the ``SerialConfiguration`` that would be handed
/// to the transport.
///
/// Regression test for issue #12, where every serial-connected radio
/// silently fell back to `SerialConfiguration.init` defaults (8-N-1,
/// no flow control) — correct for Icom but wrong for Yaesu HF (needs
/// 8-N-2) and desktop Kenwood (needs RTS/CTS handshake).
@Suite struct SerialDefaultsTests {

    // MARK: - Named profiles

    @Test func standardProfileIs8N1NoFlowControl() {
        let d = RadioDefinition.SerialDefaults.standard
        #expect(d.stopBits == 1)
        #expect(d.parity == .none)
        #expect(d.hardwareFlowControl == false)
        #expect(d.softwareFlowControl == false)
    }

    @Test func yaesuHFDesktopProfileIs8N2HardwareHandshake() {
        let d = RadioDefinition.SerialDefaults.yaesuHFDesktop
        #expect(d.stopBits == 2)
        #expect(d.hardwareFlowControl == true)
        #expect(d.softwareFlowControl == false)
    }

    @Test func yaesuHFPortableProfileIs8N2NoHandshake() {
        let d = RadioDefinition.SerialDefaults.yaesuHFPortable
        #expect(d.stopBits == 2)
        #expect(d.hardwareFlowControl == false)
    }

    @Test func kenwoodDesktopProfileIs8N1HardwareHandshake() {
        let d = RadioDefinition.SerialDefaults.kenwoodDesktop
        #expect(d.stopBits == 1)
        #expect(d.hardwareFlowControl == true)
    }

    @Test func kenwoodLegacyProfileIs8N2HardwareHandshake() {
        let d = RadioDefinition.SerialDefaults.kenwoodLegacy
        #expect(d.stopBits == 2)
        #expect(d.hardwareFlowControl == true)
    }

    @Test func elecraftK2ProfileIs8N2NoHandshake() {
        let d = RadioDefinition.SerialDefaults.elecraftK2
        #expect(d.stopBits == 2)
        #expect(d.hardwareFlowControl == false)
    }

    // MARK: - Yaesu per-radio profile assignments

    @Test func ftdx10UsesYaesuHFDesktopProfile() {
        let d = RadioDefinition.Yaesu.ftdx10.serialDefaults
        #expect(d.stopBits == 2)
        #expect(d.hardwareFlowControl == true)
    }

    @Test func ftdx101DAndMPUseYaesuHFDesktopProfile() {
        for radio in [RadioDefinition.Yaesu.ftdx101D, .Yaesu.ftdx101MP] {
            #expect(radio.serialDefaults.stopBits == 2)
            #expect(radio.serialDefaults.hardwareFlowControl == true)
        }
    }

    @Test func ft991AndFT991AUseYaesuHFDesktopProfile() {
        for radio in [RadioDefinition.Yaesu.ft991, .Yaesu.ft991A] {
            #expect(radio.serialDefaults.stopBits == 2)
            #expect(radio.serialDefaults.hardwareFlowControl == true)
        }
    }

    @Test func ft891UsesYaesuHFDesktopProfile() {
        let d = RadioDefinition.Yaesu.ft891.serialDefaults
        #expect(d.stopBits == 2)
        #expect(d.hardwareFlowControl == true)
    }

    @Test func ft710IsExceptionAndUsesStandard() {
        // Per Hamlib rigs/yaesu/ft710.c: 1 stop bit, no handshake.
        let d = RadioDefinition.Yaesu.ft710.serialDefaults
        #expect(d.stopBits == 1)
        #expect(d.hardwareFlowControl == false)
    }

    @Test func portableYaesuRadiosUseYaesuHFPortableProfile() {
        // FT-817/818/857/857D/897/897D — 2 stop, no handshake per
        // Hamlib rigs/yaesu/ft{817,857,897}.c.
        let radios: [RadioDefinition] = [
            .Yaesu.ft817, .Yaesu.ft818,
            .Yaesu.ft857, .Yaesu.ft857D,
            .Yaesu.ft897, .Yaesu.ft897D,
        ]
        for radio in radios {
            #expect(radio.serialDefaults.stopBits == 2)
            #expect(radio.serialDefaults.hardwareFlowControl == false)
        }
    }

    // MARK: - Kenwood per-radio profile assignments

    @Test func desktopKenwoodRadiosUseKenwoodDesktopProfile() {
        let radios: [RadioDefinition] = [
            .Kenwood.ts990S,
            .Kenwood.ts590SG,
            .Kenwood.ts590S,
            .Kenwood.ts2000,
            // Added in this batch — Hamlib ts570.c specifies HARDWARE handshake.
            .Kenwood.ts570D,
            .Kenwood.ts570S,
            // Added in this batch — Hamlib thd72.c specifies HARDWARE handshake.
            .Kenwood.thd72,
            .Kenwood.thd72A,
        ]
        for radio in radios {
            #expect(radio.serialDefaults.stopBits == 1)
            #expect(radio.serialDefaults.hardwareFlowControl == true)
        }
    }

    @Test func ts850UsesKenwoodLegacyProfile() {
        // Per Hamlib rigs/kenwood/ts850.c — 8-N-2 + HARDWARE handshake.
        let d = RadioDefinition.Kenwood.ts850S.serialDefaults
        #expect(d.stopBits == 2)
        #expect(d.hardwareFlowControl == true)
    }

    @Test func elecraftK2UsesElecraftK2Profile() {
        // Per Hamlib rigs/kenwood/k2.c — 8-N-2, no handshake.
        let d = RadioDefinition.Elecraft.k2.serialDefaults
        #expect(d.stopBits == 2)
        #expect(d.hardwareFlowControl == false)
    }

    @Test func lab599TX500UsesLockedBaudRate() {
        // Hamlib rigs/kenwood/tx500.c locks baud to 9600.
        // Pre-fix code shipped 115200 which the TX-500 firmware rejects.
        #expect(RadioDefinition.Lab599.tx500.defaultBaudRate == 9600)
    }

    @Test func ts480UsesStandardProfile() {
        // Per Hamlib rigs/kenwood/ts480.c — no handshake needed.
        let d = RadioDefinition.Kenwood.ts480SAT.serialDefaults
        #expect(d.stopBits == 1)
        #expect(d.hardwareFlowControl == false)
    }

    // MARK: - Icom stays on standard

    @Test func icomRadiosUseStandardProfile() {
        // Icom CI-V is uniformly 8-N-1 with no flow control across
        // every supported model. This is what the pre-issue-#12
        // defaults produced, which is why Icom hardware validators
        // continued to pass while Yaesu was broken.
        let radios: [RadioDefinition] = [
            .Icom.ic7100(),
            .Icom.ic7600(),
            .Icom.ic9700(),
            .Icom.ic7300(),
        ]
        for radio in radios {
            #expect(radio.serialDefaults.stopBits == 1)
            #expect(radio.serialDefaults.hardwareFlowControl == false)
            #expect(radio.serialDefaults.parity == .none)
        }
    }

    // MARK: - RigController wiring

    @Test func rigControllerBuildsFtdx10SerialConfigurationWithYaesuProfile() {
        // End-to-end wiring: RigController.buildSerialConfiguration
        // must translate the radio's serialDefaults into the
        // SerialConfiguration that IOKitSerialPort receives.
        // Regression guard for the original bug in issue #12 where
        // this step dropped stopBits and hardwareFlowControl.
        let config = RigController.buildSerialConfiguration(
            radio: .Yaesu.ftdx10,
            path: "/dev/cu.SLAB_USBtoUART10",
            baudRateOverride: nil
        )
        #expect(config.path == "/dev/cu.SLAB_USBtoUART10")
        #expect(config.baudRate == 38400)
        #expect(config.dataBits == 8)
        #expect(config.stopBits == 2)
        #expect(config.parity == .none)
        #expect(config.hardwareFlowControl == true)
        #expect(config.softwareFlowControl == false)
    }

    @Test func rigControllerRespectsBaudRateOverride() {
        let config = RigController.buildSerialConfiguration(
            radio: .Yaesu.ftdx10,
            path: "/dev/cu.usbserial",
            baudRateOverride: 19200
        )
        #expect(config.baudRate == 19200)
        // Serial framing profile still applies even when baud is overridden.
        #expect(config.stopBits == 2)
        #expect(config.hardwareFlowControl == true)
    }

    @Test func rigControllerBuildsIcomSerialConfigurationAsStandard() {
        let config = RigController.buildSerialConfiguration(
            radio: .Icom.ic7600(),
            path: "/dev/cu.usbserial-A1B2C3",
            baudRateOverride: nil
        )
        #expect(config.stopBits == 1)
        #expect(config.hardwareFlowControl == false)
    }
}
