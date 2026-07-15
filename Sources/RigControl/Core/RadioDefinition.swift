import Foundation

/// Represents a specific radio model with its protocol and capabilities.
public struct RadioDefinition: Sendable {
    /// Radio manufacturer
    public let manufacturer: Manufacturer

    /// Radio model name
    public let model: String

    /// Default baud rate for this radio
    public let defaultBaudRate: Int

    /// Radio capabilities
    public let capabilities: RigCapabilities

    /// CI-V address (for Icom radios)
    public let civAddress: UInt8?

    /// How thoroughly this radio definition has been validated.
    ///
    /// See ``VerificationStatus`` for the meaning of each value. A
    /// ``VerificationStatus/definition`` radio may work — but no one
    /// from the SwiftRigControl project has verified it against the
    /// real hardware.
    public let verificationStatus: VerificationStatus

    /// Serial-port termios defaults for this radio — stop bits,
    /// parity, and hardware/software flow control.
    ///
    /// ``defaultBaudRate`` covers baud; everything else lives here.
    /// Most modern CAT interfaces work with ``SerialDefaults/standard``
    /// (8-N-1, no flow control). Yaesu HF radios and desktop Kenwood
    /// rigs need different settings — see the named profiles on
    /// ``SerialDefaults``.
    public let serialDefaults: SerialDefaults

    /// Protocol factory closure
    private let protocolFactory: @Sendable (any SerialTransport) -> any CATProtocol

    /// The manufacturer of a radio. The raw value is a
    /// human-readable name suitable for display in UI.
    public enum Manufacturer: String, Sendable {
        case icom = "Icom"
        case elecraft = "Elecraft"
        case yaesu = "Yaesu"
        case kenwood = "Kenwood"
        case xiegu = "Xiegu"
        case tentec = "Ten-Tec"
        case lab599 = "Lab599"
        case flex = "FlexRadio"

        /// Generic in-memory dummy radio (no real manufacturer). Used
        /// by `RadioDefinition.dummy(...)` for previews, demo apps,
        /// and tutorials. The Swift analogue of Hamlib's Model 1.
        case dummy = "Dummy"
    }

    /// Indicates how thoroughly a radio definition has been validated.
    ///
    /// SwiftRigControl ships definitions for many more radios than the
    /// maintainers own. This field lets callers (and the UI of apps
    /// built on top) tell users whether a given radio has actually been
    /// exercised against real hardware, or whether it is paper-only.
    public enum VerificationStatus: String, Sendable, CaseIterable {
        /// Exercised against the real radio via the matching validator
        /// in `HardwareValidation/`. Frequency, mode, PTT, and at least
        /// one read-back operation are confirmed working.
        case hardware

        /// Protocol, capabilities, and command set are implemented —
        /// typically cross-referenced against the manufacturer manual
        /// and Hamlib source — but no real-hardware verification has
        /// been performed. May work; not proven.
        case definition

        /// Human-readable label suitable for UI display.
        public var displayName: String {
            switch self {
            case .hardware:   return "Hardware verified"
            case .definition: return "Definition only"
            }
        }
    }

    /// Per-radio serial-port termios settings that ``defaultBaudRate``
    /// does not cover: stop bits, parity, and flow control.
    ///
    /// The `SerialConfiguration` fed to `IOKitSerialPort` was
    /// historically built with the radio's `defaultBaudRate` and the
    /// `SerialConfiguration.init` defaults for everything else, which
    /// hard-coded 8-N-1 with no flow control. That is correct for Icom
    /// CI-V, Elecraft K3/KX2/KX3/K4, TS-480, and most other modern
    /// radios — but wrong for Yaesu HF radios (which need 8-N-2) and
    /// for desktop Kenwood rigs (which need hardware handshake).
    ///
    /// Values here should mirror Hamlib's per-radio `serial_stop_bits`
    /// and `serial_handshake` fields (`~/Developer/hamlib/rigs/`),
    /// which is the compatibility ground truth for the same radios
    /// under WSJT-X / fldigi / rigctld.
    public struct SerialDefaults: Sendable {
        /// Stop bits (1 or 2). Yaesu HF radios uniformly need 2.
        public let stopBits: Int

        /// Parity. Every currently-supported radio uses `.none`; the
        /// field exists so a future radio needing even/odd parity does
        /// not force a source-breaking init change.
        public let parity: SerialConfiguration.Parity

        /// `true` when the radio's CAT interface uses RTS/CTS. Enabled
        /// for Yaesu HF desktop rigs and desktop Kenwood rigs.
        public let hardwareFlowControl: Bool

        /// `true` when the radio's CAT interface uses XON/XOFF. No
        /// currently-supported radio needs this.
        public let softwareFlowControl: Bool

