# Hamlib parity audit — 2026-10-19

## Scope and source

This audit compares SwiftRigControl `main` after v1.2.20 with Hamlib
`master` at `06335264db0106053a2d9f7122cab28be27fe15d` (2026-10-19).
The prior human-reviewed baseline was `7a556dbfc806`; the automated
watermark had advanced through `58beb9ab5bb8`.

The review covers all 126 catalog entries mapped in `HAMLIB_WATCH.md`:

| Family | Radios | Swift implementation | Hamlib sources |
| --- | ---: | --- | --- |
| Icom | 51 | CI-V plus per-family command sets | `rigs/icom/` |
| Yaesu | 30 | newcat and four binary CAT adapters | `rigs/yaesu/` |
| Kenwood | 24 | Kenwood text, TH-D72, TH/TM family adapters | `rigs/kenwood/` |
| Elecraft | 6 | Elecraft/Kenwood text protocol | `rigs/kenwood/k2.c`, `k3.c`, `elecraft.c` |
| Ten-Tec | 6 | Orion and legacy protocols | `rigs/tentec/` |
| Xiegu | 3 | CI-V variants | `rigs/icom/xiegu.c` |
| Flex family | 5 | Kenwood-derived text protocol | `flex6xxx.c`, `ts2000.c`, `pihpsdr.c` |
| Lab599 | 1 | Kenwood-derived text protocol | `tx500.c` |

The audit checked source-path coverage, serial defaults, CI-V addresses,
frequency/mode/PTT framing, VFO and split selection, RIT/XIT, set-command
reply behavior, mode tables, and whether incomplete adapters over-claim
capabilities. Existing byte-exact and catalog-drift tests were used as the
regression baseline.

## Upstream changes since the prior watermark

### Applicable

1. `91deb674` — FTX-1 CW send uses TEXT memory 5 (`KM5...;`, then
   `KY05;`); `KY0<text>;` is invalid because `KY` only starts/stops a
   stored memory. SwiftRigControl does not currently conform
   `YaesuCATProtocol` to `SupportsSendCW`, so it does not emit the bad
   command, but FTX-1 CW send/stop remains a completeness gap.
2. `aff6e940` — G90 RIT is SET-only, ±500 Hz, uses only CI-V `21 00`,
   and treats zero as disabled. The shared Icom implementation previously
   sent the Icom-only `21 01` follow-up and exposed a lossy getter. Fixed
   in this audit with byte-exact tests.
3. `112304a` — FTX-1 Main/Sub clarifier cache must be VFO-scoped. This
   exposed a larger local mismatch: SwiftRigControl used generic newcat
   `RC/RU/RD/RT/XT` commands on the FTX-1, while that radio requires its
   `CF` command family. Fixed for the current Main-side RIT/XIT API by
   reading the paired enable state before writes, avoiding Hamlib's cache
   race entirely.

### Not applicable

- `fa0ed6d6` concerns Hamlib `rig_send_raw`; SwiftRigControl does not
  implement `send_raw`.
- `f8df85d1` keeps Hamlib configuration-level PTT overrides per instance;
  SwiftRigControl stores state per protocol actor and has no global PTT
  override.
- `ff30b987` validates Hamlib CLI PTT option parsing; SwiftRigControl does
  not expose that CLI configuration path.

## Findings by family

### Icom and Xiegu

Status: core command framing is aligned for the implemented surface.

- CI-V address drift tests cover the catalog, including IC-7300MK2 `0xB6`,
  IC-7760 `0xB2`, and G90 `0x88`.
- DATA-mode handling now follows each command set's `data_mode_supported`
  and `x25x26_always` behavior rather than inferring it from VFO shape.
- AGC uses per-model Hamlib byte tables.
- G90 RIT was the only newly confirmed wrong-wire command and is fixed.
- The IC-F8101 has its required `1A 35/36/34/37` commands but remains
  definition-only.

Open completeness items:

- The IC-7300MK2 DATA modulation-source number was absent from Hamlib's
  table. The official Icom CI-V guide identifies it as `1A 05 00 85`;
  the original IC-7300 remains `1A 05 00 67`. Both are now recorded in
  the per-model menu-setting table with regression coverage.
- Native DV/D-STAR mode is now implemented: Icom CI-V `0x17`, Kenwood
  TH-D74/75 mode indices, rigctld naming/passband, and model/range
  capabilities are covered. D-STAR-specific callsign, routing, message,
  GPS, and status operations remain additive work.
