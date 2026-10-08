import Foundation

/// Standard CI-V command set for most Icom radios.
///
/// This command set implements the "standard" CI-V protocol used by the majority of Icom radios.
/// It uses the `IcomRadioCommandSet` protocol with sensible defaults that work for ~90% of radios.
///
/// ## Standard CI-V Characteristics
/// - **Mode Filter**: REQUIRED - Mode commands include filter byte
/// - **Command Echo**: NO - Most radios don't echo commands
/// - **VFO Model**: Configurable (targetable, currentOnly, or mainSub)
/// - **Power Display**: Percentage (0-100%) for all Icom radios
///
/// ## Radios Using This Command Set
/// This command set is suitable for:
/// - **HF transceivers**: IC-7300, IC-7610, IC-7600, IC-7700, IC-7800, IC-7200, IC-7410
/// - **HF/VHF transceivers**: IC-9100, IC-746PRO, IC-7000
/// - **VHF/UHF mobiles**: ID-5100, ID-4100
/// - **Receivers**: IC-R8600, IC-R75, IC-R9500
///
/// ## Exceptions (Don't Use This)
/// - **IC-7100/IC-705**: Use `IC7100CommandSet` (no filter byte, echoes commands)
/// - **IC-9700**: Use `IC9700CommandSet` (uses Main/Sub VFO model)
///
/// ## Customization
/// You can customize behavior by passing parameters to the initializer:
/// ```swift
/// // IC-7200 (operates on current VFO, requires filter)
/// let ic7200 = StandardIcomCommandSet(
///     civAddress: 0x76,
///     vfoModel: .currentOnly,
///     echoesCommands: false
/// )
///
/// // IC-7610 (can target VFO, dual receiver capable)
/// let ic7610 = StandardIcomCommandSet(
///     civAddress: 0x98,
///     vfoModel: .mainSub,  // Has dual receiver
///     echoesCommands: false
/// )
/// ```
///
/// ## Implementation
/// Uses `IcomRadioCommandSet` protocol with all methods inherited from default implementations.
/// Only properties need to be set - zero code duplication!
public struct StandardIcomCommandSet: IcomRadioCommandSet {
    public let civAddress: UInt8
    public let vfoModel: VFOOperationModel
    public let requiresModeFilter: Bool
    public let echoesCommands: Bool
    public let powerUnits: PowerUnits
    /// Whether the radio supports DATA modes (`false` on IC-7000, per Hamlib `.data_mode_supported = 0`).
    public let supportsDataMode: Bool
    /// Whether the radio accepts `0x26` (`true` on IC-7300 / IC-7300MK2).
    /// See ``IcomRadioCommandSet/acceptsSelectedVFOModeCommand``.
    public let acceptsSelectedVFOModeCommand: Bool

    /// Initialize a standard Icom command set.
    /// - Parameters:
    ///   - civAddress: Radio's CI-V address
    ///   - vfoModel: VFO operation model (default: .targetable)
    ///   - requiresModeFilter: Whether mode commands need filter byte (default: true)
    ///   - echoesCommands: Whether radio echoes commands (default: false)
    ///   - supportsDataMode: Whether the radio implements DATA sub-modes
    ///     via the `0x1A 0x06` follow-up (default: true; set `false` for
    ///     the IC-7000 and any other Hamlib
    ///     `data_mode_supported = 0` radio).
    ///   - acceptsSelectedVFOModeCommand: Whether the radio accepts
    ///     `0x26` (default: false; Hamlib enables it only for
    ///     `x25x26_always` / `x25x26_possibly` radios). Has an effect only
    ///     with `vfoModel: .targetable`.
    public init(
        civAddress: UInt8,
        vfoModel: VFOOperationModel = .targetable,
        requiresModeFilter: Bool = true,
        echoesCommands: Bool = false,
        supportsDataMode: Bool = true,
        acceptsSelectedVFOModeCommand: Bool = false
    ) {
        self.civAddress = civAddress
        self.vfoModel = vfoModel
        self.requiresModeFilter = requiresModeFilter
        self.echoesCommands = echoesCommands
        self.powerUnits = .percentage  // All Icom radios use percentage
        self.supportsDataMode = supportsDataMode
        self.acceptsSelectedVFOModeCommand = acceptsSelectedVFOModeCommand
    }

    // All command methods inherited from IcomRadioCommandSet protocol extension!
    // No need to implement:
    // - selectVFOCommand() - automatic based on vfoModel
    // - setModeCommand() - automatic based on requiresModeFilter
    // - setPowerCommand() - standard percentage format
    // - setPTTCommand() - standard PTT
    // - setFrequencyCommand() - standard BCD encoding
    // - All parse methods - standard CI-V response parsing
}

