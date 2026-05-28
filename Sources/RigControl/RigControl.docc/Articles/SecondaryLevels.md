# Secondary level controls

Mic gain, compressor level, monitor gain, VOX gain/delay, and IF
shift — the second-tier knobs every SSB/CW operator touches.

## Overview

The primary level controls (AF, RF, squelch, preamp, attenuator,
RF power, AGC, NB, NR, IF filter, CW speed, CW pitch) live on
dedicated trait protocols and have been in SwiftRigControl since
the early phases.

The secondary level controls are the next-most-touched knobs:
the ones every voice or CW operator adjusts per band and per
QSO. SwiftRigControl exposes six of them, each on its own trait
protocol so per-radio capability declarations are explicit and
the compiler enforces them.

All six use a 0-100 normalized scale per Hamlib convention.
The per-vendor wire encoding (BCD percentage for Icom, 3-digit
ASCII for Kenwood/Yaesu) is handled internally.

## The controls

| Method                           | Hamlib level             | Notes                                          |
| -------------------------------- | ------------------------ | ---------------------------------------------- |
| ``RigController/setMicGain(_:)``        | `RIG_LEVEL_MICGAIN`     | Mic gain. Universal.                           |
| ``RigController/setCompressorLevel(_:)``| `RIG_LEVEL_COMP`        | Compressor *level*. Distinct from the on/off `RigFunction/compressor` toggle. |
| ``RigController/setMonitorGain(_:)``    | `RIG_LEVEL_MONITOR_GAIN`| Sidetone monitor gain.                         |
| ``RigController/setVOXGain(_:)``        | `RIG_LEVEL_VOXGAIN`     | VOX sensitivity.                               |
| ``RigController/setVOXDelay(_:)``       | `RIG_LEVEL_VOXDELAY`    | VOX hang time.                                 |
| ``RigController/setIFShift(_:)``        | `RIG_LEVEL_IF`          | IF passband shift. 50 = center.                |

Each setter has a matching reader (`micGain()`,
`compressorLevel()`, `monitorGain()`, `voxGain()`, `voxDelay()`,
`ifShift()`).

## SSB voice setup example

```swift
let rig = try RigController(
    radio: .icomIC7600(),
    connection: .serial(path: "/dev/cu.SLAB_USBtoUART", baudRate: 19200)
)
try await rig.connect()

// Set up for SSB on 20m.
try await rig.setFrequency(14_230_000, vfo: .a)
try await rig.setMode(.usb, vfo: .a)

// Voice levels.
try await rig.setMicGain(60)
try await rig.setFunction(.compressor, enabled: true)
try await rig.setCompressorLevel(40)
try await rig.setMonitorGain(20)
```

## VOX hands-free setup

```swift
// VOX needs both a gain (how loud to trigger) and a delay
// (how long to keep transmitting after speech stops).
try await rig.setFunction(.vox, enabled: true)
try await rig.setVOXGain(50)
try await rig.setVOXDelay(30)
```

## IF shift for QRM rejection

```swift
// IF shift offsets the IF passband to reject a louder station
// nearby. 50 = center; lower values shift down (≈ -1200 Hz on
// most radios), higher values shift up (≈ +1200 Hz).
try await rig.setIFShift(70)   // shift up to reject a station below
try await rig.setIFShift(50)   // back to center
```

## Capability gating

Each level lives on its own trait protocol — ``SupportsMicGain``,
``SupportsCompressorLevel``, ``SupportsMonitorGain``,
``SupportsVOXGain``, ``SupportsVOXDelay``, ``SupportsIFShift``.
Calling a setter on a radio that doesn't conform throws
``RigError/unsupportedOperation(_:)``. Check the conformance
indirectly via the typed vendor extensions:

```swift
if case .icom(let icom) = await rig.vendorExtensions {
    let proto: any CATProtocol = icom
    if proto is any SupportsMicGain {
        // Show the mic-gain knob.
    }
}
```

In practice most modern HF rigs (IC-7300, IC-7600, IC-7610,
IC-7700, IC-7800, IC-9700, FT-991A, FT-710, TS-590SG, TS-890S,
K3, K4) support all six.

## Topics

### Related API

- ``RigController/setMicGain(_:)``
- ``RigController/setCompressorLevel(_:)``
- ``RigController/setMonitorGain(_:)``
- ``RigController/setVOXGain(_:)``
- ``RigController/setVOXDelay(_:)``
- ``RigController/setIFShift(_:)``
- ``SupportsMicGain``
- ``SupportsCompressorLevel``
- ``SupportsMonitorGain``
- ``SupportsVOXGain``
- ``SupportsVOXDelay``
- ``SupportsIFShift``