- Several advanced settings implemented only for IC-7100/7600/9700 are
  not generalized to other Icoms even where Hamlib exposes equivalents.
  They are not advertised as portable capabilities, so this is additive
  work rather than a current correctness defect.
- ID-52A/E PLUS is now a distinct catalog model based on Hamlib
  `id52plus.c` (CI-V `0xB4`, 4800–19200 baud, Main/Sub, FM/FM-N,
  AM/AM-N receive, D-STAR, tones, DCS, VOX, levels and PTT). The shared
  CI-V implementation now preserves FIL2 so FM-N and AM-N set/read
  correctly instead of collapsing to their wide modes.
- Hamlib master does not currently provide ID-50, ID-5200, or IC-R15
  backends. Those models are intentionally not presented as complete
  Hamlib-derived implementations until authoritative command/address
  definitions are available upstream.

### Yaesu newcat and FTX-1

Status: shared newcat frequency, mode, split, set verification, monitor,
power-state, and filter forms agree with Hamlib for the catalog presets.

- The FTX-1 mode table, nine-digit frequency form, VFO-mode escape, and
  targetable mode behavior remain aligned.
- FTX-1 RIT/XIT now uses `CF` and preserves the paired clarifier state.
- The upstream per-VFO cache bug does not apply to the new implementation:
  SwiftRigControl queries current paired state for each write and its
  public RIT/XIT API currently targets Main.

Open completeness items:

- SwiftRigControl's RIT/XIT public API cannot target Main versus Sub. A
  future VFO-qualified overload is needed for complete FTX-1 clarifier
  coverage.
- FTX-1 CW message send/stop is implemented with `KM5`/`KY05` and
  `KY00`, including uppercase ASCII and 50-character handling.
- FTX-1 DATA-FM, AM-N, C4FM, and DATA-FM-N now follow Hamlib's
  executable newcat conversion table. The older `ftx1_mode.c` comment
  labeling code `E` as PSK conflicts with both that table and Hamlib's
  FTX-1 capability mask; no unsupported PSK mode is advertised.

### Yaesu binary CAT

Status: setter wire formats and fixed-length reads are substantially
aligned; readback completeness varies by adapter.

- `YaesuPortableCAT` covers FT-817/818/857/897 mode, frequency, PTT and
  status parsing; DATA USB/LSB uses DIG `0x0A` and DATA FM uses PKT `0x0C`.
- `YaesuFT100CAT` corrects the formerly wrong FT-817-family routing.
- `YaesuFT847CAT` now covers its combined frequency/mode status frame,
  PTT, cached satellite split state, RX S-meter, and TX ALC status. Its
  satellite mode writes use the Hamlib `opcode_vfo()` routing, and
  unsupported RF-power/DATA-mode capability claims have been removed.
- `YaesuFT1000MPCAT` now decodes both VFO frequency/mode records and split
  flags for the FT-1000MP/MARK-V family and the FT-920's distinct 28-byte
  layout. FT-920 PTT readback and both families' RIT/XIT clarifier controls
  are implemented. FT-1000MP PTT readback remains unsupported, matching
  Hamlib's advertised capability surface. Neither family claims RF-power
  setting; Hamlib exposes RF power as meter readback rather than a settable
  level for the FT-1000MP. Its S-meter now uses Hamlib's twelve-point
  calibration, and RF-power, ALC, compression, and SWR return Hamlib-style
  normalized readings. FT-920 signal and TX-meter advertising stays disabled
  because its Hamlib backend exposes no corresponding getters.
- FT-1000MP-family rated output is model-specific: FT-1000MP and MARK-V Field
  use 100 W capability records; MARK-V uses 200 W. The protocol implementation
  remains shared because Hamlib documents an identical CAT surface.
- Hamlib declares FT-817/857/897 serial ranges of 4800–38400, 8-N-2,
  without flow control. SwiftRigControl retains that framing and now uses
  the FT-857/857D factory 4800-baud setting as its connection default.

### Kenwood, Flex, and Lab599

Status: the high-risk shared set-command and DATA-mode paths now match
Hamlib's per-model styles and are protected by `KenwoodModeStyleTests`.

- Set commands are verified using `ID;` instead of waiting for nonexistent
  echoes.
