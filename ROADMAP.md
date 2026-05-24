# SwiftRigControl — Roadmap

**Current version:** v1.0.6 (released 2026-04-30, per git tag)
**Swift tools:** 6.2, language mode `.v6` (strict concurrency)
**Minimum platform:** macOS 14
**License:** LGPL v3.0

> Earlier versions of `CHANGELOG.md` show `[1.1.0]`, `[1.2.0]`, and
> `[1.3.0]` headings, but no such tags exist in git. That work all
> shipped under the `v1.0.6` tag. The version-numbering note at the
> top of CHANGELOG.md explains the reconciliation. The next release
> will be `v1.0.7` (patch) or `v1.1.0` (minor) depending on the scope
> of work accumulated in the `[Unreleased]` section.

> This roadmap is a living document. Per `CLAUDE.md`, it is updated
> after every commit or coherent batch of work. If something here
> contradicts the code, the code wins — fix the roadmap.

---

## North star

Meet or exceed the practical capabilities of Hamlib / `rigctld` for
the radios SwiftRigControl supports, with a modern Swift 6
actor-based API that feels native to macOS developers building
amateur-radio applications.

Hamlib is the reference implementation. We are not trying to match
its 350+ radio count; we are trying to match its **depth** on the
radios we actually verify, while presenting a much better-typed,
safer, and more ergonomic API.

---

## Current state — honest assessment

### What exists and works

- Actor-based public facade (`RigController`) over the `CATProtocol`
  abstraction.
- Five vendor protocols implemented: Icom CI-V, Elecraft (text),
  Yaesu CAT, Kenwood (text), Ten-Tec (Orion + Legacy), plus
  CI-V-compatible Xiegu.
- ~80 radio definitions in `RadioCapabilitiesDatabase` (most are
  *definition-only*, see verification status below).
- Per-feature `RigController` extensions (Frequency, Mode, PTT,
  VFO, Power, Split, RIT/XIT, DSP, LevelControls, Memory,
  SignalStrength, Configuration, CacheManagement, Connection).
- `RadioStateCache` actor with TTL for query coalescing.
- `rigctld`-compatible TCP server (`Network/`) so existing tools
  (WSJT-X, fldigi, JS8Call) can drive a SwiftRigControl backend.
- XPC helper (`RigControlXPC` + `RigControlHelper`) for Mac App
  Store / sandboxed apps.
- 192 tests passing on Swift Testing framework (unit + protocol
  via `MockTransport` + hardware suites gated by env vars).
- Build is clean: zero warnings under Swift 6 strict concurrency.

### Hardware-verified radios

Only these are exercised against real hardware. All other
definitions are **paper-only** until proven otherwise.

| Radio          | Verifier target                                                   | Notes |
| -------------- | ----------------------------------------------------------------- | ----- |
| Icom IC-7100   | `Tools/SwiftRigControlTools/HardwareValidation/IC7100Validator`   | HF/VHF/UHF, 100W |
| Icom IC-7600   | `Tools/SwiftRigControlTools/HardwareValidation/IC7600Validator`   | HF/6m dual receiver |
| Icom IC-9700   | `Tools/SwiftRigControlTools/HardwareValidation/IC9700Validator`   | VHF/UHF/1.2GHz |
| Elecraft K2    | `Tools/SwiftRigControlTools/HardwareValidation/K2Validator`       | HF QRP |

### Gaps measured against the north star

1. **No continuous integration.** `.github/workflows/` does not
   exist. There is no automated proof that `main` builds or tests
   pass on any commit other than locally.
2. **Executable target sprawl.** `Package.swift` declares 16
   debug/validator executables. Every library consumer compiles
   them transitively. This is the single biggest "modernization"
   miss.
3. **No simulator transport in the shipped library.**
   `ConnectionType.mock` exists but throws at runtime;
   `MockTransport` is buried in `Tests/`. App developers cannot
   build or demo against the library without real hardware.
4. **No reactive state observer.** Apps must poll. This is the
   single biggest API-design gap vs. a "modern" library —
   SwiftUI apps want `AsyncStream`, not a polling loop.
5. **No DocC catalog.** Public API discoverability depends on
   the README and one large API_REFERENCE markdown file.
6. **Deprecated APIs still present.** The legacy
   `IcomCIVProtocol.init(transport:civAddress:capabilities:)`
   carries a `@available(*, deprecated)` marker. Six static
   `RadioDefinition` properties are also marked for removal.
7. **Verification overclaim risk.** The README spec tables list
   many radios with no qualifier; readers may infer they are
   tested. They are not.
8. **Version drift (Phase 0 — reconciled 2026-05-22).** Latest git
   tag was `v1.0.6`; CHANGELOG headings advertised `[1.3.0]`. The
   work *was* released — under `v1.0.6` — but with stale version
   labels in CHANGELOG. A note at the top of CHANGELOG.md now makes
   this explicit. Going forward, CHANGELOG headings must match the
   git tag they ship under.
9. **Hamlib parity holes on verified radios.** No TX meters
   (PWR/SWR/ALC/COMP read), no CW keyer config, no scanning
   commands, no antenna selector, no spectrum scope.

---

## Phase 0 — Honesty pass

**Goal:** make every claim in the repo true before adding features.
This is blocking for all subsequent phases; it costs about a day.

- [x] **Reconcile version.** Confirmed actual current version is
      `v1.0.6` (git tag, released 2026-04-30). CHANGELOG and ROADMAP
      headers corrected; CHANGELOG carries an explanatory note about
      the legacy `[1.1.0]`/`[1.2.0]`/`[1.3.0]` headings. No retag
      needed; no source-code version constants existed.
- [x] **Update CHANGELOG `[Unreleased]` section.** Single uncommitted
      change (IC-7600 Main/Sub fix from commit `3931887`) now sits
      under `[Unreleased]`.
- [x] **Architecture diagram refresh.** Roadmap's current-state
      section now lists `TenTec/`, `Xiegu/`, `THD72Protocol`,
      `Network/`, `Cache/`.
- [ ] **Audit README spec tables.** Each radio row gains a
      "Verified" column with one of: *Hardware*, *Definition*.
