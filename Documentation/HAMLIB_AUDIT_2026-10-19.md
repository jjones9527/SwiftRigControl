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

- The IC-7300MK2 DATA modulation-source `1A 05` number is still absent
  from the available Hamlib table and must come from its CI-V manual.
- DV/D-STAR has no native Swift `Mode` case; the former DATA stand-ins
  were correctly removed.
- Several advanced settings implemented only for IC-7100/7600/9700 are
  not generalized to other Icoms even where Hamlib exposes equivalents.
  They are not advertised as portable capabilities, so this is additive
  work rather than a current correctness defect.

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

- Implement FTX-1 `SupportsSendCW` with `KM5`/`KY05`, `KY00` stop,
  uppercase/50-character handling, and playback sequencing. Do not add a
  generic `KY0<text>` implementation.
- SwiftRigControl's RIT/XIT public API cannot target Main versus Sub. A
  future VFO-qualified overload is needed for complete FTX-1 clarifier
  coverage.
- FTX-1 C4FM and PSK modes have no Swift `Mode` equivalents.

### Yaesu binary CAT

Status: setter wire formats and fixed-length reads are substantially
aligned; readback completeness varies by adapter.

- `YaesuPortableCAT` covers FT-817/818/857/897 mode, frequency, PTT and
  status parsing; DATA USB/LSB uses DIG `0x0A` and DATA FM uses PKT `0x0C`.
- `YaesuFT100CAT` corrects the formerly wrong FT-817-family routing.
- `YaesuFT1000MPCAT` and `YaesuFT847CAT` deliberately leave some core
  getters unsupported because their status-block decoders are incomplete.
  These radios must remain definition-only until getter parity is added.
- Hamlib declares FT-817/857/897 serial ranges of 4800–38400, 8-N-2,
  without flow control. SwiftRigControl has the correct 8-N-2 profile,
  but the FT-857/857D catalog default of 38400 conflicts with the reported
  factory 4800 setting in issue #40. Confirm against the Yaesu manual or
  reporter before changing all related defaults.

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
  `thd7x.c/.h`; SwiftRigControl still routes it through the older D74-like
  TH-D72 adapter. This is the highest-priority Kenwood completeness audit.
- QRP-Labs QMX exists in Hamlib's `ts480.c` with model-specific modes and
  metering. It is not yet in SwiftRigControl (issue #39).

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
2. Decide whether FTX-1 CW send belongs in the same patch or the next
   feature release; it is missing functionality, not a regression.
3. Investigate FT-857 issue #40 with its log and menu-013 baud setting.
4. Perform a focused TH-D75 `thd7x` diff before claiming TH-D75 protocol
   completeness.
5. Run `HARDWARE_CHECK_v1.2.19.md`, then seek Kenwood/Yaesu field reports.

## Verification performed

- All mapped Hamlib paths exist at the audited commit.
- The corrected watcher surfaces the FTX-1 CW commit.
- Xcode build-for-testing succeeds.
- The pre-audit baseline ran 1,043 tests: 986 passed, 57 hardware tests
  skipped, zero failures.
- The post-change suite ran 1,052 tests: 995 passed, 57 hardware tests
  skipped, zero failures.