- TS-590S/SG (`MD` + `DA`), TS-990S (`OM0`), TS-890S (`SF`), Flex
  (`MD6/MD9`) and PowerSDR/Thetis (`ZZMD`) DATA modes are separated.
- Legacy `.standard` mode tables remain broader than some individual
  radios. Unsupported modes are rejected by hardware, but trimming each
  table would improve capability accuracy.
- TH-D75 now has a dedicated Hamlib TH-D74/TH-D75 record codec in
  `thd7x.c/.h`. The focused follow-up corrected TH-D74/TH-D75 mode access
  to use `MD band,mode`, updated TH-D75 modes/ranges/functions, and aligned
  model-specific serial flow control. Frequency record rewriting remains
  compatible with the shared codec for the fields SwiftRigControl changes.
- The same serial audit corrected TM-V71, TH-F6A, and TH-F7E to 8-N-1
  without handshake; TM-D710 remains RTS/CTS as Hamlib specifies.
- QRP Labs QMX is now implemented as a definition-only TS-480 subset with
  model-specific `PC`/`SW` metering. SwiftRigControl deliberately recommends
  ordinary USB for digital audio (`preferredDataMode`) because QMX users report
  Hamlib's packet-USB mapping selects the incompatible front-panel `DiGi` mode.
- Hamgeek uSDX is now implemented against Hamlib's dedicated `hamgeek.c`
  backend. The adapter models its single VFO, `MD1`…`MD5` aliases, lack of
  reliable PTT readback, asymmetric `TX`/`RX0` replies, and serial garbage
  filtering; hardware validation remains outstanding.

### Elecraft

Status: K3/K3S/K4/KX set verification and strict boolean reply parsing
match Hamlib. The K2 retains its previously hardware-tested write-plus-delay
path.

Open items:

- Re-verify K2 at 8-N-2 before changing its set verification or enabling
  `K22` extended-power mode.
- Commands outside the shared public surface (for example richer K4
  controls) remain additive completeness work.

### Ten-Tec

Status: command formats agree for the implemented Orion and legacy
surfaces, but all six definitions require hardware validation.

- Legacy Jupiter/Pegasus CAT PTT is intentionally unsupported rather than
  emitting an unverified command.
- Jupiter/Pegasus tuning-factor encoding remains the highest-risk item
  because it was rewritten locally and has not touched hardware.

## Tooling finding

The weekly watcher used the literal path `rigs/yaesu/ftx1/*.c`. Because
the path list is passed to Git as a quoted array, Git did not expand that
glob; the watcher missed `91deb674`. The watch entry now targets the whole
`rigs/yaesu/ftx1` directory, and the work-order mapper recognizes it. The
TH-D75 entry was also updated to reflect Hamlib's current dedicated
`thd7x` codec.

## Priority order before hardware validation

1. Land and mock-test the G90 RIT, FTX-1 clarifier, and watcher fixes.
2. Hardware-validate the new FTX-1 `KM5`/`KY` CW-message path.
3. Hardware-validate FT-857/857D startup at the factory 4800-baud setting.
4. Hardware-validate TH-D75 frequency/mode and flow-control behavior.
5. Run `HARDWARE_CHECK_v1.2.19.md`, then seek Kenwood/Yaesu field reports.

## Verification performed

- All mapped Hamlib paths exist at the audited commit.
- The corrected watcher surfaces the FTX-1 CW commit.
- Xcode build-for-testing succeeds.
- The pre-audit baseline ran 1,043 tests: 986 passed, 57 hardware tests
  skipped, zero failures.
- The post-change suite ran 1,052 tests: 995 passed, 57 hardware tests
  skipped, zero failures.
- The focused FTX-1/FT-857/Kenwood follow-up ran 1,060 tests: 1,003
  passed, 57 hardware tests skipped, zero failures.

## Follow-up: native Flex SmartSDR

The catalog now also includes SmartSDR Slice A–H through a dedicated
native TCP adapter cross-referenced against Hamlib `smartsdr.c` and
`smartsdr_caps.h`. It uses port 4992 command/reply/status framing rather
than the separate Kenwood-compatible CAT bridge. The original 6000-series
CAT definition remains available for compatibility.

The native SmartSDR follow-up ran 1,068 tests: 1,011 passed, 57
hardware tests skipped, zero failures.
