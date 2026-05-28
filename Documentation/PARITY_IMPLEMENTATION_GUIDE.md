# Parity Implementation Guide

Template + workflow for adding Hamlib-cited radio definitions to
SwiftRigControl with high confidence in the absence of hardware
testing. This document is the *how* — the parity inventory and
release plan are separate artifacts that name *which* radios.

## Goal

Ship every modern (released 2000 or later) amateur-radio
transceiver Hamlib supports, plus older radios with confirmed
ongoing userbase, with wire-byte fidelity that matches Hamlib's
implementation. Hamlib has been hardened against real radios for
two decades; when SwiftRigControl's wire bytes match Hamlib's,
we can be confident the implementation is right without owning
the radio ourselves.

This guide standardizes the implementation pattern so every
new radio:

1. Is grounded in citable Hamlib source.
2. Has its `RigCapabilities` literal verified against the
   Hamlib `rig_caps` struct field-by-field.
3. Has protocol-level tests that lock in the exact wire bytes
   for the major operations (frequency, mode, PTT, plus
   anything radio-specific).
4. Lands in user-facing documentation (README, supported
   radios, capability tables).

## Prerequisites

- Local Hamlib clone at `~/Developer/hamlib`. Refresh with
  `git -C ~/Developer/hamlib pull` before starting a batch.
- A specific `rigs/<vendor>/<file>.c` file open in the editor
  so the `rig_caps` struct is visible.
- Pen-and-paper or scratch notes for the per-radio facts you'll
  extract (12 fields below).

## Per-radio facts to extract from Hamlib

For each radio, walk the Hamlib `rig_caps` struct and record:

1. **RIG_MODEL identifier** — e.g. `RIG_MODEL_FT2000`. Used in
   citations.
2. **Display name** — manufacturer + model number.
3. **First-ship year** — from Hamlib comments, copyright dates,
   or known release year. Used in README ordering and the
   "modern radio" priority tier.
4. **Default baud rate** — `.serial_rate_max` in the struct.
5. **CI-V address** (Icom only) — `civ_addr` in
   `icom_priv_caps`.
6. **Targetable VFO** — `.targetable_vfo` bitmap. Drives the
   `VFOOperationModel` for the command set.
7. **Mode mask** — `.modes` or per-range `modes` field. Maps to
   our `Mode` enum.
8. **Power units + max power** — Icom is always percentage; for
   others, `tx_range_list[].high_power` (in mW) or
   `tx_range_list[].mode_low_power` divided across modes.
9. **Frequency ranges** — both `rx_range_list1` (Region 1) and
   `rx_range_list2` (Region 2). We model these as
   `detailedFrequencyRanges`. Hamlib distinguishes TX-capable
   ranges; preserve that.
10. **Capability masks** to translate into v1.1 sets:
    - `*_FUNCS` mask → `supportedFunctions`
    - `*_VFO_OPS` mask → `supportedVFOOperations`
    - `*_SCAN_OPS` mask → `supports*Scan` flags
    - `*_LEVELS` mask → enables/disables specific
      `Supports<Level>` trait conformances
    - `*_ANTS` mask → `antennaCount`
11. **Memory channel count** — from `.chan_list[]`.
12. **Quirks** — anything in Hamlib comments warning about
    per-model behavior: echo handling, filter byte rejection,
    data-mode encoding, special PTT handling. Add as inline
    comments next to the affected field.

## File layout for a new radio

A new radio touches a small set of files. Pattern (using the
Icom IC-XXXX as a placeholder):

```
Sources/RigControl/
  Models/
    RadioCapabilitiesDatabase+IcomXxx.swift  ← capabilities literal
  Protocols/Icom/
    IcomRadioModel.swift                     ← enum case + civAddress + DSTAR/satellite/dualRX flags
    CommandSets/StandardIcomCommandSet.swift ← static factory (only if vfoModel/baud differ)
    IcomModels+HF.swift (or +VHF.swift)      ← public factory function

Tests/RigControlTests/
  ProtocolTests/IcomXxxProtocolTests.swift   ← wire-byte locks for major ops
  UnitTests/V11RadioDefinitionsTests.swift   ← caps sanity (or its successor)
```

For Kenwood/Yaesu/Elecraft the pattern is simpler — there's no
per-radio command set, and the protocol actor is shared. The
files reduce to:

```
Sources/RigControl/
  Models/
    RadioCapabilitiesDatabase+<Vendor>Modern.swift   ← caps literal
  Protocols/<Vendor>/
    <Vendor>Models.swift                              ← public factory let

Tests/RigControlTests/
  ProtocolTests/<Vendor>XxxProtocolTests.swift        ← (optional, for popular radios)
  UnitTests/<Vendor>RadioDefinitionsTests.swift       ← caps sanity
```

