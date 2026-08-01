# Changelog

All notable changes to SwiftRigControl will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Version-numbering note (Phase 0 reconciliation, 2026-05-22):**
> The actual released git tags through April 2026 are `v1.0.0`,
> `v1.0.1`, `v1.0.2`, `v1.0.3`, `v1.0.4`, and `v1.0.6` (1.0.5 was
> skipped). The earlier `[1.1.0]`, `[1.2.0]`, and `[1.3.0]`
> headings that appear lower in this file describe **real shipped
> work that was bundled into the `v1.0.6` release tag on
> 2026-04-30**, not separately released versions. They are
> preserved as historical feature batches.
>
> The **second** `[1.1.0]` heading below — dated 2026-05-29 — is
> the *real* v1.1.0 release, the first feature release after
> v1.0.6. From this release forward, CHANGELOG version headings
> match the git tag they ship under.

## [Unreleased]

## [1.2.7] - 2026-08-01

### Changed

- **Category D `.targetable` → `.currentOnly` reclassification.**
  Six `StandardIcomCommandSet` variants (IC-R8600, IC-R75,
  IC-R9500, IC-R20, IC-92AD, ID-1) were shipped as
  `.targetable` in v1.2.6 and earlier but are non-targetable
  in Hamlib (`.targetable_vfo = 0` on each backend). Corrected
  to `.currentOnly` in this release. **This is Hamlib-parity
  hygiene, not a user-visible bug fix** — the code paths that
  actually diverge between `.targetable` and `.currentOnly`
  (`supportsTargetableMode` → `0x26` DATA-mode opcode) are
  unreachable on these radios because none of them supports
  the `PKTUSB` / `PKTLSB` modes SwiftRigControl models as
  `.dataUSB` / `.dataLSB`. VFO-select wire bytes remain
  identical.

  Real benefit of the change: `supportsTargetableMode` and
  `requiresDataModeSubCommand` computed properties now
  correctly return `false` for these six variants — matching
  Hamlib and eliminating a stale claim that these radios
  understood the `0x26` opcode.

### Documentation

- **VFO audit — IC-7610 / IC-7600 / IC-7800 / IC-7851 item
  closed.** Deep-dive against the IC-7600 CI-V manual and
  Hamlib `icom.c:10034` / `icom.c:3078-3097` established that
  the initial audit's "Category B mismatch" label for these
  four flagships was a misdiagnosis. The IC-7600 CI-V command
  `07` (Select VFO mode) has no `07 00` / `07 01` payload —
  these radios do not have "VFO A" / "VFO B" as a wire concept;
  the VFO domain per Hamlib is Main/Sub only. Our shipped
  `.mainSub` model is wire-correct, and its `.a` → Main /
  `.b` → Sub fallback matches exactly what Hamlib's own
  `icom_set_vfo` sends. Contest apps (WSJT-X, N1MM, DXLog)
  driving these radios via rigctld already rely on this
  convention. `Documentation/VFO_MODEL_AUDIT.md` updated
  with the manual + Hamlib source evidence; category legend
  and per-radio table rows re-categorized as Category A.
  **No code change required.**
- A future `0x25`/`0x26` targetable-frequency optimization is
  worth pursuing for these four radios but is a **feature**,
  not a fix. It needs a hardware validator run against a real
  IC-7610 or IC-7600 before shipping because Hamlib itself
  special-cases IC-7800 for firmware inconsistency
  (`icom.c:2667`). Tracked as a v1.3.0-or-later item.
- **VFO audit — Category D item closed.** All six affected
  variants (IC-R8600, IC-R75, IC-R9500, IC-R20, IC-92AD,
  ID-1) reclassified in this release. Audit doc footnote ³
  captures the Hamlib-parity rationale and the "cosmetic, not
  bug" honesty about impact. Every affected factory now carries
  a Hamlib citation inline citing the `.targetable_vfo = 0`
  field in the corresponding backend.

### Tests

- Three new drift tests in `StandardIcomCommandSetVariantsTests`
  locking the Category D reclassification against Hamlib:
  - `categoryDVariantsShipAsCurrentOnly` — asserts the six
    variants all ship `.currentOnly`.
  - `categoryDVariantsDoNotClaimTargetableMode` — asserts
    `supportsTargetableMode == false` on each; catches any
    future accidental flip back to `.targetable`.
  - `categoryDVariantsStillEmitStandardVFOSelect` — asserts
    the VFO-select wire (`0x07 [0x00|0x01]`) is unchanged
    from the pre-fix behavior, documenting the "cosmetic, no
    user-visible impact" claim.

Test count 678 → 681. Zero regressions.

## [1.2.6] - 2026-08-01

### Fixed

- **IC-7000 wire-format triple fix.** Prior releases shipped the
  `StandardIcomCommandSet.ic7000` factory as `.targetable` with
  the default `requiresModeFilter: true`. A byte-level Hamlib
  audit of `rigs/icom/ic7000.c` and `rigs/icom/icom.c:2199`
  surfaced three separate wire-format issues, all of which broke
  every `setMode` call on the IC-7000:
  - **Wrong VFO model.** Hamlib sets `.targetable_vfo = 0`; the
    IC-7000 does not implement the `0x25` / `0x26` per-VFO
    opcodes. Should be `.currentOnly`.
  - **Mode filter byte forbidden.** Hamlib `icom.c:2199-2201`
    explicitly forces `icmode_ext = -1` for the IC-7000,
    grouping it with the IC-375 / IC-731 / IC-726 / IC-735 /
    IC-910 / IC-746 / IC-756 family as "don't support passband
    data." Setting `requiresModeFilter: false` emits the
    correct `0x06 [mode]` wire (one byte of data) instead of
    the rejected `0x06 [mode, 0x01]`.
  - **DATA-mode dispatch entirely skipped.** Hamlib does not
    set `.data_mode_supported = 1` on the IC-7000, so it takes
    the `icom_set_mode_without_data` path at `icom.c:2434-2452`
    and skips the `0x1A 0x06 [data_flag, filter]` follow-up.
    Our code previously emitted the `0x26` opcode for DATA
    modes (via `supportsTargetableMode`); the fix routes
    through a new `supportsDataMode` flag so IC-7000 emits the
    base mode frame alone.

  All three fixed at once. IC-7000 users can now `setMode`
  (voice and DATA) for the first time.

### Added

- **`IcomRadioCommandSet.supportsDataMode: Bool`** — new
  protocol requirement (default `true` via extension) modelling
  Hamlib's per-radio `.data_mode_supported` flag. When `false`,
  `requiresDataModeSubCommand` returns `false` and
  `IcomCIVProtocol.setMode` skips the `0x1A 0x06` follow-up.
  Source-compatible: every existing conformer inherits the
  default.
- **`StandardIcomCommandSet.init` gains a `supportsDataMode`
  parameter** (default `true`) so factory variants can opt out.
  Only the IC-7000 factory currently sets `false`.

### Changed

- `StandardIcomCommandSet.ic7000` rewritten:
  `vfoModel: .currentOnly`, `requiresModeFilter: false`,
  `supportsDataMode: false`. Every Hamlib citation captured
  inline on the factory.
- `VFOOperationModel.targetable` and `.currentOnly` docstring
  radio lists updated to reflect the reclassification.
- `IcomRadioCommandSet.supportsTargetableMode` and
  `requiresDataModeSubCommand` docstrings updated to describe
  the new `supportsDataMode` gate.
- `Documentation/VFO_MODEL_AUDIT.md` — IC-7000 item marked
  fixed; sequence status updated.

### Tests

- Four new IC-7000 unit tests in `CIVCommandSetTests`:
  - `ic7000Properties` — locks address, echo flag,
    `requiresModeFilter`, `supportsDataMode`,
    `supportsTargetableMode`, `requiresDataModeSubCommand`.
  - `ic7000SetModeCommandEmitsNoFilterByte` — asserts wire is
    `0x06 [mode]` with no `0x01` filter byte.
  - `ic7000SetDataModeCommandFallsBackToBaseModeFrame` —
    asserts DATA-mode dispatch returns the plain base-mode
    frame.
  - `ic7000VFOCommand` — locks the standard `0x07 [0x00|0x01]`
    VFO A/B wire.

### Documentation

Bundled from the [Unreleased] entry that landed on `main` on
2026-07-31 before the v1.2.6 fix work:

- **VFO-model doc reconciliation.** Following the v1.2.5
  catalog-drift buildout, the VFO / `VFOOperationModel`
  docstrings were audited against the shipped catalog and
  found to contain multiple contradictions with the actual
  code behavior — e.g. `VFO.a` docstring claimed IC-7600 was
  single-receiver but the code ships IC-7600 as `.mainSub`;
  `.targetable` example list included IC-7610 and IC-7800
  which actually ship as `.mainSub`; `supportsTargetableMode`
  comment claimed IC-7610/7800/7851 use the `0x26` opcode when
  they take the legacy `0x1A 0x06` path.
- Rewrote the affected docstrings (`VFO`, `VFOOperationModel`,
  `IcomRadioCommandSet.selectVFOCommand` /
  `supportsTargetableMode` / `setDataModeCommand`) to describe
  what the code does today, honestly, with per-radio example
  lists that match the shipped catalog.
- Added `Documentation/VFO_MODEL_AUDIT.md` capturing the
  Hamlib cross-reference table for every named
  `StandardIcomCommandSet` variant, the categorized mismatches,
  and the deferred architecture questions. The audit doc
  itself surfaced the IC-7000 investigation that produced
  this release's wire-format fix.

Test count 674 → 678. Zero regressions.

## [1.2.5] - 2026-07-31

### Added

Two new catalog-drift test suites plugging coverage gaps that
would otherwise let silent regressions ship:

- **`StandardIcomCommandSetVariantsTests`** — 7 tests covering
  all 30 named `StandardIcomCommandSet` factory variants
  (`.ic7300`, `.ic7610`, `.ic7000`, `.icR8600`, `.id52`, etc.).
  Each variant's `civAddress` and `echoesCommands` flag was
  hand-audited against the corresponding `~/Developer/hamlib/
  rigs/icom/*.c` file and captured in an `IcomVariantSpec`
  table. If someone mistypes a CI-V byte or accidentally flips
  the echo flag, the drift test fails. Also verifies universal
  properties — every variant round-trips frequency through
  5-byte BCD, emits the standard `0x1C 0x00` PTT frame, and
  uses percentage power units. **Full audit found zero
  mismatches** in the shipped catalog — the tests are a
  regression net for future edits, not a bug fix.
- **`YaesuQuirksPresetsTests`** — 12 tests locking every field
  of every named `YaesuCATProtocol.Quirks` preset (`.classic`,
  `.newcatNoST`, `.ft2000Family`, `.newcatWithSTDX`,
  `.ftdx10Family`, `.ftdx101Family`, `.ft710`, `.ft450`,
  `.ft891`, `.ftx1`). Each expected value is traceable to a
  Hamlib citation in `YaesuCATProtocol+Quirks.swift`. Also
  covers the `withTargetableMode(_:)` copy-with-override
  helper — verifies it preserves every other field and both
  the true/false override paths. The FTX-1 preset test
  additionally spot-checks the custom mode-code table for the
  CW / CW-R distinction (codes 3 = CW-USB, 7 = CW-LSB) that
  differs from the shared newcat table.

### Deferred

- **VFO-model parity audit** for `StandardIcomCommandSet` variants
  — the question of whether IC-7610 (dual-receiver, but supports
  per-VFO targeting per Hamlib `RIG_TARGETABLE_FREQ |
  RIG_TARGETABLE_MODE`) should ship as `.targetable` or
  `.mainSub` is deeper than a drift test can answer. Locking
  either the current or the flipped choice prematurely would
  freeze a possible bug. Left for a future architecture review
  release.

Test count 655 → 674. Zero regressions.

## [1.2.4] - 2026-07-31

### Fixed

- **THFamilyCAT step field computed from frequency, not
  snapshotted.** `setFrequency` on TH-F6A / TH-F7E emits
  `FQ <freq>,<step>\r`. Prior releases snapshotted the step
  from the last successful `getFrequency` and reused it on
  every subsequent set (defaulting to `0` if no get had run
  yet). Per Hamlib `rigs/kenwood/th.c:209-241` the step is
  **computed from the frequency on every set** — not a
  persistent user setting — and the get-side response's step
  field is discarded. Symptoms of the old bug:
  - A fresh actor's first `setFrequency(902_125_000, ...)`
    emitted step `0` (5-kHz grid) which the radio rejects
    above 470 MHz — the UHF band needs step `4` (10-kHz grid).
  - Front-panel step changes on the radio silently overwritten
    the moment the app called `setFrequency` again — the app's
    cached snapshot of an earlier get won the race.
  Fix: replace the `currentStepIndex` field + snapshot with a
  pure `computeStepAndRoundedFreq(hz:)` static that reproduces
  Hamlib's algorithm byte-for-byte (5-kHz vs 6.25-kHz grid
  pick, override to 10-kHz + step `4` above 470 MHz, C-style
  half-up rounding). `getFrequency` no longer stores anything
  locally.

### Refactor

Structural cleanup with **zero behavior change** — the four
largest source files split under the 500-line CLAUDE.md soft
cap:

- `RadioCapabilitiesDatabase+Icom.swift` 1049 → 544 lines,
  with two new sibling files:
  - `RadioCapabilitiesDatabase+IcomV11.swift` (IC-7760,
    IC-7300MK2, D-STAR handhelds — 320 lines)
  - `RadioCapabilitiesDatabase+IcomV12.swift` (v1.2.0
    receivers + specialty — 204 lines)
- `YaesuCATProtocol.swift` 977 → 663 lines, extracting the
  `Quirks` struct and its per-family presets to
  `YaesuCATProtocol+Quirks.swift` (314 lines). The Quirks
  block grew ~130 → ~320 lines through the v1.2.0-v1.2.3
  wire-format audits — moving it out means further Quirks
  additions won't grow the main actor file.
- `RigctldCommandHandler.swift` 900 → 548 lines, extracting
  the level-control set/get dispatch (~355 lines) to
  `RigctldCommandHandler+LevelControl.swift`.
- `RadioCapabilitiesDatabase+Kenwood.swift` 874 → 426 lines,
  with legacy HF + TM/TH mobile/handheld families moved to
  `RadioCapabilitiesDatabase+KenwoodLegacy.swift` (461 lines).

`RigctldCommandHandler.rigController` visibility widened from
`private` to internal so the level-control extension file can
reach it. Not part of the public API surface — the actor's
public methods are unchanged.

### Tests

- Updated `thFamilyGetFrequencyRoundTripsStep` (renamed to
  `thFamilyGetFrequencyDiscardsStepFieldFromResponse`) to
  reflect Hamlib-parity: a get response's step is ignored on
  the subsequent set.
- Updated `thFamilySetFrequencyEmitsFQWith11DigitsPlusHexStep`
  expected wire — 146 MHz now emits step `1` (Hamlib's
  strict-less-than tie-breaker between the 5-kHz and 6.25-kHz
  grids falls through to step `1`).
- Four new tests: `computeStepAndRoundedFreq` for the 5-kHz
  grid, 6.25-kHz grid, and above-470-MHz UHF branch; plus an
  integration test for the UHF branch through `setFrequency`.

Test count 651 → 655. Zero regressions.

## [1.2.3] - 2026-07-30

### Fixed

- **Yaesu newcat `MD` (mode) command emits the qualifier byte.**
  Every Yaesu newcat radio in Hamlib emits `MD0<char>;` (VFO A
  / non-targetable radios) or `MD1<char>;` (VFO B on radios with
  `RIG_TARGETABLE_MODE`) per `newcat.c:1785, 1797-1800`. Prior
  SwiftRigControl releases emitted `MD<char>;` — no qualifier
  byte at all. Real newcat radios accept the short form
  opportunistically but the correct wire has always included the
  qualifier.

  Additionally, on the 8 shipped radios with
  `RIG_TARGETABLE_MODE` (FT-2000, FTDX-5000, FTDX-9000, FTDX-10,
  FT-710, FTDX-101D/MP, FTX-1), `setMode(mode, vfo: .b)` now
  correctly addresses VFO B via `MD1<char>;` instead of silently
  landing on VFO A. Same for `getMode(vfo: .b)`.

  On non-targetable radios (FT-950, FT-991/A, FTDX-3000,
  FTDX-1200, FT-450(D), FT-891) the qualifier is always `0` and
  the `vfo` argument is ignored on the wire — front-panel VFO
  selection dictates which VFO the mode change lands on.
  Matches Hamlib.

### Added

- **`YaesuCATProtocol.Quirks.hasTargetableMode`** — new Bool
  field (default `false`) driving the MD qualifier dispatch.
  Each preset annotated with its Hamlib citation.
- **`YaesuCATProtocol.Quirks.withTargetableMode(_:)`** — copy-
  with-override helper for factory sites where a shared preset
  needs per-radio targetable-mode gating (e.g. `.ft2000Family`
  is shared by FT-2000 (targetable) and FTDX-3000 (not);
  `.newcatNoST` is shared by FT-950 / FT-991 (not) and
  FTDX-5000 / FTDX-9000 (targetable)).

### Changed

- **`.ftdx10Family`, `.ftdx101Family`, `.ft710`, `.ftx1` presets
  now default to `hasTargetableMode: true`.**
- **Factory updates in `YaesuModels.swift`:** FT-2000 →
  `.ft2000Family.withTargetableMode()`; FTDX-5000, FTDX-9000 →
  `.newcatNoST.withTargetableMode()`. All other factories
  unchanged.
- **`getMode` response parser** now reads the mode character at
  index 3 (post-qualifier), matching the `MD<q><char>;` wire
  format Hamlib emits.

### Tests

- Three updated tests (`setMode`, `getMode`, `modeMappings`,
  `completeWorkflow`, `ftx1SetModeMapsCWToCode3`,
  `ftx1SetModeMapsCWReverseToCode7`) to lock the new correct
  wire.
- Four new regression tests:
  `setModeEmitsQualifierByteOnNonTargetableRadio`,
  `setModeEmitsVFOBQualifierOnTargetableMode`,
  `getModeQueryEmitsVFOBQualifierOnTargetableMode`,
  `setModeIgnoresVFOArgumentOnNonTargetableRadio`.

Test count 647 → 651. Zero regressions.

## [1.2.2] - 2026-07-30

### Fixed

- **Yaesu newcat SH (IF filter / bandwidth) command dispatched
  per-family.** Prior to this release every Yaesu newcat radio
  emitted the same `SH0%02d;` wire format. Per Hamlib
  `rigs/yaesu/newcat.c:9202-9220` there are actually **four
  incompatible SH variants** across the family:
  - `SH%c%02d;` — FT-950, FT-991(A), FTDX-5000, FTDX-1200,
    FTDX-9000, FT-450(D)
  - `SH0%02d;` — FT-2000, FTDX-3000
  - `SH00%02d;` — FTDX-10, FT-710, FTX-1
  - `SH%c%d%02d;` — FTDX-101D/MP (real narrow flag),
    FT-891 (flag always `1`)

  Radios in the double-zero and vfo-plus-narrow families
  silently rejected the old form. FTDX-10, FT-710, FTX-1,
  FTDX-101D/MP, and FT-891 (6 radios in the shipped catalog)
  are affected. Fix: introduce
  `YaesuCATProtocol.Quirks.SHCommandStyle` and route
  `setIFFilter` / `getIFFilter` through it. The `get` response
  parser also learned to handle both the 6-char `SHXnn;` and
  7-char `SHXYnn;` reply widths (FTDX-101 emits the wider form
  with the narrow flag echoed back).

### Added

- **`YaesuCATProtocol.Quirks.SHCommandStyle`** enum with four
  cases (`.qualifierOnly`, `.zeroWithoutQualifier`, `.doubleZero`,
  `.vfoAndNarrow(narrowAlwaysOn:)`), each citing the Hamlib line
  where the format is emitted.
- **`filterCommandStyle`** field on `Quirks` (defaults to
  `.qualifierOnly` for source compatibility).
- Three new named `Quirks` presets:
  - `.ftdx10Family` — ST-DX split + `.doubleZero` SH (FTDX-10)
  - `.ftdx101Family` — ST-DX split + `.vfoAndNarrow` SH
    (FTDX-101D/MP)
  - `.ft2000Family` — no-ST split + `.zeroWithoutQualifier` SH
    (FT-2000, FTDX-3000)

  Existing `.ftx1`, `.ft710`, `.ft891` presets updated to their
  correct `filterCommandStyle`.

### Changed

- **Factory updates in `YaesuModels.swift`:** FTDX-10 →
  `.ftdx10Family`; FTDX-101D/MP → `.ftdx101Family`; FT-2000,
  FTDX-3000 → `.ft2000Family`. `.newcatWithSTDX` and
  `.newcatNoST` presets retained for source compatibility but
  no longer used by any built-in factory.

### Tests

- Six new `SH` per-family assertions in
  `YaesuCATProtocolTests`: double-zero for FTDX-10/FT-710/FTX-1,
  vfo-and-narrow for FTDX-101/FT-891, zero-without-qualifier
  for FT-2000, plus a `getIFFilter` regression that parses the
  7-char FTDX-101 response format.

Test count 640 → 647. Zero regressions.

## [1.2.1] - 2026-07-29

### Fixed