- [ ] **Update README's "Hardware-Verified" section** to match the
      four-radio table above (IC-7100, IC-7600, IC-9700, K2).
- [x] **Add a `verificationStatus` field to `RadioDefinition`.**
      New `VerificationStatus` enum (`.hardware` / `.definition`).
      Defaults to `.definition`; IC-7100, IC-7600, IC-9700, K2
      promoted to `.hardware`. Surfaced via
      `RigController.verificationStatus`. Guarded by 8-test
      `VerificationStatusTests` suite.
- [ ] **Sweep inline `(vX.Y.Z)` tags** in `Documentation/API_REFERENCE.md`
      and `USAGE_EXAMPLES.md`. Leave them as historical breadcrumbs
      but add a note at the top of each file pointing to the
      CHANGELOG reconciliation note.
- [ ] **Commit Phase 0 work** with `docs:` prefix. No source code
      change in this phase.

**Exit criteria:** any new reader can trust the README's
verification claims, and the version number in every doc matches
the latest git tag.

---

## Phase 1 — Foundations

**Goal:** establish the engineering hygiene a library deserves.
None of these are user-visible features, but every subsequent
phase depends on them.

### 1.1 Continuous integration

- [x] Add `.github/workflows/ci.yml` running on push and PR:
  - [x] `swift build` on macOS runner (`macos-15`, latest-stable Xcode).
  - [x] `swift test --parallel` (hardware suites auto-skip via
        `.enabled(if:)` env-var gates).
  - [x] Library built with `-Xswiftc -warnings-as-errors`; other
        targets built without to allow transient warnings in
        debug-tool executables.
  - [x] Cache `.build` between runs keyed on `Package.resolved` +
        `Package.swift`.
- [x] Add status badge to README.
- [x] Document local-equivalent commands in CONTRIBUTING.md.

### 1.2 Executable target evacuation

Decision: move debug-tool executables out of the consumed package.

- [x] Inventory complete: 16 executables grouped as Hardware
      Validators (5), Interactive Validators (8, stdin-driven),
      and Elecraft Debug Tools (3). All retained — none archived.
- [x] Created `Tools/SwiftRigControlTools/Package.swift` as a
      separate SwiftPM project depending on the parent via
      `.package(path: "../..")`.
- [x] Moved all 16 executables + `ValidationHelpers` shared library
      under `Tools/SwiftRigControlTools/` with three subfolders
      (`HardwareValidation/`, `InteractiveValidators/`,
      `Debugging/`).
- [x] Removed 16 `.executable` products and `ValidationHelpers`
      target from the main `Package.swift`. Kept `RigControlHelper`
      (real shipping component).
- [x] Updated README, CLAUDE.md, ROADMAP, and the moved
      `HardwareValidation/README.md` to show new invocation
      (`cd Tools/SwiftRigControlTools && swift run <Tool>`).

**Acceptance met:** main package now declares 3 products
(`RigControl`, `RigControlXPC`, `RigControlHelper`). Downstream
consumers no longer transitively compile the 16 debug executables.
`swift build --target RigControl` completes in ~0.2s on a warm
cache vs. ~5s before.

### 1.3 Ship a real mock transport — and an in-memory dummy radio

Hamlib precedent: Model 1 ("Dummy") is a generic in-memory rig that
exercises the full `RIG` API without any serial protocol. Source:
`rigs/dummy/dummy.c`. App developers use it for development and CI.
SwiftRigControl ships the equivalent.

- [x] **Public `MockSerialTransport`** under
      `Sources/RigControl/Transport/MockSerialTransport.swift`.
      Scriptable byte-level transport for protocol-level testing.
      Roughly the existing test fixture's behavior, promoted to a
      stable public actor with full doc-comments.
- [x] **Public `DummyCATProtocol`** under
      `Sources/RigControl/Protocols/Dummy/DummyCATProtocol.swift`.
      Direct `CATProtocol` conformer holding frequency, mode, PTT,
      VFO, power, split, RIT/XIT, DSP, level controls, memory state
      as actor-isolated fields. The Swift analogue of Hamlib Model 1.
- [x] **`RadioDefinition.dummy(name:capabilities:)`** factory and
      a new `.dummy` Manufacturer case so dummy rigs are honest
      about what they are.
- [x] **`ConnectionType.mock` wired** to `MockSerialTransport`
      (instead of throwing). When paired with `.dummy()` the
      transport is ignored; when paired with a real radio it lets
      you script byte-level responses for protocol testing.
- [x] **`Examples/BasicUsage/DummyRadioExample.swift`** reference
      file plus a SwiftUI preview-pattern snippet in its trailing
      comments.
- [x] **Tests:** 22 new tests across `MockSerialTransportTests`
      (10) and `DummyCATProtocolTests` (12). Full suite now
      222/222 passing.

**Acceptance met:** a SwiftUI `#Preview` can construct a working
`RigController` via `RadioDefinition.dummy()` and `ConnectionType.mock`
with no serial port, no XPC helper, and no hardware.

### 1.4 Remove deprecated API surface

Source-breaking *in the strict sense*. Project policy: deprecation
removals stay in the **v1.0.x** line. Each item had carried a formal
`@available(*, deprecated)` marker for at least one release, so
callers who heeded the warnings are already migrated. Reserve
major-version bumps for genuinely scope-changing API rewrites
(e.g. introducing capability-trait protocols in Phase 5), not
for cleanup of long-deprecated surface.

- [x] **Deleted `IcomCIVProtocol.init(transport:civAddress:capabilities:)`.**
      Callers must now construct an explicit command set
      (`StandardIcomCommandSet`, `IC7100CommandSet`, etc.) and pass
      it via the modern init.
- [x] **Deleted the six deprecated `RadioDefinition` static
      properties** (`.icomIC9700`, `.icomIC7300`, `.icomIC7600`,
      `.icomIC7100`, `.icomIC7610`, `.icomIC705`). The function-style
      factory methods (`.icomIC9700()` with an optional
      `civAddress:` parameter) remain.
