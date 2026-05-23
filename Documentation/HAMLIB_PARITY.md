# Hamlib Parity Audit

**Generated:** 2026-05-23 (Phase 5 + Phase 6 planning)
**Reference Hamlib version:** clone at `~/Developer/hamlib`, shallow @ master
**SwiftRigControl HEAD:** post-Phase 5.2 (`261c633`)

This document is a thorough comparison of SwiftRigControl's
exposed API surface against Hamlib's. It is intended to:

1. **Be honest** about what we cover vs. what we don't.
2. **Make the gap visible** to anyone evaluating SwiftRigControl
   for a real app.
3. **Plan additive work**: which gaps are easy ports from
   Hamlib, which are deferred, which are intentionally out of
   scope.

Bottom-line summary (detail below):

- **Headline operating surface (freq, mode, PTT, VFO, split,
  power, S-meter, RIT/XIT, DSP, levels, memory, TX meters, CW
  keyer, scanning, antenna):** good parity for the four
  hardware-verified radios; the same surface is wired for
  every other Icom/Yaesu/Kenwood/Elecraft `RadioDefinition`
  we ship.
- **Function toggles** (NB2, TONE, TSQL, VOX, AFC, MN, ANF,
  LOCK, TUNER, SCOPE, …): SwiftRigControl exposes 6 of
  Hamlib's ~50 function bits. **Biggest gap.**
- **VFO operations** (CPY, XCHG, FROM_VFO, TO_VFO, TUNE, …):
  SwiftRigControl exposes **none** of Hamlib's 14. Big gap
  for a typical UI ("swap A↔B" is a one-tap operation in
  every modern radio control app).
- **Secondary levels** (MICGAIN, MONITOR_GAIN, COMP, VOXGAIN,
  PBT_IN/OUT, NOTCHF, AGC_TIME, …): we expose ~10 of ~52.
- **Parameters** (BACKLIGHT, BEEP, TIME, ANN, …): no support
  at all. Lowest-priority gap — these are settings, not
  operational state.
- **Radio definition count:** SwiftRigControl ships ~90
  definitions; Hamlib has ~350. Most of Hamlib's lead is in
  1980s/1990s radios we deliberately don't target.

---

## Methodology

Hamlib's per-radio capability is declared as bitfields on
`struct rig_caps`:

- `.has_set_func` / `.has_get_func` — function toggles (NB, VOX,
  LOCK, TUNER, etc.)
- `.has_set_level` / `.has_get_level` — analog/discrete levels
  (AF, RF, KEYSPD, SWR, RFPOWER_METER, etc.)
- `.has_set_parm` / `.has_get_parm` — radio parameters (BEEP,
  BACKLIGHT, TIME, ANN, etc.)
- `.vfo_ops` — compound VFO operations (CPY, XCHG, TUNE, etc.)
- `.scan_ops` — scan modes (VFO, MEM, PRIO, PROG, DELTA, …)
- `.has_set_antenna` / `.has_get_antenna` — antenna selection

This audit walks each bitfield universe (Hamlib's complete
list of named bits) and marks each as:

- **✓** — SwiftRigControl exposes equivalent API surface.
- **➕** — Hamlib has it; SwiftRigControl doesn't, but the port
  would be additive (no breaking changes) and the wire-level
  command set is well-documented in Hamlib's source.
- **△** — Partially covered, or covered for some radios only.
- **—** — Out of scope (Hamlib supports a feature we
  deliberately don't target, like rotators or compatibility
  with very old radios).

Hamlib bit names come from `~/Developer/hamlib/src/misc.c`
(`rig_strfunc`, `rig_strlevel`, `rig_strvfo_op`, `rig_strscan`).

---

## Per-feature audit

### Function toggles (`set_func` / `get_func`)

Hamlib defines ~50 function bits. SwiftRigControl currently
exposes break-in via `SupportsCWKeyer`'s `BreakInMode`
(SBKIN/FBKIN), plus noise blanker and noise reduction via
`SupportsNoiseBlanker`/`SupportsNoiseReduction` *as levels*
(SwiftRigControl conflates "on/off" with "level 1-255" via
the `.off` / `.enabled(level:)` cases). The rigctld bridge
also accepts `set_func SBKIN/FBKIN`.

