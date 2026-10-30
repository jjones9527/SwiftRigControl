# Hamlib capability coverage — 2026-10-30

How much of each radio's Hamlib capability surface SwiftRigControl
implements, against Hamlib `91e7b97`. Measured with
`Scripts/hamlib-coverage.py`: for each of the 129 serial catalog radios
(the 8 SmartSDR slices are TCP and were skipped), every capability
Hamlib's `rigctl -m <model> -u` lists was run through SwiftRigControl's
rigctld bridge against a fake radio that ACKs everything.

- **Counted:** core operations (the "Can set …" flags), modes, settable
  levels, get-only meters, functions, VFO ops and scan ops.
- **Not counted:** scope and spectrum items.
- **Covered** means we accepted the command and wrote to the radio. This
  is **coverage, not wire correctness.** Bytes have been compared with
  Hamlib only for the 19 Tier 1 radios (`hamlib-diff-audit.py`), the
  Kenwood and Yaesu level tables, and RF power on all non-100 W radios
  (`hamlib-set-matrix.py`).

## Summary

6,473 Hamlib capability items across 129 radios:

| | Items | Share |
| --- | ---: | ---: |
| Covered | 3,197 | 49% |
| Wiring/flags: the protocol has the code, but the radio's capabilities don't advertise it or rigctld doesn't route it | 1,600 | 25% |
| No library API at all | 1,015 | 16% |
| Protocol work: the API exists but this radio's protocol doesn't implement it | 661 | 10% |

By category: modes 89%, core 49%, levels 52%, meters 38%, functions
28%, VFO ops 23%, scan 6%.

By family (median per-radio coverage is 48%):

| Family | Radios | Covered |
| --- | ---: | ---: |
| Elecraft | 6 | 71% |
| Lab599 | 1 | 67% |
| Flex CAT bridges | 5 | 61% |
| Kenwood HF | 16 | 61% |
| Icom | 52 | 49% |
| Yaesu binary CAT | 14 | 44% |
| Xiegu | 3 | 42% |
| Yaesu newcat | 16 | 42% |
| Kenwood HT / mobile | 8 | 34% |
| Ten-Tec | 6 | 33% |

The hardware-verified IC-7100, IC-7600 and IC-9700 score 77–78%. The
rest of the Icom catalog shares the same `IcomCIVProtocol` code but
mostly scores 35–60%, because its capability records don't advertise
what that code already does.

## The largest gaps

**Wiring and flags** (code exists; the counts are radios affected):

- **rigctld `L PREAMP`** takes a stage number; Hamlib sends dB (57).
- **Hamlib mode names** `FM-D` / `AM-D` (`misc.c:463-469`) aren't parsed (36).
- **`U RIT` / `U XIT`** aren't routed (41 / 40).
- **Capability flags not set** although the protocol implements the
  feature: CW keyer (`KEYSPD`, `CWPITCH`, break-in), TX meters (SWR,
  ALC, power), scanning, VFO ops (CPY, XCHG, FROM_VFO, TO_VFO, TUNE),
  functions (TONE, TSQL, VOX, COMP, ANF, MN, MON, LOCK, TUNER) and
  antenna selection.

**No library API** (counts are radios):

- **Memory and channel via rigctld** (`E`, `\set_channel`): 86. The
  library has a memory API; the bridge doesn't expose it.
- **DCD**: 85.
- **CTCSS tone and squelch values**: 78 / 73.
- **Tuning step**: 65.
- **Repeater shift and offset**: 63 / 59.
- **DCS**: 24–27.
- **Voice memory**: 25.
- **Levels**: `BKINDL` (42), `ANTIVOX` (38), `PBT_IN` / `PBT_OUT` (29),
  `NOTCHF` (26–42), `AGC_TIME` (21), `METER` select, `BAND_SELECT`,
  `APF`, `SLOPE`, `BAL`.

**Protocol work:** the thin adapters are
`TMFamilyCAT` / `THFamilyCAT` / `THD72Protocol` (1–3 traits),
`TenTecLegacyProtocol` / `TenTecOrionProtocol` (1–2), and
`YaesuPortableCAT` / `YaesuFT100CAT` (0–1). By comparison,
`IcomCIVProtocol` has 29 traits, `YaesuCATProtocol` 25 and
`KenwoodProtocol` 24.

## Per radio

Covered / Hamlib items. "Core" excludes items with no rigctld command.