- [x] **Deleted the `init(transport:)` requirement from `CATProtocol`**
      and the satisfying-only single-arg inits on every conformer
      (Icom's `preconditionFailure`-throwing variant; the
      `.full`-defaulting variants on Yaesu, Kenwood, Elecraft, THD72,
      Ten-Tec Orion / Legacy). Construction is now exclusively the
      job of concrete-type inits and `RadioDefinition.protocolFactory`.
- [x] CHANGELOG `[Unreleased]` has migration snippets for each
      deletion. The CHANGELOG explicitly notes that the next
      release stays in the v1.0.x line.

**Phase 1 exit criteria:** CI green, library compile time
substantially reduced for consumers, mock-driven SwiftUI demo
works, deprecated APIs gone.

---

## Phase 2 — Reactive state

**Goal:** close the largest API-design gap vs. Hamlib. Hamlib
forces apps to poll; we should let SwiftUI apps observe.

### 2.1 Event stream

The proposed `RigStateObserver` callback protocol from the old
roadmap is workable, but `AsyncStream` is more idiomatic for
Swift 6 / SwiftUI. Recommendation: ship the stream first; defer
the callback protocol until a user asks for it.

- [x] **`RigStateEvent` enum** with 16 cases covering frequency,
      mode, PTT, VFO selection, power, split, RIT/XIT, signal
      strength, AGC, NB, NR, IF filter, level controls (unified
      via a `LevelKind` discriminator), power state, and
      `ConnectionState`. New `ConnectionState` enum with
      `.disconnected`, `.connecting`, `.connected`, `.degraded`,
      `.reconnecting` cases — the latter two populated by 2.3.
- [x] **`RigController.events: AsyncStream<RigStateEvent>`**.
      Each access returns a fresh stream; the controller fans
      every emission out to all active subscribers. Per-subscriber
      `.bufferingNewest(64)` policy bounds memory under slow
      consumers. Subscribers auto-deregister on cancellation via
      `onTermination`. New subscribers see a replay of the current
      `ConnectionState` so SwiftUI views that subscribe lazily
      still get the right initial state.
- [x] **All `set*` paths on `RigController` emit** after the
      underlying protocol acknowledges (and after cache
      invalidation). Setters that fail do NOT emit. Memory channel
      operations deliberately omitted — they're app-managed state,
      not radio-state-change events.
- [x] **`connect()` / `disconnect()` emit
      `.connectionStateChanged`**, including a `.connecting`
      transition that flips to `.disconnected` if the underlying
      protocol's `connect()` throws.
- [x] **Deferred:** `RigStateObserver` callback protocol. The
      `AsyncStream` API is the right shape for Swift 6 / SwiftUI;
      a callback bridge adds complexity for users who can't use
      async, and no one has asked for it yet. Reopen if requested.
- [x] **Tests:** 12 new tests in `RigControllerEventsTests`
      covering connection lifecycle, state-change emission,
      ordering, multi-subscriber fan-out, cancellation cleanup,
      no-dedupe policy, and failed-set non-emission.

### 2.2 Polled state broadcaster

Some state (signal strength, frequency, mode, PTT from front-panel
mic) the radio does not push. Provide an opt-in poller that fans
sampled values through the same `events` stream as setter-driven
changes — UI doesn't care whether a change came from a `set` or a
poll.

- [x] **`RigController.startPolling(_:)` / `stopPolling()` /
      `isPolling`**. Each enabled field gets its own `Task` stored
      on the actor keyed by name. `disconnect()` stops polling
      automatically. Calling `start` while already polling replaces
      the previous batch.
- [x] **`PollingConfiguration` struct** with per-field intervals
      (signalStrength, frequency, mode, ptt). Defaults are tuned
      for a typical UI: 200 ms S-meter, 1 s frequency, 2 s mode,
      100 ms PTT. Convenience helpers:
      `PollingConfiguration.uniform(every:)` and
      `PollingConfiguration.disabled`.
- [x] **Emission policy:**
      `signalStrength` emits every poll (continuous monitoring data);
      `frequency`, `mode`, `ptt` emit only when the value differs
      from the previous sample.
- [x] **Per-cycle error handling:** transient failures are
      swallowed so a single timeout doesn't kill the poller.
      Persistent failure escalates to `.connectionStateChanged(.degraded(...))`
      via Phase 2.3's connection-health monitor.
- [x] **Tests:** 10 new tests in `RigControllerPollingTests`
      using fast 50–100 ms intervals against the dummy radio.
      Covers lifecycle, configuration shapes, signal-strength
      always-emit, frequency/PTT change-only emission, and the
      "front-panel mic PTT" scenario where the protocol's PTT
      flips without going through `RigController.setPTT`.

### 2.3 Connection health

- [x] `ConnectionState` enum: `.disconnected`, `.connecting`,
      `.connected`, `.degraded(reason)`, `.reconnecting(attempt)`
      — shipped in Phase 2.1 with the event stream. Phase 2.3
      populates `.degraded` and `.reconnecting`.
- [x] **Heartbeat:** `getFrequency` probe at the configured
      `heartbeatInterval` (default 5 s). On `degradeAfter`
      consecutive failures (default 3), transition to
      `.degraded(reason:)`. A subsequent successful probe
      transitions back to `.connected`.
- [x] **Optional auto-reconnect:** `RetryPolicy` struct with
      `maxAttempts` (nil = forever), `initialDelay`, `maxDelay`,
      and `multiplier`. Delay between attempts is
      `min(initialDelay × multiplier^(attempt-1), maxDelay)`.
      When configured, the monitor tears down on `.degraded` and
      drives `.reconnecting(attempt: N)` transitions until either
      success (`.connected`) or exhaustion (`.disconnected`).
- [x] **All state transitions emit `.connectionStateChanged`**
      and flow through the same `events` stream as setter and
      polling events.
- [x] **`startHealthMonitor(_:)` / `stopHealthMonitor()` /
      `isMonitoringHealth`.** `disconnect()` stops the monitor
      automatically. Restart-replaces-monitor semantics.
- [x] **Test helper on `DummyCATProtocol`:**
      `simulateFailure(_:)` flips the dummy into "always-throw"
      mode and back. Lets tests deterministically exercise the
      failure path without real I/O.
