# v1.2 Parity Plan

Verified Hamlib parity push plan, derived from the inventory
survey and ground-truth verified against actual Hamlib source
at `~/Developer/hamlib`.

**Verification methodology:** every radio listed below was
checked via `grep -E "RIG_MODEL\(RIG_MODEL_<X>\)" rigs/*/*.c` to
confirm a real `rig_caps` struct exists. The survey returned
some hallucinated entries (IC-9000, IC-2820H, TH-D75, IC-7851
as a separate file) — those are corrected here.

## Verification corrections to the inventory survey

The survey reported these as Hamlib radios; they're not:

- **IC-9000** — not in Hamlib. We ship a SwiftRigControl-native
  definition (derived from manufacturer manual + IC-910H
  family).
- **IC-2820H** — not in Hamlib. Same situation.
- **IC-7851** — not in Hamlib as a separate model; covered by
  `rigs/icom/ic785x.c` under `RIG_MODEL_IC785x` (one struct
  serves both IC-7850 and IC-7851).
- **TH-D75** — not in Hamlib. We ship our own definition based
  on the TH-D74 CAT inheritance + manual.

The survey also reported these as gaps; they're already shipping:

- **Xiegu G90, X6100, X6200** — already in our catalog
  (`RadioCapabilitiesDatabase+Xiegu.swift`).
- **IC-7850, IC-7851** — already shipping.
- **IC-7300MK2, IC-7760, IC-905, IC-9700** — already shipping.

## True parity gap — modern (2000+) and active-userbase older

After verification, the real gap of in-scope radios is much
smaller than the survey suggested. Below: every radio that's in
Hamlib, not in SwiftRigControl, and meets the user's directive
(released 2000+ OR confirmed large active userbase).

### Tier 1 — ship in v1.2.0 (modern, popular, reuses existing protocol)

| Vendor | Model | Hamlib file:line | Year | Protocol reuse | Notes |
|--------|-------|------------------|------|----------------|-------|
| Kenwood | **TH-F6A** | `kenwood/thf6a.c` | 2002 | KenwoodProtocol | Popular tri-band HT |
| Kenwood | **TH-F7E** | `kenwood/thf7.c` | 2002 | KenwoodProtocol | EU variant of TH-F6A |
| Kenwood | **TM-D700** | `kenwood/tmd700.c` | 2000 | KenwoodProtocol | Predecessor to TM-D710; still in use |
| Kenwood | **TH-D7** | `kenwood/thd7.c` | 2000 | KenwoodProtocol or new (verify; predecessor to TH-D72) |
| Kenwood | **TH-G71** | `kenwood/thg71.c` | ~2000 | KenwoodProtocol | Older HT, niche but real |
| Yaesu | **VX-1700** | `yaesu/vx1700.c` | ~2010 | YaesuCATProtocol | Marine HF, borderline scope but real CAT |
| Ten-Tec | **Omni VII (TT-588)** | `tentec/omnivii.c` | 2006 | TenTec Orion (or new — verify) | Highest-end Ten-Tec |
| Ten-Tec | **Argonaut (TT-516)** | `tentec/argonaut.c` | ~2010 | TenTec Legacy (verify) | Modern QRP version |
| Ten-Tec | **Paragon (TT-585)** | `tentec/paragon.c` | ~1985-pre-cap | TenTec Legacy | Borderline — verify userbase |

### Tier 1.5 — FlexRadio family (requires new TCP transport)

Per user's explicit authorization (commit history shows the Flex
discussion). The TCP transport is reusable infrastructure for
future radios (Icom ProAudio, remote rigctld bridging) — not
Flex-only.

| Hamlib model | RIG_MODEL_* | Hamlib file:line | Real-world radios | Wire protocol |
|--------------|-------------|------------------|-------------------|---------------|
| F6K | `RIG_MODEL_F6K` | `kenwood/flex6xxx.c` | Flex-6300, 6400, 6500, 6500R, 6600, 6700 | Kenwood-text over TCP:4992 (custom CAT bridge) |
| PowerSDR | `RIG_MODEL_POWERSDR` | `kenwood/flex6xxx.c` | Flex-3000, Flex-5000, Apache Labs ANAN (PowerSDR firmware) | Kenwood-text TS-2000 over TCP |
| Thetis | `RIG_MODEL_THETIS` | `kenwood/flex6xxx.c` | Apache Labs ANAN with open-source Thetis firmware | Kenwood-text TS-2000 over TCP |
| HPSDR | `RIG_MODEL_HPSDR` | `kenwood/pihpsdr.c` | PiHPSDR / Apache Labs with the open Pi controller | Kenwood-text-like over TCP |

**Key Flex architecture insight (CRITICAL):**

Looking at Hamlib's `flex6xxx.c` more carefully: F6K, PowerSDR,
and Thetis all use **Kenwood-derived ASCII CAT over TCP**. The
"F6K mode" naming is misleading — it's not a binary protocol.
It's `KenwoodProtocol`'s text CAT (`FA…;`, `MD…;`, `TX;`, `RX;`)
delivered over a TCP socket instead of a serial port. The
Flex-specific extensions are minor (a few extra commands for
slice management).