| Hamlib bit          | SwiftRigControl | Notes                                                       |
| ------------------- | --------------- | ----------------------------------------------------------- |
| `NB`                | △ (as level)    | `SupportsNoiseBlanker.NoiseBlanker.off`/`.enabled(level:)`  |
| `NB2`               | —               | Secondary NB stage; Icom 0x16 0x46.                         |
| `NR`                | △ (as level)    | `SupportsNoiseReduction`                                    |
| `COMP`              | ➕              | Speech compressor on/off. **Common**: every HF radio.       |
| `VOX`               | ➕              | Voice-operated transmit. **Common**.                        |
| `TONE`              | ➕              | CTCSS tone encode (FM repeater). **Common** on V/UHF.       |
| `TSQL`              | ➕              | CTCSS squelch (FM repeater). **Common** on V/UHF.           |
| `SBKIN`             | ✓               | `BreakInMode.semi`                                          |
| `FBKIN`             | ✓               | `BreakInMode.full`                                          |
| `ANF`               | ➕              | Auto notch filter. **Common** on modern radios.             |
| `MN`                | ➕              | Manual notch. **Common**.                                   |
| `LOCK`              | ➕              | Front-panel lock. **Common**, one-byte command.             |
| `TUNER`             | ➕              | Antenna tuner on/off. **Common** on ATU-equipped radios.    |
| `SCOPE`             | ➕              | Spectrum scope on/off. Common on IC-7300, IC-7610, IC-9700. |
| `MON`               | ➕              | Sidetone monitor.                                           |
| `AFC`               | ➕              | Auto frequency control (FM).                                |
| `VSC`               | ➕              | Voice squelch (Icom).                                       |
| `RIT`               | △ (as state)    | `SupportsRIT.setRIT` carries the on/off in `RITXITState`.   |
| `XIT`               | △ (as state)    | Same; covered by `SupportsXIT`.                             |
| `SATMODE`           | ➕              | Satellite operating mode. Important for IC-9700.            |
| `DUAL_WATCH`        | ➕              | Dual-receiver simultaneous watch.                           |
| `DIVERSITY`         | ➕              | Diversity reception (IC-7610, FTDX-101).                    |
| `RESUME`            | ➕              | Scan resume.                                                |
| `TBURST`            | —               | 1750 Hz repeater open tone (European).                      |
| `ARO`               | —               | Auto repeater offset (some Yaesu mobiles).                  |
| `AIP`               | —               | RF amp input protection (some Kenwoods).                    |
| `MUTE`              | ➕              | RX audio mute.                                              |
| `REV`               | ➕              | Reverse split/duplex on V/UHF.                              |
| `FAGC`              | —               | Fast AGC override.                                          |
| `BC`/`BC2`          | ➕              | Beat cancel (notch beat tone).                              |
| `RF`                | —               | RF preamp toggle (we have `SupportsPreamp` levels).         |
| `SQL`               | △               | Squelch enabled/disabled (we have `SupportsSquelch` level). |
| `ABM`               | —               | Auto band memory (mobile recall).                           |
| `APF`               | ➕              | Audio peak filter.                                          |
| `MBC`               | —               | Memory bank channel.                                        |
| `ANL`               | —               | Auto noise limiter.                                         |
| `DSQL`/`CSQL`       | ➕              | DCS squelch / call sign squelch.                            |
| `AFLT`              | —               | Audio filter.                                               |
| `TX` flagged ops    | —               | TX_INHIBIT, MN, ANR, etc.                                   |

**Summary:** SwiftRigControl exposes 2 dedicated function bits
(SBKIN/FBKIN). ~13 more (marked ➕ as **Common**) are
straightforward Icom-CI-V or Kenwood/Yaesu commands that should
be added before any "approaching Hamlib parity" claim. The
right shape is a new trait:

```swift
public protocol SupportsFunctions: CATProtocol {
    func setFunction(_ function: RigFunction, enabled: Bool) async throws
    func getFunction(_ function: RigFunction) async throws -> Bool
}

public enum RigFunction: String, Sendable, CaseIterable {
    case compressor, vox, tone, tsql, autoNotch, manualNotch,
         lock, tuner, scope, monitor, autoFrequencyControl,
         voiceSquelch, satelliteMode, dualWatch, diversity,
         resume, mute, reverse, dcsSquelch
    // ... (subset of Hamlib's universe — only the bits that
    // map to real Icom/Yaesu/Kenwood/Elecraft surface)
}
```

Per-radio capability is gated by a new
`RigCapabilities.supportedFunctions: Set<RigFunction>`.

### Levels (`set_level` / `get_level`)