- [x] **Tests:** 10 new tests in `RigControllerHealthTests`
      covering lifecycle, degradation, recovery, auto-reconnect
      success and exhaustion, and `RetryPolicy` backoff math.

**Phase 2 exit criteria met:** a SwiftUI app can write
```swift
for await event in rig.events { ... }
```
and render real-time radio state with no polling loop in user
code. The dummy radio + dummy event-stream pattern means apps
can develop, preview, and integration-test against the full
event surface (frequency, mode, PTT, signal strength, AGC, NB,
NR, IF filter, levels, RIT/XIT, power state, connection
lifecycle including degraded and reconnecting) with no real
hardware. Phase 2 is complete.

---

## Phase 3 — Documentation as a product

**Goal:** make the library discoverable without grep.

### 3.1 DocC catalog

- [x] Created `Sources/RigControl/RigControl.docc/` with curated
      organization:
      - `RigControl.md` — landing page with `Topics` grouping
        every top-level public symbol (controller, definitions,
        events, transports, models, protocols, network, errors).
      - `Articles/GettingStartedWithDummy.md` — develop without
        hardware (the SwiftUI preview pattern, recommended view
        model, capability-override examples).
      - `Articles/ReactiveState.md` — the `RigController.events`
        story (push + poll + health, emission policy, buffering,
        subscriber lifecycle, a complete `@Observable` example).
      - `Articles/VerificationStatus.md` — what `.hardware` vs
        `.definition` means, current status table, promotion
        criteria.
      - `Articles/AddingRadios.md` — condensed contributor guide
        (decision tree, recipe, Hamlib cross-check rule).
      - `Articles/HamlibMigration.md` — idiom-by-idiom mapping
        for C-Hamlib users.
- [x] Symbol pages for every top-level public type are linked
      from the landing page's `Topics` section so the docs site
      surfaces them at the root.
- [ ] DocC plugin + `swift package generate-documentation`
      command — deferred to 3.3 (alongside the GitHub Pages
      workflow that uses it).

### 3.2 Symbol-level DocC coverage

- [x] **Audit script** at `Scripts/check-public-docs.py` walks
      every Swift file in `Sources/RigControl/`, flags any public
      declaration that lacks a triple-slash doc comment, and
      excludes declarations whose identifier matches a
      `CATProtocol` / `SerialTransport` / `CIVCommandSet`
      requirement (DocC inherits documentation from protocol
      requirements automatically). Exits non-zero when issues
      remain — ready to wire into CI in the next sub-phase.
- [x] **Sweep complete.** From a baseline of 225 nominally
      undocumented declarations, the inheritance-aware audit
      identified 25 real gaps; all are now fixed. The script
      now exits clean on `main`.
- [x] **Doc comments added** to: `SerialConfiguration` `Parity`
      enum + init, `IOKitSerialPort` non-macOS stub + init,
      `RadioDefinition.Manufacturer`, `RigctldCommandParser` init,
      `SignalStrength` `<`, three `RigCapabilities` inits,
      `icomIC905`, every public field on
      `RigController.PollingConfiguration` and
      `HealthMonitorConfiguration`, `RetryPolicy` init,
      `TenTecOrionProtocol` init, `TenTecLegacyProtocol` init,
      `THD72Protocol` init, `IC9700CommandSet` init.
- [x] **CI lint** wired into `.github/workflows/ci.yml` as the
      first gate: a single `python3 Scripts/check-public-docs.py`
      step runs before the build/test steps, so doc regressions
      surface fast. The DocC build step that runs later (with
      `--warnings-as-errors`) catches a separate class of issue
      — broken symbol cross-references and parameter-name
      mismatches — that the lint can't see.

### 3.3 DocC tooling and hosting

- [x] **SwiftDocCPlugin dependency** added to `Package.swift`.
      Build-time-only — never linked into any product. CLAUDE.md's
      "no external dependencies" rule was updated to make the
      build-time-plugin exception explicit.
- [x] **DocC build step in CI** (`swift package generate-documentation
      --warnings-as-errors`) catches broken symbol references,
      missing parameter docs, and similar issues that the Swift
      compiler ignores.
- [x] **CI lint** (`Scripts/check-public-docs.py`) wired as a
      gating step.
- [x] **Power-API rename.** Discovered while clearing DocC warnings:
      the `setPower(_ watts:)` parameter name was misleading because
      Icom radios accept a 0–255 percentage scale (`PowerUnits.percentage`),
      not watts. Renamed the parameter to `level` across `CATProtocol`,
      every conformer, and `RigController`. Added a deprecated
      `setPower(watts:)` shim so source compatibility is preserved
      for callers that used the explicit label.
- [x] **GitHub Pages deploy** wired into `ci.yml`. The existing
      DocC build step now uses `--transform-for-static-hosting
      --hosting-base-path SwiftRigControl` so the output is
      ready-to-host. On push to `main`, three additional steps
      (`actions/configure-pages`, `actions/upload-pages-artifact`,
      `actions/deploy-pages`) publish to GitHub Pages under the
      `github-pages` environment. PR builds and tag builds still
      compile docs (with warnings-as-errors) but don't deploy.
- [x] **README links to hosted docs** — a Docs badge under the
      title and a paragraph at the top of the Documentation
      section both point to
      `https://jjones9527.github.io/SwiftRigControl/documentation/rigcontrol/`.

**Phase 3 exit criteria met:** opening Xcode's Quick Help on any
public symbol returns a useful answer (Phase 3.1 + 3.2), CI fails
on undocumented additions and broken DocC references (Phase 3.3a),
and the hosted DocC site is the canonical reference, regenerated
on every push to main (Phase 3.3b). Phase 3 is complete.

**Phase 3 exit criteria:** opening Xcode Quick Help on any
public symbol returns a useful answer; the GitHub Pages site
is the first hit when someone searches "SwiftRigControl".

---

## Phase 4 — Hamlib parity on verified radios

**Goal:** every Hamlib command that exists for IC-7100, IC-7600,
IC-9700, and K2 should have a SwiftRigControl equivalent.

Each item is gated on a Hamlib cross-check (read `rigs/<vendor>/
<model>.c`) and a hardware-validator run.

### 4.1 TX-side metering

