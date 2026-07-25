# Hamlib upstream watch list

SwiftRigControl re-implements per-radio CAT logic that originates in
Hamlib (`https://github.com/Hamlib/Hamlib`). Each radio SwiftRigControl
supports has one or more Hamlib source files that describe the same
radio's protocol quirks. When Hamlib fixes a bug or ships a change
against those files, we want to know so we can decide whether to port
the fix.

This file is the **source of truth for the path-scoped diff** the
`Scripts/hamlib-diff.sh` script runs against the upstream Hamlib
repository. Every path in the "Hamlib source" column feeds a
`git log -- <path>` filter. If a path listed here goes missing on
disk when the script runs, the script warns loudly — Hamlib
occasionally renames files during refactors and we want to catch
that.

## How to update this file

- **New radio added to SwiftRigControl:** add a row to the matching
  vendor table with the Hamlib source file(s) the port was based on.
  If Hamlib doesn't yet support the radio (rare — usually us following
  them), mark the Hamlib column as `— (not in Hamlib as of <date>)`.
- **Hamlib renames a file:** update the path here in the same commit
  as any code changes triggered by the rename.
- **SwiftRigControl removes a radio:** delete the row.

## Shared / cross-vendor Hamlib sources

These are watched independently of per-radio rows because a change
here potentially affects **every** radio in that family. The script
always includes them in the diff scope.

| Hamlib source | Covers |
| --- | --- |
| `rigs/icom/icom.c` | Every Icom CI-V radio — shared framing, mode setter, filter-byte encoding |
| `rigs/icom/icom.h` | Shared Icom CI-V types and macros |
| `rigs/icom/frame.c` | CI-V frame builder / parser (if present in this Hamlib version) |
| `rigs/kenwood/kenwood.c` | Every Kenwood text-protocol radio + Elecraft K-series + Lab599 TX-500 + FlexRadio |
| `rigs/kenwood/kenwood.h` | Shared Kenwood types |
| `rigs/kenwood/elecraft.c` | Shared Elecraft K-series command set |
| `rigs/yaesu/newcat.c` | Shared modern-Yaesu (FTDX / FT-991 / FT-710) command implementation |
| `rigs/yaesu/newcat.h` | Shared Yaesu newcat types |
| `rigs/yaesu/yaesu.c` | Shared classic-Yaesu framing |
| `rigs/tentec/tentec.c` | Shared Ten-Tec framing |
| `rigs/tentec/tentec.h` | Shared Ten-Tec types |
| `include/hamlib/rig.h` | Top-level `rig_caps` API — semantic changes affect our `CATProtocol` design |

## Per-radio mapping

### Icom (51 radios)

