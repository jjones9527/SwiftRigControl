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

Source-breaking; gates the next major version.

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
- [x] CHANGELOG `[Unreleased]` has a BREAKING entry with migration
      snippets for each deletion.
- [ ] **Tag as v2.0.0-alpha.1** — held pending explicit user OK.
      Tagging changes downstream consumer expectations.

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
Swift 6 / SwiftUI. Recommendation: ship both, with the stream
as primary.

- [ ] Define a `RigStateEvent` enum:
      `.frequencyChanged(VFO, UInt64)`,
      `.modeChanged(VFO, Mode)`,
      `.pttChanged(Bool)`,
      `.signalStrengthChanged(SignalStrength)`,
      `.connectionStateChanged(ConnectionState)`.
- [ ] Add `RigController.events: AsyncStream<RigStateEvent>`.
- [ ] All `set*` paths on `RigController` emit the corresponding
      event after a successful write (and after cache invalidation).
- [ ] Define `RigStateObserver` protocol for callback-style
      consumers; bridge it on top of the AsyncStream.
- [ ] Unit tests with `MockSerialTransport` proving event delivery.

### 2.2 Polled state broadcaster

Some state (signal strength, SWR, frequency drift, PTT from
front-panel mic) the radio does not push. Provide an opt-in
poller.

- [ ] `RigController.startPolling(interval:fields:)` /
      `stopPolling()`.
- [ ] Configurable per-field intervals (SignalStrength at 200ms,
      frequency at 1s, etc.).
- [ ] Polling emits the same `RigStateEvent`s — UI doesn't care
      whether a change came from a `set` or a poll.

### 2.3 Connection health

- [ ] `ConnectionState` enum: `.disconnected`, `.connecting`,
      `.connected`, `.degraded(reason)`, `.reconnecting(attempt)`.
- [ ] Heartbeat: lightweight periodic read; on N timeouts mark
      degraded.
- [ ] Optional auto-reconnect with `RetryPolicy` struct
      (max attempts, backoff).
- [ ] All state transitions emit `.connectionStateChanged`.

**Phase 2 exit criteria:** a SwiftUI app can write
```swift
ForEach(rig.events) { event in ... }
```
and render real-time radio state with no polling loop in user code.

---

## Phase 3 — Documentation as a product

**Goal:** make the library discoverable without grep.

### 3.1 DocC catalog

- [ ] Create `Sources/RigControl/RigControl.docc/`.
- [ ] Landing article: "What is SwiftRigControl?"
- [ ] Tutorial: "Your first radio app" (10 minutes, mock + real).
- [ ] How-to articles:
      "Adding a new radio",
      "Migrating from Hamlib",
      "Working with capabilities",
      "Using the rigctld bridge",
      "Driving SwiftUI with `RigController.events`".
- [ ] Symbol pages for every top-level public type.

### 3.2 Symbol-level DocC coverage

- [ ] Sweep every public symbol; add DocC comments with at least
      `- Parameter`, `- Returns`, `- Throws`.
- [ ] Add a runnable code snippet for every non-trivial public
      method (frequency, mode, PTT, configure, signal strength,
      memory channels).
- [ ] CI lint: fail build on a public symbol missing
      documentation (using SwiftLint or DocC's own checks).

### 3.3 Hosting

- [ ] GitHub Pages workflow: build DocC on tag, publish.
- [ ] README link to hosted docs.

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

- [ ] `getRFPowerOut()` — TX power meter (Icom: 0x15 0x11).
- [ ] `getSWR()` — SWR meter (Icom: 0x15 0x12).
- [ ] `getALC()` — ALC reading (Icom: 0x15 0x13).
- [ ] `getCompression()` — speech compressor (Icom: 0x15 0x14).
- [ ] `getIDMeter()` — drain current.
- [ ] `getTemp()` — final transistor temp where available.
- [ ] Capability flags per radio; default `throw unsupported`.

### 4.2 CW keyer

- [ ] `setCWSpeed(_ wpm: Int)`, `getCWSpeed()`.
- [ ] `setKeyerMemory(_ slot: Int, message: String)`.
- [ ] `sendCWMemory(_ slot: Int)`, `stopCW()`.
- [ ] `setCWPitch(_ hz: Int)`, `getCWPitch()`.
- [ ] `setBreakIn(_ mode: BreakInMode)` — `off`/`semi`/`full`.

### 4.3 Scanning

- [ ] `startScan(_ kind: ScanKind)` where `ScanKind` is
      `.vfo`, `.memory`, `.programmed(edge1, edge2)`,
      `.priority`.
- [ ] `stopScan()`.
- [ ] `setScanSpeed`, `setScanResume`.

### 4.4 Antenna and band stack

- [ ] `selectAntenna(_ index: Int)` for radios with multi-ANT.
- [ ] Band stacking register read/write where supported.

### 4.5 Rigctld bridge coverage

- [ ] Add `m`/`M` (meter), `l SWR`/`l ALC` parsing in
      `RigctldCommandHandler`.
- [ ] Add `scan`, `set_ant`/`get_ant`, `send_morse`.
- [ ] Verify with `rigctl -m 2 -r localhost:4532` against a
      known-good Hamlib build.

**Phase 4 exit criteria:** for each of the four verified radios,
`rigctl --list-flags` equivalents that Hamlib reports as
supported are also supported (or explicitly documented as
out-of-scope) by SwiftRigControl.

---

## Phase 5 — Architectural refinement

**Goal:** structural improvements that pay off as the library
grows. Defer until pain is observable — premature abstraction
is worse than no abstraction.

### 5.1 Capability traits

`CATProtocol` is approaching ~40 methods, most defaulted to
`throw unsupportedOperation`. Split along feature seams:

- [ ] `CATProtocol` keeps only the universal core
      (frequency, mode, PTT, VFO, connect/disconnect).
- [ ] `SupportsPower`, `SupportsSplit`, `SupportsDSP`,
      `SupportsMemoryChannels`, `SupportsRITXIT`,
      `SupportsScanning`, `SupportsCWKeyer`, etc., as
      separate protocols.
- [ ] `RigController` extensions adopt the form:
      `if let p = proto as? any SupportsDSP { ... } else { throw ... }`.
- [ ] Migration is mechanical; do it once, with tests.

### 5.2 Typed extension access

Replace `RigController.protocol: any CATProtocol` with a
discriminated `RigController.vendorExtensions` that returns
a typed handle:

- [ ] `enum VendorExtensions { case icom(IcomExtensions), elecraft(...), ... }`
- [ ] `IcomExtensions` exposes `setAttenuator`, `setPreamp`,
      `setBandEdge`, etc. without casting.

### 5.3 Eliminate the `CATProtocol.init(transport:)` requirement

Currently every conformer must implement an init that's never
called (Icom's variant `preconditionFailure`s). Either drop the
init requirement from the protocol, or replace with a
factory-only pattern.

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