**Implication for implementation:** we don't need a new "Flex
CAT parser." We need:
1. A new `SerialTransport` conformer for TCP (NWConnection-based).
2. A factory pattern that lets `KenwoodProtocol` use that transport.
3. Per-radio cap structs reflecting the Flex feature surface.

Total effort: ~200 LOC TCP transport + ~50 LOC per Flex model
cap struct + tests. The survey's "800-1000 LOC" estimate was
inflated because it assumed a new protocol parser.

### Tier 2 — older popular radios (defer to v1.2.x patch or v1.3)

| Vendor | Model | Hamlib file | Year | Userbase rationale |
|--------|-------|-------------|------|--------------------|
| Yaesu | **FT-840** | `yaesu/ft840.c` | 1993 | Field/portable; still active in club stations |
| Yaesu | **FT-890** | `yaesu/ft890.c` | 1991 | Similar to FT-840 |
| Yaesu | **FT-900** | `yaesu/ft900.c` | 1992 | Mobile; still used |
| Yaesu | **FT-990** | `yaesu/ft990.c` | 1991 | Contesting; small but loyal base |
| Yaesu | **FT-1000D** | `yaesu/ft1000d.c` | 1990 | Flagship; still loved by DXers |
| Yaesu | **FT-1000MP Mk-V** | `yaesu/ft1000mp.c` | 2000 | Already have FT-1000MP; consider adding Mk-V variant |
| Yaesu | **FT-757GX / GX-II** | `yaesu/ft757gx.c` | 1984/1987 | Vintage HF; ongoing club use |
| Yaesu | **FT-767GX** | `yaesu/ft767gx.c` | 1988 | Satellite ops; niche but loyal |
| Yaesu | **FT-980** | `yaesu/ft980.c` | 1985 | Vintage flagship |
| Yaesu | **FT-736R** | `yaesu/ft736.c` | 1985 | VHF/UHF satellite ops |
| Kenwood | **TS-440S** | `kenwood/ts440.c` | 1986 | Workhorse HF; still in service |
| Kenwood | **TS-450S** | `kenwood/ts450s.c` | 1990 | Compact HF; club use |
| Kenwood | **TS-690S** | `kenwood/ts690.c` | 1990 | HF/6m, popular legacy |
| Kenwood | **TS-50S** | `kenwood/ts50s.c` | 1994 | Compact mobile |
| Kenwood | **TS-680S** | `kenwood/ts680.c` | 1990 | Sibling of TS-440S |
| Kenwood | **TS-711 / TS-811** | `kenwood/ts711.c` `ts811.c` | 1985 | VHF/UHF all-mode |
| Kenwood | **TS-790** | `kenwood/ts790.c` | 1988 | Satellite |
| Kenwood | **TS-870S** | `kenwood/ts870s.c` | 1995 | DSP HF, popular |
| Kenwood | **TS-930S** | `kenwood/ts930.c` | 1982 | Vintage flagship |
| Kenwood | **TS-940S** | `kenwood/ts940.c` | 1985 | Vintage flagship |
| Kenwood | **TS-950S / SDX** | `kenwood/ts950.c` | 1989/1991 | Flagship; small but loyal |
| Kenwood | **R-5000** | `kenwood/r5000.c` | 1986 | Receiver — borderline scope |
| Icom | Many vintage (IC-271, IC-275, IC-471, IC-475, IC-575, IC-707, IC-725, IC-726, IC-728, IC-736, IC-737, IC-738, IC-746 family, IC-756 family, IC-761, IC-765, IC-775, IC-78, IC-781, IC-1275) | various | 1982-1995 | Mixed userbase; legacy CI-V addressing |
| Icom | **ID-1** | `icom/id1.c` | 2003 | First D-STAR mobile; collector + active D-STAR ops |
| Icom | **IC-92D** (verify) | `icom/ic92d.c` | 2007 | Already in our catalog — just verify |

This tier ships incrementally as user demand surfaces.
Implementation effort per radio is small (~50 LOC each); the
bottleneck is verifying each radio's Hamlib quirks rather than
coding.

### Tier 3 — defer or out of scope

| Category | Examples | Reason |
|----------|----------|--------|
| Receivers | IC-R6, IC-R7000, IC-R7100, IC-R8500, IC-R9000, IC-R10, IC-R20, IC-R71, IC-R72, IC-RX7, FRG-100, FRG-8800, FRG-9600, VR-5000, R-5000, RX-320/331/340/350 | RX-only; scope decision |
| D-STAR vintage | ID-1, IC-RX7 | Niche; small userbase |
| Hamlib SDR clones | Malachite, PT8000A, QRPLabs, QRPLabs QMX, SDRUno, SDR Console, TruSDX, FieldXperts FX4 | Mostly DIY/kit radios; specialized userbase that's tech-savvy and can use rigctld directly |
| Pre-1990 Icom | Many models | Legacy CI-V; collectors only |
| Marine / aero / commercial | IC-F8101, IC-M73, ICF-related | Outside amateur scope |