- [x] **`MeterReading` model** — single value type carrying the
      raw byte, a normalised 0..1+ value for UI bars, and a
      typed physical-unit accessor (watts / X:1 ratio / volts /
      amps / dB) selected by ``MeterReading/Kind``. Calibration
      curves transcribed from Hamlib's `icom_default_*_cal`
      tables in `rigs/icom/icom.c` so behavior matches Hamlib
      exactly on Icom radios. `MeterReading.decode(kind:raw:)`
      is the standard constructor; piecewise-linear interpolation
      handles the non-breakpoint values.
- [x] **`CATProtocol` methods**: `getRFPowerOut()`, `getSWR()`,
      `getALC()`, `getComp()`, `getVoltage()`, `getCurrent()`.
      Each defaults to `throw unsupported`; conformers opt in.
- [x] **`RigCapabilities` flags**: `supportsRFPowerMeter`,
      `supportsSWRMeter`, `supportsALCMeter`, `supportsCompMeter`,
      `supportsVoltageMeter`, `supportsCurrentMeter`. All default
      `false`; the three Icom flagships (IC-7100, IC-7600,
      IC-9700) opt into all six per the Hamlib level lists.
- [x] **`IcomCIVProtocol` implementation** wraps the existing raw
      0x15-subcommand readers (`getRFPowerMeter()`, `getSWRMeter()`,
      etc.) into typed `MeterReading` values, guarded by the
      capability flags.
- [x] **`DummyCATProtocol`** holds simulated raw values keyed by
      ``MeterReading/Kind`` with sensible idle defaults (RF power 0,
      SWR 1:1, voltage ~13.8 V, current ~1 A) and a
      `simulateMeter(_:raw:)` test helper. Returns readings
      unconditionally — the dummy is a simulator, not a real radio.
- [x] **`RigController` facade** with six matching accessors
      (`rfPowerOut()`, `swr()`, `alc()`, `comp()`, `voltage()`,
      `current()`) under `RigController+TXMeters.swift`.
- [x] **Tests**: 16 new in `MeterReadingTests` covering each
      calibration curve at every Hamlib breakpoint, interpolation
      between breakpoints, normalised value, typed-accessor nil
      semantics for wrong kinds, the dummy-served path, idle
      defaults, capability-gated unsupported error, and
      verified-radio capability promotion.
- [ ] **`getTemp()` deferred.** Hamlib has `RIG_LEVEL_TEMP_METER`
      but Icom CI-V's 0x15 0x17 (TX final temp) is documented on
      modern radios only and Hamlib's per-radio rfpower-cal tables
      don't include it for IC-7100/7600/9700. Tracked as a
      separate item; not blocking.

### 4.2 CW keyer

- [x] **Typed value wrappers**: ``CWSpeed`` (wpm, clamped 6–48),
      ``CWPitch`` (Hz, clamped 300–900), ``BreakInMode``
      (off/semi/full). Both numeric wrappers conform to
      `ExpressibleByIntegerLiteral` for ergonomic call sites
      (`rig.setCWSpeed(28)`).
- [x] **`CATProtocol` methods**: `setCWSpeed`/`getCWSpeed`,
      `setCWPitch`/`getCWPitch`, `setBreakIn`/`getBreakIn`,
      `sendCW(_ text:)`, `stopCW()`. All default to throw
      `.unsupported`.
- [x] **`RigCapabilities` flags**: `supportsCWKeyer` (covers
      speed/pitch/break-in) and `supportsSendCW` (covers text→CW).
      All three hardware-verified Icoms opt in.
- [x] **`IcomCIVProtocol` implementation** in
      `IcomCIVProtocol+CWKeyer.swift`. Uses the exact CI-V
      command bytes from Hamlib `icom_defs.h`:
      `0x14 0x0C` (KEYSPD), `0x14 0x09` (CWPITCH),
      `0x16 0x47` (BKIN), `0x17` (send/stop CW).
      Hamlib's full 43-entry `cw_lookup` table is transcribed so
      WPM↔byte conversion is byte-identical to Hamlib. Pitch
      uses the linear formula `(Hz-300) × 255 / 600`.
- [x] **`DummyCATProtocol`** holds CW state with sensible defaults
      (28 WPM, 600 Hz, semi break-in) plus `lastSentCW` and
      `isSendingCW` test helpers so SwiftUI previews can render
      realistic CW UI and tests can verify the send/stop path.
- [x] **`RigController` facade** with eight matching accessors.
- [x] **Tests**: 23 new in `CWKeyerTests`. Cover value-wrapper
      clamping, integer-literal init, full Hamlib `cw_lookup`
      cross-check at every breakpoint, decoder nearest-neighbor
      rounding, pitch formula at breakpoints + clamps,
      round-trip through dummy, ASCII truncation at 30 chars,
      non-ASCII stripping, before-connect throw, capability gating.
- [x] **Bonus fix:** pre-existing race in
      `pttPolledChangesEmit` test (subscriber registration vs.
      first poll) — subscribe-before-settle pattern documented
      on `RigController.events` and applied to the test.
- [ ] **Keyer memory write/recall** deferred. Hamlib doesn't
      expose this; the per-radio CI-V byte sequences for the
      8 keyer slots vary in non-obvious ways. Worth adding once
      we have hardware to verify against, but not blocking.

### 4.3 Scanning

- [x] **`ScanKind` enum** with all six modes Hamlib defines
      (VFO / memory / selectedMemory / priority / programmed /
      deltaF). String-backed, `CaseIterable`, `Sendable`. The
      roadmap originally called for `.programmed(edge1, edge2)`
      with embedded edge channels; in practice Hamlib's per-call
      edge parameter is rarely used (the radio remembers its
      edges) and embedding it complicates the enum. The simpler
      no-args case shipped; per-call edge selection is a follow-up.
- [x] **`CATProtocol` methods** `startScan(_:)` / `stopScan()`,
      both defaulting to throw `.unsupported`.
- [x] **`RigCapabilities` flags**: six independent bools
      (`supportsVFOScan`, `supportsMemoryScan`,
      `supportsSelectedMemoryScan`, `supportsPriorityScan`,
      `supportsProgrammedScan`, `supportsDeltaFScan`) mirroring
      Hamlib's `RIG_SCAN_*` bitfield. Per-radio support varies
      considerably; see `ScanKind`'s doc-comment matrix.
