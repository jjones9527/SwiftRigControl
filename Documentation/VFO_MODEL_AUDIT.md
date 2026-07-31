# Icom VFO Model Audit (v1.2.5)

**Status:** open — architecture decision pending
**Date audited:** 2026-07-31 (against Hamlib upstream on that date)
**Reference:** Hamlib `rigs/icom/*.c` — `.targetable_vfo` field and
`.x25x26_always` flag; SwiftRigControl
`StandardIcomCommandSet` static factory variants.

This document captures the audit of the `VFOOperationModel`
choice for every named `StandardIcomCommandSet.<radio>` factory
variant, cross-referenced against Hamlib's per-backend flags.

**It is not a fix plan.** No behavior changes have been made
based on these findings. The intent is to record what the
current code does, what Hamlib does for the same radio, and
where the two disagree, so that a future architecture review can
pick this up with the state of the world already documented.

## Why this exists

The `VFOOperationModel` enum has five cases (`.targetable`,
`.currentOnly`, `.mainSub`, `.mainSubDualVFO`, `.none`) that
control two independent wire-format behaviors:

1. **VFO selection opcode payload** — `.targetable`/`.currentOnly`
   emit `0x07 [0x00|0x01]` for VFO A/B. `.mainSub` emits
   `0x07 [0xD0|0xD1]` for Main/Sub receivers, with `.a` / `.b`
   silently falling back to Main/Sub for API compatibility (see
   `IcomRadioCommandSet.selectVFOCommand`).
2. **DATA-mode command shape** — `.targetable` uses the newer
   `0x26` opcode with a 3-byte payload carrying the DATA flag
   inline. Every other case uses the legacy 2-frame form
   (`0x06` base mode + `0x1A 0x06` sub-command to flip the
   DATA bit).

The choice per radio has therefore observable behavioral impact
even though both wire forms are usually accepted by the
firmware.

Hamlib exposes two related but distinct signals per radio:

- **`.targetable_vfo`** — a bitmask (e.g.
  `RIG_TARGETABLE_FREQ | RIG_TARGETABLE_MODE | RIG_TARGETABLE_SPECTRUM`)
  indicating **which per-VFO commands the radio accepts**
  (0x25 for frequency, 0x26 for mode, etc.). A value of `0`
  means the radio requires the "select VFO, then set on
  current" flow.
- **`.x25x26_always`** — a boolean saying whether Hamlib should
  **unconditionally use** the 0x25/0x26 opcodes vs. auto-detect
  their availability at runtime.

Note: `.targetable_vfo` reports the radio's **capability**, not a
**requirement**. Radios with `.targetable_vfo != 0` still accept
the legacy select-then-set flow — the newer opcodes are
optional. This is important context for interpreting the
mismatches below.

## The audit table

Columns:

- **Ships** — the `vfoModel` on the shipped
  `StandardIcomCommandSet.<radio>` factory.
- **Hamlib `.targetable_vfo`** — the bitmask from
  `~/Developer/hamlib/rigs/icom/<radio>.c`. `0` = not targetable.
- **Hamlib `.x25x26_always`** — `1` if Hamlib always emits the
  `0x25/0x26` opcodes; `0` if it auto-detects; `?` if the field
  was not encountered during the sweep (defaults to `0` in
  Hamlib source).
- **Category** — see the legend below the table.