        public init(
            stopBits: Int = 1,
            parity: SerialConfiguration.Parity = .none,
            hardwareFlowControl: Bool = false,
            softwareFlowControl: Bool = false
        ) {
            self.stopBits = stopBits
            self.parity = parity
            self.hardwareFlowControl = hardwareFlowControl
            self.softwareFlowControl = softwareFlowControl
        }

        /// 8-N-1, no flow control. Correct for Icom CI-V (all
        /// supported models), Elecraft K3/K3S/K4/KX2/KX3, Kenwood
        /// TS-480 and TS-890S, Yaesu FT-710, and every FlexRadio /
        /// Xiegu / Lab599 model in the catalog.
        public static let standard = SerialDefaults()

        /// 8-N-2 with RTS/CTS hardware flow control. Yaesu HF desktop
        /// profile — FT-DX10, FT-DX101(D/MP), FT-991(A), FT-891,
        /// FT-950, FT-2000, FT-DX1200/3000/5000/9000, FT-450(D).
        ///
        /// Source: Hamlib `rigs/yaesu/ftdx10.c` and friends —
        /// `.serial_stop_bits = 2, .serial_handshake = HARDWARE`.
        public static let yaesuHFDesktop = SerialDefaults(
            stopBits: 2,
            hardwareFlowControl: true
        )

        /// 8-N-2, no flow control. Yaesu portable / mobile profile —
        /// FT-817(ND), FT-818, FT-857(D), FT-897(D), FT-847, FT-920,
        /// FT-100, FT-1000MP. These radios need 2 stop bits like the
        /// rest of the Yaesu family, but their CAT interfaces do not
        /// have RTS/CTS lines.
        ///
        /// Source: Hamlib `rigs/yaesu/ft817.c` and friends —
        /// `.serial_stop_bits = 2, .serial_handshake = NONE`.
        public static let yaesuHFPortable = SerialDefaults(stopBits: 2)

        /// 8-N-1 with RTS/CTS hardware flow control. Desktop Kenwood
        /// profile — TS-590(S/SG), TS-990S, TS-2000, TS-570(D/S),
        /// TH-D72(A).
        ///
        /// Source: Hamlib `rigs/kenwood/ts590.c` and friends —
        /// `.serial_stop_bits = 1, .serial_handshake = HARDWARE`.
        public static let kenwoodDesktop = SerialDefaults(
            hardwareFlowControl: true
        )

        /// 8-N-2 with RTS/CTS hardware flow control. Legacy Kenwood
        /// desktop HF profile — TS-850S.
        ///
        /// The TS-850S is a 1990s-era HF transceiver whose CAT
        /// interface predates the 8-N-1 convention Kenwood adopted
        /// for the TS-570 forward. Second stop bit + hardware
        /// handshake is required for reliable communication.
        ///
        /// Source: Hamlib `rigs/kenwood/ts850.c` —
        /// `.serial_stop_bits = 2, .serial_handshake = HARDWARE`.
        public static let kenwoodLegacy = SerialDefaults(
            stopBits: 2,
            hardwareFlowControl: true
        )

        /// 8-N-2, no flow control. Elecraft K2 profile.
        ///
        /// The K2 predates Elecraft's move to 8-N-1 for the K3 and
        /// later. Hamlib specifies 8-N-2 for the K2's CAT interface;
        /// SwiftRigControl shipped 8-N-1 through v1.1.1 and the K2
        /// was hardware-verified against that (likely because the
        /// K2's ATmega UART is tolerant of variable stop-bit
        /// counts). This profile brings the K2 in line with Hamlib
        /// and is what future K2 validators should test against.
        ///
        /// Source: Hamlib `rigs/kenwood/k2.c` —
        /// `.serial_stop_bits = 2, .serial_handshake = NONE`.
        public static let elecraftK2 = SerialDefaults(stopBits: 2)

        /// 8-N-1 with RTS/CTS hardware flow control. Ten-Tec
        /// profile — Jupiter (TT-538), Pegasus (TT-550), Orion
        /// (TT-565), Orion II (TT-599), Eagle, Omni VII.
        ///
        /// Hamlib specifies hardware handshake uniformly across
        /// the Ten-Tec HF line — the CAT ports on these radios do
        /// rely on RTS/CTS for reliable operation at 57600 baud.
        /// (The legacy Argonaut is the exception, running at
        /// 1200 baud without handshake — it uses `.standard`.)
        ///
        /// Source: Hamlib `rigs/tentec/{jupiter,pegasus}.c`,
        /// `rigs/tentec/orion.h`, `rigs/tentec/omnivii.c` —
        /// `.serial_stop_bits = 1, .serial_handshake = HARDWARE`.
        public static let tentecModern = SerialDefaults(
            hardwareFlowControl: true
        )
    }