- [x] **`IcomCIVProtocol` implementation**
      (`IcomCIVProtocol+Scanning.swift`). Uses `0x0E` (C_CTL_SCAN)
      with sub-commands `0x00`/`0x01`/`0x02`/`0x03` from
      `icom_defs.h`. Unlike Hamlib, does NOT change the radio's
      VFO/MEM mode under the user — silent side effects hide bugs;
      callers should select the appropriate state first.
- [x] **`DummyCATProtocol`** tracks scan state and exposes an
      `activeScan` test helper.
- [x] **`RigController` facade**: `startScan(_:)` / `stopScan()`.
- [x] **Per-radio capability promotion** for IC-7100, IC-7600,
      IC-9700, each cross-checked against the matching Hamlib
      `IC{model}_SCAN_OPS` macro.
- [x] **Tests**: 10 new in `ScanningTests` covering dummy
      roundtrip, double-start replacement, idempotent stop,
      pre-connect throws, full capability-gating, and the three
      Icom per-radio matrices.
- [ ] **`setScanSpeed` / `setScanResume`** deferred. Hamlib
      exposes these as `RIG_LEVEL_*` settings; they're per-radio
      quirky and rarely used from apps. Tracked separately.

### 4.4 Antenna and band stack

- [x] **`CATProtocol` methods**: `selectAntenna(_ index: Int)`
      and `getAntenna() -> Int`. 1-based indexing to match
      operator and front-panel labels ("ANT 1", "ANT 2"). Both
      default to throw `.unsupported`.
- [x] **`RigCapabilities.antennaCount: Int`** carries both the
      "supports antenna selection" bit and the upper bound on
      valid indices. Default `1` (single fixed jack). Clamped
      to `≥1` on construction.
- [x] **`IcomCIVProtocol` implementation**
      (`IcomCIVProtocol+Antenna.swift`) using `C_CTL_ANT` (0x12)
      with 0-based byte on the wire. Public API stays 1-based.
