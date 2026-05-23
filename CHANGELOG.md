# Changelog

All notable changes to SwiftRigControl will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Version-numbering note (Phase 0 reconciliation, 2026-05-22):**
> The actual released git tags are `v1.0.0`, `v1.0.1`, `v1.0.2`, `v1.0.3`,
> `v1.0.4`, and `v1.0.6` (1.0.5 was skipped). The `[1.1.0]`, `[1.2.0]`,
> and `[1.3.0]` headings that appear below describe **real shipped work
> that was bundled into the `v1.0.6` release tag on 2026-04-30**, not
> separately released versions. They are preserved here as historical
> feature batches. Going forward, version numbers in this file match
> the git tag they ship under. The next release will be `v1.0.7` (patch)
> or `v1.1.0` (minor) — see ROADMAP.md.

## [Unreleased]

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

### Added
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