    /// Initializes a new radio definition.
    ///
    /// - Parameters:
    ///   - manufacturer: Radio manufacturer (Icom, Yaesu, etc.).
    ///   - model: Radio model name (e.g. "IC-7600").
    ///   - defaultBaudRate: Default CAT baud rate for this radio.
    ///   - capabilities: Radio capability flags and limits.
    ///   - civAddress: CI-V bus address for Icom radios; `nil` otherwise.
    ///   - verificationStatus: How thoroughly this definition has been
    ///     validated. Defaults to ``VerificationStatus/definition``.
    ///     Set to ``VerificationStatus/hardware`` only for radios that
    ///     have been exercised against the real hardware via a
    ///     `HardwareValidation/` validator.
    ///   - serialDefaults: Per-radio serial-port settings for stop
    ///     bits, parity, and flow control. Defaults to
    ///     ``SerialDefaults/standard`` (8-N-1, no flow control), which
    ///     is correct for Icom CI-V, Elecraft K3/KX-series, TS-480,
    ///     and any other modern CAT interface. Set to a different
    ///     profile only when Hamlib or the manufacturer manual says
    ///     the radio needs different framing — see the named profiles
    ///     on ``SerialDefaults``.
    ///   - protocolFactory: Closure that builds a `CATProtocol`
    ///     conformer over a given transport.
    public init(
        manufacturer: Manufacturer,
        model: String,
        defaultBaudRate: Int,
        capabilities: RigCapabilities,
        civAddress: UInt8? = nil,
        verificationStatus: VerificationStatus = .definition,
        serialDefaults: SerialDefaults = .standard,
        protocolFactory: @escaping @Sendable (any SerialTransport) -> any CATProtocol
    ) {
        self.manufacturer = manufacturer
        self.model = model
        self.defaultBaudRate = defaultBaudRate
        self.capabilities = capabilities
        self.civAddress = civAddress
        self.verificationStatus = verificationStatus
        self.serialDefaults = serialDefaults
        self.protocolFactory = protocolFactory
    }

    /// Creates a protocol instance for this radio.
    public func createProtocol(transport: any SerialTransport) -> any CATProtocol {
        protocolFactory(transport)
    }

    /// Full radio name (manufacturer + model)
    public var fullName: String {
        "\(manufacturer.rawValue) \(model)"
    }

    // MARK: - Vendor namespaces
    //
    // Radio factories are organised by manufacturer. Typing
    // `RadioDefinition.Icom.` in Xcode autocomplete filters to
    // only Icom radios. The per-vendor `<Vendor>Models.swift`
    // files extend the matching namespace below.

    /// Icom CI-V radios — HF transceivers, satellite radios,
    /// D-STAR handhelds, and wideband receivers.
    public enum Icom {}

    /// Yaesu transceivers — FTDX flagships, FT mid-range, and
    /// portable QRP rigs.
    public enum Yaesu {}

    /// Kenwood text-protocol transceivers — TS HF series,
    /// TM mobiles, and TH handhelds.
    public enum Kenwood {}

    /// Elecraft K-series — K2, K3, K3S, K4, KX2, KX3.
    public enum Elecraft {}

    /// Xiegu CI-V-compatible HF SDR transceivers — G90, X6100,
    /// X6200.
    public enum Xiegu {}

    /// Ten-Tec — Orion, Eagle, Jupiter, Pegasus.
    public enum TenTec {}

    /// Lab599 — TX-500 portable HF transceiver using a
    /// Kenwood-compatible CAT.
    public enum Lab599 {}

    /// FlexRadio Systems and compatible SDRs (PowerSDR, Thetis)
    /// that share the Kenwood-derived CAT command set documented
    /// in Hamlib `kenwood/flex6xxx.c`.
    public enum Flex {}
}

// MARK: - Connection Type

/// Represents different ways to connect to a radio.
public enum ConnectionType {
    /// Serial port connection over a `/dev/cu.*` device.
    case serial(path: String, baudRate: Int? = nil)

    /// TCP connection to a remote CAT endpoint.
    ///
    /// Use for Flex 6000-series radios (SmartSDR exposes CAT on
    /// port 4992) and for bridging to a remote `rigctld` /
    /// ``RigControlServer`` instance (default port 4532). The
    /// underlying ``CATProtocol`` does not know the bytes come
    /// from a socket instead of a serial port.
    case tcp(host: String, port: UInt16)

    /// In-memory transport with no real I/O.
    ///
    /// Pair with `RadioDefinition.dummy(...)` for SwiftUI previews,
    /// demo apps, and tutorials — the controller behaves like a real
    /// radio you can `setFrequency` / `setMode` / `setPTT` against,
    /// but never touches a serial port.
    ///
    /// Pair with a real radio definition (e.g. `.Icom.ic7600()`) for
    /// protocol-level testing: the radio's `CATProtocol` actually
    /// runs and produces byte sequences you can inspect through the
    /// underlying ``MockSerialTransport``.
    case mock
}