- [x] **`ElecraftProtocol` implementation**
      (`ElecraftProtocol+Antenna.swift`) using Kenwood-derived
      `AN<n>;` form for the K2. Skips ACK wait on K2 (matches
      the existing setPower pattern — K2 doesn't echo SET).
- [x] **Per-radio capability promotion**, each Hamlib-verified:
      - IC-7100 → 2 (Hamlib `IC7100_HF_ANTS`)
      - IC-7600 → 2 (Hamlib `IC7600_ANTS`)
      - IC-9700 → 1 (per-band hardware jacks, no SW selection)
      - K2 → 2 (Hamlib `K2_ANTS`; requires KAT-2 internal tuner
        or KAT100 external — operators without the tuner see
        `commandFailed` at runtime, matching Hamlib's posture)
- [x] **`DummyCATProtocol`** stores `antennaIndex` and gates on
      the capability flag like a real radio (unlike scan, which
      is permissive — antenna selection has stricter semantics
      because indexing matters).
- [x] **`RigController` facade**: `selectAntenna(_:)` /
      `antenna()`.
- [x] **Tests**: 12 new in `AntennaTests` covering dummy
      roundtrip, single-antenna unsupported, out-of-range
      throws, before-connect throws, antennaCount clamping,
      capability promotion for all four verified radios, and
      Icom capability gating against synthetic radio caps.
- [ ] **Band stacking register read/write** deferred. Hamlib
      models only band-select (`RIG_PARM_BANDSELECT` →
      `0x1A 0x01 <band>`); the richer per-band-per-stack model
      varies per radio in poorly-documented ways and is not
      safe to ship without hardware verification. Tracked.

### 4.5 Rigctld bridge coverage

- [x] **TX meter `get_level` support** for SWR, ALC,
      RFPOWER_METER, RFPOWER_METER_WATTS, COMP_METER, VD_METER,
      ID_METER. Each formatted per Hamlib's `RIG_LEVEL_*` float
      semantics (six-decimal precision, natural physical units).
      Level-name strings cross-checked against
      `~/Developer/hamlib/src/misc.c`'s `rig_strlevel` table.
- [x] **CW `get_level` / `set_level` support** for KEYSPD and
      CWPITCH. Plain integer values (Hamlib treats these as
      `int` levels, not floats).
- [x] **Break-in via `set_func` / `get_func`** (new commands).
      Supports `SBKIN` (semi) and `FBKIN` (full); other function
      bits return `.notImplemented`. Off is set by sending the
      currently-active bit with value 0.
- [x] **Antenna via `set_ant` / `get_ant`** (new commands).
      `get_ant` returns Hamlib's four-field format
      (`AntCurr Option AntTx AntRx`); SwiftRigControl populates
      `AntCurr` from the radio and sets the other three to
      pass-through values.
- [x] **Scanning via `scan`** (new command). Accepts `VFO`,
      `MEM`, `SLCT`, `PRIO`, `PROG`, `DELTA`, `STOP`. Case-
      insensitive. Per-channel arg parsed but ignored
      (`CATProtocol.startScan` doesn't model it).
- [x] **CW send/stop via `send_morse` / `stop_morse`** (new
      commands). Multi-word messages survive the tokenizer via
      arg-rejoin in the parser.
- [x] **Parser tests**: 13 in `RigctldParserTests` covering
      both short (`U`/`u`/`Y`/`y`/`g`/`b`) and long
      (`set_func`/`set_ant`/`get_ant`/`scan`/`send_morse`/
      `stop_morse`) forms, plus `longName` round-trip vs. Hamlib.
- [x] **Handler tests**: 22 in `RigctldHandlerTests` driving
      every new command against a dummy-backed `RigController`.
      Cover correct Hamlib-format response (SWR ratio, watts,
      dB, volts, amps), capability gating, four-field
      `get_ant` response, scan kind mapping including STOP and
      bogus-name rejection.
- [ ] **Hardware verification with `rigctl -m 2 -r localhost:4532`
      against a Hamlib build.** Deferred — requires a Hamlib
      install we can run side-by-side. Tracked as a manual
      validation step for the next hardware-test session.

**Phase 4 complete:** for each of the four verified radios, the
Hamlib command surface that maps onto SwiftRigControl's
`CATProtocol` is exposed over the rigctld bridge with byte-for-
byte format parity. Things genuinely outside scope
(`set_chan`/`get_chan`, function bits beyond break-in,
band-stacking register R/W, vfo_op compound operations)
remain `.notImplemented` and are tracked in `[Unreleased]`.

---

## Phase 5 — Architectural refinement

**Goal:** structural improvements that lock in a stable shape
for third-party consumers *before* they start depending on the
current one.

> **Re-evaluation (2026-05-23):** earlier roadmap text said
> *"defer until pain is observable — premature abstraction is
> worse than no abstraction."* That framing assumed the only
> cost of a fat protocol or a leaky escape hatch is pain to the
> library author. With stability commitments to third-party app
> developers as a hard requirement, the cost of *deferring* a
> refactor is much higher: it shifts the breakage to people who
> can't easily migrate. While the library still has only one
> external user (the project author's own apps), every
> architectural decision we postpone is a future v2-breaking
> change waiting to happen. So Phase 5 is being executed now,
> in full, before any v1.1-stable release.

### 5.1 Capability traits

`CATProtocol` carried ~40 methods, most defaulted to
`throw unsupportedOperation`. Split along feature seams so each
concrete protocol's conformance list is its capability contract:

- [x] **`CATProtocol` slimmed to the universal core**
      (`transport`/`capabilities` + frequency, mode, PTT, VFO,
      connect/disconnect). All other methods moved out; every
      default-throw extension deleted.
- [x] **21 new trait protocols** in
      `Sources/RigControl/Core/CATProtocolTraits.swift`, each
      `Supports<Feature>`-named: `SupportsPower`,
      `SupportsSplit`, `SupportsSignalStrength`, `SupportsRIT`,
      `SupportsXIT`, `SupportsAGC`, `SupportsNoiseBlanker`,
      `SupportsNoiseReduction`, `SupportsIFFilter`,
      `SupportsAFGain`, `SupportsRFGain`, `SupportsSquelch`,
      `SupportsPreamp`, `SupportsAttenuator`,
      `SupportsRemotePowerState`, `SupportsMemoryChannels`,
      `SupportsTXMeters`, `SupportsCWKeyer`, `SupportsSendCW`,
      `SupportsScanning`, `SupportsAntenna`. Each refines
      `CATProtocol`.
- [x] **Every concrete protocol declares its trait list:**
      `IcomCIVProtocol`/`DummyCATProtocol` claim all 21;
      `YaesuCATProtocol`/`KenwoodProtocol` claim 16 (power,
      split, SS, RIT, XIT, AGC, NB, NR, IF, AF, RF, squelch,
      preamp, attenuator, power-state, memory);
      `ElecraftProtocol` adds `SupportsAntenna`; `THD72Protocol`
      claims power/split/SS (handheld); `TenTecOrionProtocol`
      claims split + SS; `TenTecLegacyProtocol` claims SS only
      (no split in the legacy protocol).
- [x] **`RigController` dispatches via `as? any SupportsX`**
      using a new `requireTrait(_:named:)` helper. Error strings
      match the old default-throw extensions verbatim — apps
      catching `RigError.unsupportedOperation` and matching on
      strings see no change.
- [x] **Migration verified mechanical.** All 350 existing tests
      pass without modification; DocC builds clean with the new
      trait surface added to the catalog.

### 5.2 Typed extension access

- [x] **New `VendorExtensions` enum** with one case per supported
      vendor protocol, each carrying the concrete actor:
      `.icom(IcomCIVProtocol)`, `.elecraft(ElecraftProtocol)`,
      `.yaesu(YaesuCATProtocol)`, `.kenwood(KenwoodProtocol)`,
      `.thd72(THD72Protocol)`, `.tentecOrion(TenTecOrionProtocol)`,
      `.tentecLegacy(TenTecLegacyProtocol)`,
      `.dummy(DummyCATProtocol)`, plus
      `.unknown(any CATProtocol)` for forward compatibility.
- [x] **`RigController.vendorExtensions: VendorExtensions`**
      replaces the stringly-typed `as?` cast. Pattern-match the
      enum to reach the vendor's protocol actor:
      `if case .icom(let icom) = await rig.vendorExtensions { ... }`.
      The compiler enforces exhaustiveness — when a new vendor
      gets added, every call site is told to handle the new case.
- [x] **`RigController.protocol` renamed to `RigController.rawProtocol`**
      with a strengthened doc-comment that it's an explicit escape
      hatch for cases the vendor-extension enum doesn't cover
      (hardware validators, custom simulators, debugging). The doc
      explicitly notes that anything reached through `rawProtocol`
      is unversioned and may change between releases without a
      deprecation cycle.
- [x] **No curated `IcomExtensions` / `ElecraftExtensions` facades
      ship in this phase.** The roadmap originally called for them;
      design-discussion conclusion was that hand-curating a subset
      of the ~30 Icom-specific methods would commit us to a
      forever contract we don't have enough data to design well
      yet. The whole concrete protocol actor is accessible through
      the `.icom(let icom)` case, which is the same level of
      access apps had before — just typed.
- [x] **Bulk rename of every internal call site** from
      `rig.protocol` to `rig.rawProtocol` across Tests, Tools, and
      Examples (50+ call sites). The new `vendorExtensions`
      pattern is demonstrated in the updated `RigController` and
      `IFFilter` doc comments.
- [x] **6 new tests** in `VendorExtensionsTests`: enum-case
      dispatch for dummy / Icom / Elecraft radios, `rawProtocol`
      returns the same actor on repeated reads, vendorExtensions
      and rawProtocol agree on the same actor instance,
      switch-exhaustiveness compile-time guard.

### 5.3 Eliminate the `CATProtocol.init(transport:)` requirement

- [x] **Done in Phase 1.4** (commit `6d8a954`). The
      `init(transport:)` requirement was removed from
      `CATProtocol` and the corresponding satisfying-only init
      was deleted from every conformer (Icom's was a
      `preconditionFailure`-throwing stub; others picked
      arbitrary default capabilities). Construction is now
      exclusively the job of concrete-type inits and
      `RadioDefinition.protocolFactory`. Checked off here for
      bookkeeping completeness.

---

## Phase 5.5 — Hamlib parity closure (v1.1)

**Goal:** close the three highest-impact gaps identified in the
`Documentation/HAMLIB_PARITY.md` audit before tagging v1.1.0.

### 5.5.1 Compound VFO operations

- [x] **Landed (`609eeac`).** New `SupportsVFOOperations` trait,
      `VFOOperation` enum mirroring Hamlib `RIG_OP_*`, and
      `RigController.performVFOOperation(_:)`. Wire commands for
      Icom CI-V (0x07/0x09/0x0A/0x0B/0x1C), Kenwood text
      (UP/DN/BU/BD/MC/MR/AC), Yaesu newcat (AB/SV/AM/MA/UP/DN/
      BU0/BD0/AC002), and the Kenwood-shared subset on Elecraft.

### 5.5.2 Function toggles

- [x] **Landed (`b58f6ee`).** New `SupportsFunctions` trait,
      `RigFunction` enum (21 curated bits from Hamlib's
      `RIG_FUNC_*` universe), and per-radio
      `supportedFunctions: Set<RigFunction>`. Per-radio masks
      seeded from Hamlib for the verified Icom radios.

### 5.5.3 Secondary level controls

- [x] **Landed (`de26705`).** Six new per-trait protocols:
      `SupportsMicGain`, `SupportsCompressorLevel` (level,
      distinct from on/off toggle), `SupportsMonitorGain`,
      `SupportsVOXGain`, `SupportsVOXDelay`, `SupportsIFShift`.
      PBT_IN/OUT and NOTCHF deferred to post-v1.1 patch work.

### 5.5.4 rigctld bridge coverage

- [x] **Landed (`de26705`).** New `vfo_op` command (Hamlib `G`
      and `\vfo_op`); extended `set_func`/`get_func` to map 21
      Hamlib bit names to `RigFunction`; extended
      `set_level`/`get_level` for the six secondary-level
      tokens.

### 5.5.5 Definition adds — done

- [x] **TH-D75** — `.kenwoodTHD75`. Tri-band D-STAR/APRS HT,
      reuses `KenwoodProtocol`.
- [x] **ID-31** — `.icomID31()`. Single-band UHF D-STAR HT.
- [x] **ID-51** — `.icomID51()`. Dual-band V/U D-STAR HT.
- [x] **ID-52** — `.icomID52()`. Dual-band V/U D-STAR HT
      (successor to ID-51).
- [x] **IC-92D** — `.icomIC92D()`. Dual-band D-STAR HT
      (predecessor to ID-51 family).
- [x] **IC-R30** — `.icomICR30()`. Wideband digital handheld
      receiver, 100 kHz–3.3 GHz.
- [x] **Lab599 TX-500** — `.lab599TX500`. Portable HF;
      introduces the `lab599` manufacturer brand tag.

---

## Phase 6 — Beyond-Hamlib differentiators

**Goal:** features Hamlib does not have or does poorly.

### 6.1 Spectrum scope streaming

- [ ] IC-7300 waterfall data: parse 0x27 0x00 frames.
- [ ] IC-7610 dual scope.
- [ ] `AsyncStream<ScopeFrame>` API.
- [ ] No SwiftUI rendering shipped in the library — apps own
      the UI; we provide the data.

### 6.2 Satellite Doppler helper

- [ ] IC-9700 main/sub VFO satellite tracking helper:
      given uplink frequency, downlink frequency, and Doppler
      offsets, set both VFOs and split atomically.
- [ ] Verified on IC-9700 (we have it).

### 6.3 Memory channel set operations

- [ ] Batch import/export memory channels as a `Codable`
      `MemoryBank` type (CSV/JSON interop).
- [ ] Diff/merge helpers.

### 6.4 Auto-detection

- [ ] Enumerate `/dev/cu.*` and `/dev/tty.*`.
- [ ] Probe each at common baud rates, sending each vendor's
      identify query, return candidate matches.
- [ ] Surface as `RadioDiscovery.scan() async -> [Candidate]`.

---

## Out of scope (do not propose)

These are explicit non-goals. Reopen only with a strong reason.

- **Linux, iOS, visionOS, Windows.** macOS only. IOKit is fine.
- **Vintage / pre-CAT radios.** Not relevant.
- **Rotators, amplifiers, antenna switches as primary citizens.**
  Different domain; Hamlib's `rotctl` covers it.
- **DX cluster integration.** App-level concern.
- **Contest logging / QSO storage.** App-level concern.
- **Non-Foundation dependencies.** Zero-dependency is a feature.
- **Adding radio definitions without verification or Hamlib
  cross-reference.** Inflates the count, dilutes trust.

---

## Sequencing summary

```
Phase 0  Honesty pass                       (1 session, no risk)
Phase 1  Foundations                        (CI, evac, mock, deprecations)
Phase 2  Reactive state                     (the v2.0 headline feature)
Phase 3  Documentation as a product         (DocC + hosting)
Phase 4  Hamlib parity on verified radios   (depth, not breadth)
Phase 5  Architectural refinement           (capability traits, when ready)
Phase 6  Beyond-Hamlib differentiators      (spectrum, satellite, discovery)
```

Phases 0 and 1 are blocking. Phase 2 should ship before Phase 3
(no point documenting an API that's about to change). Phase 4 is
parallelizable per-radio. Phases 5 and 6 are pull-based — do
them when a concrete app need surfaces.

---

## Development principles

1. **Hamlib is the reference.** Cross-check before shipping.
2. **Hardware-verify before claiming "supported."**
3. **Zero warnings, zero dependencies.**
4. **Swift 6 strict concurrency, actors over locks.**
5. **Files under ~500 lines; split along feature seams.**
6. **Public symbols get DocC comments.**
7. **Update ROADMAP, CHANGELOG, README, and `Documentation/` after
   every commit** (see `CLAUDE.md`).
8. **Depth on supported radios over breadth of definitions.**

---

*73 de VA3ZTF*