| SwiftRigControl radio | Hamlib source |
| --- | --- |
| IC-703 | `rigs/icom/ic703.c` |
| IC-705 | `rigs/icom/icom.c` (defined inline; no dedicated file as of Hamlib 4.7.x) |
| IC-706 | `rigs/icom/ic706.c` |
| IC-706MKII | `rigs/icom/ic706.c` |
| IC-706MKIIG | `rigs/icom/ic706.c` |
| IC-7000 | `rigs/icom/ic7000.c` |
| IC-7100 | `rigs/icom/ic7100.c` |
| IC-718 | `rigs/icom/ic718.c` |
| IC-7200 | `rigs/icom/ic7200.c` |
| IC-7300 | `rigs/icom/ic7300.c` |
| IC-7300MK2 | `rigs/icom/ic7300.c` (Hamlib treats MK2 as an IC-7300 variant) |
| IC-735 | `rigs/icom/ic735.c` |
| IC-7400 (IC-746PRO EU) | `rigs/icom/ic7300.c` (referenced in ic7300.c comments); primary is `rigs/icom/ic746.c` |
| IC-7410 | `rigs/icom/ic7410.c` |
| IC-746 | `rigs/icom/ic746.c` |
| IC-746PRO | `rigs/icom/ic746.c` |
| IC-751 | `rigs/icom/ic751.c` |
| IC-756 | `rigs/icom/ic756.c` |
| IC-756PRO | `rigs/icom/ic756.c` |
| IC-756PROII | `rigs/icom/ic756.c` |
| IC-756PROIII | `rigs/icom/ic756.c` |
| IC-7600 | `rigs/icom/ic7600.c` |
| IC-7610 | `rigs/icom/ic7610.c` |
| IC-7700 | `rigs/icom/ic7700.c` |
| IC-7760 | `rigs/icom/ic7760.c` |
| IC-7800 | `rigs/icom/ic7800.c` |
| IC-7850 | `rigs/icom/ic785x.c` |
| IC-7851 | `rigs/icom/ic785x.c` |
| IC-820H | `rigs/icom/ic820h.c` |
| IC-905 | `rigs/icom/ic7300.c` (Hamlib references IC-905 alongside IC-7300 family) |
| IC-9100 | `rigs/icom/ic9100.c` |
| IC-910H | `rigs/icom/ic910.c` |
| IC-92D | `rigs/icom/ic92d.c` |
| IC-970 | `rigs/icom/ic970.c` |
| IC-9700 | `rigs/icom/ic9100.c` (shared CI-V family; also cross-referenced in ic7300.c) |
| IC-R30 | `rigs/icom/icr30.c` |
| IC-R75 | `rigs/icom/icr75.c` |
| IC-R8600 | `rigs/icom/icr8600.c` |
| IC-R9500 | `rigs/icom/icr9500.c` |
| IC-2730 | `rigs/icom/ic2730.c` |
| ID-31 | `rigs/icom/id31.c` |
| ID-4100 | `rigs/icom/id4100.c` |
| ID-51 | `rigs/icom/id51.c` |
| ID-5100 | `rigs/icom/id5100.c` |
| ID-52 | `rigs/icom/id52plus.c` |
| IC-R6 | `rigs/icom/icr6.c` (v1.2.0) |
| IC-R20 | `rigs/icom/icr20.c` (v1.2.0) |
| IC-R7100 | `rigs/icom/icr7000.c` (v1.2.0 — shared with IC-R7000 in Hamlib) |
| IC-F8101 | `rigs/icom/icf8101.c` (v1.2.0) |
| IC ID-1 | `rigs/icom/id1.c` (v1.2.0) |
| IC-RX7 | `rigs/icom/icrx7.c` (v1.2.0) |

### Yaesu (30 radios)

| SwiftRigControl radio | Hamlib source |
| --- | --- |
| FT-100 | `rigs/yaesu/ft100.c` |
| FT-1000MP | `rigs/yaesu/ft1000mp.c` |
| FT-2000 | `rigs/yaesu/ft2000.c` |
| FT-450 | `rigs/yaesu/ft450.c` |
| FT-450D | `rigs/yaesu/ft450.c` |
| FT-710 | `rigs/yaesu/ft710.c` |
| FT-817 | `rigs/yaesu/ft817.c` |
| FT-818 | `rigs/yaesu/ft817.c` (Hamlib treats FT-818 as an 817 variant) |
| FT-847 | `rigs/yaesu/ft847.c` |
| FT-857 | `rigs/yaesu/ft857.c` |
| FT-857D | `rigs/yaesu/ft857.c` |
| FT-891 | `rigs/yaesu/ft891.c` |
| FT-897 | `rigs/yaesu/ft897.c` |
| FT-897D | `rigs/yaesu/ft897.c` |
| FT-920 | `rigs/yaesu/ft920.c` |
| FT-950 | `rigs/yaesu/ft950.c` |
| FT-991 | `rigs/yaesu/ft991.c` |
| FT-991A | `rigs/yaesu/ft991.c` |
| FTDX-10 | `rigs/yaesu/ftdx10.c` |
| FTDX-101D | `rigs/yaesu/ftdx101.c` |
| FTDX-101MP | `rigs/yaesu/ftdx101mp.c` |
| FTDX-1200 | `rigs/yaesu/ft1200.c` |
| FTDX-3000 | `rigs/yaesu/ft3000.c` |
| FTDX-5000 | `rigs/yaesu/ft5000.c` |
| FTDX-9000 | `rigs/yaesu/ft9000.c` |
| FT-847UNI | `rigs/yaesu/ft847.c` (v1.2.0) |
| mcHF QRP | `rigs/yaesu/ft847.c` (v1.2.0) |
| FT-1000MP MARK-V | `rigs/yaesu/ft1000mp.c` (v1.2.0) |
| FT-1000MP MARK-V Field | `rigs/yaesu/ft1000mp.c` (v1.2.0) |
| FTX-1 | `rigs/yaesu/ftx1/*.c` (v1.2.0 — 18-file subsystem in Hamlib; core in ftx1.c / ftx1_freq.c / ftx1_mode.c) |