## Recommended v1.2.0 shipping set

**Confidence-weighted recommendation** (10 radios + Flex
ecosystem):

1. **Kenwood TH-F6A** — popular tri-band HT, real Hamlib (`thf6a.c`)
2. **Kenwood TM-D700** — predecessor to TM-D710, real Hamlib
3. **Kenwood TH-G71** — niche but real
4. **Yaesu FT-840** — popular legacy HF, still active
5. **Yaesu FT-990** — flagship contesting workhorse
6. **Yaesu FT-1000D** — DXer's flagship
7. **Ten-Tec Omni VII (TT-588)** — modern Ten-Tec flagship
8. **Ten-Tec Argonaut (TT-516)** — QRP popular
9. **FlexRadio F6K** — Flex 6000-series via TCP
10. **FlexRadio PowerSDR / Thetis** — Flex 3000/5000 + Apache Labs ANAN

Plus reusable infrastructure:
- **TCP transport actor** (`TCPSerialTransport` conforming to
  `SerialTransport`) — enables Flex *and* remote rigctld
  bridging *and* any future TCP-based radio.

## Implementation strategy

### Phase 1: Infrastructure (week 1)

- Build `TCPSerialTransport` actor backed by `NWConnection`.
- Add `ConnectionType.tcp(host: String, port: Int)` case.
- Wire `RigController` to construct it.
- 30+ tests covering connection / disconnection / reconnect /
  timeout / read-until-terminator.
- No new radio definitions yet — just transport.

### Phase 2: Flex family (week 2)

- Add `Manufacturer.flexRadio` brand tag.
- Per-radio `RigCapabilities` literal for F6K, PowerSDR, Thetis.
- `RadioDefinition` factories reuse `KenwoodProtocol` over TCP.
- One protocol test suite (`FlexProtocolTests`) covering the
  Flex-specific commands (e.g., `IF` and `OI` extensions).
- Wire-byte tests for each F6K/PowerSDR/Thetis quirk citing
  `flex6xxx.c` line numbers.

### Phase 3: Tier-1 serial radios (week 3)

- For each of the 8 Tier-1 serial radios:
  - Add `RigCapabilities` literal in
    `RadioCapabilitiesDatabase+<Vendor>.swift` or appropriate
    file.
  - Add `RadioDefinition` factory in `<Vendor>Models.swift`.
  - Add basic-caps + connects-via-mock test pair.
- Total ~400 LOC + tests across 8 radios.

### Phase 4: Documentation (week 3)

- Update README's per-vendor lists and counts.
- Update HAMLIB_PARITY.md.
- Add `Documentation/TCP_TRANSPORT.md` covering the new TCP
  transport for remote-rigctld bridging use cases.
- Add per-radio entries in the README Quick Reference Radio
  Specifications tables.
- CHANGELOG entries with Hamlib citations.

## Testing strategy — high confidence without hardware

Every new radio gets:

1. **Capability-struct sanity test** (one `@Test func` per
   radio): verifies maxPower, frequency ranges, supported
   modes, v1.1 sets.
2. **ConnectsViaMock test**: verifies the factory constructs
   correctly and `connect()` succeeds against MockTransport.
3. **Protocol-level wire-byte test** (for popular radios only):
   verifies the wire bytes emitted for major operations
   (setFrequency, setMode, setPTT, setSplit, performVFOOperation)
   match what Hamlib emits for the same radio. Each test cites
   `rigs/<vendor>/<file>.c:<line>` in its comment.

For TCP transport:
- Mock TCP server tests (loopback `NWConnection`).
- Reconnect-after-drop test.
- Timeout-on-no-response test.
- Multi-client connection-pool tests (rigctld bridge accepts
  multiple WSJT-X / fldigi instances).

## Out of scope confirmed

- Pre-1990 vintage Icoms.
- Receivers (separate Phase 6 work if surfaced).
- Marine / aero / commercial.
- Hamlib's SDR-kit catalog (Malachite, TruSDX, etc.) — these
  are DIY radios with tech-savvy users who already use
  Hamlib directly.

## Next concrete actions

1. ✅ Implementation guide + per-radio test template committed
   (`PARITY_IMPLEMENTATION_GUIDE.md`,
   `PerRadioCapabilityTemplate.md`).
2. ✅ This plan committed (`V12_PARITY_PLAN.md`).
3. ⏳ Start Phase 1 — `TCPSerialTransport` implementation.

Decision points for the user:

- Should the v1.2.0 shipping set be smaller (just Flex + 3
  popular serial radios), giving faster release?
- Should we tag a v1.1.1 patch with the IC-9700 NB BCD fix +
  docs work first, then start v1.2 fresh?
- Is there a specific radio from Tier 2 that has personal
  priority (e.g., a radio you own)?
