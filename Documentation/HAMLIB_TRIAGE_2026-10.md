# Hamlib upstream triage — 2026-10-05

**Range reviewed:** Hamlib `master` `0839c031` → `7a556db`
(2026-08-17 → 2026-10-03). This is the last watermark a human
reviewed (just before v1.2.15/v1.2.16) through the current upstream
head. It covers the auto-filed digests
jjones9527/SwiftRigControl#18 and #20–#25. ~75 non-merge commits; no new
Hamlib release tag (latest is still `4.7.2`).

Triage method: every commit was read against the code it touches in
SwiftRigControl, not just the watched-path list. Two of the bugs fixed
below (Icom AGC, FT-817 DIG) were found while checking an upstream
commit's neighborhood, not in the commit itself.

## Ported in this change (targeted for v1.2.17)

| Upstream | What | SwiftRigControl change |
| --- | --- | --- |
| `14f24827`, `55665a83`, `2d19d104`, `df9dfe9a` — canonical decimal wire values | Hamlib's rigctld requires complete, finite decimal tokens; accepts a decimal comma for scalars. netrigctl always sends frequencies as `%lf` (`14074000.000000`). | New `RigctldDecimal`. `F` / `I` / `2` and long forms accept decimal Hz (we previously answered `RPRT -1` to stock Hamlib clients). Level values accept `0,5`. `nan` / `inf` / huge values no longer trap `Int(Double)` and crash the host app. |
| `5ac54e5b` — G90 civaddr / AGC map | `g90_priv_caps` default `0xA4` → `0x88`; AGC OFF/FAST/SLOW/AUTO. | G90 default CI-V `0x88`; G90 AGC table added. |
| `65ce74ca` — FT-857 PKTLSB (neighborhood) | Confirms PKTUSB/PKTLSB use DIG (`0x0A`), PKTFM uses PKT (`0x0C`). | **Pre-existing bug:** `YaesuPortableCAT` sent `0x0C` (FM packet) for DATA-USB/LSB. Fixed to `0x0A`; readback `0x0C` → `.dataFM`. |
| `7e78154e` — Icom KEYERTYPE (neighborhood) | Reviewing Icom level translation. | **Pre-existing bug:** unified Icom `setAGC`/`getAGC` sent `RIG_AGC_*` enum values instead of each model's `agc_levels` byte, and threw on IC-7300/7610/705/785x. Now table-driven. |

## Deferred — port later (see plan below)

| Upstream | Relevance | Verdict |
| --- | --- | --- |
| `4b39d3cd`, `e9ef0cc3` — `TIOCEXCL` exclusive serial open | High. Two apps sharing a CAT port is a classic support issue. `IOKitSerialPort.open()` opens `O_RDWR \| O_NOCTTY \| O_NONBLOCK` with no exclusivity. | P1. Needs a check that no in-tree path (discovery → connect) reopens the port without closing. |
| `5ec5e6d2` — fall back from rejected `0x25`/`0x26` | Medium. Our IC-7100 is `.currentOnly` so unaffected, but targetable radios (IC-7300, IC-9700, IC-705, IC-7610) on old firmware would NAK `0x25/0x26` and we throw. | P2. Add a one-shot fallback to legacy `0x03`/`0x04` + VFO select, as Hamlib does. |
| `65ce74ca`, `6836abe1` — FT-857 DIG sideband via EEPROM, ATT/IPO via EEPROM | Medium. Makes DATA-USB vs DATA-LSB deterministic. EEPROM writes carry wear/brick risk. | P2, hardware-gated. FT-817 `0x65`, FT-857/897 `0x78`. |
| `635d11fe` — drain rejected newcat `AC` responses | Medium. `?;` before the verification reply desyncs the next transaction. Our `AC00x` tuner path reads one response. | P2. Port the drain-through-sync-query pattern. |
| `bfea1769` — TS-990S data mode | High — see Kenwood DATA bug below. TS-990S uses `OM0<hex>` and must target the operating band. | Folded into P0 Kenwood item. |
| `ffe227a3` — validate K4 `FR`/`FT`/`TQ` replies | Low. We check prefixes only. | P3. Same validation pattern as digest #16's `900c4d3`. |
| `b61dd14d` — G90 caps (no NR, no MICGAIN/COMP levels, RFPOWER BCD `0x5f` clamp) | Low. Our G90 caps are already HF-only / 20 W. RFPOWER read could see a malformed BCD byte at full power. | P3. Clamp power readback on G90. |
| `92839248` — FT-991 ID meter to 25.5 A | None today — we don't expose the ID meter. | Note for when we do. |
| `f301e7b4` — ID-5100 VFO switching | Low. Our ID-5100 is definition-only with no dual-watch logic. | Note. |
| `63dc4f91`, `bdee06cd`, `11ff5246`, `26b1ac26` — core data-mode / cache coherency | Not applicable — C threading/cache semantics; our actors serialize. DATA1/2/3 sub-profiles not modeled. | Skip. |
| `a3fc7596` — stream `require_native` / `NONE` | Not applicable — we don't implement rigctld streaming. | Skip. |
| `07d6a7ff`, `f440c9cd`, `2bc935fa` — dedicated TH-D75 backend | Low-medium. Our TH-D74/D75 use `THD72Protocol(.d74)`. Hamlib now has a richer backend worth diffing. | P3 audit. |
| `ca840d04` et al. — TCI 2.0 backend (Expert Electronics) | New vendor protocol. | Out of current scope; candidate for a future minor. |
| QMX, ats-mini, guohetec, usrp, KEYSPD NULL deref, docs/CI/SWIG commits | Not in our catalog / C-only. | Skip. |

