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

## Status (2026-10-07)

- **v1.2.17** shipped the four fixes in "Ported in this change".
- **v1.2.18** shipped the P0 Kenwood fix (item 1), the FT-100 / FT-920
  fix (item 2) and `TIOCEXCL` (jjones9527/SwiftRigControl#30, #31, #32).
- **v1.2.19** (2026-10-08) shipped A1 (rescoped Icom DATA-mode fixes),
  A2 (Yaesu newcat set commands), the Elecraft K3/K4/KX set path, the
  IC-F8101 command set, the D-STAR mode cleanup and Yaesu power on/off
  (jjones9527/SwiftRigControl#34–#37).
- Digests jjones9527/SwiftRigControl#16, #18 and #20–#26 and the
  earlier triage issue #17 are closed; their open items are folded
  into the list below. #19 (IC-7300MK2 `1A 05`) is item C3.

Everything is mock-tested only. No item above has run on hardware.

## Remaining work — prioritized

Ranked by how many operators each item could affect and whether we can
test it without hardware. ROADMAP Phase 5.9 tracks the checkboxes.

**A — next patch (v1.2.19): bug-class fixes we can mock-test**

1. ~~**Icom `0x26` NAK fallback** (`5ec5e6d2`).~~ **Done for
   v1.2.19, rescoped.** The premise was wrong: Hamlib marks the
   IC-7300 and IC-7300MK2 `x25x26_always = 1` (`ic7300.c:543`, `652`)
   and never stops using `0x26` on them. Checking that path found the
   real bugs instead: our `0x26` frame had no VFO byte
   (`icom.c:2392-2394`); voice modes on the IC-7300 / MK2 went through
   `0x06`, so DATA couldn't be cleared; `getMode` never read the DATA
   flag on any Icom (`icom.c:2904-2952`); the IC-7700 was sent `0x26`
   although Hamlib turns it off (`ic7700.c:153-158`); and ~20 radios
   without `data_mode_supported` were sent `0x1A 0x06` after every
   mode set. All fixed; a NAK fallback was added as well. New
   follow-ups: the IC-F8101 needs its own `1A 35/36/34` commands, and
   the D-STAR radios use `.dataFM` as a stand-in for DV (ROADMAP 5.9.5).
2. ~~**Yaesu newcat `AC` reject drain** (`635d11fe`).~~ **Done for
   v1.2.19, widened.** Sizing it showed every newcat set command read
   an echo that real radios never send (the Kenwood bug again), on all
   16 `YaesuCATProtocol` radios. Ported Hamlib `newcat_set_cmd` whole:
   write-only `FA`/`FB`/`TX`/`MD`/`ST`, `ID;` verification for the rest
   (`AI;` on FTDX-9000), `AC` drained. Also found `getRIT` sending
   `RC;` (clarifier clear); it now reads `IF;`. Next: audit Elecraft
   K3/K4, whose set path also reads an "echo".
3. **Elecraft.** Set path **done for v1.2.19**: K3/K4/KX sets required
   an echo the radio never sends; now verified with `ID;` like Hamlib
   `kenwood_transaction`. Still open: reply validation for K3/K3S `SW`,
   K4 `TM` / `FR` / `FT` / `TQ` (`900c4d3`, `ffe227a3`) — reject
   malformed replies rather than parsing prefixes only.
4. **G90 RFPOWER malformed-BCD clamp** (`b61dd14d`).

**B — waiting on hardware or field reports** (nothing to code until a
report arrives)

1. Kenwood / Flex / Lab599 against v1.2.18. Set-command verification
   changed every set on 22 radios; this is the highest-risk change
   in either release.
2. AGC on IC-7100 / IC-7600 / IC-9700; DATA-USB on FT-817 / FT-857
   (v1.2.17).
3. FT-100 / FT-920 (v1.2.18).
4. ROADMAP 5.8.1 K2 re-verify at 8-N-2, and 4.5 side-by-side
   `rigctl -m 2` check.
5. FT-817/857 DIG sideband EEPROM write (`65ce74ca`, `6836abe1`):
   opt-in only, and only with a volunteer who owns the radio, because
   of EEPROM wear risk.

**C — low-priority audits** (do when touching the code)

1. TH-D75 dedicated-backend diff (`07d6a7ff`).
2. Icom table-bounds (`b9b9723`) and rigctld parser hardening
   (`c0adbb2`). Swift collections and our bounded parser are likely
   immune; confirm with a test or two.
3. ~~IC-7300MK2 `1A 05` renumbering~~ (jjones9527/SwiftRigControl#19):
   per-model table and test added for v1.2.19
   (`IcomRadioModel.menuSettingParameter`). The MK2 DATA mod-source
   number still has to come from its CI-V manual.

**D — next minor (v1.3.0): features, not fixes**

ROADMAP 5.7 TM-D710 protocol, 5.8.3 baud-rate range API, 5.8.4 Kenwood
mic/data PTT source, 5.8.2 K2 `K22;` extended power.

**E — pull-based** (only on a concrete app request)

Phase 6 (spectrum scope, satellite Doppler, memory import/export),
Phase 5.1 capability traits (v2.0), TCI 2.0 backend, Guohetec adapter,
IC-7610 / IC-7760 SYNC (`3840e1e`).

**Not applicable:** Hamlib advisories GHSA-gpcq-c37x-pr46 (`send_raw`)
and GHSA-f72v-7gmh-m9mj (`read_string_generic`, rigctld auth) — our
bridge implements neither `send_raw` nor password auth, and our parser
has no fixed-size buffers.

**Process**
- The weekly workflow advances `.hamlib-watermark` whether or not
  anyone triaged the digest, so the watermark is not a "reviewed up
  to" marker. This review covers through `7a556db`; the next human
  review starts from there.