## Capability struct template

Use this skeleton when seeding a new `RigCapabilities` literal.
Every field that doesn't apply takes the documented default;
*don't* set fields you don't have a Hamlib citation for.

```swift
/// Vendor Model — (year, model role from Hamlib comment).
///
/// Cross-checked against Hamlib `rigs/<vendor>/<file>.c:<line>`
/// (`<rig_caps_name>_caps` / `RIG_MODEL_<X>`).
public static let vendorModel = RigCapabilities(
    // Core operating surface
    hasVFOB: true,                          // .vfo_ops & RIG_VFO_B
    hasSplit: true,                         // implied if .set_split_vfo non-NULL
    powerControl: true,                     // .set_level & RIG_LEVEL_RFPOWER
    maxPower: 100,                          // from tx_range_list[].high_power_mW / 1000
    supportedModes: [.lsb, .usb, .cw, ...], // from .modes mask, translated to our Mode enum

    // Frequency ranges (Region 2 / Americas defaults; Region 1
    // can override at construction time).
    frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
    detailedFrequencyRanges: [
        // One entry per (band, RX-only) and (band, TX-capable) range.
        // Use the rx_range_list2 / tx_range_list2 fields in Hamlib.
        DetailedFrequencyRange(min: ..., max: ..., modes: [...],
                               canTransmit: true, bandName: "20m"),
        // ...
    ],

    hasDualReceiver: false,                 // .targetable_vfo & RIG_TARGETABLE_MODE on MAIN/SUB
    hasATU: true,                           // .set_func & RIG_FUNC_TUNER
    supportsSignalStrength: true,

    // Vendor-specific transport quirks
    requiresVFOSelection: false,            // Icom only
    requiresModeFilter: true,               // Icom only — controls 0x06 frame shape
    powerUnits: .percentage,                // Icom .percentage, others .watts(max: N)

    // TX meters from *_LEVELS mask
    supportsRFPowerMeter: true,             // RIG_LEVEL_RFPOWER_METER
    supportsSWRMeter: true,                 // RIG_LEVEL_SWR
    supportsALCMeter: true,                 // RIG_LEVEL_ALC
    supportsCompMeter: true,                // RIG_LEVEL_COMP_METER
    supportsVoltageMeter: true,             // RIG_LEVEL_VD_METER
    supportsCurrentMeter: true,             // RIG_LEVEL_ID_METER

    // CW from *_LEVELS mask
    supportsCWKeyer: true,                  // RIG_LEVEL_KEYSPD | RIG_LEVEL_CWPITCH
    supportsSendCW: true,                   // .send_morse non-NULL

    // Scan ops from *_SCAN_OPS mask
    supportsVFOScan: true,                  // RIG_SCAN_VFO
    supportsMemoryScan: true,               // RIG_SCAN_MEM
    supportsSelectedMemoryScan: false,      // RIG_SCAN_SLCT
    supportsPriorityScan: false,            // RIG_SCAN_PRIO
    supportsProgrammedScan: true,           // RIG_SCAN_PROG
    supportsDeltaFScan: false,              // RIG_SCAN_DELTA

    antennaCount: 2,                        // popcount(*_ANTS)

    // v1.1 sets — translate the Hamlib bits using our
    // VFOOperation / RigFunction enum mappings (see
    // Models/VFOOperation+Presets.swift and
    // Models/RigFunction+Presets.swift for vendor presets).
    supportedVFOOperations: .icomStandard,
    supportedFunctions: .icomIC7300Funcs
)
```

For the v1.1 sets, prefer the vendor presets over inlined sets
unless the radio diverges from the standard. If you need a new
preset, add it to `VFOOperation+Presets.swift` /
`RigFunction+Presets.swift` with a Hamlib citation.

## Wire-byte test template

This is the heart of "high confidence without hardware." For
each new radio, write a test suite that locks in the exact wire
bytes for the major operations. The test name encodes the
Hamlib reference so future readers can re-verify.

The pattern, generalized from `IcomDataModeTests.swift` and
`IcomNoiseBlankerTests.swift`:

```swift
import Foundation
import Testing
@testable import RigControl

/// Protocol-level tests for the <Vendor> <Model>.
///
/// Wire bytes locked in here are taken from Hamlib's
/// `rigs/<vendor>/<file>.c` (citation in each test). The tests
/// run against `MockTransport`, so they verify that
/// SwiftRigControl emits the bytes Hamlib emits — no radio
/// required.
@Suite struct VendorModelProtocolTests {

    private func makeRadio() -> (MockTransport, ConcreteCATProtocol) {
        let mock = MockTransport()
        let proto = ConcreteCATProtocol(
            transport: mock,
            // ... radio-specific init args ...
            capabilities: RadioCapabilitiesDatabase.vendorModel
        )
        return (mock, proto)
    }

    // MARK: - Frequency

    /// Hamlib reference: rigs/<vendor>/<file>.c:<line>
    /// Setting 14.230 MHz on VFO A should emit:
    ///   [exact wire bytes per Hamlib's set_freq for this radio]
    @Test func setFrequencyVFOA() async throws {
        let (mock, proto) = makeRadio()
        try await proto.connect()
        try await proto.setFrequency(14_230_000, vfo: .a)

        let writes = await mock.recordedWrites
        let expected = Data([/* exact bytes */])
        #expect(writes.last == expected)
    }

    // MARK: - Mode

    /// Hamlib reference: rigs/<vendor>/<file>.c:<line>
    @Test func setModeUSB() async throws { /* … */ }

    /// Cross-checks against the IC-7600 DATA-USB regression
    /// pattern — radios with `data_mode_supported = 1` and
    /// non-targetable VFO model must send the 0x1A 0x06
    /// follow-up frame. (For Icom only.)
    @Test func setModeDataUSBSendsDataModeSubcommand() async throws { /* … */ }

    // MARK: - PTT

    /// Hamlib reference: rigs/<vendor>/<file>.c:<line>
    @Test func setPTTOn() async throws { /* … */ }
    @Test func setPTTOff() async throws { /* … */ }

    // MARK: - Radio-specific quirks

    // Add tests for anything Hamlib comments warn about for
    // this specific model — echo handling, filter byte
    // edge cases, unusual sub-commands.
}
```

### Minimum test surface per radio

Every new radio gets at least:

1. **setFrequency** on VFO A (or main).
2. **setMode** for each non-trivial mode the radio supports
   (USB minimum; CW and FM if the radio has them; data modes
   for any radio with `data_mode_supported = 1`).
3. **setPTT** on/off.
4. **One radio-specific quirk** if Hamlib calls one out.

Popular radios (target: Tier 1) get more:

5. **setSplit** + setSplitFrequency.
6. **setPower** at a non-trivial level (50% / 50W).
7. **setRIT** (offset + enable).
8. One **function toggle** (compressor or VOX).
9. **performVFOOperation(.exchange)** wire frame.

### How to derive the expected wire bytes

For Icom CI-V:

1. Find the Hamlib handler — `icom_set_freq` for frequency,
   `icom_set_mode` for mode, etc. — in `rigs/icom/icom.c`.
2. Trace through what bytes get serialized. For most ops this
   is the command byte (e.g. 0x05 for set_freq) plus BCD-
   encoded payload plus framing (FE FE [to] [from] ... FD).
3. Cross-check against `icom_defs.h` for command constants.
4. The expected wire bytes are deterministic. Write them out
   as `Data([0xFE, 0xFE, 0x<addr>, 0xE0, 0x<cmd>, ...])`.

For Kenwood text:

1. Find the per-vendor handler in `rigs/kenwood/kenwood.c`
   (`kenwood_set_freq`, `kenwood_set_mode`, …).
2. The wire format is ASCII — e.g. `FA00014230000;` for 14.230
   MHz on VFO A.
3. The expected string is deterministic.

For Yaesu newcat:

1. Same as Kenwood, but in `rigs/yaesu/newcat.c`.

### Capability-struct sanity tests

Beyond the wire-byte tests, every new radio gets a sanity test
that the cap struct represents reality:

```swift
@Test func vendorModelCapsBasicSanity() {
    let caps = RadioCapabilitiesDatabase.vendorModel
    #expect(caps.maxPower == 100)
    #expect(caps.canTransmit(on: 14_230_000))      // 20m
    #expect(caps.canTransmit(on: 7_100_000))       // 40m
    #expect(!caps.canTransmit(on: 30_000_000))     // out-of-band
    #expect(caps.supportedFunctions.contains(.compressor))
    #expect(caps.supportedVFOOperations.contains(.exchange))
}

@Test func vendorModelConstructsAndConnects() async throws {
    let rig = try RigController(radio: .vendorModel(), connection: .mock)
    try await rig.connect()
    #expect(await rig.radioName == "Vendor Model")
}
```

The `V11RadioDefinitionsTests.swift` file is the canonical
example — every radio shipped in v1.1 has a "BasicCaps" and
"ConnectsViaMock" pair.

## Documentation checklist

When the radio lands, update:

1. **README.md**:
   - The vendor's bulleted list (with CI-V address / baud rate).
   - The vendor's Quick Reference table.
   - The total radio count at the top of the Supported Radios
     section.
   - The vendor's section header count.

2. **CHANGELOG.md**:
   - Add to the `[Unreleased]` `Added` section.
   - Cite the Hamlib file the implementation referenced.
   - Note whether it's definition-only or hardware-verified.