| Radio | Ships | Hamlib `.targetable_vfo` | `.x25x26_always` | Category |
| --- | --- | --- | --- | --- |
| IC-7300 | `.targetable` | `FREQ\|MODE` | 1 | A: matches |
| IC-7610 | `.mainSub` | `FREQ\|MODE\|SPECTRUM` | 1 | B: architecture mismatch |
| IC-7600 | `.mainSub` | `FREQ\|MODE` | 0 | B: architecture mismatch (see E) |
| IC-9100 | `.mainSub` | `0` | 0 | C: dual-receiver over currentOnly-ish |
| IC-7200 | `.currentOnly` | `0` | 0 | A: matches |
| IC-718 | `.currentOnly` | `0` | ? | A: matches |
| IC-703 | `.currentOnly` | `0` | ? | A: matches |
| IC-7410 | `.currentOnly` | `0` | ? | A: matches |
| IC-7700 | `.targetable` | `FREQ\|MODE` | 0 | A: matches |
| IC-7800 | `.mainSub` | `FREQ\|MODE` | 0 | B: architecture mismatch |
| IC-7851 | `.mainSub` | `FREQ\|MODE\|SPECTRUM` | 1 | B: architecture mismatch |
| IC-7000 | `.targetable` | `0` | ? | **D: wrong-direction (highest risk)** |
| IC-910H | `.mainSub` | `0` | ? | C: dual-receiver over currentOnly-ish |
| IC-2730 | `.mainSub` | `0` | ? | C: dual-receiver over currentOnly-ish |
| ID-5100 | `.mainSub` | `0` | ? | C: dual-receiver over currentOnly-ish |
| ID-4100 | `.mainSub` | `0` | ? | C: dual-receiver over currentOnly-ish |
| IC-R8600 | `.targetable` | `0` | ? | D: wrong-direction (receiver) |
| IC-R75 | `.targetable` | `0` | ? | D: wrong-direction (receiver) |
| IC-R9500 | `.targetable` | `0` | ? | D: wrong-direction (receiver) |
| IC-R30 | `.mainSub` | `0` | ? | C: dual-receiver over currentOnly-ish |
| ID-31 | `.currentOnly` | `0` | ? | A: matches |
| ID-51 | `.mainSub` | `0` | ? | C: dual-receiver over currentOnly-ish |
| ID-52 | `.mainSub` | `0` | ? | C: dual-receiver over currentOnly-ish |
| IC-92AD | `.targetable` | `0` | ? | D: wrong-direction (handheld) |
| IC-R6 | `.currentOnly` | `0` | ? | A: matches |
| IC-R20 | `.targetable` | `0` | ? | D: wrong-direction (receiver) |
| IC-R7100 | `.currentOnly` | `0` | ? | A: matches |
| IC-F8101 | `.targetable` | `FREQ` (no MODE) | ? | B-adjacent: partial-target |
| ID-1 | `.targetable` | `0` | ? | D: wrong-direction |
| IC-RX7 | `.currentOnly` | `0` | ? | A: matches |

### Category legend

- **A — Matches Hamlib.** Our choice aligns with Hamlib's
  targetability flag. No action needed.
- **B — Architecture mismatch.** Hamlib flags per-VFO capability
  (`.targetable_vfo != 0`) but we ship `.mainSub`. The catalog
  choice is architecturally defensible (these are dual-receiver
  radios), but produces a specific behavior: `.a` → Main and
  `.b` → Sub instead of proper VFO A/B addressing on the current
  receiver. A caller doing `setFrequency(hz, vfo: .b)` for a
  WSJT-X-style split ends up on the Sub receiver, not on VFO B
  of the currently-selected receiver.
- **C — Dual-receiver over Hamlib-non-targetable.** Hamlib
  treats the radio as non-targetable (`.targetable_vfo = 0`),
  meaning it requires the select-then-set flow. We ship
  `.mainSub`, which also uses select-then-set — just with
  Main/Sub `0xD0/0xD1` codes instead of VFO A/B `0x00/0x01`.
  Whether Main/Sub or A/B is the correct addressing depends on
  the radio's own architecture: these are all dual-receiver
  models, so `.mainSub` may well be right — but the semantic is
  "callers using `.a`/`.b` will actually get Main/Sub." Same
  contract issue as Category B, lower severity because the
  radios genuinely have a Main/Sub distinction.
