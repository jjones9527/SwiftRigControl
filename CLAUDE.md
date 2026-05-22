# CLAUDE.md

Guidance for Claude Code (and human contributors) working in this repository.

---

## Project mission

SwiftRigControl is a native Swift 6 library that provides amateur-radio CAT
control for macOS applications. The north star is to **meet or exceed the
practical capabilities of Hamlib / rigctld** for the radios we support, while
presenting a modern, type-safe, actor-based API that feels native to Swift
developers.

Hamlib (`https://hamlib.github.io/`) and `rigctld` are the de-facto standards
for radio control. They are battle-tested across hundreds of radios and
decades of operator use. Treat them as a **reference implementation and
sanity check** — when in doubt about protocol framing, response parsing,
mode codes, or radio quirks, cross-check against Hamlib's C source before
shipping. Note divergences explicitly in code comments with a brief reason.

---

## Current release

The shipped version is **v1.0.6** (git tag, 2026-04-30). Earlier
CHANGELOG entries labeled `[1.1.0]`, `[1.2.0]`, and `[1.3.0]` were
*not* separate releases — the work they describe all shipped under
the `v1.0.6` tag. The top-of-file note in `CHANGELOG.md` explains
the reconciliation. The next release will be `v1.0.7` (patch) or
`v1.1.0` (minor), depending on the scope of accumulated work in
`[Unreleased]`.

Going forward: **`CHANGELOG.md` heading versions must match the git
tag they ship under.** No more aspirational labels.

---

## Architecture at a glance

```
Sources/RigControl/
  Core/                CATProtocol, RadioDefinition, ConnectionType
  Models/              Mode, VFO, RigCapabilities, RigError, capability DBs
  Protocols/
    Icom/              IcomCIVProtocol + CIVCommandSet implementations
    Elecraft/          ElecraftProtocol (text-based)
    Yaesu/             YaesuCATProtocol (text-based)
    Kenwood/           KenwoodProtocol + THD72Protocol
    Xiegu/             Xiegu models (CI-V compatible)
    TenTec/            Orion + Legacy
  RigController/       Public facade actor + per-feature extensions
  Transport/           SerialTransport protocol + IOKitSerialPort
  Network/             rigctld-compatible TCP server + command handler
  Cache/               RadioStateCache (TTL-based)
  Utilities/           BCDEncoding, etc.

Sources/RigControlXPC/  XPC client/server for Mac App Store sandboxed apps
Sources/RigControlHelper/ XPC helper executable

Tests/RigControlTests/ Unit, protocol (MockTransport), and hardware suites

Tools/SwiftRigControlTools/  Separate SwiftPM project — NOT pulled by
                             library consumers. Contains:
  HardwareValidation/        Per-radio smoke tests (real hardware)
  InteractiveValidators/     stdin-driven manual validators
  Debugging/                 Vendor- and command-specific debug tools
```

**Two equally important consumers:** third-party Swift apps integrating
rig control, and the project author's own apps. Design accordingly —
keep the public API small, type-safe, and well-documented; keep
extension points (capabilities, command sets, observers) accessible.

---

## Swift 6 guidance

- **Strict concurrency** is on (`swiftLanguageModes: [.v6]`). All warnings
  are treated as breakage — keep the build at zero warnings.
- **Actors over locks.** Anything with mutable state that is shared
  across tasks is an `actor`. `RigController`, `IcomCIVProtocol`,
  `IOKitSerialPort`, and `RadioStateCache` are already actors — follow
  the pattern.
- **`Sendable` everywhere it matters.** Public value types must be
  `Sendable`. Closures crossing actor boundaries must be `@Sendable`.
- **`async`/`await`, never callback APIs.** No `DispatchQueue` in
  new code. No completion handlers.
- **Structured concurrency.** Prefer `Task { }` only at API boundaries;
  inside the library, await directly.
- **No external dependencies.** Zero-dependency is a feature. Do not
  add SwiftPM dependencies without explicit discussion.

---

## File size and organization

- **Soft cap: 500 lines per file.** Above that, split along the
  natural seam (a feature group, a radio family, a sub-protocol).
  The existing pattern is `RigController+Frequency.swift`,
  `IcomCIVProtocol+IFFilter.swift`, `RadioCapabilitiesDatabase+IcomLegacy.swift`.
- **One responsibility per file.** A file should answer the question
  "what does this do?" in one sentence.
- **Group by feature, not by type.** `RigController/` extensions
  group by *what the user does* (Frequency, Mode, PTT, DSP, Memory),
  not by abstract category.

---

## Documentation and comments

- **Every public symbol gets a DocC comment.** Triple-slash, with
  `- Parameter`, `- Returns`, `- Throws` where applicable. This is
  non-negotiable for library code.
- **Include a usage example** in DocC for any non-trivial public
  API (frequency, mode, PTT, DSP, memory, configure batch).
- **Explain the *why*, not the *what*, in inline comments.** Radio
  protocols are full of vendor quirks (echo behavior, filter bytes,
  data-mode encoding). Document the quirk and cite the manual or
  Hamlib source line that confirmed it.
- **User-facing docs live in `Documentation/`.** Keep `README.md`
  accurate (it is the first thing users see).
- **DocC catalog is the goal** for the public API — add `.docc`
  symbol pages as the API stabilizes.

---

## Testing

- **Swift Testing framework** (`import Testing`, `@Test`, `#expect`)
  for all new tests. XCTest remains acceptable only in legacy files
  scheduled for migration.
- **Three test tiers:**
  - `Tests/RigControlTests/UnitTests/` — pure functions, encoding, parsing.
  - `Tests/RigControlTests/ProtocolTests/` — protocol behavior against
    `MockTransport` (no hardware needed).
  - `Tests/RigControlTests/HardwareTests/` — gated by env vars
    (`IC7600_SERIAL_PORT`, etc.); skipped automatically when absent.