Hamlib defines ~52 level bits. SwiftRigControl exposes ~12
via dedicated trait protocols (AF, RF, squelch, preamp,
attenuator, AGC, RFPOWER, IF filter, KEYSPD, CWPITCH, plus
the read-only TX-meter levels SWR/ALC/RFPOWER_METER/
RFPOWER_METER_WATTS/COMP_METER/VD_METER/ID_METER) — the
Phase 4.1 and 4.5 work covered these.

| Hamlib level                | SwiftRigControl              | Notes                                                     |
| --------------------------- | ---------------------------- | --------------------------------------------------------- |
| `AF`                        | ✓ `SupportsAFGain`           |                                                           |
| `RF`                        | ✓ `SupportsRFGain`           |                                                           |
| `SQL`                       | ✓ `SupportsSquelch`          |                                                           |
| `PREAMP`                    | ✓ `SupportsPreamp`           |                                                           |
| `ATT`                       | ✓ `SupportsAttenuator`       |                                                           |
| `RFPOWER`                   | ✓ `SupportsPower`            | Universal core.                                           |
| `AGC`                       | ✓ `SupportsAGC`              |                                                           |
| `NB`                        | ✓ `SupportsNoiseBlanker`     | Hamlib also has `RIG_LEVEL_NB`; treated as level by us.   |
| `NR`                        | ✓ `SupportsNoiseReduction`   |                                                           |
| `KEYSPD`                    | ✓ `SupportsCWKeyer`          |                                                           |
| `CWPITCH`                   | ✓ `SupportsCWKeyer`          |                                                           |
| `BKINDL`                    | △                            | Break-in delay; we have mode only, not delay value.       |
| `STRENGTH` / `RAWSTR`       | ✓ `SupportsSignalStrength`   |                                                           |
| `SWR`                       | ✓ `SupportsTXMeters.getSWR()`|                                                           |
| `ALC`                       | ✓ `SupportsTXMeters.getALC()`|                                                           |
| `RFPOWER_METER`             | ✓ `getRFPowerOut()`          |                                                           |
| `RFPOWER_METER_WATTS`       | ✓ `getRFPowerOut().watts`    |                                                           |
| `COMP_METER`                | ✓ `getComp()`                |                                                           |
| `VD_METER`                  | ✓ `getVoltage()`             |                                                           |
| `ID_METER`                  | ✓ `getCurrent()`             |                                                           |
| `TEMP_METER`                | ➕                           | TX-final temp. Common on modern Icoms.                    |
| `MICGAIN`                   | ➕                           | Mic gain level. **Very common**.                          |
| `COMP`                      | ➕                           | Compressor *level* (separate from on/off function).       |
| `MONITOR_GAIN`              | ➕                           | Sidetone monitor level.                                   |
| `VOXGAIN`                   | ➕                           | VOX gain (sensitivity).                                   |
| `VOXDELAY`                  | ➕                           | VOX hang time.                                            |
| `ANTIVOX`                   | ➕                           | Anti-VOX (mic-to-speaker rejection).                      |
| `PBT_IN`                    | ➕                           | Passband tuning inner.                                    |
| `PBT_OUT`                   | ➕                           | Passband tuning outer.                                    |
| `NOTCHF` / `NOTCHF_RAW`     | ➕                           | Notch filter frequency.                                   |
| `APF`                       | ➕                           | Audio peak filter level.                                  |
| `AGC_TIME`                  | ➕                           | AGC time constant (separate from speed).                  |
| `IF`                        | ➕                           | IF shift (separate from filter selection).                |
| `SPECTRUM_*`                | —                            | Phase 6 territory (spectrum scope streaming).             |
| `USB_AF` / `USB_AF_INPUT`   | —                            | USB audio routing on modern Icoms.                        |
| `BALANCE`                   | —                            | Stereo audio balance.                                     |
| `SPECTRUM_ATT`              | —                            | Spectrum scope attenuator.                                |
| `BAND_SELECT`               | △                            | Hamlib `RIG_PARM_BANDSELECT` covers; we defer.            |

**Summary:** ~10 levels are common-and-missing. MICGAIN, COMP
(level), MONITOR_GAIN, VOX-related, and IF shift are
table-stakes for a serious app. The right shape is to add
these to existing trait protocols (one trait per level pair),
or — if churning the trait surface feels too granular —
introduce a single `SupportsExtendedLevels` trait with a
`RigLevel` enum and `setLevel(_:value:)` / `getLevel(_:)`
methods, matching Hamlib's shape directly.