## Pre-existing issues found during this review (not upstream-driven)

1. **Kenwood DATA modes send an invalid command (P0) — fixed for
   v1.2.18**, together with a related bug found while fixing it:
   most Kenwood set commands waited for a reply real radios never
   send. See CHANGELOG `[Unreleased]`.
   `KenwoodProtocol.setMode(.dataUSB)` sends `MD13;` (two decimal
   digits). Hamlib never sends that: TS-590S/SG and TS-950 use
   `MD2;` + `DA1;` (`kenwood.c:2537-2556`, `2670-2727`), TS-990S
   uses `OM0D;` with a hex code on the operating band
   (`kenwood.c:2574-2653`), TS-890S uses `SF`. Readback only parses
   one character, so `MD12`/`MD13` can never be read either.
   Affects every Kenwood/Lab599/Flex definition that routes through
   `KenwoodProtocol` and any app using DATA-USB (VARA HF, FT8).
2. **FT-100 and FT-920 use the wrong adapter (P1) — fixed for
   v1.2.18**; both were also at 38400 baud instead of Hamlib's 4800. Both are wired
   to `YaesuPortableCAT` (FT-817 framing: mode byte first, opcode
   `0x07`; PTT opcodes `0x08`/`0x88`). Hamlib `ft100.c:210-219` (PTT `[0,0,0,1,0x0F]`, mode `[0,0,0,P1,0x0C]`) and
   `ft920.c:361` use the legacy layout (`[0,0,0,P1,0x0C]` mode set,
   different PTT and status frames). Same class as the v1.2.0
   "FT-817 family shipping wrong protocol adapter" fix. Until audited,
   these should not be advertised as working.
3. **IC-7300MK2 `1A 05` remap (jjones9527/SwiftRigControl#19).** The MK2
   renumbered the `1A 05` extended settings (e.g. `1A 05 00 67` is
   now the calibration marker, not DATA mod source) and swapped the
   USB/ACC values. We don't send any `1A 05` settings today, so no
   current bug — but the MK2 shares the IC-7300 command set, so any
   future `1A 05` feature must be per-model. Add a guard test when
   the first one lands.

## Prioritized plan

**P0**
- [x] Ship the four fixes in this change — shipped in v1.2.17
  (mock-tested only).
- [x] Kenwood DATA-mode wire fix (item 1 above), plus set-command
  `ID;` verification — done for v1.2.18. Per-radio styles: `MD`+`DA`
  (TS-590S/SG), `OM0<hex>` (TS-990S), `SF` (TS-890S), `MD6`/`MD9`
  (Flex), `ZZMD` (PowerSDR / Thetis); `unsupportedOperation` elsewhere.

**P1 — v1.2.18 or later**
- [x] FT-100 / FT-920 adapter audit (item 2) — done for v1.2.18. Was: either move to
  `YaesuLegacyCAT` with byte-level tests or mark unsupported.
- `TIOCEXCL` exclusive serial open (`4b39d3cd`).
- Hardware re-check of AGC on IC-7100 / IC-7600 / IC-9700 (the three
  verified Icoms) and DATA-USB on any available FT-817/857.

**P2 — v1.2.x as time allows**
- `0x25`/`0x26` reject fallback on targetable Icoms (`5ec5e6d2`).
- Newcat `AC` reject drain (`635d11fe`).
- FT-817/857 DIG sideband EEPROM write (`65ce74ca`), behind an
  explicit opt-in.

**P3 — opportunistic**
- K4 `FR`/`FT`/`TQ` and Elecraft SWR reply validation (`ffe227a3`,
  `900c4d3`).
- G90 RFPOWER BCD clamp (`b61dd14d`).
- TH-D75 backend diff (`07d6a7ff`).
- Existing ROADMAP items: 5.7 TM-D710 protocol, 5.8.1 K2 8-N-2
  re-verify, 5.8.3 baud-rate range API, Phase 6 spectrum scope.

**Process**
- The weekly workflow advances `.hamlib-watermark` whether or not
  anyone triaged the digest, so the watermark is not a "reviewed up
  to" marker. Digests #16, #18, #20–#25 are covered by #17 and this
  document and can be closed. Consider recording a separate
  `.hamlib-reviewed` SHA (this review: `7a556db`).
- No Swift toolchain was available for this review; the fixes are
  unverified until the macOS CI job runs.