### Kenwood (20 radios)

| SwiftRigControl radio | Hamlib source |
| --- | --- |
| TH-D72 | `rigs/kenwood/thd72.c` |
| TH-D72A | `rigs/kenwood/thd72.c` |
| TH-D74 | `rigs/kenwood/thd74.c` |
| TH-D75 | — (not in Hamlib as of 4.7.2; watch `rigs/kenwood/thd74.c` as the closest analogue) |
| TS-2000 | `rigs/kenwood/ts2000.c` |
| TS-480HX | `rigs/kenwood/ts480.c` |
| TS-480SAT | `rigs/kenwood/ts480.c` |
| TS-570D | `rigs/kenwood/ts570.c` |
| TS-570S | `rigs/kenwood/ts570.c` |
| TS-590S | `rigs/kenwood/ts590.c` |
| TS-590SG | `rigs/kenwood/ts590.c` |
| TS-850S | `rigs/kenwood/ts850.c` |
| TS-870S | `rigs/kenwood/ts870s.c` |
| TS-890S | `rigs/kenwood/ts890s.c` |
| TS-990S | `rigs/kenwood/ts990s.c` |
| TS-450S | `rigs/kenwood/ts450s.c` (v1.2.0) |
| TS-690S | `rigs/kenwood/ts690.c` (v1.2.0) |
| TS-940S | `rigs/kenwood/ts940.c` (v1.2.0) |
| TS-950S | `rigs/kenwood/ts950.c` (v1.2.0) |
| TS-950SDX | `rigs/kenwood/ts950.c` (v1.2.0) |

### Elecraft (6 radios)

| SwiftRigControl radio | Hamlib source |
| --- | --- |
| K2 | `rigs/kenwood/k2.c` |
| K3 | `rigs/kenwood/k3.c` |
| K3S | `rigs/kenwood/k3.c` |
| K4 | `rigs/kenwood/k3.c` |
| KX2 | `rigs/kenwood/k3.c` |
| KX3 | `rigs/kenwood/k3.c` |

### Ten-Tec (6 radios)

| SwiftRigControl radio | Hamlib source |
| --- | --- |
| Orion (TT-565) | `rigs/tentec/orion.c` |
| Orion II (TT-599) | `rigs/tentec/orion.c` |
| Eagle | `rigs/tentec/orion.c` (shared Orion protocol; Eagle uses TT-599 variant) |
| Jupiter (TT-538) | `rigs/tentec/jupiter.c` |
| Pegasus (TT-550) | `rigs/tentec/pegasus.c` |
| RX-320 | `rigs/tentec/rx320.c` (v1.2.0 — shared `tentec_*` command family with Jupiter / Pegasus) |

### Xiegu (3 radios)

Xiegu radios speak CI-V and are supported in Hamlib via a shared file.

| SwiftRigControl radio | Hamlib source |
| --- | --- |
| G90 | `rigs/icom/xiegu.c` |
| X6100 | `rigs/icom/xiegu.c` |
| X6200 | `rigs/icom/xiegu.c` |

### FlexRadio family (5 radios)

| SwiftRigControl radio | Hamlib source |
| --- | --- |
| 6000-series | `rigs/kenwood/flex6xxx.c` |
| PowerSDR | `rigs/kenwood/flex6xxx.c` |
| Thetis | `rigs/kenwood/flex6xxx.c` |
| SDR-Console | `rigs/kenwood/ts2000.c` (v1.2.0 — SDR-Console registers as its own model in ts2000.c) |
| PiHPSDR | `rigs/kenwood/pihpsdr.c` (v1.2.0 — dedicated file, TS-2000 emulation) |