I'd recommend **per-trait** for the high-traffic ones (MICGAIN,
COMP-level, MONITOR_GAIN — each gets its own protocol like
`SupportsMicGain`) and the enum-keyed approach for the
long-tail. Pattern matches what we already have.

### VFO operations (`vfo_op`)

Hamlib defines 14 compound VFO operations. **SwiftRigControl
exposes none.** This is the largest single gap relative to
how a typical UI is built.

| Hamlib op       | What it does                                          | Priority |
| --------------- | ----------------------------------------------------- | -------- |
| `CPY`           | Copy active VFO to other VFO (A→B or B→A).            | **High** |
| `XCHG`          | Swap A↔B.                                             | **High** |
| `FROM_VFO`      | Memory write: store VFO to current memory channel.    | **High** |
| `TO_VFO`        | Memory read: recall current memory channel to VFO.    | **High** |
| `MCL`           | Memory clear (current channel).                       | Medium   |
| `UP`            | Step VFO up (by configured tuning step).              | Medium   |
| `DOWN`          | Step VFO down.                                        | Medium   |
| `BAND_UP`       | Next band.                                            | Medium   |
| `BAND_DOWN`     | Previous band.                                        | Medium   |
| `LEFT` / `RIGHT`| Cursor / sub-band navigation.                         | Low      |
| `TUNE`          | Auto-tune the ATU.                                    | **High** |
| `TOGGLE`        | A/B toggle (similar to XCHG on some radios).          | Medium   |

**Recommendation:** add a new trait protocol:

```swift
public protocol SupportsVFOOperations: CATProtocol {
    func vfoOperation(_ op: VFOOperation) async throws
}

public enum VFOOperation: String, Sendable, CaseIterable {
    case copyAToB, copyBToA, exchange, memoryToVFO, vfoToMemory,
         memoryClear, stepUp, stepDown, bandUp, bandDown, tune
}
```

For Icom: maps to `0x07` sub-commands. For Yaesu: maps to
various `SF`/`SH` shapes. For Elecraft: K-series specific.
Per-radio support gated by a `Set<VFOOperation>` on
`RigCapabilities`.

This trait alone meaningfully closes the gap on what an
operator UI needs.

### Scan operations

Covered in Phase 4.3. Six scan kinds match Hamlib's `scan_ops`
(VFO, MEM, SLCT, PRIO, PROG, DELTA + STOP). No gap.

### Antennas

Covered in Phase 4.4. `antennaCount` matches Hamlib's per-
radio `*_ANTS` masks. No structural gap, though we don't yet
model the second `Option` argument Hamlib's `set_ant` carries
(RX-only routing on some Icoms — niche).

### Parameters (`set_parm` / `get_parm`)

| Hamlib parm   | SwiftRigControl | Notes                                              |
| ------------- | --------------- | -------------------------------------------------- |
| `BACKLIGHT`   | ➕              | LCD brightness.                                    |
| `KEYLIGHT`    | ➕              | Front-panel key backlight.                         |
| `BEEP`        | ➕              | Beep on/off.                                       |
| `TIME`        | ➕              | Set the radio's internal clock.                    |
| `ANN`         | —               | Voice announce (niche).                            |
| `BANDSELECT`  | ➕              | Band recall (Phase 4.4 deferred).                  |
| `SCREENSAVER` | —               | Display timeout (modern radios).                   |
| `KEYERTYPE`   | —               | Iambic A / Iambic B / straight.                    |

**Summary:** parm support is missing entirely. This is the
lowest-priority gap — these are radio configuration, not
operational state. Apps that need them today reach through
`rawProtocol` to the vendor-specific actor.

**Recommendation:** defer to Phase 6+. Adding a `SupportsParms`
trait with an enum-keyed shape matches Hamlib but isn't a
v1.1 blocker. The handful of parm needs apps actually have
(beep on/off, backlight) can be exposed as one-off methods
on the relevant vendor extension if a user asks.

---

## Per-radio definition coverage

What SwiftRigControl ships today (~90 radios) covers the
majority of post-2000 popular models across Icom, Yaesu,
Kenwood, Elecraft. The remaining gap is mostly:

- **1980s/1990s rigs** that Hamlib supports — we deliberately
  don't target them.
- **A handful of post-2000 models** we haven't added yet.
- **Receivers** beyond the three we ship (IC-R75, IC-R8600,
  IC-R9500).
- **D-STAR / DMR handhelds** beyond TH-D72/TH-D74 and
  ID-4100/ID-5100.

### Modern Icom transceivers since 2000