| Radio | Protocol | Core | Modes | Levels | Meters | Functions | VFO ops | Scan | Overall |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Elecraft K2 (hardware) | `ElecraftProtocol` | 9/11 | 6/6 | 4/6 | 1/1 | 2/2 | 2/3 | – | 83% |
| Elecraft K3 | `ElecraftProtocol` | 9/13 | 10/10 | 8/12 | 2/6 | 6/9 | 2/3 | – | 70% |
| Elecraft K3S | `ElecraftProtocol` | 9/13 | 10/10 | 8/12 | 2/6 | 6/9 | 2/3 | – | 70% |
| Elecraft K4 | `ElecraftProtocol` | 9/13 | 10/10 | 7/12 | 2/6 | 6/10 | 2/3 | – | 67% |
| Elecraft KX2 | `ElecraftProtocol` | 9/12 | 10/10 | 8/12 | 2/5 | 5/7 | 2/3 | – | 73% |
| Elecraft KX3 | `ElecraftProtocol` | 9/13 | 10/10 | 8/12 | 2/5 | 5/7 | 2/3 | – | 72% |
| FlexRadio 6000-series | `KenwoodProtocol` | 8/9 | 7/7 | 1/4 | – | – | – | – | 80% |
| FlexRadio PiHPSDR | `KenwoodProtocol` | 9/16 | 6/6 | 9/16 | 2/2 | 4/7 | 4/4 | 0/1 | 65% |
| FlexRadio PowerSDR | `KenwoodProtocol` | 7/8 | 7/8 | 7/11 | 1/4 | 4/8 | 4/4 | – | 70% |
| FlexRadio SDR-Console | `KenwoodProtocol` | 3/6 | 8/8 | 11/20 | 1/5 | 2/15 | 0/6 | 0/1 | 41% |
| FlexRadio Thetis | `KenwoodProtocol` | 7/8 | 7/8 | 7/11 | 1/4 | 4/8 | 4/4 | – | 70% |
| Hamgeek uSDX | `HamgeekUSDXProtocol` | 2/3 | 8/8 | – | – | – | – | – | 91% |
| Icom IC ID-1 | `IcomCIVProtocol` | 3/9 | 1/1 | 5/5 | 1/1 | 0/6 | 0/3 | 0/2 | 37% |
| Icom IC-2730 | `IcomCIVProtocol` | 4/13 | 2/2 | 5/5 | – | 0/3 | – | – | 48% |
| Icom IC-7000 | `IcomCIVProtocol` | 6/15 | 9/9 | 12/22 | 2/7 | 2/14 | 0/6 | 0/4 | 40% |
| Icom IC-703 | `IcomCIVProtocol` | 6/12 | 8/8 | 8/14 | 1/3 | 2/10 | 0/5 | 0/2 | 46% |
| Icom IC-705 | `IcomCIVProtocol` | 9/19 | 12/14 | 13/21 | 2/9 | 11/17 | 6/6 | 0/4 | 59% |
| Icom IC-706 | `IcomCIVProtocol` | 5/9 | 7/7 | – | – | – | 0/5 | – | 57% |
| Icom IC-706MKII | `IcomCIVProtocol` | 5/9 | 7/7 | – | – | – | 0/5 | – | 57% |
| Icom IC-706MKIIG | `IcomCIVProtocol` | 5/11 | 7/7 | 1/3 | 1/1 | 1/7 | 0/5 | 0/1 | 43% |
| Icom IC-7100 (hardware) | `IcomCIVProtocol` | 9/18 | 11/13 | 15/23 | 9/9 | 14/14 | 6/6 | 4/4 | 78% |
| Icom IC-718 | `IcomCIVProtocol` | 5/9 | 7/7 | 7/10 | 1/1 | 2/9 | 0/5 | 0/1 | 52% |
| Icom IC-7200 | `IcomCIVProtocol` | 6/12 | 9/9 | 11/20 | 2/6 | 2/14 | 0/6 | 0/4 | 42% |
| Icom IC-7300 | `IcomCIVProtocol` | 9/17 | 10/12 | 13/22 | 2/9 | 11/17 | 6/6 | 0/4 | 59% |
| Icom IC-7300MK2 | `IcomCIVProtocol` | 9/17 | 10/12 | 13/22 | 2/9 | 11/17 | 6/6 | 0/4 | 59% |
| Icom IC-735 | `IcomCIVProtocol` | 2/4 | 5/5 | – | – | – | 0/2 | – | 64% |
| Icom IC-7400 | `IcomCIVProtocol` | 6/15 | 8/8 | 8/18 | 1/5 | 2/17 | 0/6 | 0/5 | 34% |
| Icom IC-7410 | `IcomCIVProtocol` | 6/16 | 10/11 | 10/20 | 2/6 | 2/14 | 0/6 | 0/5 | 38% |
| Icom IC-746 | `IcomCIVProtocol` | 6/13 | 8/8 | 8/18 | 1/5 | 2/15 | 0/5 | 0/5 | 36% |
| Icom IC-746PRO | `IcomCIVProtocol` | 6/15 | 8/8 | 8/18 | 1/5 | 2/17 | 0/6 | 0/5 | 34% |
| Icom IC-751 | `IcomCIVProtocol` | 3/5 | 6/6 | – | 2/2 | – | 0/2 | – | 73% |
| Icom IC-756 | `IcomCIVProtocol` | 5/10 | 8/8 | – | – | 0/1 | 0/5 | 0/5 | 45% |
| Icom IC-756PRO | `IcomCIVProtocol` | 6/15 | 8/8 | 8/17 | 2/2 | 2/13 | 0/5 | 0/5 | 40% |
| Icom IC-756PROII | `IcomCIVProtocol` | 6/15 | 8/8 | 8/19 | 2/2 | 2/13 | 0/5 | 0/5 | 39% |
| Icom IC-756PROIII | `IcomCIVProtocol` | 6/13 | 8/8 | 10/22 | 2/7 | 2/14 | 0/6 | 0/5 | 37% |
| Icom IC-7600 (hardware) | `IcomCIVProtocol` | 11/17 | 10/14 | 14/23 | 9/9 | 15/17 | 6/6 | 5/5 | 77% |
| Icom IC-7610 | `IcomCIVProtocol` | 9/18 | 10/14 | 12/23 | 2/9 | 11/18 | 6/6 | 0/5 | 54% |
| Icom IC-7700 | `IcomCIVProtocol` | 9/17 | 10/14 | 12/24 | 2/9 | 2/17 | 0/6 | 0/5 | 38% |
| Icom IC-7760 | `IcomCIVProtocol` | 9/17 | 10/14 | 12/24 | 2/9 | 11/18 | 6/6 | 0/5 | 54% |
| Icom IC-7800 | `IcomCIVProtocol` | 9/17 | 10/14 | 12/24 | 2/9 | 2/18 | 0/6 | 0/5 | 38% |
| Icom IC-7850 | `IcomCIVProtocol` | 9/17 | 10/14 | 11/24 | 2/9 | 2/18 | 0/6 | 0/5 | 37% |
| Icom IC-7851 | `IcomCIVProtocol` | 9/17 | 10/14 | 12/24 | 2/9 | 2/18 | 0/6 | 0/5 | 38% |
| Icom IC-820H | `IcomCIVProtocol` | 2/4 | 4/4 | – | – | – | 0/4 | 0/1 | 46% |
| Icom IC-905 | `IcomCIVProtocol` | 9/19 | 12/14 | 12/21 | 2/9 | 2/17 | 5/5 | 0/4 | 47% |
| Icom IC-9100 | `IcomCIVProtocol` | 6/16 | 10/10 | 10/21 | 1/2 | 2/15 | 0/6 | 0/4 | 39% |
| Icom IC-910H | `IcomCIVProtocol` | 6/14 | 4/4 | 9/15 | 1/1 | 2/11 | 0/5 | 0/1 | 43% |
| Icom IC-92D | `IcomCIVProtocol` | – | 3/3 | 5/5 | 1/1 | 5/6 | 3/3 | 0/2 | 85% |
| Icom IC-970 | `IcomCIVProtocol` | 2/4 | 4/4 | – | – | – | 0/2 | – | 60% |
| Icom IC-9700 (hardware) | `IcomCIVProtocol` | 9/18 | 9/9 | 15/22 | 9/9 | 15/18 | 5/5 | 3/3 | 77% |
| Icom IC-F8101 | `IcomCIVProtocol` | 6/9 | 5/11 | 7/9 | 1/1 | 2/9 | – | 0/1 | 52% |
| Icom IC-R20 | `IcomCIVProtocol` | 1/2 | 6/6 | – | 1/1 | – | – | – | 89% |
| Icom IC-R30 | `IcomCIVProtocol` | 4/12 | 12/20 | 3/4 | 2/2 | 4/8 | 3/3 | – | 57% |
| Icom IC-R6 | `IcomCIVProtocol` | 1/5 | 3/3 | 3/3 | 2/2 | 0/5 | – | – | 50% |
| Icom IC-R7100 | `IcomCIVProtocol` | 2/6 | 5/5 | 3/3 | 1/1 | 0/1 | 0/2 | 0/1 | 58% |
| Icom IC-R75 | `IcomCIVProtocol` | 3/8 | 8/9 | 5/10 | 2/2 | 2/3 | 0/3 | 0/2 | 54% |
| Icom IC-R8600 | `IcomCIVProtocol` | 3/12 | 10/18 | 5/11 | 2/2 | 2/12 | 0/3 | 0/5 | 35% |
| Icom IC-R9500 | `IcomCIVProtocol` | 2/11 | 9/10 | 5/13 | 1/1 | 2/7 | 0/3 | 0/4 | 39% |
| Icom IC-RX7 | `IcomCIVProtocol` | 1/2 | 3/3 | – | 1/1 | – | – | – | 83% |
| Icom ID-31 | `IcomCIVProtocol` | 3/10 | 3/3 | 5/5 | 1/1 | 3/5 | – | – | 62% |
| Icom ID-4100 | `IcomCIVProtocol` | 3/10 | 3/3 | 5/5 | 1/1 | 0/5 | – | – | 50% |
| Icom ID-51 | `IcomCIVProtocol` | 4/11 | 3/3 | 5/5 | 1/1 | 3/5 | – | – | 64% |
| Icom ID-5100 | `IcomCIVProtocol` | 7/14 | 5/5 | 5/5 | 1/1 | 0/6 | – | – | 58% |
| Icom ID-52 | `IcomCIVProtocol` | 4/11 | 4/4 | 6/6 | 1/1 | 3/5 | – | – | 67% |
| Icom ID-52 PLUS | `IcomCIVProtocol` | 4/11 | 4/4 | 6/6 | 1/1 | 3/5 | – | – | 67% |
| Kenwood TH-D72 (hardware) | `THD72Protocol` | 6/14 | 3/3 | 1/5 | – | 0/4 | – | – | 38% |
| Kenwood TH-D72A (hardware) | `THD72Protocol` | 6/14 | 3/3 | 1/5 | – | 0/4 | – | – | 38% |
| Kenwood TH-D74 | `THD72Protocol` | 3/14 | 9/9 | 1/5 | – | 0/2 | – | – | 43% |
| Kenwood TH-D75 | `THD72Protocol` | 3/12 | 9/9 | 1/5 | 0/1 | 0/3 | – | – | 43% |
| Kenwood TH-F6A | `THFamilyCAT` | 3/7 | 6/6 | 0/6 | – | 0/4 | 0/2 | – | 36% |
| Kenwood TH-F7E | `THFamilyCAT` | 3/7 | 6/6 | 0/6 | – | 0/4 | 0/2 | – | 36% |
| Kenwood TM-D710(G) | `TMFamilyCAT` | 3/15 | 3/3 | 0/2 | – | 0/8 | 0/2 | – | 20% |
| Kenwood TM-V71(A) | `TMFamilyCAT` | 3/12 | 3/3 | 0/2 | – | 0/8 | 0/2 | – | 22% |
| Kenwood TS-2000 | `KenwoodProtocol` | 9/17 | 8/8 | 12/20 | 1/5 | 10/15 | 5/6 | 0/1 | 62% |
| Kenwood TS-450S | `KenwoodProtocol` | 9/12 | 8/8 | 0/2 | 2/4 | 0/3 | 0/2 | 0/1 | 59% |
| Kenwood TS-480HX | `KenwoodProtocol` | 9/13 | 8/8 | 12/20 | 1/5 | 2/12 | 0/6 | – | 50% |
| Kenwood TS-480SAT | `KenwoodProtocol` | 9/13 | 8/8 | 12/20 | 1/5 | 7/12 | 5/6 | – | 66% |
| Kenwood TS-570D | `KenwoodProtocol` | 9/15 | 6/6 | 7/11 | 1/1 | 2/10 | 0/2 | 0/1 | 54% |
| Kenwood TS-570S | `KenwoodProtocol` | 9/15 | 6/6 | 7/11 | 1/1 | 2/10 | 0/2 | 0/1 | 54% |
| Kenwood TS-590S | `KenwoodProtocol` | 9/16 | 10/12 | 12/20 | 1/6 | 7/12 | 3/4 | 0/1 | 59% |
| Kenwood TS-590SG | `KenwoodProtocol` | 9/16 | 10/12 | 12/20 | 1/6 | 7/12 | 3/4 | 0/1 | 59% |
| Kenwood TS-690S | `KenwoodProtocol` | 9/12 | 8/8 | 0/1 | 1/3 | 0/3 | 0/2 | 0/1 | 60% |
| Kenwood TS-850S | `KenwoodProtocol` | 8/11 | 8/8 | 0/3 | 3/5 | 0/2 | 0/2 | – | 61% |
| Kenwood TS-870S | `KenwoodProtocol` | 9/14 | 8/8 | 8/8 | 2/4 | 2/7 | – | – | 71% |
| Kenwood TS-890S | `KenwoodProtocol` | 9/15 | 10/14 | 6/8 | 2/9 | 8/13 | 5/6 | – | 62% |
| Kenwood TS-940S | `KenwoodProtocol` | 8/10 | 6/6 | – | – | 0/1 | 0/2 | 0/1 | 70% |
| Kenwood TS-950S | `KenwoodProtocol` | 5/8 | 6/6 | – | 1/1 | – | – | – | 80% |
| Kenwood TS-950SDX | `KenwoodProtocol` | 5/8 | 6/6 | – | 1/1 | – | – | – | 80% |
| Kenwood TS-990S | `KenwoodProtocol` | 9/16 | 10/17 | 9/16 | 2/3 | 7/7 | 3/3 | 0/1 | 63% |
| Lab599 TX-500 | `KenwoodProtocol` | 8/15 | 6/6 | 9/16 | 2/2 | 7/9 | 4/4 | 0/1 | 68% |
| QRP Labs QMX | `QRPLabsQMXProtocol` | 6/6 | 2/4 | – | 3/3 | – | – | – | 85% |
| Ten-Tec Eagle | `TenTecOrionProtocol` | 6/8 | 6/6 | 0/5 | 1/3 | 0/1 | 0/2 | – | 52% |
| Ten-Tec Jupiter (TT-538) | `TenTecLegacyProtocol` | 2/6 | 5/5 | 0/6 | 1/2 | 0/3 | – | – | 36% |
| Ten-Tec Orion (TT-565) | `TenTecOrionProtocol` | 6/13 | 7/7 | 0/16 | 1/2 | 0/4 | 0/5 | – | 30% |
| Ten-Tec Orion II (TT-599) | `TenTecOrionProtocol` | 6/13 | 7/7 | 0/16 | 1/2 | 0/4 | 0/5 | – | 30% |
| Ten-Tec Pegasus (TT-550) | `TenTecLegacyProtocol` | 1/8 | 5/6 | 0/14 | 2/3 | 0/4 | 0/1 | – | 22% |
| Ten-Tec RX-320 | `TenTecLegacyProtocol` | 1/1 | 4/4 | 0/4 | 1/1 | – | – | – | 60% |
| Xiegu G90 | `IcomCIVProtocol` | 7/16 | 11/11 | 6/9 | 1/2 | 1/12 | 0/6 | 0/4 | 43% |
| Xiegu X6100 | `IcomCIVProtocol` | 6/15 | 12/12 | 9/18 | 1/3 | 2/14 | 0/6 | 0/4 | 42% |
| Xiegu X6200 | `IcomCIVProtocol` | 6/15 | 12/12 | 9/18 | 1/3 | 2/14 | 0/6 | 0/4 | 42% |
| Yaesu FT-100 | `YaesuFT100CAT` | 5/9 | 8/8 | 0/1 | 0/6 | 0/2 | – | – | 50% |
| Yaesu FT-1000MP | `YaesuFT1000MPCAT` | 8/8 | 6/6 | 0/1 | 3/7 | 0/11 | 0/5 | – | 45% |
| Yaesu FT-1000MP MARK-V | `YaesuFT1000MPCAT` | 8/8 | 6/6 | 0/1 | 3/7 | 0/11 | 0/5 | – | 45% |
| Yaesu FT-1000MP MARK-V Field | `YaesuFT1000MPCAT` | 8/8 | 6/6 | 0/1 | 3/7 | 0/11 | 0/5 | – | 45% |
| Yaesu FT-2000 | `YaesuCATProtocol` | 8/18 | 12/13 | 11/21 | 2/9 | 2/16 | 0/10 | 0/1 | 40% |
| Yaesu FT-450 | `YaesuCATProtocol` | 7/16 | 9/10 | 9/18 | 2/5 | 2/12 | 0/8 | 0/1 | 41% |
| Yaesu FT-450D | `YaesuCATProtocol` | 7/16 | 9/10 | 9/18 | 2/5 | 2/12 | 0/8 | 0/1 | 41% |
| Yaesu FT-710 | `YaesuCATProtocol` | 9/18 | 13/14 | 12/22 | 2/9 | 2/15 | 0/10 | 0/1 | 43% |
| Yaesu FT-817 | `YaesuPortableCAT` | 3/15 | 8/13 | 0/1 | 2/6 | 0/5 | 0/1 | – | 32% |
| Yaesu FT-818 | `YaesuPortableCAT` | 5/15 | 8/13 | 0/1 | 2/5 | 0/4 | 0/1 | – | 38% |
| Yaesu FT-847 | `YaesuFT847CAT` | 5/11 | 6/6 | 0/1 | 3/3 | 0/2 | – | – | 61% |
| Yaesu FT-847UNI | `YaesuFT847CAT` | 5/11 | 6/6 | 0/1 | 0/3 | 0/2 | – | – | 48% |
| Yaesu FT-857 | `YaesuPortableCAT` | 5/15 | 8/11 | 0/3 | 1/3 | 0/5 | 0/1 | – | 37% |
| Yaesu FT-857D | `YaesuPortableCAT` | 5/15 | 8/11 | 0/3 | 1/3 | 0/5 | 0/1 | – | 37% |
| Yaesu FT-891 | `YaesuCATProtocol` | 5/16 | 11/11 | 12/22 | 2/8 | 2/13 | 0/9 | 0/1 | 40% |
| Yaesu FT-897 | `YaesuPortableCAT` | 4/14 | 7/9 | 0/1 | 2/5 | 0/5 | 0/1 | – | 37% |
| Yaesu FT-897D | `YaesuPortableCAT` | 5/15 | 7/9 | 0/1 | 2/5 | 0/3 | 0/1 | – | 41% |
| Yaesu FT-920 | `YaesuFT1000MPCAT` | 8/8 | 7/9 | 0/1 | – | 0/1 | – | – | 79% |
| Yaesu FT-950 | `YaesuCATProtocol` | 8/18 | 10/11 | 10/20 | 1/3 | 2/15 | 0/10 | 0/1 | 40% |
| Yaesu FT-991 | `YaesuCATProtocol` | 8/20 | 13/14 | 12/23 | 2/9 | 11/16 | 9/9 | 0/1 | 60% |
| Yaesu FT-991A | `YaesuCATProtocol` | 8/20 | 13/14 | 12/23 | 2/9 | 2/16 | 0/9 | 0/1 | 40% |
| Yaesu FTDX-10 | `YaesuCATProtocol` | 9/18 | 13/14 | 12/22 | 2/9 | 2/15 | 0/10 | 0/1 | 43% |
| Yaesu FTDX-101D | `YaesuCATProtocol` | 9/19 | 13/14 | 12/22 | 2/10 | 2/16 | 0/10 | 0/1 | 41% |
| Yaesu FTDX-101MP | `YaesuCATProtocol` | 9/19 | 13/14 | 12/22 | 2/10 | 2/16 | 0/10 | 0/1 | 41% |
| Yaesu FTDX-1200 | `YaesuCATProtocol` | 8/18 | 11/12 | 11/21 | 2/9 | 2/13 | 0/10 | 0/1 | 40% |
| Yaesu FTDX-3000 | `YaesuCATProtocol` | 8/18 | 12/13 | 11/21 | 2/9 | 2/16 | 0/10 | 0/1 | 40% |
| Yaesu FTDX-5000 | `YaesuCATProtocol` | 8/18 | 12/13 | 11/21 | 2/9 | 2/16 | 0/10 | 0/1 | 40% |
| Yaesu FTDX-9000 | `YaesuCATProtocol` | 7/17 | 9/10 | 11/21 | 1/3 | 2/12 | 0/10 | 0/1 | 41% |
| Yaesu FTX-1 | `YaesuCATProtocol` | 10/21 | 14/16 | 12/24 | 2/9 | 2/18 | 0/10 | – | 41% |
| Yaesu mcHF QRP | `YaesuFT847CAT` | 5/11 | 6/6 | 0/1 | 3/3 | 0/2 | – | – | 61% |

To refresh: `Scripts/hamlib-coverage.py --json out.json --markdown out.md`
(needs the Hamlib build from `Scripts/hamlib-wire-capture.py` and
`HamlibDiffClient`, as `hamlib-diff-audit.py` does).
