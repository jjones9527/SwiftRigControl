# Radio parity — target list for v1.2.0

This is the audit that scopes SwiftRigControl v1.2.0. The instruction was:
**"~50 of the most recently released radios we don't cover, plus new
vendors to match Hamlib's amateur-radio coverage."** This file records
both the numbers behind the pick and the specific 50 radios selected,
so future contributors can see the decision framework rather than just
the result.

See `HAMLIB_PARITY.md` for the separate **feature/command**-level parity
audit (VFO ops, function toggles, secondary levels, etc.). That file
tracks whether we expose Hamlib's *API surface*; this file tracks
whether we cover Hamlib's *radio list*.

## The gap in numbers

- **Hamlib `include/hamlib/riglist.h`:** 379 `RIG_MODEL_*` entries
  across 42 vendor groups (as of Hamlib master @ `083a748`, 2026-07-24).
- **SwiftRigControl v1.1.3:** 103 radios across 8 vendors.
- **Diff (in-scope vendors only):** 231 radios in Hamlib that
  SwiftRigControl doesn't ship.

"In-scope" here follows CLAUDE.md's stated scope: no rotators, no
amplifiers, no vintage pre-CAT, macOS + amateur focus. The out-of-scope
Hamlib vendor groups excluded from the diff are: Dummy, ADAT (test
rigs), Barrett / Codan / ICMarine (marine SSB), EK / RS (Rohde-Schwarz
commercial), Harris / Motorola / MDS (military and commercial), Kachina
/ Gomspace / TAPR (satellite / packet), Racal / RFT / PRM80 / Skanti /
WJ (military / commercial), Simplecat (single kit), Tuner (tuners),
Dorji (single-chip modules), Kit (~18 SDR kits that are more "software
toys" than radios — evaluated case-by-case).

## Selection framework for the top 50

Radios ranked by:

1. **Release recency.** Newer radios first — a 2024 flagship gets
   priority over a 1995 legacy HF. Estimated release years come from
   manufacturer knowledge; where uncertain, cited from Hamlib source
   file comments (e.g. `hamgeek.c` header comment cites 2026 addition).
2. **Operator prevalence.** Currently-produced radios rank ahead of
   discontinued ones. Chinese-market SDRs (Guohetec, Xiegu, Hamgeek)
   count as high-prevalence because they're the fastest-growing amateur
   segment.
3. **Protocol reuse ease.** Where two radios of similar recency tie,
   the one reusing an existing SwiftRigControl protocol adapter
   (Kenwood text, Yaesu newcat, Icom CI-V) ranks ahead of the one
   needing a new adapter.
4. **Amateur-radio focus.** Marine, military, and pure-commercial
   radios drop off the list even when recent.

## v1.2.0 target: 50 radios + 6 new vendor protocol adapters

Grouped by vendor / protocol family for batching efficiency.

### Group A: Flagship 2023-2025 releases (7 radios) — highest priority

| # | Model | Vendor | Hamlib source | ~Year | Reuse | Effort |
|---|---|---|---|---|---|---|
| 1 | FTX-1 | Yaesu | `rigs/yaesu/ftx1_*.c` (15 files) or `ftx1_mono.c` | 2025 | reuse (newcat) + likely new commands | ~2 days |
| 2 | ID-52A/E Plus | Icom | `rigs/icom/id52plus.c` | 2024 | reuse-existing (CI-V) | ~2 hours |
| 3 | Q900 | Guohetec | `rigs/guohetec/q900.c` | 2024 | **new-vendor-protocol** | ~1 day |
| 4 | PMR-171 | Guohetec | `rigs/guohetec/pmr171.c` | 2023 | reuse (same guohetec adapter) | ~4 hours |
| 5 | Hamgeek uSDX | Kenwood family | `rigs/kenwood/hamgeek.c` | 2024 | reuse-existing (TS-480 subset over BT) | ~4 hours |
| 6 | QRP Labs QMX | Kenwood family | `rigs/kenwood/ts480.c` (in-file entry) | 2023 | reuse-existing (Kenwood TS-480 subset) | ~2 hours |
| 7 | (tr)uSDX | Kenwood family | `rigs/kenwood/ts480.c` (in-file entry) | 2022 | reuse-existing (Kenwood TS-480 subset) | ~2 hours |

### Group B: Chinese / active-market DMR + tri-band (1 radio)

| # | Model | Vendor | Hamlib source | ~Year | Reuse | Effort |
|---|---|---|---|---|---|---|
| 8 | AT-D578UVIII | Anytone | `rigs/anytone/anytone.c` | 2023 | **new-vendor-protocol** | ~1 day |

### Group C: Compact/kit HF + Elad (3 radios)

| # | Model | Vendor | Hamlib source | ~Year | Reuse | Effort |
|---|---|---|---|---|---|---|
| 9 | FDM-DUO | Elad | `rigs/elad/fdm_duo.c` | 2015 (still selling) | **new-vendor-protocol** | ~1 day |
| 10 | CTX-10 | CommRadio | `rigs/commradio/ctx10.c` | 2019 | **new-vendor-protocol** (small — 95 LOC) | ~4 hours |
| 11 | Malahit-DSP | Kenwood family | `rigs/kenwood/ts480.c` | 2021 | reuse-existing (TS-480 subset) | ~2 hours |

### Group D: Icom missing modern (7 radios)

All reuse the existing `IcomCIVProtocol`. Radios still in production
or recently discontinued that Hamlib supports but SwiftRigControl
doesn't.

| # | Model | Vendor | Hamlib source | ~Year | Reuse | Effort |
|---|---|---|---|---|---|---|
| 12 | IC-R6 | Icom | `rigs/icom/icr6.c` | 2009 (still sold) | reuse-existing | ~2 hours |
| 13 | IC-R20 | Icom | `rigs/icom/icr20.c` | 2004 | reuse-existing | ~2 hours |
| 14 | IC-R7100 | Icom | `rigs/icom/icr7000.c` (shared) | 1993 | reuse-existing | ~1 hour |
| 15 | IC-F8101 | Icom | `rigs/icom/icf8101.c` | 2010 | reuse-existing (HF SSB, borderline commercial) | ~2 hours |
| 16 | ID-1 | Icom | `rigs/icom/id1.c` | 2004 (first D-STAR) | reuse-existing | ~1 hour |
| 17 | IC-RX7 | Icom | `rigs/icom/icrx7.c` | 2007 | reuse-existing | ~1 hour |
| 18 | IC-910 (base) | Icom | `rigs/icom/ic910.c` | 2001 (base variant of already-shipped 910H) | reuse-existing | ~1 hour |

### Group E: Kenwood mobile/handheld modern (4 radios)

| # | Model | Vendor | Hamlib source | ~Year | Reuse | Effort |
|---|---|---|---|---|---|---|
| 19 | TM-D710 | Kenwood | `rigs/kenwood/tmd710.c` | 2007 (still sold) | reuse-existing (text) | ~4 hours |
| 20 | TM-V71 | Kenwood | `rigs/kenwood/tmv7.c` (family) | 2005 (still sold) | reuse-existing | ~2 hours |
| 21 | TH-F6A | Kenwood | `rigs/kenwood/thf6a.c` | 2001 | reuse-existing | ~2 hours |
| 22 | TH-F7E | Kenwood | `rigs/kenwood/thf7.c` | 2001 | reuse-existing | ~2 hours |

### Group F: Yaesu legacy HF still-common (5 radios)

| # | Model | Vendor | Hamlib source | ~Year | Reuse | Effort |
|---|---|---|---|---|---|---|
| 23 | FT-1000MP MkV | Yaesu | `rigs/yaesu/ft1000mp.c` | 1999 (still on-air) | reuse-existing (classic) | ~2 hours |
| 24 | FT-1000MP MkV Field | Yaesu | `rigs/yaesu/ft1000mp.c` | 2000 | reuse-existing | ~1 hour |
| 25 | FT-847UNI | Yaesu | `rigs/yaesu/ft847.c` | 2000 (region variant) | reuse-existing | ~1 hour |
| 26 | VX-1700 | Yaesu | `rigs/yaesu/vx1700.c` | 2007 (HF SSB, borderline commercial) | reuse-existing (own file — new CommandSet) | ~4 hours |
| 27 | mcHF QRP | Yaesu-family kit | `rigs/yaesu/newcat.c` entry | ~2015 kit | reuse-existing | ~2 hours |

### Group G: Kenwood legacy HF still-common on the air (5 radios)

| # | Model | Vendor | Hamlib source | ~Year | Reuse | Effort |
|---|---|---|---|---|---|---|
| 28 | TS-450S | Kenwood | `rigs/kenwood/ts450s.c` | 1991 | reuse-existing | ~2 hours |
| 29 | TS-690S | Kenwood | `rigs/kenwood/ts690.c` | 1992 | reuse-existing | ~2 hours |
| 30 | TS-940 | Kenwood | `rigs/kenwood/ts940.c` | 1985 | reuse-existing | ~2 hours |
| 31 | TS-950S | Kenwood | `rigs/kenwood/ts950.c` (family) | 1988 | reuse-existing | ~2 hours |
| 32 | TS-950SDX | Kenwood | `rigs/kenwood/ts950.c` (family) | 1991 | reuse-existing | ~1 hour |

### Group H: FlexRadio SmartSDR variants (8 radios)

The Flex 6000-series uses TCP CAT we already implement. SmartSDR A-H
are variant labels for different concurrent-connection slots. All
reuse the existing `Flex.flex6000` protocol; each is essentially a
factory + capabilities entry.

| # | Model | Vendor | Hamlib source | ~Year | Reuse | Effort |
|---|---|---|---|---|---|---|
| 33 | SmartSDR-A | Flex | `rigs/kenwood/flex6xxx.c` | 2014+ | reuse-existing | ~1 hour |
| 34 | SmartSDR-B | Flex | `rigs/kenwood/flex6xxx.c` | 2014+ | reuse-existing | ~1 hour |
| 35 | SmartSDR-C | Flex | `rigs/kenwood/flex6xxx.c` | 2014+ | reuse-existing | ~1 hour |
| 36 | SmartSDR-D | Flex | `rigs/kenwood/flex6xxx.c` | 2014+ | reuse-existing | ~1 hour |
| 37 | SmartSDR-E | Flex | `rigs/kenwood/flex6xxx.c` | 2014+ | reuse-existing | ~1 hour |
| 38 | SmartSDR-F | Flex | `rigs/kenwood/flex6xxx.c` | 2014+ | reuse-existing | ~1 hour |
| 39 | SmartSDR-G | Flex | `rigs/kenwood/flex6xxx.c` | 2014+ | reuse-existing | ~1 hour |
| 40 | SmartSDR-H | Flex | `rigs/kenwood/flex6xxx.c` | 2014+ | reuse-existing | ~1 hour |

### Group I: SDR-Console + Flex kits (3 radios)

| # | Model | Vendor | Hamlib source | ~Year | Reuse | Effort |
|---|---|---|---|---|---|---|
| 41 | SDR-Console | Flex family | `rigs/kenwood/flex.c` | 2018+ ongoing | reuse-existing (Kenwood-derived) | ~2 hours |
| 42 | HPSDR / piHPSDR | Kenwood family | `rigs/kenwood/pihpsdr.c` | 2015+ | reuse-existing (Kenwood-derived) | ~4 hours |
| 43 | Elecraft F6K | Flex family | `rigs/kenwood/flex.c` | (Flex-based compat) | reuse-existing | ~1 hour |

### Group J: Ten-Tec RX-series receivers (3 radios)

| # | Model | Vendor | Hamlib source | ~Year | Reuse | Effort |
|---|---|---|---|---|---|---|
| 44 | RX-320 | Ten-Tec | `rigs/tentec/rx320.c` | 2001 | reuse-existing (Ten-Tec Legacy variant) | ~2 hours |
| 45 | RX-340 | Ten-Tec | `rigs/tentec/rx340.c` | 2002 | reuse-existing | ~2 hours |
| 46 | RX-350 | Ten-Tec | `rigs/tentec/rx350.c` | 2003 | reuse-existing | ~2 hours |

### Group K: Alinco compact HF (2 radios)

| # | Model | Vendor | Hamlib source | ~Year | Reuse | Effort |
|---|---|---|---|---|---|---|
| 47 | DX-SR8 | Alinco | `rigs/alinco/dx77.c` (family) | 2010 | **new-vendor-protocol** | ~1 day |
| 48 | DX-77 | Alinco | `rigs/alinco/dx77.c` | 1996 (still on-air) | reuse (same Alinco adapter) | ~2 hours |

### Group L: AOR wideband amateur receivers (2 radios)

The AOR line has 16 models in Hamlib. The two most-recent
amateur-facing wideband receivers are picked here; the rest fall
below the 50-radio cutoff.

| # | Model | Vendor | Hamlib source | ~Year | Reuse | Effort |
|---|---|---|---|---|---|---|
| 49 | AR-8600 | AOR | `rigs/aor/ar8600.c` | 2001 | **new-vendor-protocol** | ~1 day |
| 50 | AR-7030+ | AOR | `rigs/aor/ar7030.c` | 2003 (rare — professional HF receiver still respected by DXers) | reuse (same AOR adapter) | ~4 hours |

## New vendor adapters added by this release

Six new `Sources/RigControl/Protocols/<Vendor>/` folders:

- **Guohetec** — for PMR-171, Q900. New `GuohetecProtocol.swift`.
  Chinese HF SDR line, growing operator base.
- **Anytone** — for AT-D578UVIII. New `AnytoneProtocol.swift`.
  Tri-band DMR flagship.
- **Elad** — for FDM-DUO. New `EladProtocol.swift`.
  Italian compact HF, distinct binary protocol.
- **CommRadio** — for CTX-10. New `CommRadioProtocol.swift`.
  Small protocol (~95 LOC in Hamlib), amateur-focused.
- **Alinco** — for DX-77, DX-SR8. New `AlincoProtocol.swift`.
  Japanese amateur HF, budget-market presence.
- **AOR** — for AR-8600, AR-7030+. New `AORProtocol.swift`.
  Wideband amateur receivers.

Each new vendor also gets:
- A new `RadioDefinition.Manufacturer` enum case (additive — see note
  below on consumer impact).
- A new `RadioCapabilitiesDatabase+<Vendor>.swift`.
- A new `<Vendor>Models.swift`.
- Entry in `RadioDefinition+Catalog.swift` for the vendor's
  `allRadios` array.
- Rows in `Tests/RigControlTests/UnitTests/RadioCatalogDriftTests.swift`.
- Path mapping in `Scripts/hamlib-diff.sh` `hamlib_to_swift()`.
- Entries in `HAMLIB_WATCH.md`.

## Effort estimate

Rough hour counts across the 50 radios:

- **~15 hours** — the 27 radios that reuse an existing protocol adapter
  (mostly ~1-2 hours each: capabilities entry + factory + drift-test row).
- **~1.5 days** — FTX-1 alone (largest single port; new subsystems in
  Hamlib's `ftx1_*.c` files).
- **~5 days** — new-vendor protocol adapters (~1 day each for
  Guohetec, Anytone, Elad, Alinco, AOR + ~½ day for CommRadio).
- **~1 day** — plumbing (Manufacturer enum expansion, `allRadios`
  arrays, drift test, `HAMLIB_WATCH.md` mapping, `hamlib_to_swift()`
  in the digest script, CHANGELOG, ROADMAP).

**Total: roughly 3 weeks part-time / 8-10 focused workdays** for a
definition-only v1.2.0 with no hardware verification of any new
radio. Hardware verification remains a separate promotion path per
CLAUDE.md — the current 5-radio verified tier is unchanged by this
release.

## What v1.2.0 does NOT include

Explicit non-goals kept honest so future contributors don't file
"why isn't X in here?" issues:

- **AOR wideband scanners beyond AR-8600 / AR-7030+** — 14 further
  AOR models (AR-3000, AR-5000, AR-8200, etc.) exist in Hamlib; they
  fall below the 50-radio cutoff and mostly target commercial /
  monitoring use. Follow-up in v1.3.0 if operator demand appears.
- **UNIDEN scanners** (12 in Hamlib) — consumer scanners, not amateur
  transceivers. Out-of-scope per CLAUDE.md.
- **WINRADIO** (11 in Hamlib) — Windows-first SDR line. Out-of-scope
  for a macOS library.
- **RadioShack scanners** (6) — consumer scanners.
- **Microtune / PCR** receivers — consumer wideband receivers.
- **Vintage Icom pre-CAT** (IC-271, IC-275, IC-471, IC-475, IC-1271,
  IC-1275, IC-575, IC-707, IC-725, IC-726, IC-728, IC-729, IC-731,
  IC-736, IC-737, IC-738, IC-761, IC-765, IC-775, IC-781, IC-820,
  IC-821H, IC-78, MiniScout, Xplorer, OMNI-VI, OS-535, ParagonII,
  Delta-II — 27 models) — pre-CAT or early-CAT vintage, most from
  the 1980s / early 1990s. Follow-up releases if operator demand
  materializes; low priority.
- **KIT vendor SDRs** (18) — mostly software toys (SoftRock, DDS-60,
  MiniVNA, FunCube dongles). FunCube Dongle+ is arguably worth
  including in a future release; the rest are outside scope.
- **JRC NRD receivers** (7) — Japanese commercial-grade shortwave
  receivers. Follow-up if demand appears.
- **Drake DKR-8/A/B** — vintage American HF receivers (1980s).
  Out-of-scope pre-CAT vintage.
- **Lowe HF-150/225/250/235** — British receiver specialist; vintage.
  Out-of-scope.

## Release cadence going forward

- **v1.2.0** — this batch of 50 radios + 6 new vendors. Target ship
  date: ~3 weeks from start.
- **v1.3.0+** — the digest workflow will keep flagging new Hamlib
  additions weekly. Each new digest becomes a mini-batch for the
  next minor. Expect v1.3.0 to be smaller (5-10 radios) and driven
  by whatever Hamlib merges in the interim.
- **No parity aspiration beyond ~230 radios** — CLAUDE.md's scope
  rule stays in force: no rotators, no amplifiers, no vintage
  pre-CAT, no pure commercial / marine / military. The 149 Hamlib
  radios excluded from this release stay excluded until either
  (a) operator demand justifies the case-by-case reversal or
  (b) SwiftRigControl's scope is formally widened.

## Manufacturer enum expansion

`RadioDefinition.Manufacturer` currently has 9 cases (icom, elecraft,
yaesu, kenwood, xiegu, tentec, lab599, flex, dummy). v1.2.0 adds:

- `.guohetec`
- `.anytone`
- `.elad`
- `.commradio`
- `.alinco`
- `.aor`

**This is additive** but is technically a breaking change for
downstream consumers that exhaustively switch on the enum without a
`default:` arm. The CHANGELOG entry for v1.2.0 will call this out
explicitly and recommend that consumers add a `default:` arm to any
`Manufacturer` switch, so future minors can keep adding cases without
another breaking-change note.

Per CLAUDE.md's versioning policy, this remains a minor-version bump
(v1.2.0, not v2.0.0) because the enum is opaque from most downstream
code paths — consumers who don't switch exhaustively see zero impact.
The formal-deprecation-then-removal machinery reserved for v2.0.0
does not apply here (no symbols are removed).

## Suggested implementation order

Land groups in this order to minimize plumbing rework:

1. **Plumbing first** — extend `Manufacturer` enum with the six new
   cases (empty vendor namespaces), update `allRadios(for:)` switch,
   update drift-test structure, extend `HAMLIB_WATCH.md` and
   `hamlib_to_swift()` scaffolding. One coherent PR, no new radios
   yet. Gives every subsequent PR clean edit surfaces.
2. **Reuse-existing radios by vendor** (Groups D, E, F, G, H, I, J) —
   these are the ~30 radios that just need factories + capability
   entries. Batch by existing vendor (all Icom together, all Kenwood
   together, etc.). ~1-2 hours per radio; one PR per vendor batch.
3. **New-vendor adapters** (Groups A, B, C, K, L) — one adapter per
   PR: Guohetec first (Q900 + PMR-171), then Anytone, Elad,
   CommRadio, Alinco, AOR. Each PR ships the adapter + all radios in
   that new vendor. ~1 day per PR.
4. **FTX-1 last** — the largest single port; deserves its own PR with
   dedicated test coverage. FTX-1's ~15-file backend in Hamlib may
   surface new commands (memory-mode voice, CTCSS/DCS handling,
   clarifier variants) worth exposing as new `Supports*` capability
   traits — do that work carefully rather than rushing to include in
   an omnibus.

## Provenance

- Hamlib catalog extracted from `~/Developer/hamlib/include/hamlib/riglist.h`
  at commit `083a748` (2026-07-24).
- SwiftRigControl catalog from
  `Sources/RigControl/Core/RadioDefinition+Catalog.swift` at v1.1.3
  (`318a160`) plus the drift-test `expectedModels` sets.
- Release-year estimates: manufacturer knowledge; where uncertain,
  cited from Hamlib source-file header comments (e.g. `hamgeek.c`
  cites 2026 addition, `ctx10.c` cites `version = "20240809.0"`).
- Effort estimates: rough per-radio × complexity, not measured.