| Model         | Year    | Status | Hamlib file       |
| ------------- | ------- | ------ | ----------------- |
| IC-7800       | 2004    | ✓      | ic7800.c          |
| IC-7700       | 2008    | ✓      | ic7700.c          |
| IC-7600       | 2009    | ✓      | ic7600.c          |
| IC-7400       | ~2002   | ✓      | (covered)         |
| IC-7100       | 2013    | ✓      | ic7100.c          |
| IC-7200       | 2008    | ✓      | ic7200.c          |
| IC-7300       | 2016    | ✓      | ic7300.c          |
| IC-7300 MK2   | 2025    | ✓      |                   |
| IC-7610       | 2017    | ✓      | ic7610.c          |
| IC-7700       | 2008    | ✓      |                   |
| IC-7760       | 2024    | ✓      |                   |
| IC-7850       | 2014    | ✓      | ic785x.c          |
| IC-7851       | 2014    | ✓      | ic785x.c          |
| IC-705        | 2020    | ✓      | (in ic7300.c)     |
| IC-9100       | 2010    | ✓      | ic9100.c          |
| IC-9700       | 2019    | ✓      | (in ic7300.c)     |
| IC-905        | 2023    | ✓      |                   |
| IC-7000       | 2005    | ✓      | ic7000.c          |
| IC-7410       | 2011    | ✓      | ic7410.c          |
| IC-718        | 2000    | ✓      | ic718.c           |
| IC-746PRO     | 2003    | ✓      |                   |
| IC-2730       | 2014    | ✓      | ic2730.c          |
| IC-2820H      | 2007    | ✓      |                   |
| IC-9000       | 1999    | ✓      |                   |
| ID-4100       | 2014    | ✓      |                   |
| ID-5100       | 2014    | ✓      |                   |
| **ID-31/51/52** | 2012-2022 | ➕  | id31.c/id51.c/id52plus.c — D-STAR handhelds |
| **IC-92D**    | 2008    | ➕     | ic92d.c — D-STAR handheld         |
| **IC-9100M**  | 2010    | △      | covered by ic9100.c           |

### Modern Yaesu transceivers since 2000

| Model         | Year    | Status |
| ------------- | ------- | ------ |
| FT-100/FT-100D| 1999/2000 | ✓    |
| FT-817 / FT-818 | 2001/2018 | ✓  |
| FT-857 / FT-857D | 2003 | ✓     |
| FT-897 / FT-897D | 2003 | ✓     |
| FT-847        | 1998    | ✓      |
| FT-920        | 1997    | ✓      |
| FT-950        | 2007    | ✓      |
| FT-2000       | 2006    | ✓      |
| FT-450 / FT-450D | 2007 | ✓     |
| FT-891        | 2016    | ✓      |
| FT-991 / FT-991A | 2014 | ✓     |
| FT-710        | 2022    | ✓      |
| FT-1000MP     | 1998    | ✓      |
| FT-9000       | 2005    | ✓      |
| FT-5000       | 2009    | ✓      |
| FT-3000       | 2008    | ✓      |
| FT-1200       | 2014    | ✓      |
| FTDX-10       | 2020    | ✓      |
| FTDX-101D / MP | 2018   | ✓      |
| **FT-840**    | 1993    | —      | older                   |
| **FT-890**    | 1993    | —      | older                   |
| **FT-990 / 990v12** | 1991 | —   | older                   |
| **FT-1000D**  | 1990    | —      | older                   |
| **FT-450 (non-D)** | 2007 | △    | covered as FT-450       |
| **VR-5000**   | ~2002   | ➕     | wideband receiver       |
| **VX-1700**   | ~2010   | ➕     | marine HF transceiver   |

### Modern Kenwood transceivers since 2000

| Model         | Year    | Status |
| ------------- | ------- | ------ |
| TS-2000       | 2000    | ✓      |
| TS-590S       | 2010    | ✓      |
| TS-590SG      | 2014    | ✓      |
| TS-480 (all)  | 2004    | ✓      |
| TS-890S       | 2018    | ✓      |
| TS-990S       | 2013    | ✓      |
| TS-570S/D     | 1998    | ✓      |
| TS-870S       | 1995    | ✓      |
| TS-850S       | 1991    | ✓ (legacy) |
| TS-690        | 1990    | —      | older                  |
| TS-450/690    | 1990    | —      | older                  |
| **TH-D72A**   | 2010    | ✓      |
| **TH-D74**    | 2015    | ✓      |
| **TM-D710**   | 2006    | ✓      |
| **TM-V71**    | 2010    | ✓      |
| **TH-D75**    | 2023    | ➕     | newer D-STAR handheld  |
| **TH-F6A** / **TH-F7E** | 2002 | ➕ | older but popular     |
| **TM-D700**   | 1998    | ➕     | popular older         |
| **R-5000**    | 1986    | —      | older receiver         |