// MARK: - Convenience Initializers for Specific Radios

// DATA sub-modes (`supportsDataMode`) follow Hamlib's per-radio
// `data_mode_supported` flag. As of v1.2.19 the variants Hamlib leaves it
// unset for pass `supportsDataMode: false`: before that they inherited
// `true`, so `setMode` followed every mode set with a `0x1A 0x06` the
// radio doesn't implement (and v1.2.19's `getMode` would read it).
extension StandardIcomCommandSet {
    /// IC-7300 HF/50MHz entry-level transceiver
    /// - VFO Model: Targetable (can target VFO A/B directly)
    /// - Mode commands use `0x26` (Hamlib `x25x26_always = 1`,
    ///   `ic7300.c:543`)
    /// - 115200 baud, 100W, requires mode filter
    public static var ic7300: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x94, vfoModel: .targetable,
                               acceptsSelectedVFOModeCommand: true)
    }

    /// IC-7300MK2 HF/50MHz/70MHz transceiver (2025)
    ///
    /// Same CAT command set as the IC-7300 (Hamlib `ic7300mk2_caps`
    /// differs from `ic7300_caps` only in model and `priv` caps;
    /// `IC7300MK2_priv_caps` differs only in address, `extcmds` and
    /// clock commands, `ic7300.c:448-662`). Its own variant so the two
    /// can diverge without touching each other:
    /// - default CI-V address **0xB6**, not 0x94 (`icom.c:585`)
    /// - `1A 05` menu numbers are renumbered — see
    ///   ``IcomRadioModel`` `menuSettingParameter(_:)` and
    ///   jjones9527/SwiftRigControl#19.
    public static var ic7300MK2: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0xB6, vfoModel: .targetable,
                               acceptsSelectedVFOModeCommand: true)
    }

    /// IC-7610 HF/50MHz SDR transceiver with dual receivers
    /// - VFO Model: Main/Sub (dual receiver architecture)
    /// - 115200 baud, 100W, requires mode filter
    public static var ic7610: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x98, vfoModel: .mainSub)
    }

    /// IC-7600 HF/50MHz high-end transceiver with dual receiver
    /// - VFO Model: Main/Sub (dual receiver, NOT VFO A/B)
    /// - Note: Uses Main/Sub bands, operates on currently selected band
    /// - 19200 baud, 100W, requires mode filter
    /// - IMPORTANT: Echoes commands over USB connection (Hamlib issue #583)
    public static var ic7600: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x7A, vfoModel: .mainSub, echoesCommands: true)
    }

    /// IC-9100 HF/VHF/UHF all-mode transceiver with dual receivers
    /// - VFO Model: Main/Sub (dual receiver architecture)
    /// - 115200 baud, 100W, requires mode filter
    public static var ic9100: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x7C, vfoModel: .mainSub)
    }

    /// IC-7200 HF/50MHz mid-range transceiver
    /// - VFO Model: Current Only (operates on current VFO)
    /// - 19200 baud, 100W, requires mode filter
    public static var ic7200: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x76, vfoModel: .currentOnly)
    }

    /// IC-718 HF budget transceiver
    /// - VFO Model: Current Only (operates on current VFO)
    /// - 19200 baud, 100W, requires mode filter
    public static var ic718: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x5E, vfoModel: .currentOnly, supportsDataMode: false)
    }

    /// IC-703 Portable HF/6m QRP transceiver
    /// - VFO Model: Current Only (operates on current VFO)
    /// - 19200 baud, 10W, requires mode filter
    public static var ic703: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x68, vfoModel: .currentOnly, supportsDataMode: false)
    }

    /// IC-7410 HF/50MHz transceiver
    /// - VFO Model: Current Only (operates on current VFO)
    /// - 19200 baud, 100W, requires mode filter
    public static var ic7410: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x80, vfoModel: .currentOnly)
    }

    /// IC-7700 HF/50MHz high-power flagship transceiver
    /// - VFO Model: Targetable (can target VFO A/B directly)
    /// - 19200 baud, 200W, requires mode filter
    /// - No `0x26`: Hamlib turns `0x25` / `0x26` off when the IC-7700
    ///   opens (`ic7700.c:153-158`). DATA modes use `0x06` + `0x1A 0x06`.
    ///   Pre-v1.2.19 we sent `0x26` for DATA-USB/LSB here.
    ///   Divergence: Hamlib keeps `RIG_TARGETABLE_MODE` on the IC-7700,
    ///   so after the `0x26` refusal it sends only `0x1A 0x06` and
    ///   never sets the base mode (`icom.c:2517-2524`, `2586-2609`). We
    ///   send `0x06` first, as Hamlib does for every other non-`0x26`
    ///   radio, so LSB → DATA-USB changes the sideband too.
    public static var ic7700: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x74, vfoModel: .targetable)
    }

    /// IC-7800 HF/50MHz high-power flagship transceiver
    /// - VFO Model: Main/Sub (dual receiver architecture)
    /// - 19200 baud, 200W, requires mode filter
    public static var ic7800: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x6A, vfoModel: .mainSub)
    }

    /// IC-7850/IC-7851 HF/50MHz flagship with spectrum scope
    /// - VFO Model: Main/Sub (dual receiver architecture with targetable spectrum)
    /// - 19200 baud, 200W, requires mode filter
    public static var ic7851: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x8E, vfoModel: .mainSub)
    }

    /// IC-7000 HF/VHF/UHF mobile transceiver
    ///
    /// **Wire quirks (all cross-referenced against Hamlib
    /// `rigs/icom/ic7000.c`):**
    /// - VFO Model: `.currentOnly` per `.targetable_vfo = 0` at
    ///   `ic7000.c:264`. The IC-7000 does not accept the newer
    ///   `0x25` / `0x26` per-VFO opcodes; callers must select VFO
    ///   A/B via `0x07 [0x00|0x01]` and then operate on the
    ///   currently-selected VFO.
    /// - **`requiresModeFilter = false`** — Hamlib
    ///   `icom.c:2199` explicitly lists the IC-7000 as a radio
    ///   whose set-mode command must NOT carry a passband /
    ///   filter byte. Emitting `0x06 [mode, 0x01]` would be
    ///   rejected; the correct wire is `0x06 [mode]`.
    /// - **`supportsDataMode = false`** — Hamlib does not set
    ///   `.data_mode_supported` on IC-7000, so it takes the
    ///   `icom_set_mode_without_data` path at `icom.c:2434-2452`
    ///   and skips the `0x1A 0x06 [data_flag, filter]` follow-up
    ///   entirely.
    /// - 19200 baud, 100W HF/50W VHF/35W UHF.
    ///
    /// **v1.2.6 fix:** prior releases shipped this variant as
    /// `.targetable` with the default `requiresModeFilter: true`,
    /// which broke every `setMode` call on the IC-7000 —
    /// `setMode(.usb, ...)` emitted `0x06 [0x01, 0x01]` (bad
    /// filter byte) and `setMode(.dataUSB, ...)` emitted the
    /// `0x26` targetable-mode opcode (not supported by IC-7000).
    /// See `Documentation/VFO_MODEL_AUDIT.md` for the full
    /// audit context.
    public static var ic7000: StandardIcomCommandSet {
        StandardIcomCommandSet(
            civAddress: 0x70,
            vfoModel: .currentOnly,
            requiresModeFilter: false,
            supportsDataMode: false
        )
    }

    /// IC-910H VHF/UHF satellite transceiver
    /// - VFO Model: Main/Sub (satellite dual receiver with A/B per receiver)
    /// - 19200 baud, 100W 2m/75W 70cm, requires mode filter
    public static var ic910H: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x60, vfoModel: .mainSub, supportsDataMode: false)
    }

    /// IC-2730 VHF/UHF dual-band mobile transceiver
    /// - VFO Model: Main/Sub (dual receiver, no VFO operations)
    /// - 19200 baud, 25W/50W depending on region
    /// - Note: No memory support via CI-V (clone mode only)
    public static var ic2730: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x90, vfoModel: .mainSub, supportsDataMode: false)
    }

    /// ID-5100 VHF/UHF mobile transceiver with D-STAR
    /// - VFO Model: Main/Sub (complex dual-watch architecture)
    /// - 19200 baud, 25W/50W depending on region
    /// - Note: Use SP2 port for rig control, not Data port
    public static var id5100: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x8C, vfoModel: .mainSub, supportsDataMode: false)
    }

    /// ID-4100 VHF/UHF mobile transceiver with D-STAR
    /// - VFO Model: Main/Sub (dual receiver)
    /// - 19200 baud, 25W/50W depending on region
    /// - Note: Use SP2 port for rig control, not Data port
    public static var id4100: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x9A, vfoModel: .mainSub, supportsDataMode: false)
    }

    /// IC-R8600 wideband communications receiver
    ///
    /// **Wire quirks (per Hamlib `rigs/icom/icr8600.c`):**
    /// - VFO Model: `.currentOnly` per `.targetable_vfo = 0`.
    ///   The IC-R8600 does not implement the `0x25` / `0x26`
    ///   per-VFO opcodes and has a single VFO + memory
    ///   architecture (`RIG_VFO_VFO | RIG_VFO_MEM` in Hamlib).
    /// - Receiver only — no PTT, no TX power control
    ///   (`RIG_PTT_NONE`, `RIG_TYPE_RECEIVER`).
    /// - 115200 baud (high speed).
    ///
    /// **v1.2.7 change:** shipped as `.targetable` in v1.2.6 and
    /// earlier. The mistake was cosmetic — none of the wire
    /// paths that actually get exercised diverge between
    /// `.targetable` and `.currentOnly` on this receiver
    /// (identical `0x07 [0x00|0x01]` VFO select bytes; no
    /// DATA-mode paths reachable because IC-R8600 doesn't
    /// support `PKTUSB` / `PKTLSB`). Corrected to
    /// `.currentOnly` for Hamlib parity. See
    /// `Documentation/VFO_MODEL_AUDIT.md`.
    public static var icR8600: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x96, vfoModel: .currentOnly, supportsDataMode: false)
    }

    /// IC-R75 HF communications receiver
    ///
    /// **Wire quirks (per Hamlib `rigs/icom/icr75.c`):**
    /// - VFO Model: `.currentOnly` per `.targetable_vfo = 0`.
    ///   Single VFO + memory architecture.
    /// - Receiver only — no PTT, no TX power control.
    /// - 19200 baud.
    ///
    /// **v1.2.7 change:** was `.targetable`; corrected to
    /// `.currentOnly` for Hamlib parity (see IC-R8600 note for
    /// the wire-impact analysis).
    public static var icR75: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x5A, vfoModel: .currentOnly, supportsDataMode: false)
    }

    /// IC-R9500 professional wideband communications receiver
    ///
    /// **Wire quirks (per Hamlib `rigs/icom/icr9500.c`):**
    /// - VFO Model: `.currentOnly` per `.targetable_vfo = 0`.
    ///   VFO A + memory architecture (`RIG_VFO_A | RIG_VFO_MEM`).
    /// - Receiver only — no PTT, no TX power control.
    /// - 1200 baud (very slow — older serial hardware).
    ///
    /// **v1.2.7 change:** was `.targetable`; corrected to
    /// `.currentOnly` for Hamlib parity.
    public static var icR9500: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x72, vfoModel: .currentOnly, supportsDataMode: false)
    }

    // MARK: - D-STAR Handhelds (v1.1 parity additions)

    /// IC-R30 wideband digital handheld receiver (2018)
    /// - VFO Model: Main/Sub (per Hamlib `icr30.c`)
    /// - 9600 baud default, receiver only (no PTT/power control)
    public static var icR30: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x9C, vfoModel: .mainSub, supportsDataMode: false)
    }

    /// ID-31A/E single-band UHF D-STAR handheld (2012)
    /// - VFO Model: Current Only (no targetable VFO)
    /// - 9600 baud, 5W UHF, FM + D-STAR
    /// - Note: Use the SP (speaker) port for CAT; the Data port
    ///   is firmware-upgrade only (per Hamlib `id31.c`).
    public static var id31: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0xA0, vfoModel: .currentOnly, supportsDataMode: false)
    }

    /// ID-51A/E / ID-51A Plus2 dual-band V/U D-STAR handheld (2012/2016)
    /// - VFO Model: Main/Sub (logical dual-watch)
    /// - 9600 baud, 5W / 25W (EU) or 50W (USA) high power, FM + D-STAR
    /// - Note: Use the SP port for CAT (Data port is firmware-only).
    public static var id51: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x86, vfoModel: .mainSub, supportsDataMode: false)
    }

    /// ID-52A/E / ID-52A Plus2 dual-band V/U D-STAR handheld (2020/2024)
    /// - VFO Model: Main/Sub (logical dual-watch)
    /// - 9600 baud, 5W max, FM + D-STAR. Successor to ID-51.
    /// - Per Hamlib `id52plus.c`, uses 0xB4 default CI-V address.
    public static var id52: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0xB4, vfoModel: .mainSub, supportsDataMode: false)
    }

    /// IC-92AD / IC-E92D dual-band D-STAR handheld (2008)
    ///
    /// **Wire quirks (per Hamlib `rigs/icom/ic92d.c`):**
    /// - VFO Model: `.currentOnly` per `.targetable_vfo = 0`.
    ///   Has VFO A (broadband RX), VFO B (2m/70cm), and memory
    ///   — `RIG_VFO_A | RIG_VFO_B | RIG_VFO_MEM` — but Hamlib
    ///   treats VFO switching as select-then-set, not
    ///   per-command targeting.
    /// - No PTT (`RIG_PTT_NONE`, `RIG_TYPE_HANDHELD`).
    /// - 9600 baud, 5 W. Predecessor to the ID-51 family.
    /// - Uses 0x01 default address (unusual — shared with ID-1;
    ///   set a custom address if both are on one CI-V bus) and
    ///   full-duplex serial.
    ///
    /// **v1.2.7 change:** was `.targetable`; corrected to
    /// `.currentOnly` for Hamlib parity.
    public static var ic92d: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x01, vfoModel: .currentOnly, supportsDataMode: false)
    }

    // MARK: - v1.2.0 Group D — receivers + specialty

    /// IC-R6 compact handheld wideband receiver (2009)
    /// - VFO Model: Current Only (single-VFO handheld)
    /// - 19200 baud, receiver only
    /// - Per Hamlib `icr6.c`, default CI-V address 0x7E.
    public static var icR6: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x7E, vfoModel: .currentOnly, supportsDataMode: false)
    }

    /// IC-R20 dual-VFO handheld wideband receiver (2004)
    ///
    /// **Wire quirks (per Hamlib `rigs/icom/icr20.c`):**
    /// - VFO Model: `.currentOnly` per `.targetable_vfo = 0`.
    ///   Marketed as "dual-VFO with simultaneous audio," but the
    ///   Hamlib backend enumerates only `RIG_VFO_A`; the second
    ///   audio channel is not addressable as a separate VFO
    ///   over CI-V.
    /// - Receiver only — no PTT, no TX power control
    ///   (`RIG_PTT_NONE`, `RIG_TYPE_RECEIVER | RIG_FLAG_HANDHELD`).
    /// - 19200 baud. Default CI-V address 0x6C.
    ///
    /// **v1.2.7 change:** was `.targetable`; corrected to
    /// `.currentOnly` for Hamlib parity.
    public static var icR20: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x6C, vfoModel: .currentOnly, supportsDataMode: false)
    }

    /// IC-R7100 VHF/UHF communications receiver (1993)
    /// - VFO Model: Current Only
    /// - **1200 baud** (very slow — older serial hardware), receiver only
    /// - Per Hamlib `icr7000.c`, default CI-V address 0x34.
    public static var icR7100: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x34, vfoModel: .currentOnly, supportsDataMode: false)
    }

    /// IC-F8101 HF SSB transceiver (2010)
    /// - VFO Model: Targetable
    /// - **38400 baud** (higher than most Icoms of the era)
    /// - Per Hamlib `icf8101.c`, default CI-V address 0x8A. 100 W TX.
    ///
    /// No DATA modes (`supportsDataMode: false`): Hamlib's
    /// `icf8101_priv_caps` doesn't set `data_mode_supported`, and the
    /// radio has no `0x26`. Note that Hamlib drives frequency and mode
    /// on the F8101 with its own `1A 35` / `1A 36` / `1A 34` commands
    /// (`icf8101.c:39-130`), which this command set doesn't model yet.
    public static var icF8101: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x8A, vfoModel: .targetable,
                               supportsDataMode: false)
    }

    /// ID-1 first-generation 1.2 GHz D-STAR mobile (2004)
    ///
    /// **Wire quirks (per Hamlib `rigs/icom/id1.c`):**
    /// - VFO Model: `.currentOnly` per `.targetable_vfo = 0`.
    ///   `RIG_VFO_A | RIG_VFO_MEM` — single VFO + memory
    ///   architecture.
    /// - Has PTT (`RIG_PTT_RIG`, `RIG_TYPE_MOBILE`), 10 W TX.
    ///   Modes: FM, DIGDATA (D-STAR data), DIGVOICE (D-STAR
    ///   voice) — no SSB-DATA path, so the `PKTUSB` / `PKTLSB`
    ///   dispatch is not exercised.
    /// - 19200 baud. Default CI-V address 0x01 (shared with
    ///   IC-92AD; set a custom address if both on one bus).
    ///
    /// **v1.2.7 change:** was `.targetable`; corrected to
    /// `.currentOnly` for Hamlib parity.
    public static var id1: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x01, vfoModel: .currentOnly, supportsDataMode: false)
    }

    /// IC-RX7 compact handheld wideband receiver (2007)
    /// - VFO Model: Current Only
    /// - 19200 baud, receiver only
    /// - Per Hamlib `icrx7.c`, default CI-V address 0x78.
    public static var icRX7: StandardIcomCommandSet {
        StandardIcomCommandSet(civAddress: 0x78, vfoModel: .currentOnly, supportsDataMode: false)
    }
}