- **Low-baud-rate framing for Yaesu binary CAT (FT-857 report,
  MacWinlink beta30 field report).** `YaesuPortableCAT` and
  `YaesuFT847CAT` read fixed-length status frames — 5-byte
  frequency/mode responses and 1-byte TX/RX status. The old code
  called `transport.read(timeout:)` once and treated any shorter
  response as `RigError.invalidResponse`. At 4800 baud (FT-857 /
  FT-897 factory default) each byte takes ~2 ms, so a single
  `Darwin.read` typically returns 1–3 bytes of a 5-byte frame and
  the caller saw a spurious "Received invalid response from
  radio." flrig on the same hardware worked because it accumulates.
  Fix: introduce `SerialTransport.readExact(count:timeout:)`, the
  fixed-length counterpart to `readUntil(terminator:timeout:)`,
  and route every Yaesu binary status/ACK path through it. Frames
  now accumulate across multiple OS reads until the full expected
  length arrives or the timeout budget expires.

### Added

- **`SerialTransport.readExact(count:timeout:)`** protocol
  requirement plus a source-compatible default extension that
  loops `read(timeout:)` and accumulates. `IOKitSerialPort`
  overrides with a tighter `Darwin.read` loop that inherits the
  remaining budget on each iteration to avoid double-timing.
  `MockSerialTransport` and the test-scoped `MockTransport`
  gain a `setChunkedResponse(_:)` helper for scripting
  multi-chunk arrival patterns in tests.

### Tests

- `ReadExactTests` — verifies zero-count, accumulation across
  chunks, over-read trimming, and `.timeout` (not
  `.invalidResponse`) on a silent wire.
- `YaesuPortableCATTests.getFrequencyReassemblesChunkedResponseAtLowBaudRate`
  — regression for the FT-857 4800-baud report; scripts a 1 + 2 +
  2 byte arrival pattern and confirms `getFrequency` decodes
  correctly.

Test count 635 → 640. Zero regressions.

## [1.2.0] - 2026-07-25

### v1.2.0 highlights

v1.2.0 is the largest single release in SwiftRigControl history.
Catalog grew **103 → 126 radios** (23 additions across the
Icom, Yaesu, Kenwood, Flex, and Ten-Tec families), plus **25
latent protocol bugs fixed** that were quietly shipping in
prior releases against radios that had never been hardware-
verified.

The release started as a radio-catalog expansion (see
`Documentation/RADIO_PARITY_v1.2.md`) but expanded to include
substantial protocol-correctness work as latent bugs surfaced
during the byte-level Hamlib audit that gated the ship
decision. Every latent-broken definition in the catalog now
either (a) uses the correct protocol adapter for the first
time or (b) is explicitly flagged for follow-up in v1.2.1.

**Catalog additions (23):**
- 6 Icom receivers + specialty (IC-R6, IC-R20, IC-R7100,
  IC-F8101, IC ID-1, IC-RX7)
- 2 Flex family (SDR-Console, PiHPSDR)
- 5 Kenwood legacy HF (TS-450S, TS-690S, TS-940S, TS-950S,
  TS-950SDX)
- 4 Yaesu classic (FT-847UNI, mcHF QRP, FT-1000MP MARK-V,
  FT-1000MP MARK-V Field)
- 1 Yaesu new flagship (FTX-1, 2025)
- 1 Ten-Tec receiver (RX-320)
- 4 Kenwood TH/TM family (TM-D710(G), TM-V71(A), TH-F6A,
  TH-F7E)

**New protocol adapters (5):**
- `YaesuPortableCAT` — pre-newcat 5-byte binary for FT-817
  family (fixes 8 broken definitions)
- `YaesuFT847CAT` — pre-newcat with satellite mode
- `YaesuFT1000MPCAT` — pre-newcat with little-endian BCD
- `TMFamilyCAT` — 13-field CSV FO command
- `THFamilyCAT` — FQ + MD discrete commands
Plus a `Family` enum extension on the existing `THD72Protocol`
to correctly drive TH-D74 and TH-D75 (fixes 2 broken
definitions).

**Latent bugs fixed (25):**
- FT-817-family shipping wrong protocol adapter (8 radios,
  YaesuPortableCAT batch)
- FT-847, FT-1000MP wrong adapter (YaesuFT847CAT + FT1000MP
  batch)
- 15 modern Yaesu newcat radios shipping 11-digit FA/FB
  frequency format (correct wire is 9-digit; FTX-1 batch)
- TH-D74, TH-D75 wired to KenwoodProtocol instead of the
  CR-terminated THD72Protocol (Group E batch)
- Kenwood mode codes 8 and 9 swapped, affecting every Kenwood
  HF radio + Elecraft K-series + Lab599 TX-500 + Flex family
  (audit-fix batch, 27 radios)
- FT-847 getPTT bit polarity inverted (3 radios)
- Yaesu newcat GT (AGC) command completely wrong format (24
  radios)
- Yaesu newcat RG (RF gain) missing VFO qualifier (24 radios)
- Yaesu newcat SH (IF filter) missing VFO qualifier (24
  radios)
- Yaesu newcat RU/RD (RIT/XIT) signed vs unsigned + missing
  `RC;` prelude (24 radios)

**New infrastructure:**
- `Vendor.allRadios` static arrays + `withCivAddress(_:)`
  helper — downstream apps can now enumerate radios instead
  of hand-maintaining parallel picker lists.
- `HostRequirement` enum — flags 4 Flex definitions that
  require a Windows/Linux companion machine (PowerSDR,
  Thetis, SDR-Console, PiHPSDR).
- Weekly Hamlib upstream-watch GitHub Action — surfaces new
  Hamlib radios, security advisories, and fix-vs-refactor
  bucketed commits touching files SwiftRigControl mirrors.
- `Documentation/RADIO_PARITY_v1.2.md` — audit table plus
  release-batch planning.
- 6 new `Manufacturer` enum cases (Guohetec, Anytone, Elad,
  CommRadio, Alinco, AOR) — additive scaffolding for future
  vendor adapters. Radios in these vendors deferred to
  v1.3.0+ per the parity plan.

**Test coverage:** 542 → 635 tests. Every fix has regression
coverage. Zero regressions across the release.

**Known follow-ups deferred to v1.2.1 patch:** 11 items — Yaesu
MD VFO qualifier for `RIG_TARGETABLE_MODE` radios, SH
per-family variants (FTX-1/FT-DX10/FT-710 want `SH00%02d;`),
Kenwood AG/SQ format variants (TS-450S/TS-690S / TS-890S
dual-RX), TH-D72 power quantization API contract, THFamilyCAT
step persistence, Ten-Tec Orion II bandwidth follow-up, Orion
split command shape, legacy S-meter parsing, plus per-radio
test coverage expansion. See individual entries below.

### Detailed changes below

#### Plumbing

- Extend `RadioDefinition.Manufacturer` with 6 new cases:
  `.guohetec`, `.anytone`, `.elad`, `.commradio`, `.alinco`,
  `.aor`. Additive but requires downstream consumers with
  exhaustive switches to add a `default:` arm.
- Add 6 empty vendor namespaces
  (`RadioDefinition.Guohetec/Anytone/Elad/CommRadio/Alinco/AOR`),
  each with an `allRadios: [RadioDefinition] = []` array to be
  populated by follow-up adapter PRs.
- Extend `allSupportedRadios`, `allRadios(for:)`,
  `RadioIdentifyProbe`, and `RadioCatalogDriftTests` for the 6
  new vendors.
- Extend `HAMLIB_WATCH.md` with per-vendor sections listing the
  upstream Hamlib source paths each adapter will mirror. Extend
  `Scripts/hamlib-diff.sh` `vendor_dirs` list and
  `hamlib_to_swift()` case arms.

#### Group D — Icom receivers + specialty (6 radios)

Definition-only additions to the Icom catalog, all reusing the
existing `IcomCIVProtocol` + `StandardIcomCommandSet`:

- **IC-R6** (2009) — compact handheld wideband receiver, 100 kHz
  – 1.31 GHz, AM/FM/WFM. Per Hamlib `icr6.c` the CAT interface
  does not expose the memory-channel list.
- **IC-R20** (2004) — dual-VFO handheld wideband receiver, 150
  kHz – 3.305 GHz, AM/CW/SSB/FM/WFM, ~1250 CAT-accessible memory
  channels. Marketed as "Dual receive."
- **IC-R7100** (1993) — VHF/UHF communications receiver, 25 MHz
  – 2 GHz, AM/SSB/FM/WFM. Notoriously slow serial link — 1200
  baud maximum per Hamlib `icr7000.c`.
- **IC-F8101** (2010) — HF SSB transceiver, 1.6–30 MHz, 100 W.
  Commercial-adjacent land-mobile HF radio; serial link tops
  out at 38400 baud per Hamlib `icf8101.c`.
- **IC ID-1** (2004) — first-generation 1.2 GHz D-STAR mobile,
  10 W TX. Industry's first D-STAR transceiver. Default CI-V
  address 0x01 shared with IC-92AD — set a custom address if
  both are on one bus. Model string is `IC ID-1` (with space)
  matching Hamlib's `id1.c` `model_name`.
- **IC-RX7** (2007) — compact handheld wideband receiver, 150
  kHz – 1.3 GHz, AM/FM/WFM. Predecessor to the IC-R6. Per
  Hamlib `icrx7.c` the CAT interface does not expose the
  memory-channel list.

All six use the existing `IcomCIVProtocol` and add matching
entries to `IcomRadioModel`, `RadioCapabilitiesDatabase.Icom`,
`StandardIcomCommandSet`, `Icom.allRadios`, and the drift-test
`expectedModels` set. Total Icom count: 45 → 51.

#### Group I — Flex-family TS-2000-emulation SDR clients (2 radios)

- **SDR-Console** (Simon Brown / SDR Radio) — Windows-first SDR
  client that drives external SDR hardware via a TS-2000-style
  Kenwood CAT emulation, typically bridged through a virtual
  serial port. Registered in Hamlib as `RIG_MODEL_SDRCONSOLE` in
  `rigs/kenwood/ts2000.c`.
- **PiHPSDR** (OpenHPSDR) — open-source SDR client for HPSDR /
  ANAN hardware, running on Raspberry Pi or desktop Linux.
  Registered in Hamlib as `RIG_MODEL_HPSDR` in
  `rigs/kenwood/pihpsdr.c` (dedicated file, TS-2000-derived per
  the file header).

Both use the existing `KenwoodProtocol` (no new protocol code)
and land as static factories on the existing `RadioDefinition.Flex`
namespace alongside `flex6000`, `powerSDR`, `thetis`. Total Flex
count: 3 → 5.

**Correction from earlier plan.** The v1.2.0 plan's Group I also
listed "Elecraft F6K" as a separate radio; on reading
`rigs/kenwood/flex6xxx.c` I confirmed `RIG_MODEL_F6K` is the
Flex 6000-series that SwiftRigControl already ships as
`Flex.flex6000` (model string `"6000-series"`). Not a gap; not
included.

#### Group G — Kenwood legacy HF (5 radios)

Definition-only additions to the Kenwood catalog covering 1980s
and early-1990s flagship HF transceivers that remain common on
the air:

- **TS-450S** (1991) — HF 100 W, no 6m. Optional AT-450 internal
  ATU. Cross-checked against Hamlib `ts450s.c`.
- **TS-690S** (1992) — TS-450S with 6m added. Cross-checked
  against Hamlib `ts690.c`.
- **TS-940S** (1985) — Kenwood's mid-1980s flagship HF, 100 W.
  Cross-checked against Hamlib `ts940.c`. Note the model name is
  "TS-940S" (with S suffix) even though the RIG_MODEL enum drops
  it.
- **TS-950S** (1988) — 150 W HF flagship. Unusual serial
  framing — 8-N-2 with **no** flow control, requiring the new
  `SerialDefaults.kenwoodLegacyNoHandshake` profile added in
  this release.
- **TS-950SDX** (1991) — DSP-equipped variant of TS-950S. Same
  CAT surface and serial framing.

All five use the existing `KenwoodProtocol` (`;`-terminated).
Four of the five reuse the existing `SerialDefaults.kenwoodLegacy`
profile (8-N-2, hardware handshake — same as the already-shipped
TS-850S); TS-950S/SDX get the new `.kenwoodLegacyNoHandshake`
profile.

Doc drift correction: the `kenwoodLegacy` `SerialDefaults` docs
previously listed only TS-850S as an example. Updated to note
TS-450S / TS-690S / TS-940S all use the same profile per Hamlib.

Total Kenwood count: 15 → 20.

### v1.2.0 catalog totals so far

Icom 45 → 51 (Group D); Flex 3 → 5 (Group I); Kenwood 15 → 20
(Group G). SwiftRigControl total: 103 → 116 across three
reuse-existing batches. Groups A, B, C, E, H, K, L (new-protocol
adapters) and FTX-1 still pending.

#### HostRequirement — flag radios that need a companion machine

Adds a new `RadioDefinition.HostRequirement` enum plus a
`hostRequirement: HostRequirement` field on `RadioDefinition`
that flags whether a radio can be driven from a Mac by itself or
requires a companion Windows / Linux host running the SDR
application whose CAT bridge SwiftRigControl connects to.

Cases:

- `.standalone` (default) — physical CAT over USB serial, or
  TCP-native software radio like the Flex 6000-series SmartSDR
  TCP bridge. Works with only a Mac. This is what every radio
  in the catalog defaults to.
- `.windowsCompanion(app: String)` — the CAT interface is a
  virtual serial port exposed by a Windows-only SDR app. A Mac
  can connect via serial-over-network tunnel (e.g. `socat`,
  `com2tcp`), but a Mac alone cannot drive it.
- `.linuxCompanion(app: String)` — same story for a Linux /
  Raspberry Pi host.

Four existing Flex-namespace definitions are flagged
appropriately as of this release:

- `Flex.powerSDR` → `.windowsCompanion(app: "PowerSDR")`
- `Flex.thetis` → `.windowsCompanion(app: "Thetis")`
- `Flex.sdrConsole` → `.windowsCompanion(app: "SDR-Console")`
- `Flex.pihpsdr` → `.linuxCompanion(app: "PiHPSDR")`

Their DocC comments gain a `> Note:` block explaining the
companion-host requirement so anyone reading the API (or a
picker UI) sees the constraint upfront, not after failing to
connect. `Flex.flex6000` stays `.standalone` — SmartSDR exposes
CAT on a TCP socket the Mac can connect to directly.

Additive, non-breaking: existing callers that don't touch
`hostRequirement` see zero source impact. Adding the field with
a default value means every not-explicitly-flagged radio
correctly defaults to `.standalone`. `HostRequirement` conforms
to `Sendable` and `Equatable` for switch dispatch and picker-UI
filtering.

Drift-test coverage: `RadioCatalogDriftTests` gains seven new
assertions covering the flagged four, `Flex.flex6000` as
standalone, an invariant that every non-flagged radio in
`allSupportedRadios` is `.standalone` (so a future non-Flex
adapter that needs `windowsCompanion` won't silently ship
mis-flagged), and a display-name check.

#### YaesuPortableCAT — fixes 8 previously-broken Yaesu definitions

Adds a new `YaesuPortableCAT` actor implementing the pre-newcat
5-byte binary CAT protocol used by the FT-817 family of portable
and mobile Yaesu transceivers. Rewires 8 existing radio
definitions from the incorrect `YaesuCATProtocol` (the modern
newcat driver) to the new `YaesuPortableCAT`:

- FT-817, FT-818 (portables)
- FT-857, FT-857D (mobiles)
- FT-897, FT-897D (mobile/portable base)
- FT-100 (mobile)
- FT-920 (base with DSP)

**Prior to this release these 8 definitions shipped with a
protocol adapter that didn't drive them.** `YaesuCATProtocol`
was designed for the modern semicolon-terminated newcat radios
(FT-950 / FT-991 / FTdx / FT-710) and its inline documentation
already noted "this shared newcat implementation does not drive
[the FT-817 family] anyway." Any Mac app that shipped a
picker containing one of these 8 radios and let an operator
connect would fail silently (no bytes emitted, no responses
parseable). This release closes that gap.

Frame layout: 5-byte fixed `[P1, P2, P3, P4, Opcode]` frames,
no checksum, no terminator. Set commands read a 1-byte ACK
(`ft817_read_ack()` in Hamlib). Status commands (opcode `0x03`
for freq+mode, `0xF7` for TX status) return fixed-length
payloads without ACK. Frequency is 8-digit **big-endian** BCD
in 10-Hz units. Mode selectors: LSB=0x00, USB=0x01, CW=0x02,
CW-R=0x03, AM=0x04, FM=0x08, FM-N=0x88, DIG=0x0A, PKT=0x0C
(both DATA-USB and DATA-LSB collapse to PKT, matching hardware).

Every byte fixture in the 23-test protocol suite is derived
directly from Hamlib `rigs/yaesu/ft817.c`. That's the closest
we can get to hardware verification without owning one of
these radios, but downstream operators should treat FT-817
family support as "definition-only against the reference
implementation" until a hardware validator lands.

**Two other Yaesu radios kept using YaesuCATProtocol** but
gained explicit `> Warning:` doc blocks flagging the same
class of bug pending a follow-up port:

- `Yaesu.ft847` — FT-847 uses a distinct pre-newcat CAT with
  satellite-mode VFO opcodes (0x03/0x13/0x23 per Hamlib
  `rigs/yaesu/ft847.c`). Needs `YaesuFT847Protocol`.
- `Yaesu.ft1000MP` — FT-1000MP uses pre-newcat CAT with
  dual-VFO opcodes (0x0A/0x8A) and **little-endian** BCD (per
  Hamlib `rigs/yaesu/ft1000mp.c`) — opposite endian to the
  FT-817 family. Needs `YaesuFT1000MPProtocol`.

Both are lower-usage than the FT-817 family; their fixes are
tracked for a follow-up release.

Test count 555 → 578 (23 new); zero regressions. Clean build
under Swift 6 strict concurrency.

#### YaesuFT847CAT + YaesuFT1000MPCAT — finish the Yaesu binary CAT port

Adds two new pre-newcat Yaesu binary CAT actors and 4 new radios,
finishing the Yaesu classic-family port started in the previous
release. Fixes the two remaining "warning-flagged" definitions
(`Yaesu.ft847`, `Yaesu.ft1000MP`) that were still shipping the
wrong protocol adapter, and adds the previously-deferred Group F
variants.

**`YaesuFT847CAT`** — covers the FT-847 family:

- Big-endian BCD frequency encoding (like the FT-817 family)
- Mode selector in byte 0 (P1)
- **Fire-and-forget** set commands — no ACK read (contrast with
  FT-817 which reads a 1-byte ACK). Attempting to read a
  nonexistent ACK would time out and mask real errors.
- **Satellite mode** support via `setSatelliteMode(_:)` — toggles
  the radio between main-VFO (opcode 0x03/0x07/0x01) and
  sat-VFO (opcodes 0x13/0x23 for SAT RX / SAT TX freq queries;
  0x11/0x21 for SAT RX / SAT TX freq sets)
- **Unidirectional variant** flag `isUnidirectional: Bool` —
  when true (FT-847UNI, FT-650), getters throw
  `.unsupportedOperation`; setters continue to write

**`YaesuFT1000MPCAT`** — covers the FT-1000MP family:

- **Little-endian** BCD frequency encoding (opposite endian to
  the FT-817/847 families). See
  `YaesuBinaryFrame.encodeBCDLittleEndian8(_:)`.
- Mode selector in byte 3 (P4). High bit of P4 tags VFO A vs
  VFO B: 0x00-0x0B for A, 0x80-0x8B for B.
