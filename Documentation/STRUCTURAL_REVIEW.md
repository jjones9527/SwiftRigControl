# Structural Review

Evaluation of SwiftRigControl's package organization against
Hamlib's reference structure and modern Swift 6 / SwiftPM best
practices. Conducted 2026-05-28 in response to the user's
request to evaluate whether we're laid out the best way
possible for a macOS library developers want to integrate.

## Headline

**The bones are good.** Almost all findings below are taste-level
or "do this once the API stabilizes," not "stop and fix this now."
The single highest-leverage outside-visible change is namespacing
the radio factories (`RadioDefinition.Icom.ic9700()`); everything
else can wait for natural refactor moments without accumulating
debt.

## Findings ranked by leverage

### 1. Should do — clear wins, low risk

| # | Change | Effort | Public-API impact |
|---|--------|--------|--------------------|
| 1 | Namespace radio factories under `RadioDefinition.Icom.ic9700()` etc., with `@available(*, deprecated, renamed:)` aliases for one release | ~1 day | Source-breaking with deprecation cycle |
| 2 | Extract the rigctld bridge into its own product `RigControlRigctld` so consumers can opt out | ~half day | Type-aliased + `@_exported import` for one release; minimal |
| 3 | Move PDFs (`IC-7100 CIV.pdf`, `KIO2 Pgmrs Ref rev E.pdf`, `Icom CI-V Manuals/`) and stray scripts out of repo root into `Documentation/Manufacturer/` | ~15 min | None |
| 4 | Empty `RadioCapabilitiesDatabase+Icom.swift` by redistributing definitions into the existing era-specific files (Compact / Flagships / Legacy) | ~2 hours | None |
| 5 | Rename ambiguous `RigController+*.swift` extensions (`+VFO` vs `+VFOOperations`, `+LevelControls` vs `+SecondaryLevels`) | ~30 min | None |
| 6 | Pick one `Archived/` test location; delete the other | ~15 min | None |
| 7 | Decide DocC vs `Documentation/` as canonical for user-facing docs (rec: DocC for users, `Documentation/` for contributor planning only) | ~doc work | None |

### 2. Worth considering — judgment calls

| # | Change | Effort | Notes |
|---|--------|--------|-------|
| 8 | Reshape `Sources/RigControl/` into `Core/` + `Types/` + `RadioDefinitions/<Vendor>/` + `Protocols/<Vendor>/` | ~1 day | No consumer-visible change; bundle with #1 if doing it at all |
| 9 | Write a DocC article elevating the `CIVCommandSet` pattern; mark `CIVCommandSet` `public` once the next Icom radio addition doesn't change the protocol | ~doc + access modifier change | Don't make public until evolution settles |

### 3. Don't change — current state is right

- Three-product target structure (`RigControl` / `RigControlXPC` / `RigControlHelper`) — matches mature Swift package conventions exactly.
- Per-feature `RigController+*.swift` extensions — splitting by feature reads better than monolithic `RigController.swift`.
- Three-tier test layout (`UnitTests` / `ProtocolTests` / `HardwareTests` + `Support`).
- Actor-and-trait architecture (`CATProtocol` + `SupportsX` traits) — the Phase 5 work delivered the right shape.
- Zero runtime dependencies (SwiftDocCPlugin exception correctly scoped).

## Detailed rationale

### Why namespace the factories (item 1)

Today a user typing `RadioDefinition.` in Xcode autocomplete sees
all ~100 factories at once. With vendor namespaces:

```swift
RadioDefinition.Icom.ic9700(civAddress: 0xA2)
RadioDefinition.Kenwood.ts890S()
RadioDefinition.Elecraft.k2()
RadioDefinition.Yaesu.ft991A()
RadioDefinition.Lab599.tx500
```

Three wins:

1. Autocomplete filters by vendor — `RadioDefinition.Icom.` shows
   only Icom radios.
2. Naming becomes regular — today `icomIC9700` repeats "I" twice;
   `lab599TX500` is awkward.
3. It matches how the user thinks. Nobody owns "a radio"; they
   own "an Icom IC-9700" or "a Yaesu FT-991A".

Implementation pattern:

```swift
extension RadioDefinition {
    public enum Icom {
        public static func ic9700(civAddress: UInt8? = nil) -> RadioDefinition { … }
        // … 46 Icom factories
    }
    public enum Kenwood { … }
    public enum Yaesu { … }
    public enum Elecraft { … }
    public enum Xiegu { … }
    public enum Lab599 { … }
}

// Deprecation aliases for one release:
extension RadioDefinition {
    @available(*, deprecated, renamed: "RadioDefinition.Icom.ic9700")
    public static func icomIC9700(civAddress: UInt8? = nil) -> RadioDefinition {
        Icom.ic9700(civAddress: civAddress)
    }
    // … one alias per old name
}
```

Same treatment for `RadioCapabilitiesDatabase`.

This is the change that, every day we wait, more consumers ship
code against the current shape and the migration gets noisier.
Worth doing in the next big release window.

### Why extract the rigctld bridge (item 2)

`Sources/RigControl/Network/` is ~2,200 lines and is the only
piece of `RigControl` that needs `import Network`. Most native
macOS apps integrating SwiftRigControl don't want to expose a
TCP server — that's a power-user / interoperability feature
(WSJT-X, fldigi, JS8Call). Putting it behind a separate product
lets app developers opt in:

```swift
// Package.swift consumers
.product(name: "RigControl", package: "SwiftRigControl"),
.product(name: "RigControlRigctld", package: "SwiftRigControl"),  // optional
```

Matches the SwiftNIO / Vapor pattern of "core package = what
every consumer needs, peer products = optional surface."

Mitigation for breakage: keep a typealias in `RigControl` and
`@_exported import RigControlRigctld` for one release so existing
call sites compile while users migrate.

### Why NOT split per-vendor sub-products

Hamlib ships per-vendor `.so` libraries for embedded-systems
binary-size reasons. Swift's whole-module optimization + dead-code
stripping + macOS-only scope make that noise here. Apollo doesn't
ship `ApolloIcom` and we shouldn't either.

### Why keep the per-feature `RigController` split (item 5 / Q5)

The natural reading unit *is* a feature (a developer asks "how
does DSP work?", not "what's the second extension method on
RigController?"). Strict concurrency makes diff review harder
when changes are spread across a 5,000-line monolith — small
files make it easy to see exactly which feature is affected.
DocC catalog organization will naturally mirror the file split,
which is good.

Apollo iOS, SwiftNIO, and Vapor all do smaller-per-feature files.
The standard library's monolithic `Array.swift` model is a poor
reference because the standard library has a single audience
reading from one direction; library code with many feature
groups and many contributors benefits from the split.

The only smell worth fixing: a few names are confusable. That's
item 5 above.

### Why the capability database layout is fine (Q3)

The Hamlib model (one `ic7300.c` per radio) is right for C
because each model file owns *both* the capability struct *and*
the rig-specific overrides. In SwiftRigControl those concerns
are already separated: per-radio behavior lives in
`Protocols/Icom/CommandSets/` and `Protocols/Icom/RadioExtensions/`,
while the capability literal is a static `let` that's never
read by anyone but the factory. One-file-per-radio for a 30-line
`static let` would be ceremony.

Current per-vendor-segment split (`+IcomCompact`, `+IcomFlagships`,
`+IcomLegacy`) is doing its job. The one cleanup: `+Icom.swift`
(854 lines, 15 factories) looks like the "didn't get sorted yet"
bucket. Redistribute into the era-specific files so every
filename describes its contents (item 4).

## Additional repo-root cleanup (item 3)

Files currently at the repo root that should move or be deleted:

- `IC-7100 CIV.pdf` → `Documentation/Manufacturer/`
- `KIO2 Pgmrs Ref rev E.pdf` → `Documentation/Manufacturer/`
- `Icom CI-V Manuals/` → `Documentation/Manufacturer/Icom/`
- `test_ic7100_ptt.sh` → `Scripts/` or `Tools/`
- `RELEASE_NOTES_v1.0.4.md` → delete (CHANGELOG has the content)
   or move to `Documentation/`
- `Sources/.DS_Store` → add `.DS_Store` to `.gitignore`; remove
  from history at next convenient commit

## Documentation split (item 7)

`Documentation/` currently has 13+ ad-hoc `.md` files that
overlap heavily with the DocC catalog at
`Sources/RigControl/RigControl.docc/Articles/`. Decide which is
authoritative:

**Recommended split:**

- **DocC catalog** = canonical user-facing documentation. Anything
  a developer integrating SwiftRigControl reads.
- **`Documentation/`** = contributor-facing planning and history.
  Audits, parity plans, migration guides, design rationale.

Specifically:

| Current location | Recommended location |
|------------------|---------------------|
| `Documentation/USAGE_EXAMPLES.md` | Stays — too long for DocC |
| `Documentation/API_REFERENCE.md` | Delete — DocC is canonical now |
| `Documentation/HAMLIB_PARITY.md` | Keep in `Documentation/` |
| `Documentation/HAMLIB_MIGRATION.md` | DocC has a `HamlibMigration.md` article; pick one |
| `Documentation/AUDIT_2026-05-28.md` | Keep — historical record |
| `Documentation/V12_PARITY_PLAN.md` | Keep — internal planning |
| `Documentation/PARITY_IMPLEMENTATION_GUIDE.md` | Keep — contributor onboarding |
| `Documentation/STRUCTURAL_REVIEW.md` | Keep — this doc |
| `Documentation/IC7600_API_GUIDE.md` | Delete or merge into DocC if still relevant |
| `Documentation/NETWORK_CONTROL.md` | Move content into DocC `RigctldBridge.md`; this is user-facing |
| `Documentation/SERIAL_PORT_GUIDE.md` | Move into DocC; user-facing |
| `Documentation/TROUBLESHOOTING.md` | Move into DocC; user-facing |
| `Documentation/XPC_HELPER_GUIDE.md` | Move into DocC; user-facing |
| `Documentation/ADDING_RADIOS.md` | DocC `AddingRadios.md` already exists; pick one |

## Recommendation summary

Bundle the **high-leverage public-surface change (item 1)** with
the **directory reshape (item 8)** in a single PR, since both
touch the public namespace. Do the **rigctld extraction (item 2)**
as a separate PR. The remaining cleanups (items 3-7) are
incremental and can happen on quiet days.

The rest of the package is in good shape. Keep building features.