### Modern Elecraft (K-series)

| Model | Year | Status |
| ----- | ---- | ------ |
| K2    | 1999 | ✓ (verified) |
| K3    | 2007 | ✓      |
| K3S   | 2014 | ✓      |
| K4    | 2019 | ✓      |
| KX2   | 2016 | ✓      |
| KX3   | 2012 | ✓      |

### Receivers / specialty

| Model | Year | Status | Notes                                   |
| ----- | ---- | ------ | --------------------------------------- |
| IC-R75 | 2000 | ✓     |                                         |
| IC-R8600 | 2017 | ✓   |                                         |
| IC-R9500 | 2006 | ✓   |                                         |
| **IC-R30** | 2018 | ➕ | wideband digital RX, popular           |
| **IC-R8500** | 1996 | ➕ | older but popular                    |
| **IC-R6/R20** | 2003/2004 | ➕ | handheld wideband               |
| **Perseus** | 2007 | ➕  | SDR receiver                            |
| **FlexRadio 6xxx** | 2014+ | — | requires SmartSDR (not serial CAT)   |

### Other manufacturers

| Manufacturer | Status | Notes |
| ------------ | ------ | ----- |
| **Xiegu** (G90, X6100, X6200) | ✓ (3 models) | Already shipped |
| **Ten-Tec** (Orion, Orion II, Eagle, Jupiter, Pegasus) | ✓ | Orion + Legacy protocols |
| **Lab599 TX-500** | ➕ | Modern portable; Kenwood-like protocol |
| **QRP Labs** QDX / QMX | ➕ | Popular digital QRP |

---

## Triaged work list

### v1.1.0 candidates (close before release)

If "approaching Hamlib parity" matters for v1.1, these are the
highest-impact additive wins. None require breaking changes.

1. **VFO operations trait** (5–6 most-used ops: CPY, XCHG,
   FROM_VFO, TO_VFO, TUNE, MCL). One new trait, one new enum,
   wire commands well-documented in Hamlib per-radio source.
2. **Function toggles trait** for the common bits (COMP, VOX,
   TONE, TSQL, LOCK, TUNER, ANF, MN, SATMODE, MUTE, REV,
   DUAL_WATCH, SCOPE, MON, AFC). One new trait, one new enum,
   one `Set<RigFunction>` on RigCapabilities.
3. **Secondary levels** (MICGAIN, COMP-level, MONITOR_GAIN,
   VOXGAIN, VOXDELAY, IF-shift, PBT_IN/OUT, NOTCHF). Either
   per-trait protocols or a single `SupportsExtendedLevels`
   trait with enum keys (latter is more Hamlib-shaped).
4. **Definition adds** for ~5 currently-missing radios that
   look common: TH-D75 (2023 D-STAR HT), ID-31/51/52 (D-STAR
   HTs we don't have), Lab599 TX-500, IC-R30.

### Phase 6 candidates

1. **Parm trait** (BACKLIGHT, BEEP, TIME, KEYLIGHT).
2. **Spectrum scope streaming** (SPECTRUM_*) — already roadmapped.
3. **Older Kenwood / Yaesu rigs** (TS-450, TS-690, FT-840,
   FT-890, FT-990) — only if user demand surfaces.
4. **D-STAR-specific operations** (call signs, message,
   D-STAR status) — already in Hamlib's `cmdparams` table for
   IC-9100/IC-7100; warrants its own feature trait.
5. **FlexRadio** — requires SmartSDR networking, not serial
   CAT. Different transport layer entirely.

### Out of scope (deliberate)

- Pre-1990s rigs (no CAT or very limited CAT).
- Marine / aero / commercial radios (different domain).
- Rotators (use `rotctld`).
- Amplifiers.

---

## Recommended next step

**Before tagging v1.0.7** (a documentation-only patch release of
what's on `main`), consider whether to roll this audit into a
v1.1.0 that includes at least items 1 and 2 from the "v1.1.0
candidates" list — VFO operations + function toggles. That
delivers the most-felt parity improvement in a single batch
and lines up with the post-Phase-5 architectural reshape as
the right milestone for adopters to pin against.

Items 3 and 4 can ship in v1.1.x patch releases as they land.
