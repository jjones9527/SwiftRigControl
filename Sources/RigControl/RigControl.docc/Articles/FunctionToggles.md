# Function toggles

On/off radio function bits — speech compressor, VOX, CTCSS,
lock, ATU enable, satellite mode, scope. Twenty-one curated bits
from Hamlib's `RIG_FUNC_*` universe, surfaced through a single
type-safe API.

## Overview

A "function" is an on/off radio bit that's truly boolean — "is
the compressor engaged?", "is the front panel locked?". This is
distinct from level-shaped controls (where you set 0-100%) and
from compound operations (one-shot actions like A↔B swap).

SwiftRigControl exposes function toggles through
``RigController/setFunction(_:enabled:)`` /
``RigController/getFunction(_:)``. Per-radio support is gated by
``RigCapabilities/supportedFunctions``.

When this enum vs. a dedicated trait: some on/off-shaped things
already live on their own trait (e.g. ``SupportsSplit``,
``SupportsRIT``) because they pair with a query method that
returns more than a bool. ``RigFunction`` is for bits that are
truly boolean.

## The 21 function bits

| Case                  | Hamlib bit             | Notes                                       |
| --------------------- | ---------------------- | ------------------------------------------- |
| `.compressor`         | `RIG_FUNC_COMP`        | Speech compressor on/off. Universal.        |
| `.vox`                | `RIG_FUNC_VOX`         | Voice-operated transmit.                    |
| `.ctcssTone`          | `RIG_FUNC_TONE`        | CTCSS tone encode (FM repeater access).     |
| `.ctcssSquelch`       | `RIG_FUNC_TSQL`        | CTCSS squelch (FM repeater RX).             |
| `.lock`               | `RIG_FUNC_LOCK`        | Front-panel lock.                           |
| `.tuner`              | `RIG_FUNC_TUNER`       | Internal ATU enable. (Distinct from triggering a tune cycle — see ``VFOOperation/tune``.) |
| `.autoNotch`          | `RIG_FUNC_ANF`         | Automatic notch filter (DSP).               |
| `.manualNotch`        | `RIG_FUNC_MN`          | Manual notch filter.                        |
| `.satelliteMode`      | `RIG_FUNC_SATMODE`     | Satellite operating mode. IC-9700, IC-9100. |
| `.monitor`            | `RIG_FUNC_MON`         | Sidetone monitor — hear your TX audio.      |
| `.autoFrequencyControl` | `RIG_FUNC_AFC`       | Auto frequency control (FM).                |
| `.beatCancel`         | `RIG_FUNC_BC`          | Beat canceller. Kenwood-specific.           |
| `.noiseBlanker2`      | `RIG_FUNC_NB2`         | Second-stage noise blanker.                 |
| `.audioPeakFilter`    | `RIG_FUNC_APF`         | Audio peak filter (CW).                     |
| `.reverseSplit`       | `RIG_FUNC_REV`         | Reverse split / duplex on V/UHF.            |
| `.dualWatch`          | `RIG_FUNC_DUAL_WATCH`  | Dual watch / sub-receiver.                  |
| `.diversity`          | `RIG_FUNC_DIVERSITY`   | Diversity reception. IC-7610, FTDX-101.     |
| `.mute`               | `RIG_FUNC_MUTE`        | RX audio mute.                              |
| `.scope`              | `RIG_FUNC_SCOPE`       | Spectrum scope on/off.                      |
| `.scanResume`         | `RIG_FUNC_RESUME`      | Scan auto-resume.                           |
| `.voiceSquelch`       | `RIG_FUNC_VSC`         | Voice-controlled squelch. Icom-specific.    |

## Usage

```swift
let rig = try RigController(
    radio: .Icom.ic7600(),
    connection: .serial(path: "/dev/cu.SLAB_USBtoUART", baudRate: 19200)
)
try await rig.connect()

// Engage speech compressor for SSB rag-chew.
try await rig.setFunction(.compressor, enabled: true)

// Lock the front panel.
try await rig.setFunction(.lock, enabled: true)

// Read a function bit.
let voxOn = try await rig.getFunction(.vox)
```

## Repeater operating

```swift
// FM repeater access: CTCSS tone encode + tone squelch.
try await rig.setMode(.fm, vfo: .a)
try await rig.setFunction(.ctcssTone, enabled: true)
try await rig.setFunction(.ctcssSquelch, enabled: true)
```

## IC-9700 satellite operating

```swift
// Engage satellite mode (cross-band TX/RX between main and sub).
try await rig.setFunction(.satelliteMode, enabled: true)
try await rig.setFunction(.dualWatch, enabled: true)
```

## Capability gating

```swift
let supported = rig.capabilities.supportedFunctions

// Show only the toggles this radio supports in your UI.
let availableToggles = RigFunction.allCases.filter { supported.contains($0) }
for fn in availableToggles {
    print("Available: \(fn.rawValue)")
}
```

## Curation policy

`RigFunction` is a *curated* subset of Hamlib's ~50 `RIG_FUNC_*`
bits. We ship the bits that:

1. Map to a real wire command on at least one shipping radio.
2. Are commonly surfaced in operator UIs.

Hamlib-defined bits that no vendor surfaces (FAGC, ABM, ANL,
etc.) are intentionally omitted. If you need a niche bit, use
``RigController/vendorExtensions`` to reach the concrete protocol
actor and call its model-specific method directly.

## Topics

### Related API

- ``RigController/setFunction(_:enabled:)``
- ``RigController/getFunction(_:)``
- ``RigFunction``
- ``RigCapabilities/supportedFunctions``
- ``SupportsFunctions``