- Dual-VFO frequency opcodes: 0x0A for VFO A, 0x8A for VFO B.
- Fire-and-forget set commands.
- Getters (`getFrequency`, `getMode`, `getPTT`) throw
  `.unsupportedOperation` in this release — the FT-1000MP's
  16-byte status-update-block response uses a distinct
  non-BCD encoding (raw big-endian binary × 10/16, per the
  radio's 1.5625 Hz PLL step) that deserves a dedicated
  hardware-verified implementation.

Both new actors share a new `YaesuBinaryFrame` enum with static
BCD encode/decode helpers for both endiannesses. The
`YaesuPortableCAT` big-endian helpers were refactored into this
shared location — no behavior change, but callers reading
`YaesuPortableCAT.encodeBCDBigEndian8(_:)` should now read
`YaesuBinaryFrame.encodeBCDBigEndian8(_:)`. The `internal`
visibility means downstream consumers were not affected.

**Rewired factories:**

- `Yaesu.ft847` — no longer uses `YaesuCATProtocol`. Now uses
  `YaesuFT847CAT`.
- `Yaesu.ft1000MP` — no longer uses `YaesuCATProtocol`. Now
  uses `YaesuFT1000MPCAT`.

Both had `> Warning:` doc blocks in the previous release
flagging them as broken; those warnings are removed.

**New radios (4):**

- `Yaesu.ft847UNI` — FT-847 with the unidirectional CAT mod.
  Same wire protocol; unidirectional flag on.
- `Yaesu.mchfQRP` — mcHF QRP open-source kit. Wire protocol
  identical to FT-847 per Hamlib.
- `Yaesu.ft1000MPMkV` — 200W upgrade of the FT-1000MP (2000).
  Hamlib documents these as "identical" wire protocol; only
  maxPower differs, which we currently don't model per-variant
  (both share `RadioCapabilitiesDatabase.Yaesu.ft1000MP`).
- `Yaesu.ft1000MPMkVField` — 100W field-portable MkV (2001).
  Same wire protocol.

Cross-referenced against Hamlib `rigs/yaesu/ft847.c` ncmd table
(lines 236-318) and `rigs/yaesu/ft1000mp.c` ncmd table (lines
168-217). Every byte fixture in the 28-test suite maps to a
specific Hamlib table entry with line-number citations in the
test comments.

Test count 578 → 606 (28 new); zero regressions. Clean build.

Yaesu catalog: 25 → 29. Total: 116 → 120.

#### FTX-1 + Yaesu newcat frequency-format bug fix

Adds `Yaesu.ftx1` for Yaesu's 2025 flagship portable, and fixes a
**latent bug affecting every newcat Yaesu radio in the catalog**
that was uncovered while porting FTX-1.

**The bug.** Since v1.0.0 our `YaesuCATProtocol.setFrequency` has
emitted an 11-digit format (`FA00014230000;`) that no real Yaesu
radio accepts. Hamlib's newcat uses either **9 digits**
(`FA014230000;` — modern radios: FT-DX10, FT-DX101(D/MP), FT-991,
FT-991A, FT-710, FT-891, FTX-1) or **8 digits** (older newcat
radios that respond to `IF` with a 27- or 30-byte payload) — see
`rigs/yaesu/newcat.c` `newcat_set_freq` and the variable-width
dispatch driven by the `IF` response length. `getFrequency` had
the same 11-digit parser assumption. Neither would match real
hardware.

Because none of these radios have been hardware-verified in
SwiftRigControl (the current 5-radio verified tier is Icom
IC-7100/7600/9700, Elecraft K2, Kenwood TH-D72A — no Yaesu),
the bug went undetected. It affects: FT-950, FT-991, FT-991A,
FT-2000, FT-450, FT-450D, FT-710, FT-891, FT-DX10,
FT-DX101D/MP, FT-DX1200/3000/5000, FT-9000, and the new FTX-1
— 15 currently-shipping definitions.

**The fix.** `YaesuCATProtocol.Quirks` gains a
`frequencyDigits: Int` field with a default of 9 (correct for
every modern newcat radio). Both `setFrequency` and
`getFrequency` now use it. A specific older radio needing 8
digits can override via a new Quirks case in a follow-up
release. The existing `YaesuCATProtocolTests` were updated to
assert the correct 9-digit wire format; two new regression tests
guard against the bug returning.

**Also added:** `Quirks.modeCodeTable: [Mode: Character]?` for
per-radio mode-selector table overrides, and
`Quirks.requiresMemoryModeEscape: Bool` for the FTX-1's
`SV0;` prelude requirement. Both default to inactive; only the
new `Quirks.ftx1` static uses them.

**FTX-1 specifics** (from `rigs/yaesu/ftx1/`, added to Hamlib in
2025):

- Same semicolon-terminated newcat protocol as FT-DX10 / FT-710,
  with 9-digit frequency format.
- Mode codes diverge from the shared newcat table on codes 3
  and 7: FTX-1 uses `3` = CW-USB (shared table: CW) and `7` =
  CW-LSB (shared: CW-R). Swift `.cw` maps to `3` and `.cwR` to
  `7` on FTX-1. C4FM and PSK codes exist in Hamlib but have no
  Swift `Mode` equivalent and are omitted from the table.
- Memory-mode escape prelude: FTX-1 silently treats `MD` / `FA` /
  `FB` sets as transient overlays while Main is in Memory mode.
  Hamlib's `ftx1_ensure_vfo_mode()` sends `SV0;` before each set;
  `Quirks.requiresMemoryModeEscape = true` mirrors that behavior.

New radio `Yaesu.ftx1` shares the FTdx10 capabilities (same HF+6m,
100 W coverage). Registered in `Yaesu.allRadios` and the drift
test.

**HAMLIB_WATCH.md** gains a row for `rigs/yaesu/ftx1/*.c`.
`Scripts/hamlib-diff.sh` `hamlib_to_swift()` gets an explicit
case mapping the FTX-1 subdirectory to `YaesuCATProtocol.swift`
(Quirks.ftx1) + `YaesuModels.swift`.

**Not in scope for this fix**, and tracked as follow-up:
- `RG`, `GT`, `SH` commands emitted without the VFO qualifier
  byte Hamlib uses (`RG0%03d` vs our `RG%03d`, etc.). These are
  the same class of bug and affect the same 15 radios; audit
  visible in the commit message trail.
- `RU` / `RD` clarifier commands use `%+05d` (5-char with sign)
  where Hamlib uses `%04ld` (4-digit unsigned, direction encoded
  in command letter).

Test count 606 → 612 (6 new); zero regressions. Clean build.

Yaesu catalog: 29 → 30. Total: 120 → 121. Yaesu amateur-2000+
coverage: 100% (FTX-1 was the last remaining hole).

#### Group J narrower fix — RX-320 (Ten-Tec)

Adds `TenTec.rx320` — Ten-Tec RX-320 PC-controlled HF general-
coverage receiver (1998). 100 kHz – 30 MHz, AM/CW/SSB, no
transmitter.

Uses the existing `TenTecLegacyProtocol` — the RX-320 shares the
`tentec_*` command family with the Jupiter (TT-538) and Pegasus
(TT-550) per Hamlib `rigs/tentec/rx320.c`. `TenTecLegacyProtocol`
already throws `.unsupportedOperation` on `setPTT`, which is
correct behavior for a receiver.

**Correction from earlier plan.** The v1.2.0 plan's Group J
originally listed three radios (RX-320, RX-340, RX-350). On
reading the Hamlib sources, only RX-320 reuses an existing
protocol:
- RX-320: shared `tentec_*` (matches our TenTecLegacyProtocol).
- RX-340: distinct per-radio `rx340_*` (~590 LOC in Hamlib).
- RX-350: `tentec2_*` — a separate Argonaut-V-family protocol
  (~600 LOC combined in tentec2.c + rx350.c).

RX-340 and RX-350 each need their own protocol adapter and are
deferred to a follow-up "Ten-Tec receivers" adapter PR alongside
the other new-vendor adapters.

Test count 612 unchanged (RX-320 rides the drift test); Ten-Tec
catalog 5 → 6. Total 121 → 122.

#### Group E — Kenwood TH/TM CR-terminated CAT (4 new + 2 fixed)

Adds two new protocol adapters and 4 new radios, plus fixes a
latent bug affecting the existing `Kenwood.thd74` /
`Kenwood.thd75` factories.

**The latent bug (2 fixed).** `Kenwood.thd74` and
`Kenwood.thd75` were shipping wired to `KenwoodProtocol`
(semicolon-terminated), but Hamlib documents both radios'
`.cmdtrm = EOM_TH` (CR-terminated) with an `FO`-string protocol
like the TH-D72. Same class of bug as the FT-817 family and
Yaesu newcat freq-format bugs fixed earlier in this release —
hidden because neither TH-D74 nor TH-D75 was hardware-verified.

Fix: `THD72Protocol` gains a `Family` enum with `.thd72`
(existing behavior, default) and `.thd74` (TH-D74 + TH-D75).
Family carries per-variant field offsets — TH-D72's FO response
is 53 bytes with mode at char 51; TH-D74's is 72 bytes with mode
at char 31. TH-D75 uses the TH-D74 family case per Kenwood's
service documentation (TH-D75 is not yet in Hamlib but is
documented as TH-D74-compatible). Both factories rewired to use
`THD72Protocol` with `family: .thd74`.

**Two new protocol adapters.**

`TMFamilyCAT` — covers TM-D710(G) and TM-V71(A) dual-band FM
mobiles. Different from `THD72Protocol` despite the family
resemblance: the FO command uses **13 comma-separated fields**
instead of a fixed-position ASCII string, and VFO is embedded in
FO field 0 rather than selected with a separate `BC` command.
Cross-checked against Hamlib `rigs/kenwood/tmd710.c`
`tmd710_push_fo()` (line ~1008) — one file covers both radios.

`THFamilyCAT` — covers TH-F6A and TH-F7E. Distinct again: no
omnibus FO command; frequency comes off the wire via `FQ` (11-
digit Hz + hex tuning step) and mode via a separate `MD`
command. Cross-checked against Hamlib `rigs/kenwood/th.c` shared
helpers (used by both `thf6a.c` and `thf7.c`).

Three focused actors — one per family — matches Hamlib's own
file layout. Unifying would produce a `switch family` explosion
where the three protocols diverge on almost every command.

**Four new radios:**

- **TM-D710(G)** (2007+) — dual-band FM mobile, 2m (50 W) +
  70cm (35 W), wideband RX 118-524 MHz. Uses `TMFamilyCAT`.
- **TM-V71(A)** (2005+) — TM-D710 minus D-STAR / TNC hardware.
  Same wire protocol.
- **TH-F6A** — tri-band FM/SSB handheld (2m + 1.25m + 70cm,
  5 W FM). Broadband RX 100 kHz – 1.3 GHz in FM/WFM/AM/LSB/USB/CW.
  Uses `THFamilyCAT`.
- **TH-F7E** — European TH-F6A variant (2m + 70cm TX, no 1.25m
  allocation in Region 1). Same wire protocol.

Verification: 13 new protocol tests covering all three actors
(THD72Protocol .thd72 baseline + .thd74 variant, TMFamilyCAT
FO round-trip + VFO routing + PTT + mode mapping, THFamilyCAT
FQ format + MD command + step round-trip). Every fixture cites
the specific Hamlib source line.

Test count 612 → 625. Zero regressions. Clean build.

Kenwood catalog: 20 → 24. Total: 122 → 126. Kenwood
amateur-2000+ coverage now covers every Hamlib RIG_MODEL_TMD710
/ RIG_MODEL_TMV71 / RIG_MODEL_THF6A / RIG_MODEL_THF7E entry.

#### Audit-fix batch — 6 critical bugs found by protocol audit

Before cutting v1.2.0 we ran a byte-level protocol audit across
every one of the 126 catalog radios, spread across 6 parallel
sub-agent reports. The Icom CI-V family (51 radios) passed with
100% Hamlib match. The other 5 families surfaced 6 critical bugs
plus a handful of medium / low issues. This batch fixes the 6
criticals with regression tests for each.

**Fix 1: Kenwood mode codes 8 and 9 swapped.** Prior code mapped
`.rttyR` → `MD8;` and `.dataLSB` → `MD9;`. Per Hamlib
`rigs/kenwood/kenwood.c` `kenwood_mode_table` (lines 141-167),
mode 8 is `RIG_MODE_NONE` (TUNE on most radios) and mode 9 is
`RIG_MODE_RTTYR` (FSK-R). Sending `MD8;` for reverse RTTY put
the radio into TUNE mode silently. Also adds `.dataUSB` → `MD13;`
(PKT-USB) which wasn't previously mapped; `.dataLSB` now correctly
maps to `MD12;` (PKT-LSB). Affects every Kenwood HF radio,
Elecraft K-series, Lab599 TX-500, and Flex-family radios using
`KenwoodProtocol` — 27 radios total.

**Fix 2: FT-847 getPTT bit polarity inverted.** Per Hamlib
`ft847.c:1673`:

```c
*ptt = (p->tx_status & 0x80) ? RIG_PTT_OFF : RIG_PTT_ON;
```

Bit 7 SET means PTT OFF, bit 7 CLEAR means PTT ON. Swift had
this inverted — `getPTT()` returned `false` while the radio was
transmitting and `true` while idle. Affects FT-847, FT-847UNI,
mcHF QRP.

**Fix 3: Yaesu newcat GT (AGC) command format completely wrong.**
Prior code emitted 3-digit codes (`GT000`, `GT001`, `GT002`,
`GT003`) with mapping Fast=0, Medium=1, Slow=2, Auto=3. Per
Hamlib `newcat.c:4142-4158`, the correct wire is 2-digit codes
with mapping OFF=00, FAST=01, MEDIUM=02, SLOW=03, AUTO=04. Real
newcat radios reject both the width and the mapping. Affects all
24 modern Yaesu radios (FT-DX10 / FT-DX101(D/MP) / FT-DX1200 /
FT-DX3000 / FT-DX5000 / FT-9000 / FT-450(D) / FT-710 / FT-891 /
FT-950 / FT-991(A) / FT-2000 / FTX-1).

**Fix 4: Yaesu newcat RG (RF gain) missing VFO qualifier.** Prior
code emitted `RG%03d;`. Per Hamlib `newcat.c:4477`:

```c
SNPRINTF(..., "RG%c%03d%c", main_sub_vfo, fpf, cat_term);
```

Correct wire is `RG0%03d;` (main receiver) or `RG1%03d;` (sub).
Query is `RG0;` not `RG;`. Response is `RG0nnn;` with VFO byte
between prefix and value. Affects all 24 modern Yaesu radios.

**Fix 5: Yaesu newcat SH (IF filter / bandwidth) missing VFO
qualifier.** Prior code emitted `SH%02d;`. Per Hamlib
`newcat.c:9205-9218` the format varies per radio family
(`SH00%02d;` for FTX-1/FT-DX10/FT-710, `SH0%02d;` for FT-2000
family, `SH%c%d%02d;` for FT-DX101 with narrow-flag). This fix
emits `SH0%02d;` — the common single-VFO-qualifier form that
works on the broadest set of modern newcat radios. **Shipped in
v1.2.2** as `Quirks.SHCommandStyle` / `filterCommandStyle`,
routing FTDX-10/FT-710/FTX-1 → `SH00`, FTDX-101D/MP/FT-891 →
narrow-flag form, FT-2000/FTDX-3000 → zero-without-qualifier.

**Fix 6: Yaesu newcat RU/RD (RIT/XIT clarifier) format.** Prior
code emitted `RU%+05d;` (signed 5-digit with `+` sign character).
Per Hamlib `newcat.c:2930-2936`:

```c
SNPRINTF(..., "RC%cRU%04ld%c", cat_term, labs(rit), cat_term);
```

Correct wire is:
1. `RC;` clarifier-clear prelude
2. `RU<4-digit-unsigned>;` for positive offsets (direction in
   command letter)
3. `RD<4-digit-unsigned>;` for negative offsets
4. `RT1;` / `RT0;` to enable/disable

Real newcat radios reject the signed form with the `+` sign
character. Affects all 24 modern Yaesu radios that support
RIT/XIT.

**Note on Fix 2 as originally scoped.** The audit report also
flagged Elecraft K2 signal strength (SM vs SM0) as critical. On
inspection, `ElecraftProtocol.getSignalStrength` already handles
this correctly via `isK2 ? "SM" : "SM0"`. The K2 test at
`ElecraftProtocolTests.swift:21` was already passing. Not a bug;
skipped.

**Regression tests added:** 10 new tests in
`YaesuCATProtocolTests` (GT/RG/SH/RU/RD formats) and
`YaesuLegacyCATTests` (FT-847 getPTT polarity) plus updates to
existing `KenwoodProtocolTests.modeMappings` and
`Tier1SafetyFixesTests.kenwoodModeCode9RoundTripsToRTTYR`. Prior
to these regression tests, the buggy behaviors had zero test
coverage — which is why they persisted through the earlier v1.1.2
safety audit.

**Deferred to a future patch release** (medium / low severity;
non-blocking — rolled forward past v1.2.1 (Yaesu binary-CAT
framing fix), v1.2.2 (Yaesu newcat SH per-family dispatch),
v1.2.3 (Yaesu newcat MD qualifier byte), and v1.2.4
(THFamilyCAT step + structural refactor):

- Yaesu newcat MD qualifier byte — **shipped in v1.2.3.**
- Yaesu newcat SH per-family variants — **shipped in v1.2.2.**
- THFamilyCAT step persistence — **shipped in v1.2.4.**
- Kenwood AF gain format variants — TS-450S/TS-690S do not
  expose AF gain via CAT at all per Hamlib (`RIG_LEVEL_AF` not
  in `LEVEL_ALL`). Real fix is a level-capability audit across
  the catalog rather than a wire-format change; deferred to
  v1.3.0 alongside per-level capability flags.
- Kenwood squelch VFO-aware — TS-890S dual-RX needs `SQ1nnn;`
  for sub-receiver.
- TH-D72 power-level API contract (integer watts vs normalized
  0.0-1.0 float).
- THFamilyCAT step persistence (front-panel step changes get
  overwritten by cached snapshot).
- Ten-Tec Orion II setMode missing bandwidth command follow-up.
- Ten-Tec Orion split command shape (`*E` vs Hamlib's `*KV`).
- Ten-Tec legacy S-meter reads 1 byte instead of Hamlib's 3.
- Icom test coverage — 21 StandardIcomCommandSet radios have no
  model-specific tests.
- Yaesu newcat test coverage — RG/GT/SH/RU/RD/AG/etc. now have
  fix-regression tests but not full behavioral coverage.

**Verification:** clean build; **635 tests pass** (was 625;
+10 new). Zero regressions.

## [1.1.3] - 2026-07-24

Additive catalog release. Downstream Swift apps that build radio
pickers or model-name matchers currently hand-maintain parallel
lists of every SwiftRigControl radio, and drift between the app
and the library has caused user-visible bugs (a picker offering a
radio the matcher couldn't find). This release makes
SwiftRigControl the single source of truth for the catalog so
downstream apps can iterate `Vendor.allRadios` instead of
hard-coding arrays.

No behavior changes for connected radios; no removals; no
signature changes.

### Added

- `RadioDefinition.<Vendor>.allRadios` — a `[RadioDefinition]`
  static on each vendor namespace (`Icom`, `Yaesu`, `Kenwood`,
  `Elecraft`, `Xiegu`, `Flex`, `TenTec`, `Lab599`), sorted
  alphabetically by model. Enumerates every shipped radio for that
  vendor. Icom entries are built with each factory's default CI-V
  address; use `withCivAddress(_:)` to override at connect time.

- `RadioDefinition.allSupportedRadios` — top-level `[RadioDefinition]`
  aggregate that concatenates every vendor's `allRadios`. The
  generic in-memory `dummy(name:capabilities:)` factory is
  intentionally excluded (it takes user-supplied name and
  capabilities and has no canonical entry).

- `RadioDefinition.allRadios(for: Manufacturer)` — returns the
  matching vendor's array, or `[]` for `.dummy`.

- `RadioDefinition.withCivAddress(_:)` — returns a copy of an
  Icom definition rebuilt through the same factory with the given
  CI-V bus address. Non-Icom definitions return `self`. Passing
  `nil` restores the model's factory default. Every Icom factory
  populates an internal rebuilder hook that `withCivAddress`
  dispatches to, so both `RadioDefinition.civAddress` **and** the
  underlying `protocolFactory` closure honour the new address —
  a plain struct copy would not (the closure captures the
  address at construction time).

- `RadioDefinition.init` gains an optional
  `civAddressRebuilder:` parameter (default `nil`) that the Icom
  factories use to wire the rebuilder hook. Non-Icom callers can
  ignore it.

### Migration (downstream consumers)

Apps that hand-maintain radio catalogs can now replace:

```swift
// Before
let icomRadios: [RadioDefinition] = [
    .Icom.ic7300(), .Icom.ic7300MK2(), .Icom.ic7600(), /* ... */
]

func matchIcom(_ model: String, civAddress: UInt8?) -> RadioDefinition? {
    if model.contains("7300") { return .Icom.ic7300(civAddress: civAddress) }
    // ...
}
```

with:

```swift
// After
let icomRadios = RadioDefinition.Icom.allRadios

func match(_ model: String, civAddress: UInt8?) -> RadioDefinition? {
    RadioDefinition.allSupportedRadios
        .first { $0.model == model }?
        .withCivAddress(civAddress)  // no-op for non-Icom
}
```

Every future radio added here becomes zero-touch for consumers
that shifted to `allRadios`.

### Tests

- `RadioCatalogDriftTests` — hand-maintained expected model-name
  sets per vendor assert `Set` equality with
  `Vendor.allRadios.map(\.model)`. When someone adds a new radio
  to a vendor's Models file but forgets to register it in
  `RadioDefinition+Catalog.swift`, the test fails until both
  lists agree. Also covers alphabetical sort order, manufacturer
  tagging, `allSupportedRadios` aggregation, `allRadios(for:)`
  dispatch, and the `withCivAddress(_:)` contract (override,
  restore-to-default, non-Icom no-op, and that every Icom
  factory populates its rebuilder).

## [1.1.2] - 2026-07-15

Safety-focused patch release. Started as a fix for the Yaesu HF
serial-framing bug reported downstream (issue #12) and expanded
into a full seven-vendor Hamlib parity audit after several
additional latent bugs were uncovered — including one Kenwood
PTT bug that could key the transmitter on every `setPTT(false)`
call and one that keyed on every `getPTT()` poll. Every finding
in this release is traceable to a Hamlib source-file citation.

### Fixed — safety-critical (PTT / TX-VFO)

- **Kenwood `setPTT(false)` no longer keys the transmitter.**
  Pre-fix code sent `TX0;` for PTT-off, but on Kenwood `TX0;`
  actually means "PTT on via mic port" — the *opposite* of
  releasing PTT. Every call to `setPTT(false)` was keying the
  radio. `setPTT(true)` also sent `TX1;` ("PTT on via data
  port"), which does key but is not the canonical form.
  `setPTT(_:)` now uses bare `TX;` / `RX;` per Hamlib
  `kenwood_set_ptt` (rigs/kenwood/kenwood.c).

- **Kenwood `getPTT()` no longer keys the transmitter on every
  poll.** Pre-fix code sent the `TX;` *set* command to query PTT
  state, then parsed the (nonexistent) response. Every PTT poll
  keyed the radio. `getPTT()` now sends `IF;` and reads byte 28
  of the response per Hamlib `kenwood_get_ptt`.

- **Yaesu `setSplit()` no longer risks TXing on the wrong VFO.**
  Pre-fix code sent `FT0;`/`FT1;` — but on modern Yaesu radios
  `FT` is the *TX-VFO selection* command, not split. Sending
  `FT1;` for "enable split" would silently reassign which VFO the
  radio transmits from. Now uses `ST0;`/`ST1;` per Hamlib
  `newcat_set_split` (newcat.c:8317). On radios that don't
  support `ST` (FT-950/891/991/2000/DX3000/DX5000/DX1200/DX9000),
  the method throws `unsupportedOperation` with a message telling
  callers to use `selectVFO()` instead of silently doing the
  wrong thing.

- **Yaesu `selectVFO()` uses the correct FT encoding per radio.**
  On FT-950 / FT-2000 / FT-DX3000/5000/1200 / FT-991(A) / FT-DX10
  / FT-DX101(D/MP), `FT2;` selects VFO A and `FT3;` selects VFO B
  (`FT0;`/`FT1;` reserved for toggling the TX function). On
  FT-710 / FT-450, the classic `FT0;`/`FT1;` encoding applies.
  On FT-891, the `FT` command doesn't exist at all — the method
  throws. Matches Hamlib `newcat_set_tx_vfo` (newcat.c:8164).

- **Yaesu `getPTT()` recognises `TX2;` and `TX3;` as
  transmitting.** Pre-fix code checked only for `TX1;`, so on
  radios that report PTT-via-data (`TX2`) or PTT-via-CAT (`TX3`)
  the driver misreported the state as RX. A UI that polled PTT
  would show the radio idle while it was actually keyed —
  tempting the operator to hit PTT again. Matches Hamlib
  `newcat_get_ptt` (newcat.c:2282-2295).

### Fixed — per-radio serial framing

- **Per-radio stop bits and hardware handshake now propagate
  through `RigController` into `SerialConfiguration`.** Pre-fix
  code let `SerialConfiguration.init` defaults win (8-N-1, no
  flow control). Correct for Icom CI-V, wrong for every modern
  Yaesu HF radio except FT-710 (needs 8-N-2) and desktop Kenwood
  TS-590/990S/2000/TS-570 (needs RTS/CTS).

- **Serial framing corrected for five additional Kenwood radios**
  the initial fix missed: TS-570D, TS-570S, TH-D72, TH-D72A
  (→ `.kenwoodDesktop`, 8-N-1 + HW), and TS-850S (→ new
  `.kenwoodLegacy`, 8-N-2 + HW). Per Hamlib rigs/kenwood/*.c.

- **Elecraft K2** switched to 8-N-2 per Hamlib `k2.c`. The K2 is
  hardware-verified — its ATmega UART is tolerant of variable
  stop-bit counts, which is why the pre-fix 8-N-1 defaults
  worked. Aligning to Hamlib is safer for sustained rapid-fire
  command sequences. **Hardware-verified status should be
  re-confirmed at 8-N-2 before v1.1.3.**

- **Lab599 TX-500** baud rate corrected from 115200 → 9600.
  Hamlib `tx500.c` locks baud to 9600; the TX-500 firmware
  rejects any other rate, so the pre-fix code left the radio
  completely unresponsive.

- **Yaesu FT-891 `hasSplit` capability corrected to `false`.**
  Per Hamlib newcat.c:516,578 the FT-891 supports neither `ST`
  nor `FT` — there is no CAT path to establish split. The pre-fix
  capability advertised split as available and callers would
  silently fail (or, before the split fix above, mis-key TX-VFO).

### Fixed — protocol correctness

- **Kenwood mode-code table completed.** Mode code `8` (FSK-R /
  RTTY-R) is now mapped to `Mode.rttyR` in both directions —
  pre-fix `kenwoodCodeToMode` treated `8` as an invalid response
  and `modeToKenwoodCode` had no encoder for `.rttyR`. Matches
  Hamlib `rigs/kenwood/ts990s.c:92`.

- **Elecraft K2 post-write delay** increased from 50ms to 100ms
  per Hamlib `k2.c:137` (`post_write_delay = 100`). The pre-fix
  value could drop bytes on the K2's UART under sustained
  command sequences.

- **Ten-Tec Legacy protocol (Jupiter, Pegasus) frequency
  encoding rewritten.** Pre-fix code sent a 6-byte zero-padded
  decimal ASCII string; the Jupiter/Pegasus firmware doesn't
  understand that format and ignored every frequency set. The
  radios use three 16-bit binary tuning factors computed from
  frequency, mode, filter width, PBT, and (for CW) BFO offset.
  Ported directly from Hamlib `tentec_tuning_factor_calc`
  (rigs/tentec/tentec.c:181). Unit-tested against hand-computed
  reference values for USB/LSB/CW/AM. Note: the Ten-Tec Legacy
  protocol is not currently exposed as a public
  `RadioDefinition.TenTec.*` factory, so no consumer was
  affected by the pre-fix bug.

- **Ten-Tec Jupiter/Pegasus baud rate** corrected from 38400 to
  57600 per Hamlib jupiter.c:139 and pegasus.c:75.

### Added

- **`RadioDefinition.SerialDefaults`** — new value type carrying
  termios settings that `defaultBaudRate` does not cover: stop
  bits, parity, and hardware/software flow control. Named
  profiles:
  - `.standard` — 8-N-1, no flow control. Icom, Elecraft K3+,
    TS-480/890S, FT-710, FlexRadio, Xiegu.
  - `.yaesuHFDesktop` — 8-N-2 + RTS/CTS. FT-DX10, FT-DX101(D/MP),
    FT-991(A), FT-891, FT-950, FT-2000, FT-DX1200/3000/5000/9000,
    FT-450(D).
  - `.yaesuHFPortable` — 8-N-2, no handshake. FT-817(D), FT-818,
    FT-857(D), FT-897(D), FT-847, FT-920, FT-100, FT-1000MP.
  - `.kenwoodDesktop` — 8-N-1 + RTS/CTS. TS-590(S/SG), TS-990S,
    TS-2000, TS-570(D/S), TH-D72(A).
  - `.kenwoodLegacy` — 8-N-2 + RTS/CTS. TS-850S.
  - `.elecraftK2` — 8-N-2, no handshake. K2.

- **`RadioDefinition.init(serialDefaults:)`** — new optional
  parameter defaulting to `.standard` for source compatibility.

- **`YaesuCATProtocol.Quirks`** — per-model behavioural quirks
  the shared newcat command set can't express uniformly.
  Captures ST-split support and FT-encoding variants sourced
  from Hamlib newcat.c's `valid_commands` table and
  `newcat_set_tx_vfo` / `newcat_set_split_vfo`. Named profiles:
  `.classic`, `.newcatNoST`, `.newcatWithSTDX`, `.ft710`,
  `.ft450`, `.ft891`. `YaesuCATProtocol.init` gains an optional
  `quirks:` parameter defaulting to `.classic` for source
  compatibility.

- **Ten-Tec radio factories now public.** The
  `TenTecOrionProtocol` and `TenTecLegacyProtocol`
  implementations existed but had no `RadioDefinition.TenTec.*`
  factories, making them unreachable from consumer code. Added:
  `.orion` (TT-565), `.orionII` (TT-599), `.eagle`, `.jupiter`
  (TT-538), `.pegasus` (TT-550). All marked
  `verificationStatus: .definition` — the wire protocols match
  Hamlib byte-for-byte but no radio has been driven against real
  hardware since the v1.1.2 fixes landed.

- **`SerialDefaults.tentecModern`** — 8-N-1 with RTS/CTS
  handshake per Hamlib `rigs/tentec/*.c` (jupiter.c:139-143,
  pegasus.c:75-79, omnivii.c, orion.h:224-229 and :443-448).
  Applied to all newly-exposed Ten-Tec factories.

- **Elecraft K2 response timeout bumped to 2s** (from 1s) per
  Hamlib `k2.c:139` — the K2 can take up to 500ms to complete a
  band-change frequency set, and the previous 1s ceiling risked
  spurious timeouts. K3 and later stay at 1s. `responseTimeout`
  is now per-instance, resolved from `isK2` in
  `ElecraftProtocol.init`.

### Deferred to v1.2.0 (feature release)

- Elecraft K2 extended-power probing (`K22;`) — adds
  higher-resolution power reads on QRO K2s.
- Baud-rate range support on `RadioDefinition` (radios with a
  Hamlib-declared range currently hard-code a single default).

### Audit provenance

This release closes findings from a seven-agent Hamlib parity
audit (Icom, Yaesu, Kenwood + THD72, Elecraft, Xiegu/Lab599/Flex,
Ten-Tec, cross-vendor connect-path safety). Icom, connect-path,
and Ten-Tec Orion vendors passed cleanly. Every fix here is
traceable to a Hamlib source-file citation in code comments.

Tier 2 findings deferred to v1.1.3 (K2 hardware re-verification
at 8-N-2, potential PTT-command variants for specific Kenwood
models, capability-flag audits for definition-only radios).

Tier 3 findings (Ten-Tec Legacy protocol not yet reachable via a
public factory, per-radio baud-rate ranges, additional K3
extended-command probing) are tracked in ROADMAP.md.

## [1.1.1] - 2026-07-10

Patch release fixing a safety-critical bug that keyed Yaesu radios
into transmit on connect.

### Fixed

- **`IOKitSerialPort.open()` now de-asserts DTR and RTS** after
  configuring termios. macOS opens serial ttys with DTR asserted
  by default, and CP210x / FTDI drivers leave RTS in its power-on
  state. Yaesu HF radios (FT-DX10, FT-DX101, FT-991A, FT-891,
  FT-450D, FT-950, FT-2000, FT-DX3000/5000, and many earlier
  models) drive hardware PTT off one of these lines on their CAT
  USB port — so simply opening the port keyed the radio into TX
  and held it there until the USB cable was physically unplugged.
  Clearing `CRTSCTS` in termios only disables *flow-control use*
  of the pins; the fix uses `ioctl(TIOCMBIC, TIOCM_DTR |
  TIOCM_RTS)` to actually drive them low. Reported in issue #11
  after a downstream MacWinlink FT-DX10 report. Safety and
  regulatory concern under FCC §97.213 and equivalent regimes
  worldwide — a CAT library that keys on connect is not fit to
  ship. RTS is preserved when `hardwareFlowControl` is `true`.

### Added

- **`SerialTransport.setDTR(_:)` / `setRTS(_:)`** — public API to
  drive the DTR and RTS modem control lines from the transport
  layer. Since `open()` now de-asserts both lines, callers whose
  device legitimately needs DTR or RTS asserted (some GPS pucks,
  Kenwood TS-590 with DTR-as-PTT configured, external TNCs) can
  opt in explicitly. `IOKitSerialPort` implements via
  `TIOCMBIS` / `TIOCMBIC`; `TCPSerialTransport` is a documented
  no-op; `MockSerialTransport` records calls as `recordedDTR` /
  `recordedRTS` for test assertions.

## [1.1.0] - 2026-05-29

First feature release after the v1.0.6 baseline. Highlights:
vendor-namespace refactor (breaking), TCP transport, FlexRadio
family, targeted serial-port auto-detection. Migration guide
lives at `Documentation/MIGRATION_v1.1.md`.

### Removed (BREAKING)

- **`RadioDefinition.Kenwood.tmd710`** (TM-D710 / TM-D710GA) and
  **`RadioDefinition.Kenwood.tmv71`** (TM-V71 / TM-V71A) — and
  their corresponding `RadioCapabilitiesDatabase.Kenwood.tmd710`
  / `tmv71` caps. Real-hardware testing on 2026-05-29 confirmed
  that `KenwoodProtocol` is wire-incompatible with these radios.
  Both use CR (`\r`) terminator, 9600-baud default, and a
  different command vocabulary (`FO`/`BC`/`MR`/`MS`/`TY` per
  Hamlib `rigs/kenwood/tmd710.c`) — none of which
  `KenwoodProtocol` produces. The previous shipped definitions
  wired both radios to `KenwoodProtocol` and **could never have
  worked**: discovery couldn't find them, and any frequency /
  mode / PTT call would have thrown. Removed rather than ship a
  stub that lies about catalog coverage. A proper
  `TMD710Protocol` is on the v1.2 roadmap; see ROADMAP.md for
  the implementation plan and captured wire bytes. Migration:
  there is no drop-in replacement — pin to v1.0.6 if you
  depend on either radio.

### Fixed (from real-hardware validation, 2026-05-29)

Five radios were re-validated on real hardware as the v1.1.0
release pass: IC-7100, IC-7600, IC-9700, K2, and TH-D72A.
Several pre-existing protocol bugs surfaced during this work
and are fixed in this release.

**Icom CI-V (affects every dual-receiver Icom — IC-7600,
IC-9700, IC-9100, IC-7800, IC-7850/51, IC-910H, …):**

- **`selectVFO(.a)` was sending VFO A code (`0x07 0x00`) on
  dual-receiver radios with `.mainSub` VFO model**, which they
  reject. The Main bank code is `0x07 0xD0`. Fixed by
  delegating to `commandSet.selectVFOCommand(vfo)` — the
  single source of truth that already encodes the correct
  mapping for every `VFOOperationModel`. This unblocked all
  IC-7600 operations (every getFrequency / setFrequency /
  setMode call had been throwing). Regression test:
  `ic7600SelectVFOAUsesMainBankCode`,
  `ic7600SelectVFOBUsesSubBankCode`.

- **Data-mode exit follow-up was using the wrong filter byte.**
  Per Hamlib `icom_set_mode` (icom.c:2637) — "the only good
  combo possible according to manual" — both bytes of the
  `0x1A 0x06` follow-up must be 0 when the data flag is 0.
  The previous impl held the filter at FIL1 (`0x02`); the
  IC-7600 NAKs that. Now sends `[data_flag, data_flag == 0 ?
  0x00 : FIL1]`. Regression test:
  `ic7600ExitDataModeSendsDataFlagOff` extended to pin
  `data[7] == 0x00`.

- **IC-7600 squelch-condition parser was rejecting valid
  replies.** The captured `FE FE E0 7A 15 01 01 FD` parses as
  `command=[0x15, 0x01], data=[0x01]` (per the existing
  hasSubCommand rule for 0x15) — but `getSquelchConditionIC7600`
  required `data.count >= 2`. Relaxed to `>= 1`. Regression
  tests in new file `IC7600ResponseParsingTests.swift`.

- **IC-7600 AGC time-constant reader assumed the wrong frame
  shape** — checked `command.count >= 2` but `CIVFrame.parse`
  doesn't treat 0x1A as a sub-command prefix (only 0x14/0x15/
  0x1C are in that list), so the actual split is
  `command=[0x1A], data=[sub, value]`. Fixed to match.

- **IC-7600 band-edge read marked as `.unsupportedOperation`.**
  Command `0x02` returns a multi-segment payload (per-segment
  IDs, 4-byte BCD freq fields) that doesn't match the
  previously-assumed "5+5 BCD" layout. Hamlib defines
  `C_RD_BAND` but doesn't call it from any rig handler.
  Marked as not-reliably-parseable pending a manual cross-check.

- **IC-9700 dualwatch was sending the wrong wire command.**
  Previous impl sent `0x07 0xC2/0xC3` (the S_DUAL_OFF/S_DUAL_ON
  form HF Icoms use). Per Hamlib `icom_set_func` (icom.c:7263),
  the IC-9100 / IC-9700 / ID-5100 family routes dualwatch
  through `C_CTL_FUNC (0x16) + S_MEM_DUALMODE (0x59)` instead.
  Real radio NAKed the old form. Also added the missing
  `getDualwatchIC9700` reader. Regression tests in new file
  `IC9700ResponseParsingTests.swift`.

- **IC-9700 digital-squelch and satellite-mode readers had
  the same parser-shape bug** as the AGC reader above. Fixed
  both to match `command=[0x16], data=[sub, value]`.

**Elecraft (affects K2 specifically; spot-checked K3/K3S/K4/
KX2/KX3 caps against Hamlib):**

- **K2 signal strength used `SM0;`, but the K2 actually uses
  `SM;` (no main/sub digit).** Per Hamlib `kenwood_get_level`
  (kenwood.c), only TS-590/480/2000 use `SM0` — every other
  Kenwood-derived radio including the K2 uses plain `SM`.
  Fixed; K3/K3S/K4 keep `SM0`. Regression tests:
  `k2SignalStrengthSendsSMNotSM0`, `k3SignalStrengthSendsSM0`.

- **K2 capabilities falsely claimed AM, FM, and RTTY
  support.** Per Hamlib K2_MODES the K2 is CW/CWR/SSB/PKTLSB/
  PKTUSB only — no AM, FM, or RTTY. Real radio silently keeps
  the previous mode on out-of-range requests. Narrowed
  `supportedModes` to match Hamlib + reality.

- **K3 / K3S spot-check found missing FM support** in
  `supportedModes`. K3_MODES (which K3/K3S/K4/KX2/KX3 all
  share per Hamlib k3.c) includes FM, and Elecraft's official
  spec confirms FM on 6m for repeater work. Added.

- **KX2 was missing `.dataLSB`.** Per K3_MODES which the KX2
  inherits. Added.

- **RTTY-R deferred** across the K-family. K3_MODES has both
  RTTY and RTTYR but `ElecraftProtocol.modeToElecraftCode`
  maps `.rtty` to `MD6` only. Per the K3 Programmer's
  Reference (and Hamlib `k3_set_mode`), proper K-series RTTY
  is a two-command sequence: `MD<n>;DT<n>;`. Documented as
  tracked-for-future; not exposed in supportedModes for now.

**Kenwood TH-D72 / TH-D72A (CR-terminated handheld):**

- **`THD72Protocol.getSignalStrength` returned bogus parsed
  data.** Real radio rejects `SM 0\r` with `?\r`. Per Hamlib
  `THD72_LEVEL_ALL` (RFPOWER / SQL / BALANCE / VOXGAIN /
  VOXDELAY only), the TH-D72 has no numeric S-meter via CAT.
  Now correctly throws `.unsupportedOperation` with a message
  pointing callers at the busy-flag query. Caps:
  `supportsSignalStrength: false` (was true).

- **New `THD72Protocol.getBusy(vfo:)`** — the radio's actual
  facility for "is the band squelch-open?". Wire command
  `BY <band>\r`, parses `BY n,m\r` (m=0/1). Tolerates leading
  APRS/NMEA buffer noise.

- **`RadioIdentifyProbe` gained a CR-terminated probe path**
  routed for TH-handheld family radios (TH-D72/D74/D75). The
  existing semicolon-`ID;` probe was structurally wrong for
  these radios — they use `\r` per Hamlib's `EOM_TH` and
  reply with an alphabetic model name (`ID TH-D72\r`) rather
  than the numeric `ID017;` of HF Kenwoods. Real radio
  validated end-to-end via the new `THD72Validator`.

- **Race-condition fix in `RadioDiscovery.defaultProbe`.** The
  previous `defer { Task { await port.close() } }` form
  spawned a detached close task that raced against the next
  probe iteration's `open()`, producing spurious EBUSY errors
  on Silicon Labs CP210x adapters. Closes synchronously now.

**Verified-radio promotions:**

- **TH-D72 / TH-D72A** marked `verificationStatus: .hardware`
  (was `.definition`) after the full validator run completed
  6/6 with PTT keyed into a dummy load.

**New hardware validators in Tools/SwiftRigControlTools:**

- `THD72Validator` — frequency, mode, VFO, power, PTT, busy
- Existing IC-7100 / IC-7600 / IC-9700 / K2 validators
  updated with corrected per-radio test data (the IC-9700
  attenuator/preamp ranges, K2 mode list, IC-7600 squelch
  test mode-restore, etc.).

### Added

- **Targeted auto-detection** — new `RadioDiscovery` actor under
  `Sources/RigControl/Discovery/` answers "which serial port is my
  radio on?" without scanning every vendor at every baud. Two
  entry points:
  - `RadioDiscovery.detect(_ radio:)` — single radio, returns
    the first port whose identify matches.
  - `RadioDiscovery.detect(_ radios:)` — multi-radio overload
    for apps that support several rigs at once. Probes are
    sequential; a port that already matched a previous radio is
    skipped for subsequent candidates.
  Each port is probed at the radio's `defaultBaudRate` with the
  appropriate vendor identify query — `0x19 0x00` to the radio's
  CI-V address for Icom; `ID;` for Kenwood / Yaesu / Elecraft /
  Xiegu / Lab599 / Flex. Returns `DetectedPort` with port path,
  baud rate, the matched radio definition, and the raw identity
  response. Ten-Tec is currently skipped (no standard identify);
  the dummy radio is also a no-op. The port enumerator and probe
  function are both injectable via `RadioDiscovery.init`, so
  apps and tests can drive discovery without touching `/dev/`.
- 9 new tests in `RadioDiscoveryTests` covering single + multi
  radio matching, wrong-radio rejection, port-exclusivity in the
  multi-radio path, USB-serial port ranking, and the
  Kenwood-family `ID###;` parser at every published model-ID
  shape.
- **TCP serial transport** — new `TCPSerialTransport` actor under
  `Sources/RigControl/Transport/`, conforming to `SerialTransport`.
  Backed by Network.framework's `NWConnection`; zero new
  third-party dependencies. The underlying `CATProtocol`
  implementations cannot tell whether their bytes come from a USB
  serial port or a TCP socket, so any text-based vendor protocol
  works unchanged.
- **`ConnectionType.tcp(host:port:)`** — pair any radio
  definition with a TCP endpoint instead of `/dev/cu.*`. Use for
  Flex 6000-series radios (SmartSDR on port 4992) and for
  bridging to a remote `rigctld` / `RigControlServer` (port
  4532). The `defaultBaudRate` field is ignored for TCP
  connections.
- **FlexRadio family** — three definition-only radios under a new
  `.Flex` namespace and `.flex` `Manufacturer` case, all driven
  by the existing `KenwoodProtocol`:
  - `.Flex.flex6000` — Flex 6000-series (6300/6400/6500/6600/6700)
    via SmartSDR's TCP CAT bridge. Cross-checked against Hamlib
    `kenwood/flex6xxx.c` (`RIG_MODEL_F6K`,
    `.port_type = RIG_PORT_NETWORK`). Pair with
    `ConnectionType.tcp(host: …, port: 4992)`.
  - `.Flex.powerSDR` — PowerSDR (FlexRadio Systems / Apache Labs)
    via virtual serial CAT. Superset of Flex 6000 caps: adds VOX,
    ANF, MUTE, TUNER function bits and RF-power / SWR meter
    support per Hamlib `POWERSDR_*` macros.
  - `.Flex.thetis` — Thetis (TAPR) open-source PowerSDR fork.
    Same CAT surface as PowerSDR.
  All three are **definition-only** — no field validation against
  real hardware. Issue reports welcome.
- 15 new tests across `TCPSerialTransportTests` (loopback
  echo server: connect, write/read round-trip, partial-frame
  buffering, read timeout, flush, refused / unroutable connect)
  and `FlexRadioDefinitionsTests` (caps shape, mock connect,
  manufacturer brand tag).

### Changed (BREAKING — flat names replaced by vendor namespaces)

- **Radio definitions and capability presets are now organized
  under vendor namespaces** on `RadioDefinition` and
  `RadioCapabilitiesDatabase`. The flat `icomXxx`, `yaesuXxx`,
  `kenwoodXxx`, `elecraftXxx`, `xieguXxx`, and `lab599Xxx`
  members were removed and replaced with namespaced forms
  (`.Icom.ic7300()`, `.Yaesu.ftdx10`, `.Kenwood.ts890S`,
  `.Elecraft.k3`, `.Xiegu.g90`, `.Lab599.tx500`). The radio
  identity is unchanged; only the spelling moves. Icom factories
  still accept an optional CI-V address
  (`.Icom.ic7600(civAddress: 0x7B)`).

  **Migration**: search-and-replace at call sites.
  ```swift
  // before
  let rig = try RigController(radio: .icomIC7300(), …)
  let caps = RadioCapabilitiesDatabase.yaesuFTDX10
  // after
  let rig = try RigController(radio: .Icom.ic7300(), …)
  let caps = RadioCapabilitiesDatabase.Yaesu.ftdx10
  ```

  The `IcomRadioModel` enum cases (e.g. `.ic7300`, `.ic9700`)
  are unchanged — those identify radios *inside* the Icom
  CI-V protocol implementation, not the public catalog. Function
  and VFO-operation preset sets (`.icomIC7600Funcs`,
  `.icomStandard`, `.yaesuStandard`, etc.) on `Set<RigFunction>`
  / `Set<VFOOperation>` are also unchanged.

### Removed (BREAKING for callers using these specific radios)

- **`RadioDefinition.icomIC9000()`** factory and supporting
  `IcomRadioModel.ic9000` enum case + cap struct. After
  verification with the manufacturer, the IC-9000 does not
  exist as an Icom amateur product — no manufacturer page, no
  Hamlib entry, and the SwiftRigControl definition's
  description had been copy-pasted from the IC-9100. The CI-V
  address was a duplicate of the IC-910H's. Callers using
  `.icomIC9000()` should switch to `.icomIC910H()` (the actual
  satellite transceiver at CI-V 0x60) or `.icomIC9100()` (the
  HF/VHF/UHF satellite transceiver at 0x7C), depending on
  which physical radio they own.

- **`RadioDefinition.icomIC2820H()`** factory and supporting
  `IcomRadioModel.ic2820h` enum case + cap struct. The
  IC-2820H is a real product (2007 dual-band FM mobile with
  D-STAR), but it does **not** expose a CAT control surface —
  its serial port is used only for cloning (via Icom's
  CS-2820 software) and as a packet-TNC interface. Hamlib
  also does not support it. SwiftRigControl shipping the
  definition implied capabilities that don't exist on the
  wire. Callers who wanted memory-bank programming should use
  Icom's CS-2820 cloning software directly.

### Changed

- **IC-7850 / IC-7851 documentation clarified.** The two enum
  cases are both retained because the model name on the front
  panel matters for UI display, but the IC-7850's doc comment
  now explicitly notes it is the 50th-anniversary limited
  edition (≈150 units worldwide, late 2014) with functionally
  identical internals to the IC-7851 production model. Both
  resolve to CI-V 0x8E and share the same command set. Hamlib
  uses one entry (`RIG_MODEL_IC785x`) for both.

- **TH-D75 documentation marked as reverse-engineered.** The
  TH-D75A is a real Kenwood product (announced Hamvention
  2024, shipping mid-2024), but Kenwood doesn't publish a PC
  command reference. SwiftRigControl's CAT surface for this
  radio is inferred from the TH-D74's community-derived
  command set; specific commands have not been
  hardware-verified. The doc comment now explicitly notes
  this and warns that the TH-D75 supports only USB-C virtual
  COM and Bluetooth SPP — RS-232 over a USB-serial adapter
  will not work.

### Fixed
- **IC-9700 / IC-705 noise blanker level was being encoded with
  reversed bytes and could emit invalid BCD.** The setter at
  `IcomCIVProtocol+NoiseControl.swift:143` inlined its own BCD
  math instead of calling the shared
  `BCDEncoding.encodePower(_:)` helper. The inlined math
  emitted bytes in little-endian order (`[tens-ones, hundreds]`
  instead of Icom's canonical big-endian `[hundreds, tens-ones]`)
  *and* produced invalid BCD digits for levels > 99 — e.g. a
  level of 128 emitted `[0xC8, 0x01]` where `0xC` is not a
  valid BCD digit. The reader had the matching inverse error,
  so round-trips via SwiftRigControl appeared self-consistent
  while the radio actually held a value off by a factor of
  10 or 100 from what the operator requested. The fix calls
  `BCDEncoding.encodePower` / `decodePower` — the same helpers
  IC-7100's NB level setter and the NR level setter already
  use (introduced in commit `b2f2ca4`). Four protocol-level
  tests in `IcomNoiseBlankerTests` lock in the wire bytes for
  levels 50, 128, and 255 to prevent regression.

- **IC-7600 (and IC-9100, IC-9700) DATA-USB / DATA-LSB / DATA-FM
  modes were not being engaged.** Previously these non-targetable
  radios received only the base mode set (`0x06 [mode, filter]`)
  with `filter=0x00` as a DATA marker — but the IC-7600 family
  does not interpret filter=0x00 as a DATA-mode signal. Per
  Hamlib `icom_set_mode` (rigs/icom/icom.c:2494), every Icom
  with `data_mode_supported = 1` that isn't covered by the
  targetable `0x26` command needs a separate `0x1A 0x06
  [data_flag, filter]` frame after the base mode set. That path
  was previously hardcoded to fire only on IC-7100/IC-705; it
  now fires on every non-targetable radio with data-mode
  support. Symptom: SwiftRigControl-backed apps (like
  MacWinlink) requesting `.dataUSB` on an IC-7600 ended up with
  the radio in plain USB instead.
- **Exiting DATA mode now clears the DATA sub-mode bit.**
  Going from DATA-USB back to plain USB previously left the
  radio stuck in DATA on the affected radios. The fix sends
  `0x1A 0x06 [0x00, filter]` to clear the bit, matching Hamlib.

### Added
- **Compound VFO operations** (Hamlib parity, item 1 of v1.1).
  New `RigController.performVFOOperation(_:)` exposes the
  one-tap operations every modern radio's front panel has:
  `.exchange` (A↔B swap), `.copyVFO` (A→B copy),
  `.vfoToMemory` / `.memoryToVFO`, `.memoryClear`, `.tune` (ATU
  cycle), and `.stepUp`/`.stepDown`/`.bandUp`/`.bandDown` for
  text-protocol radios. Mirrors Hamlib's `RIG_OP_*` bitfield.
  Per-radio capability gated by
  `RigCapabilities.supportedVFOOperations`. Wire commands
  cross-checked against `rigs/icom/icom.c::icom_vfo_op`,
  `rigs/kenwood/kenwood.c::kenwood_vfo_op`,
  `rigs/yaesu/newcat.c::newcat_vfo_op`.

- **Function toggles** (Hamlib parity, item 2 of v1.1). New
  `RigController.setFunction(_:enabled:)` /
  `getFunction(_:)` expose 21 on/off bits curated from
  Hamlib's `RIG_FUNC_*` universe: compressor, VOX, CTCSS
  tone/squelch, lock, ATU enable, auto/manual notch, satellite
  mode, monitor, AFC, beat cancel, NB2, APF, reverse split,
  dual watch, diversity, mute, scope, scan resume, voice
  squelch. Per-radio capability gated by
  `RigCapabilities.supportedFunctions`. Verified Icom radios
  (IC-7100, IC-7600, IC-7300, IC-7610, IC-705, IC-9700,
  IC-7760, IC-7300MK2) seeded from their respective Hamlib
  `IC*_FUNCS` masks.

- **Secondary level controls** (Hamlib parity, item 3 of
  v1.1). Six new per-trait protocols: `SupportsMicGain`,
  `SupportsCompressorLevel` (level, distinct from the on/off
  function toggle), `SupportsMonitorGain`, `SupportsVOXGain`,
  `SupportsVOXDelay`, `SupportsIFShift`. Per-vendor wire
  implementations for Icom CI-V (0x14 sub-cmd family), Kenwood
  text (MG/PL/ML/VG/VD/IS), and Yaesu newcat (MG/PL/ML0/VG/
  VD/IS0).

- **rigctld bridge: `vfo_op` command** (Hamlib `G` /
  `\vfo_op`). Maps all Hamlib VFO-op tokens (CPY, XCHG, FROM_VFO,
  TO_VFO, MCL, UP, DOWN, BAND_UP, BAND_DOWN, TUNE, TOGGLE) to
  `performVFOOperation()`. Tools like WSJT-X that send these
  tokens now work without further client changes.

- **rigctld bridge: 21 new `set_func`/`get_func` tokens**.
  COMP, VOX, TONE, TSQL, LOCK, TUNER, ANF, MN, SATMODE, MON,
  AFC, BC, NB2, APF, REV, DUAL_WATCH, DIVERSITY, MUTE, SCOPE,
  RESUME, VSC, on top of the existing SBKIN/FBKIN.

- **rigctld bridge: 6 new `set_level`/`get_level` tokens**.
  MICGAIN, COMP, MONITOR_GAIN, VOXGAIN, VOXDELAY, IF_SHIFT.
  (IF_SHIFT named distinctly to avoid collision with the
  pre-existing IF=IFFILTER token — vendor extension to
  Hamlib's `RIG_LEVEL_IF`.)

- **Seven new radio definitions** (Hamlib parity, item 4 of
  v1.1). Cross-checked against the corresponding Hamlib
  `rigs/icom/` and `rigs/kenwood/` source files:
  - **Icom ID-31A/E** (2012 single-band UHF D-STAR HT).
  - **Icom ID-51A/E** and ID-51A Plus2 (2012/2016 dual-band V/U
    D-STAR HT).
  - **Icom ID-52A/E** and ID-52A Plus2 (2020/2024 dual-band V/U
    D-STAR HT — successor to ID-51).
  - **Icom IC-92AD / IC-E92D** (2008 dual-band D-STAR HT —
    predecessor to ID-51).
  - **Icom IC-R30** (2018 wideband digital handheld receiver,
    100 kHz–3.3 GHz).
  - **Kenwood TH-D75A** (2023 tri-band D-STAR/APRS HT —
    successor to TH-D74).
  - **Lab599 TX-500** (modern portable HF transceiver — uses
    Kenwood-compatible CAT, introduces new manufacturer brand
    tag `RadioDefinition.Manufacturer.lab599`).

  All seven are definition-only (`VerificationStatus.definition`)
  — definitions match the manufacturer's CAT documentation and
  Hamlib precedent, but behavior is not field-validated. Each
  has a smoke test confirming it constructs and connects via
  the mock transport.

### Changed
- **`setPower` parameter renamed** from `watts` to `level` across
  `CATProtocol`, every conformer (`IcomCIVProtocol`,
  `YaesuCATProtocol`, `KenwoodProtocol`, `THD72Protocol`,
  `ElecraftProtocol`, `DummyCATProtocol`), and `RigController`.
  Reason: the parameter was misleadingly named — Icom radios
  accept a 0–255 percentage scale (`PowerUnits.percentage`), not
  watts. The new name is unit-neutral; callers should consult
  `RigCapabilities.powerUnits` to interpret. Most call sites use
  the unlabeled form (`rig.setPower(50)`) and are unaffected. The
  labeled form (`rig.setPower(watts: 50)`) is preserved by a
  `@available(*, deprecated, renamed:)` shim — callers see a
  warning, code keeps compiling.

### Changed
- **Typed `VendorExtensions` enum + `rawProtocol` rename (Phase 5.2).**
  New `RigController.vendorExtensions: VendorExtensions` returns
  a discriminated enum carrying the concrete protocol actor for
  the radio's vendor. Pattern-match instead of casting:

  ```swift
  // Before:
  if let icom = await rig.protocol as? IcomCIVProtocol {
      try await icom.setAttenuatorIC9700(.dB12)
  }

  // After:
  if case .icom(let icom) = await rig.vendorExtensions {
      try await icom.setAttenuatorIC9700(.dB12)
  }
  ```

  The discriminated enum gives the compiler switch-exhaustiveness
  — adding a new vendor case forces every call site to handle it
  (or explicitly opt out via `default:`).

  **`RigController.protocol` renamed to `RigController.rawProtocol`**
  (hard rename, no deprecation shim). The accessor still returns
  the type-erased protocol actor for cases the vendor-extensions
  enum doesn't cover (hardware validators that touch per-model
  methods, custom simulators), but is now explicitly documented
  as an unversioned escape hatch. Internal callers across Tests,
  Tools, Examples and the IFFilter doc-comment example all
  updated to the new name (50+ call sites).

  Curated per-vendor facades (e.g. an `IcomExtensions` wrapping
  only "common" methods) were considered and deliberately not
  shipped — they'd commit us to a forever subset we don't have
  data to design well yet. The whole concrete protocol actor is
  accessible through `vendorExtensions`, which is the same level
  of surface apps had before, now typed.

  6 new tests in `VendorExtensionsTests` cover enum-case
  dispatch per vendor, `rawProtocol` identity stability,
  agreement between the two access paths, and the switch-
  exhaustiveness compile-time guard.

- **`CATProtocol` split into capability traits (Phase 5.1).** The
  fat protocol that carried ~40 methods with default-throw
  extensions has been refactored into a narrow universal core
  (frequency, mode, PTT, VFO, connect/disconnect) plus 21
  focused trait protocols (one per feature group:
  `SupportsPower`, `SupportsSplit`, `SupportsAGC`,
  `SupportsTXMeters`, `SupportsCWKeyer`, `SupportsAntenna`,
  `SupportsScanning`, … — all `Supports<Feature>`-named under
  `Sources/RigControl/Core/CATProtocolTraits.swift`).

  Each concrete protocol now declares its supported features in
  its conformance list — `IcomCIVProtocol`'s line carries 21
  traits, `THD72Protocol`'s carries 3. Adding a new conformer
  no longer means inheriting a throwing default for every
  feature; the conformer opts in to exactly what it implements,
  and the compiler enforces that.

  `RigController` accessors now dispatch via
  `try requireTrait((any SupportsX).self, named: "…")`. The
  error message produced when a trait isn't conformed matches
  what the old default-throw extension produced, verbatim — so
  app code that catches `RigError.unsupportedOperation` and
  matches on the message string sees no behavior change. The
  150+ existing tests pass without modification.

  This is a one-time architectural refactor done while the
  library still has only one external user. The cost is paid
  here so third-party adopters never have to migrate later.

### Added
- **Rigctld bridge coverage (Phase 4.5).** The `rigctld`-compatible
  TCP server now speaks every Hamlib command that maps onto the
  Phase 4.1–4.4 features added above. Apps that drive
  SwiftRigControl-backed radios through `rigctl` (or via WSJT-X,
  fldigi, JS8Call, etc.) get the same surface they'd see talking
  to a real Hamlib build:

  - `get_level SWR / ALC / RFPOWER_METER / RFPOWER_METER_WATTS /
    COMP_METER / VD_METER / ID_METER` — TX-meter readings,
    each formatted per Hamlib's `RIG_LEVEL_*` float semantics.
  - `set_level / get_level KEYSPD` and `CWPITCH` — CW keyer.
  - `set_func / get_func SBKIN` and `FBKIN` — semi / full
    break-in. New `setFunc` / `getFunc` commands; other
    function bits return `.notImplemented`.
  - `set_ant / get_ant` — antenna selection. `get_ant` returns
    the four-field Hamlib format `AntCurr Option AntTx AntRx`.
  - `scan VFO/MEM/SLCT/PRIO/PROG/DELTA/STOP` — case-insensitive
    scan control; the per-channel arg is parsed and ignored
    (matches `CATProtocol.startScan`'s shape).
  - `send_morse <text>` and `stop_morse` — radio-generated CW.
    Multi-word messages survive the tokenizer.

  All wire formats cross-checked against Hamlib's
  `~/Developer/hamlib/src/misc.c` `rig_strlevel` table and
  `tests/rigctl_parse.c` short-command table.

  35 new tests across `RigctldParserTests` (13) and
  `RigctldHandlerTests` (22) — parser shape, handler routing,
  Hamlib format parity (SWR ratio, watts, dB, volts, amps),
  case insensitivity, error mapping for bogus scan kinds and
  unknown function names.

- **Antenna selection API (Phase 4.4).** Two new accessors on
  `CATProtocol` and `RigController`:
  - `selectAntenna(_ index: Int)` — choose ANT 1 / ANT 2 / etc.
  - `antenna()` — read the currently-selected antenna

  Indexing is 1-based to match operator and front-panel labels.
  New `RigCapabilities.antennaCount` carries both the
  "supports selection" bit and the upper bound on valid
  indices; default `1` (single fixed jack).

  Per-radio promotion cross-checked against Hamlib's
  per-radio `*_ANTS` macros:
  - IC-7100: 2 (HF jacks; VHF/UHF fixed)
  - IC-7600: 2
  - IC-9700: 1 (per-band hardware jacks; no SW selection)
  - K2: 2 (requires KAT-2 internal tuner or KAT100 external;
    radios without the tuner installed see `commandFailed` at
    runtime)

  Implementations:
  - `IcomCIVProtocol+Antenna.swift` uses `C_CTL_ANT` (`0x12`)
    with 0-based byte on the wire (matching Hamlib's
    `icom_set_ant`).
  - `ElecraftProtocol+Antenna.swift` uses the Kenwood-derived
    `AN<n>;` form for the K2. K2 SET commands don't echo, so
    the implementation skips the ACK wait on the K2 path
    (matches the existing `setPower` pattern).

  Band-stacking register read/write was scoped in but deferred —
  Hamlib only models band-select, and the richer per-band
  registers vary in poorly-documented ways. Tracked.

  12 new tests in `AntennaTests` cover dummy roundtrip,
  single-antenna unsupported, out-of-range invalid parameter,
  before-connect throws, antennaCount clamp, all four verified
  radios' capability promotion, and Icom protocol-level gating.

- **Scanning API (Phase 4.3).** Two new accessors on `CATProtocol`
  and `RigController`:
  - `startScan(_:)` — start a scan of the requested kind
  - `stopScan()` — abort any scan in progress

  New `ScanKind` enum covers all six Hamlib `RIG_SCAN_*` modes:
  `.vfo`, `.memory`, `.selectedMemory`, `.priority`, `.programmed`,
  `.deltaF`. The enum's doc comment carries a per-verified-radio
  support matrix.

  Six new capability flags on `RigCapabilities` (one per scan
  kind) mirror Hamlib's bitfield. Per-radio promotion for
  IC-7100 / IC-7600 / IC-9700 cross-checked against the matching
  `IC{model}_SCAN_OPS` macros in `rigs/icom/`.

  `IcomCIVProtocol` implementation uses CI-V `0x0E` (C_CTL_SCAN)
  with sub-commands `0x00`–`0x03` per `icom_defs.h`. Unlike
  Hamlib, does not silently change the radio's VFO/MEM mode under
  the user — callers must select the appropriate state first.

  `DummyCATProtocol` tracks active scan state with a new
  `activeScan` test helper.

  10 new tests in `ScanningTests` cover roundtrip, replacement
  semantics, idempotent stop, before-connect throws, per-kind
  capability gating, and the three Icom per-radio matrices.

- **CW keyer API (Phase 4.2).** Six new typed accessors on
  `CATProtocol` and `RigController`:
  - `setCWSpeed(_:)` / `cwSpeed()` — keyer WPM
  - `setCWPitch(_:)` / `cwPitch()` — sidetone Hz
  - `setBreakIn(_:)` / `breakIn()` — `BreakInMode.off`/`.semi`/`.full`
  - `sendCW(_ text:)` — text → Morse via the radio
  - `stopCW()` — abort transmission

  Three new typed value wrappers — `CWSpeed`, `CWPitch`,
  `BreakInMode` — replace raw `Int`/`Bool` arguments. `CWSpeed`
  and `CWPitch` clamp to the supported range (6–48 WPM, 300–900 Hz)
  on construction and accept integer literals
  (`rig.setCWSpeed(28)`).

  Two new capability flags on `RigCapabilities`:
  `supportsCWKeyer` (speed/pitch/break-in) and `supportsSendCW`
  (text→CW). All three hardware-verified Icoms opt in; per-radio
  promotion cross-checked against Hamlib's `IC{model}_LEVEL_ALL`
  macros and `send_morse` op.

  `IcomCIVProtocol` implementation uses byte-identical encoding
  to Hamlib's `rigs/icom/icom.c`:
  - WPM via the full 43-entry `cw_lookup` table.
  - Pitch via the linear formula
    `icom_byte = round((Hz − 300) × 255 / 600)`.
  - Break-in via `0x16 0x47` with payload `0x00`/`0x01`/`0x02`.
  - Send via `0x17` (ASCII, truncated to 30 chars).
  - Stop via `0x17` with payload `0xFF`.

  `DummyCATProtocol` holds CW state with sensible defaults
  (28 WPM, 600 Hz, semi break-in) plus `lastSentCW` and
  `isSendingCW` test/preview helpers.

  23 new tests cover value-wrapper clamping, full Hamlib
  `cw_lookup` parity at every breakpoint, pitch formula
  round-trips, dummy state roundtrip, ASCII truncation, non-ASCII
  stripping, capability gating, and before-connect throws.

- **Subscriber-registration race fix and documentation.**
  `RigController.events` registers new subscribers via a detached
  `Task` (so the accessor can be `nonisolated` and called from
  any context). Under parallel test load this can lag the first
  emission; the events doc comment now documents this caveat
  with the recommended subscribe-in-init pattern. The
  pre-existing `pttPolledChangesEmit` test that was sensitive to
  this race has been rewritten to follow the documented pattern.

- **TX-side metering API (Phase 4.1).** Six new typed accessors
  on `CATProtocol` and `RigController`:
  - `getRFPowerOut()` / `rfPowerOut()` — RF power output
  - `getSWR()` / `swr()` — SWR
  - `getALC()` / `alc()` — ALC
  - `getComp()` / `comp()` — speech compressor
  - `getVoltage()` / `voltage()` — supply voltage
  - `getCurrent()` / `current()` — supply current

  Each returns a new `MeterReading` value type with the raw byte
  the radio sent, a normalised 0..1+ representation suitable for
  UI bars, and a typed physical-unit accessor (`watts`,
  `swrRatio`, `volts`, `amps`, `dB`). Calibration curves are
  transcribed from Hamlib's `icom_default_*_cal` tables so
  Swift readings match Hamlib's exactly on Icom radios.

  Six new capability flags on `RigCapabilities`
  (`supportsRFPowerMeter`, `supportsSWRMeter`, `supportsALCMeter`,
  `supportsCompMeter`, `supportsVoltageMeter`,
  `supportsCurrentMeter`) — all default `false`. The three
  hardware-verified Icoms (IC-7100, IC-7600, IC-9700) opt into
  all six; per-radio promotion cross-checked against the
  matching Hamlib `IC{model}_LEVEL_ALL` macro. Calling an
  unsupported meter throws `RigError.unsupportedOperation`.

  `DummyCATProtocol` ships with sensible idle defaults (RF
  power 0, SWR 1:1, voltage ~13.8 V, current ~1 A) and a
  `simulateMeter(_:raw:)` test/preview helper so SwiftUI
  previews can render meaningful meter UI without hardware.

- **Hosted DocC site** at
  https://jjones9527.github.io/SwiftRigControl/documentation/rigcontrol/
  — generated and published on every push to `main` by the
  existing CI workflow. PR builds and tag builds still compile
  docs (with `--warnings-as-errors`) but don't deploy. The DocC
  build now uses `--transform-for-static-hosting
  --hosting-base-path SwiftRigControl` so links work under the
  sub-path GitHub Pages serves us at. README gained a Docs badge
  and a paragraph at the top of the Documentation section.
- **SwiftDocCPlugin** (Apple, build-time only) declared as the
  package's first external dependency. Enables
  `swift package generate-documentation` for CI and local doc
  builds. Not linked into any product; downstream consumers pay
  one extra `git fetch` at resolve time and nothing else.
  CLAUDE.md's "no external dependencies" rule was updated to
  document the build-time-plugin exception.
- **CI doc gates.** `.github/workflows/ci.yml` now runs the
  inheritance-aware public-symbol audit
  (`Scripts/check-public-docs.py`) as the first gate and a
  `--warnings-as-errors` DocC build later in the pipeline. Doc
  regressions surface before the longer build/test steps.
- **`Package.resolved` is no longer tracked.** Library convention:
  consumers should resolve fresh against the package's version
  requirements. `docs-build/` (local DocC output) is also ignored
  now.
- **Symbol-level DocC sweep.** Every public declaration in
  `Sources/RigControl/` now has a doc comment, or inherits one
  from a `CATProtocol` / `SerialTransport` / `CIVCommandSet`
  requirement (DocC handles inheritance automatically). Net
  additions: `SerialConfiguration` parity/init,
  `RadioDefinition.Manufacturer`, the new Phase 2
  `PollingConfiguration` and `HealthMonitorConfiguration` /
  `RetryPolicy` fields, and a long tail of struct inits.
- **`Scripts/check-public-docs.py`** — inheritance-aware audit
  script that walks `Sources/RigControl/`, reports any public
  declaration without a `///` doc comment, and exits non-zero
  when issues remain. Ready for CI wiring in the next commit.
- **DocC catalog (`Sources/RigControl/RigControl.docc/`)** with a
  curated landing page (every top-level public symbol grouped by
  topic) plus five articles: Getting started without hardware,
  Reactive state and the events stream, Verification status,
  Adding a new radio, and Migrating from Hamlib. Xcode users get
  inline Quick Help and the Documentation Viewer immediately;
  GitHub Pages hosting lands in a follow-up commit.
- **Connection-health monitor (`startHealthMonitor` /
  `stopHealthMonitor`).** Periodic `getFrequency` heartbeat at the
  configured `heartbeatInterval` (default 5 s). After
  `degradeAfter` consecutive failures (default 3), transitions
  the connection to `.degraded(reason:)`; a subsequent successful
  probe transitions back to `.connected`. Optional `RetryPolicy`
  drives automatic reconnection with exponential backoff —
  `initialDelay × multiplier^(attempt-1)`, capped at `maxDelay`,
  bounded by `maxAttempts` (nil = retry forever). State
  transitions fan through the same `events` stream as setter and
  polling events. `disconnect()` stops the monitor automatically.
  New `isMonitoringHealth` accessor.
- **`RigController.HealthMonitorConfiguration` / `RetryPolicy`
  structs** for tuning. Auto-reconnect is opt-in (`retryPolicy`
  defaults to nil) — apps that want manual reconnect can subscribe
  to `.degraded` and call `connect()` themselves.
- **`DummyCATProtocol.simulateFailure(_:)` test helper** that flips
  the dummy into "always-throw" mode and back. Used by the
  health-monitor tests to exercise failure paths deterministically;
  also useful for app-side integration tests that need to simulate
  "the radio went away."
- **Polled state broadcaster (`startPolling` / `stopPolling`).**
  Read-only state the radio doesn't push (signal strength,
  front-panel-driven frequency/mode/PTT changes) can now be
  sampled on a configurable cadence and fanned through the same
  `events` stream as setter-driven changes. New
  `PollingConfiguration` struct exposes per-field intervals with
  sensible defaults (200 ms S-meter, 1 s frequency, 2 s mode,
  100 ms PTT) plus `.uniform(every:)` and `.disabled`
  convenience helpers. Emission policy: `signalStrength` emits
  every poll; `frequency` / `mode` / `ptt` emit only on actual
  change. `disconnect()` stops polling automatically. Transient
  per-cycle errors are swallowed so a single timeout doesn't
  kill the poller. New `isPolling` accessor.
- **Push-style event stream (`RigController.events`).** New
  `AsyncStream<RigStateEvent>` that fires whenever a `set*` call
  on `RigController` succeeds. SwiftUI apps can drive `@Observable`
  view models from the stream with no polling loop in user code.
  Multiple subscribers are supported (each `events` access returns
  a fresh stream; the controller fans events out). Per-subscriber
  `.bufferingNewest(64)` policy bounds memory; subscribers
  auto-deregister on cancellation. New subscribers see a replay of
  the current connection state so views that subscribe lazily get
  the right initial value.
- **`RigStateEvent` enum** with cases for frequency, mode, PTT,
  VFO, power, split, RIT/XIT, signal strength, AGC, NB, NR, IF
  filter, level controls (unified via a `LevelKind` discriminator),
  power state, and connection-state transitions. Equatable +
  Sendable.
- **`ConnectionState` enum** (`.disconnected`, `.connecting`,
  `.connected`, `.degraded(reason:)`, `.reconnecting(attempt:)`).
  Phase 2.1 emits the first three; `.degraded` and `.reconnecting`
  are populated by Phase 2.3's connection-health monitor.
- `Examples/BasicUsage/DummyRadioExample.swift` gained an inline
  `@Observable` SwiftUI view-model pattern showing the
  event-stream consumption idiom.

### Removed
The items below are source-breaking *in the strict sense*, but each
had carried a formal `@available(*, deprecated)` marker since
v1.0.x. Callers who heeded the deprecation warnings are already
migrated. The next release will stay in the **v1.0.x** line per
project policy: breaking changes are gated by a formal deprecation
period, not by a major-version bump.

- `IcomCIVProtocol.init(transport:civAddress:capabilities:)` — the
  legacy two-arg-plus-caps initializer deprecated since v1.0.x.
  **Migration:** pass an explicit command set.
  ```swift
  // Before
  let proto = IcomCIVProtocol(
      transport: transport,
      civAddress: 0xA2,
      capabilities: .full
  )
  // After
  let proto = IcomCIVProtocol(
      transport: transport,
      civAddress: 0xA2,
      radioModel: .ic9700,
      commandSet: StandardIcomCommandSet(civAddress: 0xA2),
      capabilities: .full
  )
  ```
  In most cases you should not be calling this initializer
  directly — use `RadioDefinition.icomIC9700()` (etc.) and let
  `RigController` build the protocol for you.
- Six deprecated `RadioDefinition` static properties:
  `.icomIC9700`, `.icomIC7300`, `.icomIC7600`, `.icomIC7100`,
  `.icomIC7610`, `.icomIC705`. **Migration:** add `()` —
  `.icomIC9700()`, `.icomIC7600()`, etc. Each now accepts an
  optional `civAddress:` parameter for non-default bus addresses.
  ```swift
  // Before
  let rig = RigController(radio: .icomIC9700, connection: …)
  // After
  let rig = try RigController(radio: .icomIC9700(), connection: …)
  // Or with a custom CI-V address:
  let rig = try RigController(radio: .icomIC9700(civAddress: 0xA3), connection: …)
  ```
- `CATProtocol.init(transport:)` requirement and the
  satisfying-only single-arg inits on every conformer
  (`IcomCIVProtocol`, `YaesuCATProtocol`, `KenwoodProtocol`,
  `THD72Protocol`, `ElecraftProtocol`, `TenTecOrionProtocol`,
  `TenTecLegacyProtocol`). The Icom variant called
  `preconditionFailure` at runtime; the others picked arbitrary
  default capabilities. None had real call sites.
  **Migration:** if you were constructing a protocol with the
  one-arg init (you almost certainly were not), pass an explicit
  capabilities value via the radio's `init(transport:capabilities:)`
  (or, for Icom and Ten-Tec Orion, the longer per-radio init).
  Construction is now exclusively the job of concrete-type inits
  and `RadioDefinition.protocolFactory`.

### Changed
- **BREAKING for tool users (not library consumers).** All 16
  developer-tool executables — hardware validators, interactive
  validators, and Elecraft debug tools — moved out of the main
  package into a separate SwiftPM project at
  `Tools/SwiftRigControlTools/`. Library consumers pulling
  SwiftRigControl via SPM now compile only `RigControl`,
  `RigControlXPC`, and `RigControlHelper` (3 products) instead of
  19. To run a validator or debug tool, `cd Tools/SwiftRigControlTools`
  first. No source code or radio support changed; this is purely a
  package layout change.
- `ConnectionType.mock` now constructs an in-memory transport
  instead of throwing `RigError.unsupportedOperation`. Existing
  code that catches the throw will no longer see it; existing
  code that avoided `.mock` because it threw can now use it.

### Added
- **Dummy radio (`RadioDefinition.dummy(name:capabilities:)`)** — the
  Swift analogue of Hamlib's Model 1 ("Dummy") rig. A new
  `DummyCATProtocol` actor holds frequency, mode, PTT, VFO, power,
  split, RIT/XIT, DSP, level-controls, and memory-channel state in
  memory and answers reads with what was written. Use it for
  SwiftUI previews, demo apps, tutorials, and integration tests of
  app code that should not require real hardware. New `.dummy` case
  on `RadioDefinition.Manufacturer`.
- **Public `MockSerialTransport`** — the test-fixture mock transport
  promoted to a stable public API. Scriptable byte-level transport
  for protocol-level testing in downstream projects. Lives at
  `Sources/RigControl/Transport/MockSerialTransport.swift`.
- `Examples/BasicUsage/DummyRadioExample.swift` reference file
  demonstrating the dummy radio pattern and a SwiftUI preview
  snippet.
- **Continuous integration** — `.github/workflows/ci.yml` runs
  `swift build` (library with warnings-as-errors, then all
  targets) and `swift test --parallel` on every push and pull
  request, using the latest-stable Xcode on `macos-15`. The Tools
  subproject is built in a follow-on step. README carries a CI
  status badge. CONTRIBUTING.md documents how to reproduce the CI
  gate locally.
- `RadioDefinition.VerificationStatus` enum (`.hardware` /
  `.definition`) capturing how thoroughly a radio definition has
  been validated. Defaults to `.definition` for backward
  compatibility — new radio additions are paper-only until
  promoted explicitly.
- `RadioDefinition.verificationStatus` property and convenience
  `RigController.verificationStatus` accessor so apps can show
  honest "Hardware verified" vs. "Definition only" badges in UI.
- IC-7100, IC-7600, IC-9700, and K2 are marked `.hardware`;
  every other shipping radio defaults to `.definition`.
- `VerificationStatusTests` suite (8 tests) guarding against
  accidental promotion or demotion.

### Fixed
- IC-7600: send Main/Sub selection before mode changes to ensure the
  command targets the intended receiver (commit `3931887`).

## [1.3.0] - 2026-04-28

### Added

#### Radio Support
- **11 new radio models** (9 from Hamlib comparison + 2 new):
  - **Icom:** IC-7760 (HF/6m flagship, 200W), IC-7300 MK2 (HF/6m SDR, 100W), IC-9000 (VHF/UHF all-mode, dual RX), IC-2820H (VHF/UHF FM/D-STAR)
  - **Yaesu Legacy:** FT-1000MP (HF, 200W, dual RX), FT-857 (HF/VHF/UHF, 100W), FT-897 (HF/VHF/UHF, 100W), FT-450 (HF/6m, 100W)
  - **Kenwood Legacy:** TS-850S (HF, 100W, ATU), TS-570D (HF/6m, 100W, ATU), TS-570S (HF, 100W)
- **Ten-Tec protocol family** — two new protocol implementations:
  - **TenTecOrionProtocol**: Full CAT for Orion (TT-565), Orion II (TT-599), Eagle — hybrid ASCII/binary `*`/`?`/`@` framing, 4-byte big-endian frequency, 7-mode support (USB/LSB/CW/CW-R/AM/FM/RTTY), PTT, split, S-meter
  - **TenTecLegacyProtocol**: ASCII set-only protocol for Jupiter (TT-538), Pegasus (TT-550) — `N<freq>`, `M<mode>`, CR-terminated; cached frequency/mode (no query commands)

#### Level Controls API
- **New `CATProtocol` methods** for hardware-level controls:
  - `setAFGain(_:)` / `getAFGain()` — AF gain (volume), 0–255 scale
  - `setRFGain(_:)` / `getRFGain()` — RF gain (receiver sensitivity), 0–255 scale
  - `setSquelch(_:)` / `getSquelch()` — Squelch level, 0–255 scale
  - `setPreamp(_:)` / `getPreamp()` — Preamplifier selection (0=off, 1=AMP1, 2=AMP2)
  - `setAttenuator(_:)` / `getAttenuator()` — Attenuator level in dB
  - `setPowerState(_:)` / `getPowerState()` — Remote power on/off (PS command)
- **New `RigController` convenience methods** wrapping the above with caching support:
  - `setAFGain(_:)` / `afGain(cached:)`
  - `setRFGain(_:)` / `rfGain(cached:)`
  - `setSquelch(_:)` / `squelch(cached:)`
  - `setPreamp(_:)` / `preamp(cached:)`
  - `setAttenuator(_:)` / `attenuator(cached:)`
  - `setPowerState(_:)` / `getPowerState()`

#### DSP Controls API
- **New `CATProtocol` methods** for DSP control:
  - `setAGC(_:)` / `getAGC()` — AGC mode (`.fast`, `.mid`, `.slow`, `.off`, `.auto`)
  - `setNoiseBlanker(_:)` / `getNoiseBlanker()` — Noise blanker on/off
  - `setNoiseReduction(_:level:)` / `getNoiseReduction()` — DSP noise reduction with level
  - `setIFFilter(_:)` / `getIFFilter()` — IF filter selection (`.filter1`–`.filter3`)
- **New types:**
  - `AGCMode` enum: `.off`, `.fast`, `.mid`, `.slow`, `.auto`
  - `IFFilter` enum: `.filter1` (wide), `.filter2` (mid), `.filter3` (narrow)
- **RigController DSP methods** with caching:
  - `setAGC(_:)` / `agc(cached:)`
  - `setNoiseBlanker(_:)` / `noiseBlanker(cached:)`
  - `setNoiseReduction(_:level:)` / `noiseReduction(cached:)`
  - `setIFFilter(_:)` / `ifFilter(cached:)`

#### Protocol Implementations

**Yaesu CAT Protocol** (`YaesuCATProtocol+LevelControls.swift`):
- AF gain: `AG0nnn` / `AG0` query
- RF gain: `RGnnn` / `RG` query
- Squelch: `SQ0nnn` / `SQ0` query
- Preamp: `PA0n` — 0=IPO (off), 1=AMP1, 2=AMP2
- Attenuator: `RAnn` — 0→00, 6→01, 12→02, 18→03
- AGC: `GTnnn` — 000=fast, 001=mid, 002=slow, 003=auto
- Noise blanker: `NB0` / `NB1`
- Noise reduction: `NR0` / `NR1` / `NR2`
- IF filter: `SHnn` — filter1→07, filter2→05, filter3→02
- Power state: `PS1` / `PS0`
- Memory: `MCnnn`

**Kenwood Protocol** (`KenwoodProtocol+LevelControls.swift`):
- Same command set as Yaesu with differences:
  - Preamp: `PA` (not `PA0`) — single stage, level>0 enables
  - AGC: 0=off, 1=fast, 2=mid, 3=slow

**Elecraft Protocol** (`ElecraftProtocol+LevelControls.swift`):
- K2/K3/K4-aware with full isK2 branching:
  - AF gain: `AGnnn` (no "0" suffix, unlike Yaesu/Kenwood)
  - Squelch: `SQnnn` (no "0" suffix)
  - Attenuator: K2 uses 10/20 dB steps; K3/K4 use 6 dB steps
  - AGC: K2 supports fast(0)/slow(1) only; K3/K4 add mid(1)
  - IF filter: K2 uses `FW` command (Hz); K3/K4 use `BW` command (10Hz units)
  - K2 SET commands do not echo — uses 50ms delay instead of `receiveResponse()`
  - Memory: `MC` with K2 10-channel limit vs 100 for K3/K4

### Changed

- `CATProtocol` extended from 12 to 31 methods; all new methods have default implementations throwing `.unsupportedOperation` for graceful degradation
- `YaesuCATProtocol.sendCommand` / `receiveResponse` changed from `private` to `internal` access to support extension files
- `KenwoodProtocol.sendCommand` / `receiveResponse` changed from `private` to `internal` access to support extension files

### Fixed

#### Hamlib/rigctld Compatibility Audit
- **AGC byte values corrected** to match Hamlib CI-V constants: OFF=0x00, FAST=0x02, SLOW=0x03, MID=0x05, AUTO=0x06 (was wrong sequential 1/2/3)
- **Attenuator steps expanded** to cover all models: 3/6/9/12 dB for IC-9700; 10/20 dB for IC-7300/7610; 30 dB added for IC-7800
- **RFPOWER minimum floor**: Both get and set now enforce 0.05 minimum (radios reject 0W, matching Hamlib behavior)
- **rigctld AGC numeric codes** aligned with Hamlib wire codes: FAST→2, SLOW→3, MID→5, AUTO→6
- **DATA mode command routing**: DATA-USB/LSB/FM now uses CI-V command 0x26 (`C_SEND_SEL_MODE`) with `data_flag=0x01` on targetable radios (IC-7300, IC-7610, IC-7760, IC-7300MK2), rather than using filter byte 0x00 on command 0x04. Non-targetable radios use 0x04 with filter byte as before.
- `IcomCIVProtocol+MemoryChannels.swift`: Non-exhaustive switch in `getMemoryChannelCount()` fixed by adding `case .ic7760, .ic7300mk2: return 99`

---

## [1.0.4] - 2026-01-14

### Added

#### License & Project Organization
- **LGPL v3.0 License** - Added GNU Lesser General Public License v3.0
  - Follows [Hamlib](https://hamlib.github.io/) licensing model
  - Allows commercial application integration
  - Requires library modifications be shared back to community
  - Clear documentation of license terms in README
  - Complete license text with SwiftRigControl copyright (2024-2025)

#### GitHub Integration
- **Issue Templates** for professional bug reporting and feature requests:
  - `.github/ISSUE_TEMPLATE/bug_report.md` - Structured bug reporting
  - `.github/ISSUE_TEMPLATE/feature_request.md` - Feature request template
  - `.github/ISSUE_TEMPLATE/radio_support.md` - New radio support requests
- **Pull Request Template** (`.github/PULL_REQUEST_TEMPLATE.md`):
  - Code review checklist
  - Testing requirements
  - Documentation updates
  - Breaking change guidelines

#### Debug Tools
- **Examples/Debugging/** directory for K2 troubleshooting tools:
  - `K2PTTDebug` - PTT control testing with 5-second observation windows
  - `K2PowerDebug` - QRP power control verification (0-15W)
  - `K2NewCommandsTest` - TQ, RC, RD, RU command testing
  - Complete README explaining tool usage

### Fixed

#### Elecraft K2 Implementation (Critical Fixes)
- **Power Control Format Issue** ([K2_POWER_FIX.md](Documentation/Development/K2/K2_POWER_FIX.md)):
  - **Problem:** Setting 5W read back as 2W, settings not persisting correctly
  - **Root Cause:** K2 uses direct watts (PC005 = 5W), K3/K4 use percentage (PC033 = 33%)
  - **Solution:** Auto-detect K2 by maxPower (≤15W) and use correct format
  - **Status:** ✅ FIXED - Power control now accurate across all Elecraft models

- **PTT Control Missing** ([K2_PTT_FIX.md](Documentation/Development/K2/K2_PTT_FIX.md)):
  - **Problem:** `getPTT()` threw "unsupported operation" error
  - **Root Cause:** PTT query not implemented for K2
  - **Solution:** Implement using TQ command (K2) and IF command (K3/K4)
  - **Status:** ✅ FIXED - PTT query fully functional

- **PTT Timing Issues** ([K2_PTT_TIMING_FIX.md](Documentation/Development/K2/K2_PTT_TIMING_FIX.md)):
  - **Problem:** TQ query returned RX (TQ0) even when radio transmitting
  - **Root Cause:** K2 TX/RX transition takes 50-100ms (relay switching, PA bias, RF muting)
  - **Solution:**
    - Increased `setPTT()` delay from 50ms to 100ms
    - Added 20ms pre-query delay in `getPTT()`
    - Total timing budget: ~120ms for verified state transition
  - **Status:** ✅ FIXED - Verified with external watt meter showing correct RF output

- **K2 Protocol Handling** in `ElecraftProtocol.swift`:
  - Added K2 detection logic (maxPower ≤ 15W)
  - Added 50ms command delay (k2CommandDelay) to prevent buffer overflow
  - Fixed non-echoing SET command handling (K2 only echoes QUERY commands)
  - Added busy state detection (?; response)

#### K2 New Commands Implemented
- **TQ (Transmit Query)** - GET only, returns TQ0 (RX) or TQ1 (TX)
  - Most efficient way to check TX/RX status on K2
  - Used by `getPTT()` for K2 radios
- **RC (RIT Clear)** - Clears RIT/XIT offset to zero
- **RD (RIT Down)** - Decreases RIT/XIT offset by 10 Hz
- **RU (RIT Up)** - Increases RIT/XIT offset by 10 Hz

### Changed

#### Project Structure Reorganization
- **Root Directory Cleanup:**
  - Moved 60+ markdown files from root to `Documentation/Development/`
  - Organized into subdirectories: K2/, Icom/, Research/, Testing/, Sprints/, General/
  - Root now contains only essential user-facing files

- **Documentation Structure:**
  ```
  Documentation/
  ├── Development/
  │   ├── K2/                  # 10 K2 implementation docs
  │   ├── Icom/                # 19 IC-7600/7100/9700 docs
  │   ├── Research/            # 6 Hamlib comparison docs
  │   ├── Testing/             # 8 test suite docs
  │   ├── Sprints/             # 5 sprint summaries
  │   └── General/             # 12 misc development docs
  └── (user-facing docs)
  ```

- **Enhanced .gitignore:**
  - Added `*.pdf` exclusion (copyrighted manufacturer manuals)
  - Added `*.sh` exclusion (test scripts)
  - Added editor directory exclusions (.vscode/, .idea/)
  - Organized with category comments

#### Package.swift Updates
- Removed 3 redundant K2 debug tools (K2Debug, K2RITDebug, K2IFDebug)
- Updated paths for debug tools moved to Examples/Debugging/
- Added clear section markers for debug tools
- Verified build succeeds with updated structure

#### Hardware Validation
- **K2Validator PTT Test Updated:**
  - Changed from USB mode to CW mode (SSB requires audio input for RF)
  - Extended TX hold time to 5 seconds for easy observation
  - Added detailed diagnostic prompts and watt meter instructions
  - Confirmed working with hardware validation

### Verified

#### Hardware Testing Complete
- ✅ **IC-7600** - All 13 comprehensive tests passing (commit 5a02fca)
- ✅ **IC-7100** - All 7 multi-band tests passing
- ✅ **IC-9700** - All 14 tests passing (4-state VFO architecture)
- ✅ **Elecraft K2** - All 11 tests passing with fixes applied
  - Frequency control (160m-10m including WARC bands)
  - Mode control (LSB/USB/CW/AM/FM)
  - QRP power control (1-15W)
  - PTT control (CW mode tested)
  - RIT/XIT control
  - Split operation

### Documentation

#### Comprehensive K2 Documentation (10 files, ~80 pages)
- [K2_IMPLEMENTATION_REVIEW.md](Documentation/Development/K2/K2_IMPLEMENTATION_REVIEW.md) - 17-page detailed analysis vs KIO2 spec
- [K2_REVIEW_SUMMARY.md](Documentation/Development/K2/K2_REVIEW_SUMMARY.md) - Executive summary (A- grade, 90% implementation)
- [K2_POWER_FIX.md](Documentation/Development/K2/K2_POWER_FIX.md) - Power format fix details
- [K2_PTT_FIX.md](Documentation/Development/K2/K2_PTT_FIX.md) - PTT implementation
- [K2_PTT_TIMING_FIX.md](Documentation/Development/K2/K2_PTT_TIMING_FIX.md) - TX/RX timing analysis
- [K2_PTT_TROUBLESHOOTING.md](Documentation/Development/K2/K2_PTT_TROUBLESHOOTING.md) - Troubleshooting guide
- [K2_PTT_SSB_AUDIO_REQUIREMENT.md](Documentation/Development/K2/K2_PTT_SSB_AUDIO_REQUIREMENT.md) - SSB audio requirement discovery
- [K2_PTT_CW_MODE_TEST.md](Documentation/Development/K2/K2_PTT_CW_MODE_TEST.md) - CW mode testing rationale
- [K2_PTT_5_SECOND_TEST.md](Documentation/Development/K2/K2_PTT_5_SECOND_TEST.md) - 5-second observation test guide
- [K2_PTT_INVESTIGATION.md](Documentation/Development/K2/K2_PTT_INVESTIGATION.md) - Initial investigation notes

### Removed

#### Cleanup
- 5 PDF files removed from tracking (~3MB copyrighted manuals):
  - IC-7100 CIV.pdf
  - IC-7600 CI-V.pdf
  - IC-9700 CI-V.pdf
  - KIO2 Pgmrs Ref rev E.pdf
  - Users should download from manufacturers
- test_ic7100_ptt.sh script removed
- main.swift.backup files removed
- 3 redundant K2 debug tools removed (K2Debug, K2IFDebug, K2RITDebug)

### Technical Details

#### K2 Protocol Characteristics Documented
- Does NOT echo SET commands (only echoes QUERY commands)
- Requires 50ms delay between commands (prevent buffer overflow)
- Returns ?; when busy (transmit, direct frequency entry, scanning)
- Uses direct watts for power control (000-015 for QRP)
- TX/RX transition: 50-100ms hardware delay for relay/PA
- Firmware requirement: 2.01+ (tested with 2.04)

#### Build Status
- ✅ Swift 6.2+ compatible
- ✅ Package builds successfully with new structure
- ✅ All hardware validators functional
- ✅ Zero compilation errors

#### License Alignment
- Follows Hamlib's LGPL model (industry standard for ham radio libraries)
- LGPL v3.0 (modern version) vs Hamlib's LGPL v2.1 (1999)
- Enables commercial integration while ensuring community benefits from improvements

### Migration Notes

**No breaking changes** - This is a bugfix and organizational release.

#### For K2 Users
If you were experiencing power control or PTT issues with K2, these are now fixed. No code changes required on your end - just update to v1.0.4.

#### For All Users
The project structure is cleaner but all public APIs remain unchanged. If you reference internal documentation files in your build scripts, note they've moved to `Documentation/Development/`.

### Release Significance

This release represents a major milestone:
1. ✅ **Production-Ready K2 Support** - All critical bugs fixed
2. ✅ **Four Radios Verified** - IC-7600, IC-7100, IC-9700, K2 with hardware
3. ✅ **Professional Structure** - Clean organization ready for contributors
4. ✅ **Proper Licensing** - LGPL v3.0 following industry standards
5. ✅ **GitHub Ready** - Issue templates, PR templates, proper .gitignore

SwiftRigControl is now ready for public release and third-party integration.

---

## [1.0.3] - 2024-12-23

### Added

#### Comprehensive Hardware Test Suite
- **IC-7600 Hardware Tests** - 13 comprehensive test methods covering:
  - Frequency control across all HF bands + 6m (160m-6m)
  - Dual VFO operation and independent control
  - Mode control (8 modes: LSB, USB, CW, CW-R, RTTY, RTTY-R, AM, FM)
  - Power control with ±5W tolerance (10-100W)
  - Split operation for DX work
  - RIT/XIT functionality (Receiver/Transmitter Incremental Tuning)
  - PTT control with safety confirmation dialogs
  - S-meter signal strength reading
  - Performance testing (50 rapid frequency changes with timing)
  - Frequency boundary testing (min/max validation)

- **IC-7100 Hardware Tests** - 7 multi-band test methods covering:
  - HF band testing (160m - 10m)
  - VHF/UHF band testing (6m, 2m VHF, 70cm UHF)
  - Mode control across all bands
  - PTT control with safety confirmation
  - Power control
  - Split operation
  - **Note:** Correctly documented - IC-7100 does NOT have satellite mode

- **IC-9700 Hardware Tests** - 14 comprehensive test methods covering:
  - VHF band testing (2m / 144 MHz)
  - UHF band testing (70cm / 430 MHz)
  - 1.2GHz band testing (23cm / 1.2 GHz)
  - Mode control (LSB, USB, CW, CW-R, FM, AM)
  - Dual independent receivers (Main + Sub)
  - Independent mode control for Main/Sub receivers
  - **Satellite mode operation** - Uplink/downlink configuration testing
  - Split operation
  - Power control (5-50W)
  - PTT control with safety confirmation
  - Signal strength reading
  - Rapid frequency changes (50 iterations with performance metrics)
  - Cross-band operation (2m/70cm, 2m/23cm, 70cm/23cm)
  - **Note:** Correctly documented - IC-9700 DOES have satellite mode

- **K2 Hardware Tests (Elecraft)** - 11 comprehensive test methods covering:
  - Frequency control across all HF bands (160m - 10m including WARC)
  - Fine frequency control with 10 Hz step testing
  - Mode control (LSB, USB, CW, CW-R, AM, FM)
  - QRP power control (1-15W with ±2W tolerance)
  - VFO A/B control
  - Split operation
  - RIT control (Receiver Incremental Tuning)
  - XIT control (Transmitter Incremental Tuning)
  - PTT control with safety confirmation
  - CW mode specialty testing (K2's strength)
  - Rapid frequency changes (30 iterations)
  - Band edge testing (low/high frequency limits for all bands)
  - Signal strength reading

#### Test Infrastructure
- **`HardwareTestHelpers.swift`** - Comprehensive test infrastructure providing:
  - Serial port enumeration (`listSerialPorts()`) for macOS /dev/cu.* devices
  - Interactive serial port selection (`promptForSerialPort()`)
  - Environment variable or interactive port selection (`getSerialPort()`)
  - PTT safety confirmation dialogs with detailed warnings
  - Radio state save/restore (`RadioState` struct)
  - Test result reporting (`TestReport` struct)
  - Frequency formatting utilities (`formatFrequency()`)

#### Documentation
- **`HARDWARE_TESTS_COMPLETE.md`** - 300+ line comprehensive documentation covering:
  - Test suite organization and structure
  - Individual test suite descriptions and features
  - Running instructions with environment variables
  - Test quality standards and safety features
  - Build status and coverage summary
  - Migration guide and fixes applied

- **`TEST_CLEANUP_PLAN.md`** - Test strategy and organization plan with:
  - Current test suite analysis
  - Phase-by-phase cleanup plan
  - Test execution strategy
  - Test quality standards
  - Success criteria

- **`Tests/RigControlTests/Archived/README.md`** - Documentation for archived tests explaining:
  - Directory structure
  - Legacy tests that were replaced
  - How to run current tests
  - Note about maintenance status

### Changed

#### Test Organization (Swift Best Practices)
- Reorganized entire test directory structure:
  - `Tests/RigControlTests/UnitTests/` - Unit tests for core functionality (4 files, 47 tests)
  - `Tests/RigControlTests/ProtocolTests/` - Protocol-level tests with mocks (4 files, 90+ tests)
  - `Tests/RigControlTests/HardwareTests/` - Comprehensive hardware test suites (4 files, 45 tests)
  - `Tests/RigControlTests/Support/` - Test infrastructure and helpers (2 files)
  - `Tests/RigControlTests/Archived/` - Legacy tests and debug tools (preserved for reference)

#### API Improvements
- **RigController initialization** now properly throws errors instead of using fatalError:
  ```swift
  // Before (v1.0.2):
  let rig = RigController(radio: .icomIC7600, connection: .serial(...))

  // After (v1.0.3):
  let rig = try RigController(radio: .icomIC7600, connection: .serial(...))
  ```

- **Power method simplified** - Removed deprecated `cached` parameter:
  ```swift
  // Before (v1.0.2):
  let power = try await rig.power(cached: false)

  // After (v1.0.3):
  let power = try await rig.power()
  ```

### Fixed

#### Actor Isolation Issues (Swift 6 Concurrency)
- **MockTransport** - Fixed actor isolation by adding proper async methods:
  - Added `setShouldThrowOnRead(_:)` method
  - Added `setShouldThrowOnWrite(_:)` method
  - Removed invalid `setProperty(\.keyPath, to:)` pattern

- **IcomProtocolTests** - Fixed actor isolation on line 163:
  - Changed from `setProperty(\.shouldThrowOnRead, to: true)`
  - Changed to `setShouldThrowOnRead(true)`

- **IcomIntegrationTests** - Fixed actor isolation in 5 locations:
  - All `rig.capabilities` access now properly awaited
  - All `rig?.radioName` access now properly awaited
  - Pattern: `let capabilities = await rig.capabilities`

#### Test Suite Issues
- Fixed `StandardIcomCommandSet` initializer calls - Removed non-existent `requiresVFOSelection` parameter
- Removed obsolete convenience initializer tests (`.ic705`, `.ic7300`, etc.)
- Updated all `power()` method calls to remove `cached` parameter
- Fixed `RigctldTest/main.swift` to properly handle throwing RigController init with do-catch

#### Documentation Corrections
- **Satellite Mode Clarification** (Critical accuracy fix):
  - ❌ **BEFORE:** IC-7100 has satellite mode, IC-9700 does not
  - ✅ **AFTER:** IC-7100 does NOT have satellite mode, IC-9700 DOES have satellite mode
  - Updated in: `TEST_CLEANUP_PLAN.md`, IC-7100 test suite, IC-9700 test suite

### Removed

#### Package.swift Cleanup
- Removed 15+ obsolete debug tool executable targets:
  - Removed `IcomInteractiveTest` target
  - Removed `IC7100VFODebug` target
  - Removed `IC7600ModeDebug` target
  - Removed `IC7600ComprehensiveTest` target (was commented out)
  - Removed `IC7100LiveTest` target
  - Removed `IC7100DiagnosticTest` target
  - Removed `IC7100RawTest` target
  - Removed `IC7100DebugTest` target
  - Removed `IC7100InteractiveTest` target
  - Removed `IC7100ModeDebug` target
  - Removed `IC7100PowerTest` target
  - Removed `IC7100PowerDebug` target
  - Removed `IC7100PTTTest` target
  - Removed `IC7100PTTDebug` target

- Added `exclude: ["Archived"]` to RigControlTests target configuration
- Cleaned up product definitions to only include RigctldTest

#### Archived (Not Deleted - Preserved for Reference)
- Moved `IcomIntegrationTests.swift` to `Archived/LegacyTests/`
- Moved all IC-7100 debug tools to `Archived/DebugTools/IC7100Tests/`
- Moved IC-7100 VFO debug to `Archived/DebugTools/IC7100VFODebug/`
- Moved IC-7600 comprehensive test to `Archived/DebugTools/IC7600ComprehensiveTest/`
- Moved IC-7600 mode debug to `Archived/DebugTools/IC7600ModeDebug/`
- Moved Icom interactive test to `Archived/DebugTools/IcomInteractiveTest/`
- All archived code preserved but excluded from build

### Technical Details

#### Build Status
- ✅ Swift 6.2+ compatible
- ✅ Zero compilation errors
- ✅ Build time: 1.75s
- ✅ 184 tests total
  - 137 active tests (all passing)
  - 47 hardware tests (skip gracefully without connected hardware)
- ✅ All tests following Swift concurrency best practices
- ✅ Clean actor isolation - no data races

#### Test Coverage Summary
| Category | Files | Methods | Status |
|----------|-------|---------|--------|
| Unit Tests | 4 | 47 | ✅ Passing |
| Protocol Tests | 4 | 90+ | ✅ Passing |
| Hardware Tests | 4 | 45 | ✅ Ready (skip without hardware) |
| **Total** | **12** | **180+** | **✅ Production Ready** |

#### Safety Features
- All PTT tests require explicit user confirmation
- Safety warnings displayed before keying transmitter:
  - Dummy load connection reminder
  - Power level recommendations (5-10W)
  - Antenna tuner check reminder
- Radio state preservation:
  - Frequency saved before tests
  - Mode saved before tests
  - Power level saved before tests
  - All settings restored after tests complete
- Conservative test power levels (5-10W default)

### Running Hardware Tests

Each radio's tests require setting an environment variable with the serial port:

```bash
# IC-7600 Tests
export IC7600_SERIAL_PORT="/dev/cu.IC7600"
swift test --filter IC7600HardwareTests

# IC-7100 Tests
export IC7100_SERIAL_PORT="/dev/cu.usbserial-2110"
swift test --filter IC7100HardwareTests

# IC-9700 Tests
export IC9700_SERIAL_PORT="/dev/cu.IC9700"
swift test --filter IC9700HardwareTests

# Elecraft K2 Tests
export K2_SERIAL_PORT="/dev/cu.usbserial-K2"
swift test --filter K2HardwareTests

# Run all hardware tests (with all environment variables set)
swift test --filter HardwareTests

# Run only unit tests
swift test --filter UnitTests

# Run only protocol tests
swift test --filter ProtocolTests
```

### Migration Notes

No breaking changes for existing users. The only API changes are:

1. **RigController init** now throws - wrap in `try`:
   ```swift
   let rig = try RigController(radio: .icomIC7600, connection: .serial(...))
   ```

2. **power() method** no longer takes `cached` parameter - simply remove it:
   ```swift
   let power = try await rig.power()  // cached parameter removed
   ```

Both changes are compile-time safe - your code will not compile until fixed.

---

## [1.2.0] - 2025-12-19

### Added

#### Memory Channel Operations
- **New `MemoryChannel` model** with universal memory channel structure
  - Core properties: channel number, frequency, mode, name
  - Optional manufacturer-specific features: split, CTCSS tones, duplex offset, data mode, filter selection, power level
  - Validation method `validate(for:)` checks configuration against radio capabilities
  - Convenience properties: `isSimplex`, `hasTone`, `description`
- **Memory channel protocol methods** in `CATProtocol`:
  - `setMemoryChannel(_:)` - Store configuration to memory
  - `getMemoryChannel(_:)` - Read channel configuration
  - `getMemoryChannelCount()` - Get total channel count
  - `clearMemoryChannel(_:)` - Erase a channel
- **RigController memory operations**:
  - `setMemoryChannel(_:)` - Store channel with cache invalidation
  - `getMemoryChannel(_:)` - Read channel from radio
  - `memoryChannelCount()` - Get radio's channel capacity
  - `clearMemoryChannel(_:)` - Clear channel with cache invalidation
  - `recallMemoryChannel(_:to:)` - Recall channel to VFO (convenience)
  - `storeCurrentToMemory(_:from:name:)` - Store current VFO to channel (convenience)
- **Icom CI-V memory implementation**:
  - Uses CI-V command 0x1A 0x00 (Advanced Settings - Memory Contents) for read/write
  - Uses CI-V command 0x0B (Memory Clear) for channel erase
  - BCD encoding for channel numbers, frequencies, duplex offsets
  - CTCSS tone encoding/decoding (67.0-254.1 Hz)
  - 10-character space-padded ASCII names
  - Model-specific channel counts (IC-7300: 99, IC-7600: 100, IC-7100/9700: 109)
  - Supports all Icom radio models (25 models)

#### Documentation
- **Comprehensive API reference** for memory channel operations
  - All memory methods with parameters, returns, errors
  - MemoryChannel model structure and usage examples
  - Manufacturer feature support matrix
  - Channel number ranges per radio model
- **Four detailed usage examples** in USAGE_EXAMPLES.md:
  - Basic memory channel management (store, recall, list)
  - Contest memory bank setup (CQ WW with quick band switching)
  - VHF/UHF repeater memory manager (CTCSS tones, duplex offsets)
  - DX memory bank with split operation
- **README update** listing memory channel feature

### Enhanced

#### Architecture
- **Universal memory model** works across all manufacturers (Icom, Yaesu, Kenwood, Elecraft)
- **No code duplication** - single MemoryChannel struct with optional properties
- **Manufacturer flexibility** - optional properties enable radio-specific features
- **Type safety** - full Swift type system with validation

#### Capabilities
- **Repeater programming** - CTCSS tones (67.0-254.1 Hz), duplex offsets, DCS codes
- **Split operation** - Store RX/TX frequencies for DX operation
- **Data mode support** - Filter selection and data mode flags
- **Channel names** - Up to 10 characters (Icom), varies by manufacturer
- **Validation** - Checks frequency range, mode support, tone values

### Technical Details
- **Thread-safe**: All operations actor-isolated
- **BCD encoding**: Efficient binary-coded decimal for Icom protocol
- **Error handling**: Detects empty channels (NAK response)
- **Caching**: Memory reads/writes invalidate appropriate cache entries
- **Extensible**: Easy to add manufacturer-specific features

## [1.0.2] - 2025-11-24

### Added

#### Frequency Validation System
- **New `DetailedFrequencyRange` structure** with mode and transmit capability information
- **Frequency validation methods** in `RigCapabilities`:
  - `isFrequencyValid(_:)` - Check if frequency is within radio capabilities
  - `canTransmit(on:)` - Verify transmit capability for frequency
  - `supportedModes(for:)` - Get modes available at specific frequency
  - `bandName(for:)` - Get amateur band name (e.g., "20m", "40m")
  - `frequencyRange(containing:)` - Retrieve detailed range information
- **ITU Regional Band Support** with three regional band types:
  - `Region2AmateurBand` (Americas - 50-54 MHz 6m, 7.0-7.3 MHz 40m)
  - `Region1AmateurBand` (Europe/Africa/Middle East - 50-52 MHz 6m, 7.0-7.2 MHz 40m)
  - `Region3AmateurBand` (Asia-Pacific - 50-54 MHz 6m, 7.0-7.3 MHz 40m)
  - All regions support 2200m through 23cm bands
  - Common modes per band based on regional band plans
  - Band name lookup by frequency for each region
- **Regional Validation in `RigCapabilities`**:
  - `region` property (defaults to Region 2 - Americas)
  - `isInAmateurBand(_:)` - Check if frequency is in amateur allocation for configured region
  - `amateurBandName(for:)` - Get amateur band name based on radio's region
  - `isValidAmateurFrequency(_:)` - Validates both radio capability and amateur band allocation
- **`RadioCapabilitiesDatabase`** with complete specifications for 24+ radios:
  - Icom: IC-9700, IC-7610, IC-7300, IC-7600, IC-7100, IC-705
  - Yaesu: FTDX-10, FT-991A, FT-710, FT-891, FT-817, FTDX-101D
  - Kenwood: TS-590SG, TS-890S, TS-990S, TM-D710, TS-480SAT, TS-2000
  - Elecraft: K3, K2, K3S, K4, KX2, KX3
  - Each radio includes: transmit/receive ranges, supported modes per range, band names, power specs, dual receiver support, ATU support
- **New `RigError` cases** for frequency validation:
  - `frequencyOutOfRange(_:model:)` - Frequency outside radio capabilities
  - `transmitNotAllowed(_:reason:)` - Transmit not allowed on frequency
  - `modeNotSupported(_:frequency:)` - Mode not supported at frequency
  - Includes recovery suggestions for all errors

#### Testing & Documentation
- **Comprehensive test suite** (`RadioCapabilitiesTests`) with 15+ test cases
- **Amateur band validation tests** for US allocations
- **Radio capability tests** for all supported models
- **Edge case testing** for band boundaries and receive-only ranges
- **Performance benchmarks** for validation operations
- **Updated README** with frequency validation examples and safety features
- **API documentation** for all new public types and methods

### Enhanced

#### Radio Models
- **Updated radio definitions** to use centralized `RadioCapabilitiesDatabase`
- **Eliminated capability duplication** across protocol factories
- **Consistent specifications** for all supported radios
- **Improved maintainability** with single source of truth for radio specs

#### Safety Features
- **Hardware protection** by preventing transmit outside radio capabilities
- **Global compliance** support with ITU regional band validation (Region 1, 2, and 3)
- **Regional frequency allocation** awareness for legal operation worldwide
- **Receive-only range identification** for general coverage receivers
- **Mode validation** per frequency range

### Technical Details
- **Thread-safe**: All validation methods work with Swift 6 concurrency
- **No breaking changes**: Fully backward compatible with v1.0.1
- **Zero performance impact**: Validation is opt-in
- **Comprehensive coverage**: Supports all major amateur bands HF through UHF
- **Conservative validation**: Better to reject valid frequency than allow invalid

## [1.1.0] - 2025-11-19

### Added

#### Signal Strength (S-Meter) Reading
- **New `SignalStrength` model** with S-units (0-9) and over-S9 dB representation
- **S-meter support across all 4 protocols**:
  - Icom CI-V: Command `0x15 0x02` (Read S-meter)
  - Elecraft: Command `SM0;` (Main receiver S-meter)
  - Yaesu CAT: Command `RM5;` (Main S-meter)
  - Kenwood: Command `SM0;` (Main receiver S-meter)
- **`signalStrength()` method** in `RigController` with caching support
- **Signal strength capabilities flag** (`supportsSignalStrength`) in `RadioCapabilities`
- **Helper properties**: `isStrongSignal`, `isWeakSignal`, `decibels` conversion
- **Comparable conformance** for signal strength comparisons

#### Performance Caching Layer
- **New `RadioStateCache` actor** for thread-safe state caching
- **10-20x performance improvement** for repeated queries
- **Configurable cache expiration** (default: 500ms)
- **`cached` parameter** added to `frequency()` and `mode()` methods
- **Automatic cache invalidation** on write operations and disconnect
- **Cache management methods**: `invalidateCache()`, `cacheStatistics()`
- **Cache statistics** for debugging and monitoring

#### RIT/XIT Support
- **New `RITXITState` model** representing RIT/XIT enabled state and frequency offset
- **RIT (Receiver Incremental Tuning) support across all 3 protocols**:
  - Icom CI-V: Command `0x21 0x00/0x01` (RIT offset and enable)
  - Yaesu CAT: Commands `RT1;`/`RT0;`, `RU;`/`RD;` (Kenwood-compatible)
  - Kenwood: Commands `RT1;`/`RT0;`, `RU;`/`RD;`, `RC;` (Native)
- **XIT (Transmitter Incremental Tuning) support** with graceful degradation:
  - Icom CI-V: Command `0x21 0x02/0x03` (XIT offset and enable)
  - Yaesu CAT: Commands `XT1;`/`XT0;` (limited support, many radios RIT-only)
  - Kenwood: Commands `XT1;`/`XT0;` (shares offset with RIT on most models)
- **RigController methods**: `setRIT(_:)`, `getRIT(cached:)`, `setXIT(_:)`, `getXIT(cached:)`
- **Capability flags**: `supportsRIT` and `supportsXIT` in `RigCapabilities`
- **BCD encoding/decoding** for Icom RIT/XIT offsets (±9999 Hz range)
- **Offset validation** with clear error messages for out-of-range values
- **State caching** with 500ms TTL for RIT/XIT queries
- **Radio-specific handling**: NAK detection for unsupported XIT, shared RIT/XIT offsets
- **Comprehensive documentation** with usage examples for CW, contest, and data mode operations

#### Batch Configuration API
- **New `configure()` method** for setting multiple parameters in one call
- **Optional parameters**: frequency, mode, VFO, power
- **Optimal execution order** (frequency → mode → power)
- **Simplified setup** for common scenarios (e.g., "set up for FT8 on 20m")

### Enhanced

#### RigController API
- **Caching support** for `frequency(cached:)` and `mode(cached:)`
- **Cache invalidation** integrated into all setter methods
- **Improved documentation** with caching behavior notes
- **Performance examples** in code documentation

#### Protocol Enhancements
- **Multi-byte command support** in Icom CI-V frame parser
- **New command constants** for S-meter reading in all protocols
- **Default implementation** for `getSignalStrength()` in `CATProtocol`

### Performance

- **Query latency**: <10ms for cached reads (vs ~50-100ms uncached)
- **Cache hit rate**: Near 100% for UI refresh scenarios
- **Serial port load reduction**: 90%+ reduction in repeated queries
- **Responsiveness**: Enables 60fps UI updates for monitoring applications

### Documentation

- **Updated README.md** with v1.1.0 features and examples
- **New batch configuration examples**
- **Performance caching usage guide**
- **S-meter reading examples**
- **Updated protocol command comparison table**

### Backward Compatibility

- ✅ **Zero breaking changes** - all new features are additive
- ✅ **Default parameter values** maintain v1.0.0 behavior
- ✅ **Existing code works unchanged** - caching is opt-in via defaults
- ✅ **RadioCapabilities** updated with default values for new fields

## [1.0.0] - 2025-11-19

### Added

#### Core Library
- Native Swift library for amateur radio transceiver control on macOS
- Modern async/await API for all radio operations
- Actor-based concurrency for thread-safe operations
- Protocol-oriented design with `CATProtocol` abstraction
- Type-safe enums for VFO, Mode, and error handling
- Automatic memory management with ARC

#### Radio Support (24 Radios)

**Icom CI-V Protocol (6 Radios)**
- IC-9700 (VHF/UHF/1.2GHz, 115200 baud, 100W)
- IC-7610 (HF/6m SDR, 115200 baud, 100W, Dual RX)
- IC-7300 (HF/6m, 115200 baud, 100W)
- IC-7600 (HF/6m, 19200 baud, 100W, Dual RX)
- IC-7100 (HF/VHF/UHF, 19200 baud, 100W)
- IC-705 (Portable, 19200 baud, 10W)

**Elecraft Protocol (6 Radios)**
- K4 (HF/6m SDR, 38400 baud, 100W, Dual RX)
- K3S (HF/6m Enhanced, 38400 baud, 100W, Dual RX)
- K3 (HF/6m, 38400 baud, 100W, Dual RX)
- KX3 (Portable HF/6m, 38400 baud, 15W)
- KX2 (Portable HF, 38400 baud, 12W)
- K2 (HF, 4800 baud, 15W)

**Yaesu CAT Protocol (6 Radios)**
- FTDX-101D (HF/6m, 38400 baud, 100W, Dual RX)
- FTDX-10 (HF/6m, 38400 baud, 100W)
- FT-991A (HF/VHF/UHF, 38400 baud, 100W)
- FT-710 (HF/6m, 38400 baud, 100W)
- FT-891 (HF/6m, 38400 baud, 100W)
- FT-817 (Portable QRP, 38400 baud, 5W)

**Kenwood Protocol (6 Radios)**
- TS-990S (Flagship HF/6m, 115200 baud, 200W, Dual RX)
- TS-890S (HF/6m, 115200 baud, 100W, Dual RX)
- TS-590SG (HF/6m, 115200 baud, 100W)
- TS-2000 (HF/VHF/UHF, 57600 baud, 100W)
- TS-480SAT (HF/6m, 57600 baud, 100W)
- TM-D710 (VHF/UHF, 57600 baud, 50W, Dual RX)

#### Protocol Implementations

**IcomCIVProtocol (Binary Protocol)**
- CI-V binary protocol with BCD frequency encoding
- Automatic ACK/NAK response handling
- Address-based radio communication
- Supports all Icom-specific features
- 42+ unit tests

**ElecraftProtocol (Text-Based)**
- ASCII text-based command protocol
- Echo-based acknowledgment
- Auto-info disable on connect
- 15 unit tests

**YaesuCATProtocol (Text-Based)**
- Kenwood-compatible CAT commands
- TX1/TX0 PTT control (Yaesu-specific)
- 9 mode mappings including DATA modes
- 15 unit tests

**KenwoodProtocol (Text-Based)**
- Native Kenwood command set
- FR0/FR1 VFO selection (Kenwood-specific)
- Supports up to 200W power control
- 17 unit tests including dual receiver tests

#### Operations

- Frequency control (set/get) for VFO A/B and Main/Sub
- Mode control (LSB, USB, CW, CW-R, FM, FM-N, AM, RTTY, DATA-LSB, DATA-USB)
- PTT (Push-To-Talk) control with enable/disable and status query
- VFO selection (A/B, Main/Sub with automatic mapping)
- Split operation (enable/disable/query)
- Power control in watts with automatic percentage conversion
- Radio capabilities query

#### Transport Layer

**IOKitSerialPort**
- Direct IOKit integration for serial communication
- No external dependencies
- Terminator-based frame reading
- Proper termios configuration for raw mode
- Automatic buffer flushing
- Timeout support

#### XPC Helper (Mac App Store Compatibility)

**XPCProtocol**
- Objective-C protocol for cross-process communication
- Complete operation coverage

**XPCClient**
- Actor-based client with async/await interface
- Singleton pattern for app-wide access
- Automatic reconnection support
- Type-safe Swift API wrapping XPC callbacks

**XPCServer**
- Bridges XPC calls to RigControl library
- String-based radio model lookup for all 24 radios
- Error translation to XPC-compatible types

**RigControlHelper**
- Standalone XPC service executable
- Mach service: com.swiftrigcontrol.helper
- SMJobBless compatible

#### Testing

**Unit Tests (89+ tests)**
- BCD encoding/decoding tests
- CI-V frame construction tests
- Protocol command generation tests
- Mock transport for hardware-free testing
- Error handling validation
- All protocol implementations tested

**Integration Tests (10 tests)**
- Real hardware testing support
- Auto-detection of radio model from port name
- Frequency control validation
- Mode switching verification
- PTT operation testing
- Split operation validation
- VFO control testing

#### Documentation (3,300+ lines)

**README.md**
- Quick start guide
- Installation instructions
- Supported radios list
- Architecture overview
- Quick reference tables (radio specs, protocol comparison, modes)
- Common use cases

**USAGE_EXAMPLES.md (615 lines)**
- Basic operations examples
- Digital mode applications (SSTV, FT8/FT4, PSK31)
- Split operation examples
- Power control patterns
- Multi-VFO operations
- Error handling patterns
- Mac App Store/XPC usage
- SwiftUI integration examples
- Logging and monitoring patterns

**TROUBLESHOOTING.md (580 lines)**
- Connection issue solutions
- Command failure diagnosis
- Serial port problem resolution
- XPC helper troubleshooting
- Radio-specific issues
- Performance optimization
- Build and integration issues
- Complete diagnostic checklist

**SERIAL_PORT_GUIDE.md (645 lines)**
- Finding serial ports on macOS
- Radio-specific configuration for all 24 radios
- USB driver installation guides
- Testing serial communication
- Advanced configuration
- Quick reference for all manufacturers

**HAMLIB_MIGRATION.md (570 lines)**
- Complete migration guide from Hamlib C library
- Architecture comparison
- Side-by-side code examples
- Error handling conversion
- Feature comparison matrix
- Complete migration example
- Common gotchas and solutions

**XPC_HELPER_GUIDE.md (580 lines)**
- SMJobBless setup and installation
- XPC client/server implementation
- Mac App Store sandboxing solutions
- Complete SwiftUI example application
- Troubleshooting XPC issues

**Week Completion Documents**
- WEEK1_COMPLETION.md - Foundation and Icom
- WEEK2_AND_3_COMPLETION.md - Elecraft and split operation
- WEEK4_AND_5_COMPLETION.md - XPC helper
- WEEK6_AND_7_COMPLETION.md - Yaesu and Kenwood
- RELEASE_NOTES_v1.0.0.md - v1.0.0 release details

#### Utilities

**BCDEncoding**
- Little-endian BCD encoding for Icom frequency representation
- 5-byte frequency encoding/decoding
- Error handling for invalid BCD values

**RadioDefinition**
- Type-safe radio model registry
- Protocol factory pattern
- Capabilities metadata
- Manufacturer enum

**RigCapabilities**
- Feature flags (VFO B, split, power control, etc.)
- Supported modes list
- Frequency range
- Maximum power
- Dual receiver indication
- ATU (Antenna Tuner) indication

**RigError**
- Typed error enum for all failure cases
- notConnected, timeout, commandFailed
- unsupportedOperation, invalidParameter
- invalidResponse

### Development Process

#### Week 1 - Foundation and Icom CI-V
- Project structure and module organization
- Core protocol definitions
- IOKit serial port implementation
- Type-safe models
- Icom CI-V protocol implementation
- BCD encoding utilities
- 6 Icom radio definitions
- RigController API
- 42+ unit tests

#### Week 2 & 3 - Split Operation and Elecraft
- Split operation support across all protocols
- Integration tests for real hardware
- ElecraftProtocol implementation
- 6 Elecraft radio definitions
- 15 Elecraft unit tests

#### Week 4 & 5 - XPC Helper
- XPC protocol definition
- XPCClient with async/await interface
- XPCServer bridging to RigControl
- RigControlHelper executable
- XPC helper documentation

#### Week 6 & 7 - Yaesu and Kenwood
- YaesuCATProtocol implementation
- 6 Yaesu radio definitions
- 15 Yaesu unit tests
- KenwoodProtocol implementation
- 6 Kenwood radio definitions
- 17 Kenwood unit tests
- XPC server support for all new radios

#### Week 8 - Documentation Refinement
- USAGE_EXAMPLES.md (615 lines)
- TROUBLESHOOTING.md (580 lines)
- SERIAL_PORT_GUIDE.md (645 lines)
- HAMLIB_MIGRATION.md (570 lines)
- README.md quick reference tables

#### Week 9 - v1.0.0 Release
- Release notes
- CHANGELOG.md
- CONTRIBUTING.md
- Final testing and verification
- Version tagging
- GitHub release

### Technical Details

**Requirements**
- macOS 13.0 or later
- Swift 5.9 or later
- Xcode 15.0 or later (for development)

**Architecture**
- Protocol-oriented design
- Actor-based concurrency
- Async/await throughout
- No external dependencies
- Direct IOKit integration

**Performance**
- Command latency: 10-80ms (varies by radio/operation)
- Memory footprint: 2-3 MB typical
- Zero memory leaks (ARC-managed)
- Thread-safe by design

**Code Metrics**
- Core library: ~3,500 lines
- Protocol implementations: ~2,800 lines
- XPC helper: ~800 lines
- Test suite: ~2,200 lines
- Documentation: ~3,300 lines
- Total: ~12,600 lines

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 1.3.0 | 2026-04-28 | Level/DSP controls, 11 new radios, Ten-Tec protocol, rigctld audit |
| 1.2.0 | 2025-12-19 | Memory channel operations |
| 1.1.0 | 2025-11-19 | Signal strength, RIT/XIT, caching |
| 1.0.4 | 2026-01-14 | K2 fixes, LGPL license, hardware tests |
| 1.0.2 | 2025-11-24 | Frequency validation, ITU regions |
| 1.0.0 | 2025-11-19 | Initial production release |

---

For detailed information about the v1.0.0 release, see [RELEASE_NOTES_v1.0.0.md](RELEASE_NOTES_v1.0.0.md).
