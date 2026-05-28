# Migrating from Hamlib

Map common Hamlib C idioms onto SwiftRigControl Swift code.

## Overview

If you're rewriting an existing Hamlib-based app in Swift, or
building a new one but coming from a Hamlib mental model, this
article maps the most-used idioms across.

The deeper guide lives at `Documentation/HAMLIB_MIGRATION.md`
in the repo. This article is the quick reference.

## Initialization

```c
// Hamlib
RIG *rig = rig_init(RIG_MODEL_IC7600);
rig->state.rigport.parm.serial.rate = 19200;
strncpy(rig->state.rigport.pathname, "/dev/cu.IC-7600", FILPATHLEN);
rig_open(rig);
```

```swift
// SwiftRigControl
let rig = try RigController(
    radio: .Icom.ic7600(),
    connection: .serial(path: "/dev/cu.IC-7600", baudRate: 19200)
)
try await rig.connect()
```

The Swift factory carries everything — model, default baud rate,
default CI-V address, capabilities, protocol implementation — so
configuration is a single call site.

## Operations

| Hamlib | SwiftRigControl |
| --- | --- |
| `rig_set_freq(rig, RIG_VFO_A, 14230000)` | `try await rig.setFrequency(14_230_000, vfo: .a)` |
| `rig_get_freq(rig, RIG_VFO_A, &freq)` | `let freq = try await rig.frequency()` |
| `rig_set_mode(rig, RIG_VFO_A, RIG_MODE_USB, RIG_PASSBAND_NORMAL)` | `try await rig.setMode(.usb, vfo: .a)` |
| `rig_get_mode(rig, RIG_VFO_A, &mode, &width)` | `let mode = try await rig.mode()` |
| `rig_set_ptt(rig, RIG_VFO_A, RIG_PTT_ON)` | `try await rig.setPTT(true)` |
| `rig_get_ptt(rig, RIG_VFO_A, &ptt)` | `let on = try await rig.isPTTEnabled()` |
| `rig_set_split_vfo(rig, RIG_VFO_A, RIG_SPLIT_ON, RIG_VFO_B)` | `try await rig.setSplit(true)` |
| `rig_set_level(rig, RIG_VFO_A, RIG_LEVEL_RFPOWER, val)` | `try await rig.setPower(50)` |
| `rig_get_level(rig, RIG_VFO_A, RIG_LEVEL_STRENGTH, &val)` | `let s = try await rig.signalStrength()` |
| `rig_close(rig); rig_cleanup(rig);` | `await rig.disconnect()` |

Mode codes are spelled-out `Mode` cases (``Mode/usb``, ``Mode/cw``,
``Mode/dataUSB``, …) instead of integer constants.

## The reactive replacement for transceive mode

Hamlib's transceive callbacks:

```c
rig_set_freq_callback(rig, my_freq_cb, NULL);
rig_set_mode_callback(rig, my_mode_cb, NULL);
rig_set_ptt_callback(rig, my_ptt_cb, NULL);
```

…become a single ``RigController/events`` stream:

```swift
for await event in rig.events {
    switch event {
    case .frequencyChanged(let vfo, let hz):
        // ...
    case .modeChanged(let vfo, let mode):
        // ...
    case .pttChanged(let on):
        // ...
    default:
        break
    }
}
```

The stream covers more than Hamlib's transceive does: setters
emit synchronously, the opt-in poller catches front-panel
changes on radios without transceive, and the health monitor
emits connection-lifecycle transitions. See <doc:ReactiveState>
for the full story.

## Cache timeout

Hamlib has `rig_set_cache_timeout_ms()`. SwiftRigControl's cache
is an actor with a 500 ms default TTL; query freshness through
the `cached:` parameter on accessors:

```swift
let fresh = try await rig.frequency(cached: false)
let cached = try await rig.frequency(cached: true)  // default
```

## rigctld

If your app drives an external `rigctld`, you can either:

- **Keep using rigctld.** SwiftRigControl ships
  ``RigControlServer`` — a TCP server that speaks the same
  `rigctld` text protocol. Drop-in for WSJT-X, fldigi, JS8Call.
- **Drop rigctld.** Embed SwiftRigControl directly; you no
  longer need a long-running C daemon.

## What Hamlib has that SwiftRigControl doesn't

- **Cross-platform support.** Hamlib runs on Linux, Windows,
  BSD. SwiftRigControl is macOS-only by design.
- **350+ radios.** SwiftRigControl ships ~80, only four
  hardware-verified.
- **Rotator / amplifier / antenna-switch APIs.** Out of scope
  for this project.
- **Network-multicast event distribution.** SwiftRigControl
  apps that need this can build it on top of the events stream.

## What SwiftRigControl has that Hamlib doesn't

- **Strict-concurrency Swift 6 actors.** No locks, no manual
  synchronization.
- **Unified `AsyncStream<RigStateEvent>`.** Push, poll, and
  connection-health all in one stream. Hamlib has per-event
  C callbacks and no built-in heartbeat.
- **Built-in connection-health monitor with auto-reconnect.**
- **In-memory ``DummyCATProtocol``** that participates fully in
  ``RigController`` lifecycle — SwiftUI previews work with no
  hardware.
- **Type-safe enums** instead of integer mode/VFO codes.
- **``RadioDefinition/VerificationStatus``** so apps can be
  honest with users about which radios are field-tested.

## Related

- <doc:ReactiveState>
- ``RigController``
- ``RigControlServer``