- **D — Wrong-direction mismatch.** Hamlib flags the radio as
  non-targetable, but we ship `.targetable`. Consequence:
  - VFO select emits standard `0x07 [0x00|0x01]` which the radio
    accepts. No wire-format break there.
  - `setDataModeCommand` emits the `0x26` opcode. If the radio
    firmware doesn't accept `0x26`, the DATA-mode set fails
    silently (the two-frame legacy form was skipped).
  - **IC-7000 is the highest concern** — it is a shipped HF/VHF
    mobile with active users, and Hamlib treats it as
    non-targetable. If IC-7000 firmware rejects `0x26`, DATA
    modes (RTTY, PSK, FT8 via digital-mode audio) are broken
    for every SwiftRigControl-driven session. Requires
    verification against the IC-7000 CI-V manual or a hardware
    validator run before making a determination.
  - Receivers (IC-R8600, IC-R75, IC-R9500, IC-R20) don't
    transmit, so the DATA-mode divergence is moot; the
    wrong-direction is cosmetic.
  - IC-92AD, ID-1 are legacy D-STAR handhelds with limited
    real-world CAT use; low priority.

### Public API contract cross-check

The `VFO.swift` docstring today claims:

> - Single-receiver radios (IC-7100, IC-7600, K2, FT-891,
>   TS-590SG, etc.) only expose `.a` and `.b`.
> - Dual-receiver radios (IC-9700, IC-7300 D-version, etc.)
>   expose `.main` and `.sub` in addition to `.a` / `.b`.

That contract does **not** match the shipped catalog:

1. It lists IC-7600 as single-receiver, but the code ships
   IC-7600 as `.mainSub`, silently mapping `.a` → Main and
   `.b` → Sub. **Contract mismatch (Category E).**
2. It does not mention the dozen-plus other radios shipped as
   `.mainSub` — IC-7610, IC-7800, IC-7851, IC-9100, IC-910H,
   IC-2730, ID-5100, ID-4100, IC-R30, ID-51, ID-52. Users
   reading the doc would not know that `.a` addresses Main on
   these models.

Meanwhile, `VFOOperationModel` docstrings list example radios
per case that do not match the shipped catalog either:

- `.targetable` example list includes IC-7610 and IC-7800, but
  they ship as `.mainSub`.
- `.mainSubDualVFO` example list includes IC-9100, but it
  ships as plain `.mainSub`.
- `.none` example list includes IC-R75 and IC-R8600, but both
  ship as `.targetable`.

And in `IcomRadioCommandSet.swift`:

- The `supportsTargetableMode` docstring claims IC-7610 /
  IC-7800 / IC-7851 use the `0x26` opcode "as the Hamlib-
  preferred path for DATA mode." Because they ship as
  `.mainSub`, `supportsTargetableMode` returns `false` for
  them and they take the legacy `0x1A 0x06` path instead.
  Stale comment.

## Recommended sequence (not a plan yet)

1. **Doc reconciliation** (this document + inline doc edits) —
   describe what the code does today, honestly, without
   locking in an architecture call. **Safe, zero code risk.**
2. **IC-7000 investigation** — highest-severity item on the
   audit. Requires either an IC-7000 CI-V manual review or a
   hardware validator run to determine whether `0x26` is
   accepted. If not, flip to `.currentOnly` (matches Hamlib).
3. **IC-7610 / IC-7600 / IC-7800 / IC-7851 architecture
   decision** — needs a "what does a WSJT-X-style caller
   expect from `vfo: .b`?" discussion. If the answer is
   "proper VFO A/B addressing on the current receiver," flip
   to `.targetable`. If the answer is "target the Sub
   receiver on a dual-receiver radio," keep `.mainSub` and
   fix the public docs to say so.
4. **Category D receiver cleanup** — IC-R8600 / IC-R75 /
   IC-R9500 / IC-R20 to `.none` or `.currentOnly` to match
   Hamlib. Cosmetic.
5. **`VFOOperationModel` example lists** — update once (2)–(4)
   are settled.

## Sourcing

Every Hamlib flag in the table above was extracted by grep from
`~/Developer/hamlib/rigs/icom/<radio>.c`. Verification command
recorded in the v1.2.5 CHANGELOG. The `.x25x26_always` field
also appears on radios not yet swept ("`?`" in the table);
absent explicit reads, Hamlib treats those as `0` (auto-detect).
The catalog-drift regression tests in
`Tests/RigControlTests/UnitTests/StandardIcomCommandSetVariantsTests.swift`
lock the `civAddress` and `echoesCommands` fields against
Hamlib but intentionally do not lock `vfoModel` — that field's
correctness is exactly what this audit is investigating.