- **Mock first, hardware second.** Every new protocol command needs
  a `MockTransport` test before it can claim to work.
- **No new tests in `Archived/`.** That tree is read-only legacy.

### Hardware verification policy

The README and ROADMAP advertise specific radios as "verified."
**A radio is only "verified" if at least one operation in each
major feature group (frequency, mode, PTT, signal strength) has
been exercised against the real hardware** and the result captured
in `Tools/SwiftRigControlTools/HardwareValidation/<Radio>Validator/`.

Currently verified on real hardware:
- Icom IC-7100, IC-7600, IC-9700
- Elecraft K2

All other radios are **definition-only** — code paths exist and
should follow the manufacturer's manual + Hamlib precedent, but
behavior is not field-validated. When adding a radio, mark its
status honestly. Do not claim "supported" without a validator run.

---

## Working with radio protocols

- **Hamlib cross-check.** Before implementing a new command or
  debugging a quirk, look at the corresponding Hamlib source
  (`rigs/<vendor>/<model>.c`). Hamlib's comments often capture
  hard-won knowledge about vendor bugs.
- **Manufacturer manuals are authoritative.** The PDFs in the repo
  root (`IC-7100 CIV.pdf`, `KIO2 Pgmrs Ref rev E.pdf`) and
  `Icom CI-V Manuals/` are the primary source.
- **Per-radio command sets.** Icom CI-V quirks live in
  `Protocols/Icom/CommandSets/<Model>CommandSet.swift`, conforming
  to `CIVCommandSet`. Add new radios by composing a command set,
  not by branching inside `IcomCIVProtocol`.
- **Capability flags gate behavior.** If a radio doesn't support
  a feature, set the capability to `false` and let the default
  `throw RigError.unsupportedOperation` fire. Do not silently no-op.
- **Echo handling.** Some Icom radios (IC-7100, IC-705) echo every
  command. The command set's `echoesCommands` flag drives the
  receive loop to skip the echo frame.
- **Data modes are filter-byte encoded** on Icom (see
  `IcomCIVProtocol.setMode`). DATA-USB is `USB mode code + filter
  byte 0x00`, not a separate mode. Cross-check Hamlib's
  `icom.c::icom_set_mode` if extending.

---

## Platform and dependencies

- **macOS 14+ only.** No Linux, no iOS, no Windows. `IOKit` and
  `Darwin` are fair game.
- **Swift tools 6.2+**, Swift language mode `.v6`.
- **No third-party packages.** Foundation, IOKit, and Network only.

---

## Working with the rigctld bridge

`RigControlServer` + `RigctldCommandHandler` expose the library
over the Hamlib `rigctld` text protocol so existing tools
(WSJT-X, fldigi, JS8Call) can drive SwiftRigControl-backed apps.
When adding a new rigctld command:

1. Confirm Hamlib's behavior with `rigctld --help` and the
   protocol documentation under `Documentation/NETWORK_CONTROL.md`.
2. Match Hamlib's response format exactly — third-party clients
   parse responses byte-for-byte.
3. Add a parser test in `RigctldCommandParserTests` (when
   present) before wiring the handler.

---

## Common pitfalls

- **Don't call sync IOKit from an async function.** Wrap in the
  serial-port actor; the actor serialises access.
- **Don't widen `CATProtocol`** without checking whether the new
  method is actually universal across vendors. If only one
  vendor implements it, add it on the concrete actor and access
  via the `RigController.protocol` cast.
- **Don't claim Hamlib parity without checking.** If unsure
  whether a feature is in Hamlib, grep its source before
  asserting "we now match Hamlib."
- **Don't ship a new radio definition without a CHANGELOG entry**
  and an honest verification status.

---

## Progress tracking

After every commit (or coherent batch of commits), update the relevant
progress-tracking documents so the project's stated state stays
synchronized with reality:

- **`ROADMAP.md`** — mark completed items, move work between phases as
  scope shifts, and add new items uncovered during the work. The
  roadmap is a living document, not a frozen plan.
- **`CHANGELOG.md`** — every user-visible change (new radio, new
  command, bug fix, breaking change, deprecation) gets an entry under
  the next-version heading. Follow Keep-a-Changelog conventions.
- **`README.md`** — update only when the public API, supported-radio
  list, or hardware-verification status changes.
- **`Documentation/`** — refresh the affected user guide if a public
  API or workflow changed.

The discipline: a feature is not "done" until the docs that advertise
it tell the truth. If you finish work and the roadmap still shows it
as pending, the work is not finished.

---

## Quick reference

| Task | Where |
| --- | --- |
| Add a new Icom radio | `Models/RadioCapabilitiesDatabase+Icom*.swift` + (if quirks) `Protocols/Icom/CommandSets/` |
| Add a new vendor protocol | New folder under `Protocols/<Vendor>/`, conform to `CATProtocol` |
| Add a new top-level operation | Extend `CATProtocol` + add default `throw unsupported` impl + extend `RigController` |
| Add a new rigctld command | `Network/RigctldCommandHandler.swift` + parser update |
| Add a hardware validator | `Tools/SwiftRigControlTools/HardwareValidation/<Radio>Validator/`, register in `Tools/SwiftRigControlTools/Package.swift` |
| Bump version | `CHANGELOG.md`, `ROADMAP.md`, README badges |

---

## Out of scope (do not propose)

- Linux, iOS, visionOS, Windows support
- Vintage / pre-CAT radios
- Rotator, amplifier, or DX-cluster integration
- Contest logging or QSO storage
- Adding non-Foundation dependencies

73 de VA3ZTF
