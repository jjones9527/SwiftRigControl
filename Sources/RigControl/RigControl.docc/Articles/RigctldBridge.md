# The rigctld TCP bridge

Drive a SwiftRigControl-backed app from WSJT-X, fldigi, JS8Call,
or any Hamlib-compatible client over a local TCP socket.

## Overview

``RigControlServer`` is a TCP server that speaks the Hamlib
`rigctld` text protocol. From the client's perspective it looks
identical to standalone `rigctld` connected to a real radio —
which means every Hamlib-savvy amateur radio tool (WSJT-X,
fldigi, JS8Call, `rigctl`, custom Hamlib clients) Just Works
against a SwiftRigControl-backed app.

This is the integration path of choice for amateur radio
operators using SwiftRigControl-backed apps to do digital modes:
no need to teach WSJT-X about SwiftRigControl — the bridge
makes the connection look like generic Hamlib.

## Starting the bridge

```swift
import RigControl

let rig = try RigController(
    radio: .Icom.ic7600(),
    connection: .serial(path: "/dev/cu.SLAB_USBtoUART", baudRate: 19200)
)
try await rig.connect()

// Listen on localhost:4532 — the standard rigctld port.
let server = RigControlServer(rigController: rig, port: 4532)
try await server.start()

print("rigctld bridge listening on 127.0.0.1:4532")
```

Multiple Hamlib clients can connect to the same `RigControlServer`
simultaneously — the server multiplexes commands onto the single
``RigController`` and serializes via the controller's actor
boundary.

## Pointing WSJT-X at the bridge

In **WSJT-X → File → Settings → Radio**:

- **Rig**: `Hamlib NET rigctl`
- **Network Server**: `127.0.0.1:4532`
- **PTT Method**: `CAT`
- Click **Test CAT** — the indicator turns green when the
  bridge replies correctly.

WSJT-X will then read frequency / mode / PTT from your app and
push frequency changes back when the operator double-clicks a
decoded signal.

## Pointing fldigi at the bridge

In **fldigi → Configure → Rig Control → Hamlib**:

- **Use Hamlib**: ✓
- **Rig**: `Hamlib NET rigctl (#2)`
- **Device**: `127.0.0.1:4532`
- Click **Initialize**.

## Manual testing with `rigctl`

Install Hamlib (`brew install hamlib`), then:

```bash
rigctl -m 2 -r localhost:4532

Rig command: f          # query frequency
14230000
Rig command: F 14210000 # set frequency to 14.210 MHz
RPRT 0
Rig command: m          # query mode
USB
2400
Rig command: q          # quit
```

`-m 2` tells `rigctl` to use the `NET rigctl` model — i.e. talk
to a remote rigctld over TCP rather than a local serial port.
`-r localhost:4532` is the address.

## Supported commands

The bridge covers the standard Hamlib client surface:

| Category    | Commands                                                                  |
| ----------- | ------------------------------------------------------------------------- |
| Frequency   | `f`, `F`, `i`, `I`                                                        |
| Mode        | `m`, `M`, `x`, `X`                                                        |
| PTT         | `t`, `T`                                                                  |
| VFO         | `v`, `V`                                                                  |
| Split       | `s`, `S`                                                                  |
| Levels      | `l`, `L` for AF, RF, SQL, PREAMP, ATT, RFPOWER, AGC, NB, NR, KEYSPD, CWPITCH, SWR, ALC, RFPOWER_METER, COMP_METER, VD_METER, ID_METER |
| Functions   | `u`, `U` for SBKIN, FBKIN                                                 |
| Antenna     | `Y`, `y`                                                                  |
| Scan        | `g`                                                                       |
| CW          | `b`, `\stop_morse`                                                        |
| Power state | `\set_powerstat`, `\get_powerstat`                                        |
| Info        | `\dump_state`, `\dump_caps`, `\chk_vfo`                                   |

### v1.1 additions

| Category           | Tokens                                                                     |
| ------------------ | -------------------------------------------------------------------------- |
| VFO operations     | `G` / `\vfo_op` with `CPY`, `XCHG`, `FROM_VFO`, `TO_VFO`, `MCL`, `UP`, `DOWN`, `BAND_UP`, `BAND_DOWN`, `TUNE`, `TOGGLE` |
| Function toggles   | Extended `u` / `U` for COMP, VOX, TONE, TSQL, LOCK, TUNER, ANF, MN, SATMODE, MON, AFC, BC, NB2, APF, REV, DUAL_WATCH, DIVERSITY, MUTE, SCOPE, RESUME, VSC |
| Secondary levels   | Extended `l` / `L` for MICGAIN, COMP, MONITOR_GAIN, VOXGAIN, VOXDELAY, IF_SHIFT |

`IF_SHIFT` is a vendor-extension token (Hamlib uses plain `IF`
for both filter selection and shift; we use `IF_SHIFT` to avoid
the collision with `IFFILTER`).

## Capability gating

If the radio doesn't support an operation, the bridge returns a
non-zero `RPRT` code rather than crashing. WSJT-X handles this
gracefully — it stops attempting the operation after a few
NAKs. Custom clients should check the `RPRT` code.

## More information

See `Documentation/NETWORK_CONTROL.md` in the repo for the full
protocol reference and per-command response formats.

## Topics

### Related API

- ``RigControlServer``
- ``RigController``
