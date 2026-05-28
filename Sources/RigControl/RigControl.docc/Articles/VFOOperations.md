# Compound VFO operations

Single-call equivalents of the "swap A↔B", "copy A→B", and
"memory recall" buttons on a modern transceiver's front panel.

## Overview

Compound VFO operations are single-action commands that don't
fit the typical get/set pattern: they're the kind of thing you'd
do with one button-press on the radio. Swap A↔B. Copy the
active VFO. Recall a memory channel. Start the ATU tune cycle.

SwiftRigControl exposes 11 of these through
``RigController/performVFOOperation(_:)``, mirroring Hamlib's
`RIG_OP_*` bitfield. Per-radio support is gated by
``RigCapabilities/supportedVFOOperations`` — calling an op the
radio doesn't claim throws ``RigError/unsupportedOperation(_:)``.

## The operations

Each ``VFOOperation`` case names what the operation *does* from
the operator's perspective; on the wire each vendor translates
differently (CI-V 0x07 sub-commands for Icom, ASCII tokens for
text protocols), but you write the same Swift either way.

| Case             | Effect                                                       |
| ---------------- | ------------------------------------------------------------ |
| `.copyVFO`       | Active VFO → other VFO (Hamlib `RIG_OP_CPY`).                |
| `.exchange`      | Swap A↔B (`RIG_OP_XCHG`). The most-used compound op.         |
| `.toggle`        | A/B toggle (`RIG_OP_TOGGLE`). Aliased to `.exchange` on radios that don't distinguish. |
| `.vfoToMemory`   | "M.W" — store active VFO to current memory (`RIG_OP_FROM_VFO`). |
| `.memoryToVFO`   | "M→V" — recall current memory to active VFO (`RIG_OP_TO_VFO`). |
| `.memoryClear`   | Erase the selected memory channel (`RIG_OP_MCL`).            |
| `.stepUp`        | Step VFO up by configured tuning step (`RIG_OP_UP`).         |
| `.stepDown`      | Step VFO down (`RIG_OP_DOWN`).                               |
| `.bandUp`        | Move to next amateur band (`RIG_OP_BAND_UP`).                |
| `.bandDown`      | Move to previous amateur band (`RIG_OP_BAND_DOWN`).          |
| `.tune`          | Start automatic ATU tune cycle (`RIG_OP_TUNE`).              |

## Usage

```swift
let rig = try RigController(
    radio: .Icom.ic7600(),
    connection: .serial(path: "/dev/cu.SLAB_USBtoUART", baudRate: 19200)
)
try await rig.connect()

// Most-used: swap A↔B.
try await rig.performVFOOperation(.exchange)

// Set up VFO B for split, then copy A.
try await rig.performVFOOperation(.copyVFO)

// ATU tune cycle on radios with internal tuner.
try await rig.performVFOOperation(.tune)
```

## Capability gating

Build your UI around the capability set so buttons match the
radio:

```swift
let ops = rig.capabilities.supportedVFOOperations

swapButton.isEnabled  = ops.contains(.exchange)
copyButton.isEnabled  = ops.contains(.copyVFO)
tuneButton.isEnabled  = ops.contains(.tune)

// Or show the full list of available ops:
for op in VFOOperation.allCases where ops.contains(op) {
    print("Available: \(op.rawValue)")
}
```

## Per-vendor wire commands

For reference — you shouldn't need to know these to use the API,
but they're useful when debugging against a Hamlib trace:

| Vendor   | `.exchange`     | `.copyVFO`     | `.tune`               |
| -------- | --------------- | -------------- | --------------------- |
| Icom     | `0x07 0xB0`     | `0x07 0xA0`    | `0x1C 0x01` + `0x02`  |
| Kenwood  | n/a (sequence)  | n/a (sequence) | `AC111`               |
| Yaesu    | `SV`            | `AB`           | `AC002`               |
| Elecraft | n/a in this protocol | n/a       | model-specific `SWT`  |

Operations a vendor's protocol doesn't natively support throw
``RigError/unsupportedOperation(_:)``. Cross-checked against
Hamlib `icom_vfo_op` (rigs/icom/icom.c:8710), `kenwood_vfo_op`
(rigs/kenwood/kenwood.c:5724), and `newcat_vfo_op`
(rigs/yaesu/newcat.c:7470).

## Topics

### Related API

- ``RigController/performVFOOperation(_:)``
- ``VFOOperation``
- ``RigCapabilities/supportedVFOOperations``
- ``SupportsVFOOperations``