3. **Documentation/HAMLIB_PARITY.md**:
   - Move the radio from the pending list to the shipped list.

4. **DocC catalog**:
   - The radio's factory function is auto-discovered by DocC.
   - If the radio introduces a new manufacturer brand tag,
     update the landing page's "What you get" bullets.

## Quality gates before shipping

Run these locally before opening a PR:

```bash
# Build clean with warnings-as-errors.
swift build

# All tests pass.
swift test

# Doc lint passes.
python3 Scripts/check-public-docs.py

# DocC catalog builds clean.
swift package generate-documentation --target RigControl --product RigControl
```

CI runs all four on every push to `main`.

## A worked example: adding the IC-705

(Already shipping — used here as a reference walkthrough.)

1. **Hamlib reference**: `rigs/icom/ic7300.c:1763`
   (`ic705_caps`). It's in the IC-7300 file because the IC-705
   shares the IC-7300's command set.
2. **CI-V address**: 0xA4 (from `ic705_priv_caps`).
3. **Default baud**: from the same priv struct, 19200.
4. **Mode mask**: full HF + VHF/UHF modes including DATA.
5. **`data_mode_supported = 1`** → needs the 0x1A 0x06
   follow-up. This is the same pattern as IC-7600 / IC-9700.
6. **`VFO_OPS = IC7300_VFO_OPS`** → use `.icomStandard` preset.
7. **`FUNCS = IC7300_FUNCS`** → use `.icomIC7300Funcs` preset.

Resulting cap struct in
`RadioCapabilitiesDatabase+Icom.swift` matches every field
above. Tests in `IcomNoiseBlankerTests` would (if we added it
to the suite) lock in the NB level wire bytes using the same
helper.

## A worked example for v1.2: the Yaesu FT-2000

The cap struct ships but **is missing v1.1 trait seedings**.

1. **Hamlib reference**: `rigs/yaesu/ft2000.c`, `ft2000_caps`.
2. **`*_FUNCS`** mask: look up in the source, translate to
   `RigFunction` set. Likely matches `.yaesuHFStandard`
   preset.
3. **`*_VFO_OPS`** mask: likely `.yaesuStandard` preset
   (CPY/XCHG/UP/DOWN/BAND_UP/BAND_DOWN/TUNE).
4. **Tests**: write `YaesuFT2000ProtocolTests.swift` with
   setFrequency / setMode / setPTT / setSplit. Each test cites
   the Hamlib line that produced its expected bytes.

This is the v1.2 pattern for every Yaesu / Kenwood / Elecraft
radio that currently has a definition-only cap struct without
v1.1 trait seedings.

## Backfill task: existing radios missing v1.1 traits

Many radios shipped before v1.1 and never got their
`supportedFunctions` / `supportedVFOOperations` sets back-filled.
Known examples (incomplete list — verify before fixing):

- Yaesu FT-2000, FT-1000MP, FT-847, FT-857, FT-857D, FT-897,
  FT-897D, FT-450, FTDX-5000, FTDX-9000, FTDX-3000, FTDX-1200,
  FTDX-101D, FTDX-101MP, FT-100, FT-817, FT-818
- Kenwood TS-850S, TS-570D/S, TS-480HX, TM-V71, TH-D72
- Elecraft K2 (partial — has VFO ops, missing functions?)
- Most older Icoms (IC-756 family, IC-718, IC-735, IC-751)

Each backfill is a small edit: add `supportedVFOOperations`
and `supportedFunctions` parameters using the matching vendor
preset. Where the preset doesn't fit, derive from the Hamlib
`*_FUNCS` mask. Each backfill should be in a separate commit
with the Hamlib citation in the message.

This is good "first-PR" material for contributors.

## When wire bytes are ambiguous

Sometimes Hamlib hides per-model variation behind a generic
helper (e.g. `icom_set_mode`'s many branches). When that happens:

1. **Run Hamlib in debug mode against the dummy backend** to
   see what bytes it would have emitted for that specific
   radio. The `rigctl` tool with `-vvvvv` prints every CAT
   transaction.
2. **Cross-check with the radio's CI-V manual** if available
   (some are in the repo root).
3. **Document the disagreement** in the test's comment and
   prefer Hamlib's bytes by default. Note the discrepancy in
   the commit message so a future hardware-validation pass can
   resolve it.

## Out of scope (do not propose)

These vendors / models are deliberately excluded:

- Marine VHF radios (IC-M73, etc.).
- Aero radios.
- Amplifiers (IC-PW1, IC-2KL).
- Rotators (use `rotctld` for those).
- Drake, AOR, Alinco, Uniden, WinRadio (covered by Hamlib but
  outside SwiftRigControl's amateur-radio scope).
- Pre-1985 radios with non-standard or no CAT.

When in doubt, ask before committing.