### Lab599 (1 radio)

| SwiftRigControl radio | Hamlib source |
| --- | --- |
| TX-500 | `rigs/kenwood/tx500.c` |

### Guohetec (0 radios shipped — v1.2.0 target)

Chinese HF SDR line. Shared Guohetec framing lives in
`rigs/guohetec/guohetec.c`. Q900 and PMR-171 land in the
Guohetec adapter PR.

| Watched Hamlib source | Covers |
| --- | --- |
| `rigs/guohetec/guohetec.c` | Shared Guohetec framing |
| `rigs/guohetec/guohetec.h` | Shared Guohetec types |
| `rigs/guohetec/q900.c` | Q900 (planned v1.2.0) |
| `rigs/guohetec/pmr171.c` | PMR-171 (planned v1.2.0) |

### Anytone (0 radios shipped — v1.2.0 target)

Chinese tri-band DMR flagship line. AT-D578UVIII lands in the
Anytone adapter PR.

| Watched Hamlib source | Covers |
| --- | --- |
| `rigs/anytone/anytone.c` | Shared Anytone protocol |
| `rigs/anytone/anytone.h` | Shared Anytone types |

### Elad (0 radios shipped — v1.2.0 target)

Italian compact HF SDR line. FDM-DUO lands in the Elad adapter
PR.

| Watched Hamlib source | Covers |
| --- | --- |
| `rigs/elad/fdm_duo.c` | FDM-DUO (planned v1.2.0) |

### CommRadio (0 radios shipped — v1.2.0 target)

US-designed amateur transceiver line. CTX-10 lands in the
CommRadio adapter PR.

| Watched Hamlib source | Covers |
| --- | --- |
| `rigs/commradio/ctx10.c` | CTX-10 (planned v1.2.0) |

### Alinco (0 radios shipped — v1.2.0 target)

Japanese amateur HF budget line. DX-77 and DX-SR8 land in the
Alinco adapter PR.

| Watched Hamlib source | Covers |
| --- | --- |
| `rigs/alinco/dx77.c` | DX-77 + DX-SR8 (planned v1.2.0) |

### AOR (0 radios shipped — v1.2.0 target)

Wideband amateur receiver line. AR-8600 and AR-7030+ land in
the AOR adapter PR. See `Documentation/RADIO_PARITY_v1.2.md`
for the rationale on which AOR models are included vs
deferred (14 further AOR models exist in Hamlib but fall
below the 50-radio v1.2.0 cutoff).

| Watched Hamlib source | Covers |
| --- | --- |
| `rigs/aor/ar8600.c` | AR-8600 (planned v1.2.0) |
| `rigs/aor/ar7030.c` | AR-7030+ (planned v1.2.0) |

## Also watched (project-wide signal)

These are not per-radio but affect the whole project. The script
always includes them:

| Path | Why |
| --- | --- |
| `NEWS` | Hamlib's machine-readable release changelog |
| `ChangeLog` | Migration notes for major versions |
| `ReleaseNotes_4.7.md` | 4.7.x LTS branch notes (per Hamlib maintainers, LTS runs parallel to 5.0) |
| `ReleaseNotes_5.0.md` | Next-major notes (structural / API changes we might mirror) |
| `tests/rigctl_parse.c` | Canonical rigctld command list — new commands here signal work for our `RigctldCommandHandler` |
| `tests/rigctld.c` | rigctld server implementation — where the June 2026 CVEs landed |

## Rigctld security advisories

The `rigctld` protocol bridge in `Sources/RigControl/Network/` is
byte-compatible with Hamlib's `rigctld`, so **any Hamlib `rigctld`
CVE is directly applicable to SwiftRigControl and treated as
drop-everything priority**. Watched at:

- `https://github.com/Hamlib/Hamlib/security/advisories`

The `Scripts/hamlib-diff.sh` script polls this feed independently
of the commit diff so an advisory can never be missed even if the
corresponding fix commit is filtered out by the path scope.
