# ``RigControl``

A native Swift 6 library for amateur-radio CAT (Computer Aided
Transceiver) control on macOS.

## Overview

SwiftRigControl gives macOS app developers a modern, type-safe,
actor-based API for talking to amateur-radio transceivers over
serial CAT protocols (Icom CI-V, Elecraft, Yaesu, Kenwood,
Ten-Tec, Xiegu).

The library's design is anchored against
[Hamlib](https://hamlib.github.io/) — the industry-standard C
library that has covered this domain for two decades — but
presents a Swift-native shape: actors instead of locks,
`AsyncStream` instead of polling, discriminated enums instead
of integer codes, and `RadioCapabilities` flags that enforce
themselves at the type level instead of failing at runtime.

### What you get

- **~97 radio definitions** across 7 manufacturers. Four are
  field-verified against real hardware; the rest are
  definition-only (Hamlib- and manual-derived) until someone
  exercises them. See <doc:VerificationStatus>.
- **Reactive state.** `RigController.events` is an
  `AsyncStream<RigStateEvent>` that pushes frequency, mode,
  PTT, signal-strength, and connection-state changes — no
  polling loop in your code. See <doc:ReactiveState>.
- **In-memory dummy radio.** `RadioDefinition.dummy()` lets
  SwiftUI previews, demos, and tutorials run with zero hardware.
- **Compound VFO operations** (v1.1) — one-call A↔B swap, copy,
  memory write/recall, ATU tune. See <doc:VFOOperations>.
- **Function toggles** (v1.1) — 21 on/off radio bits with type-
  safe enum dispatch. See <doc:FunctionToggles>.
- **Secondary level controls** (v1.1) — mic gain, compressor
  level, monitor gain, VOX gain/delay, IF shift. See
  <doc:SecondaryLevels>.
- **rigctld-compatible TCP server.** Drop-in for WSJT-X, fldigi,
  JS8Call, and other Hamlib clients. See <doc:RigctldBridge>.
- **XPC helper** for Mac App Store sandboxed apps.
- **Type-safe capability dispatch.** Trait protocols and the
  ``VendorExtensions`` enum gate per-radio features at compile
  time. See <doc:TraitProtocols>.

### Quick taste

```swift
import RigControl

let rig = try RigController(
    radio: .icomIC9700(),
    connection: .serial(path: "/dev/cu.IC9700", baudRate: 115200)
)

try await rig.connect()
try await rig.setFrequency(14_230_000, vfo: .a)
try await rig.setMode(.usb, vfo: .a)
try await rig.setPTT(true)
// ... transmit ...
try await rig.setPTT(false)
await rig.disconnect()
```

For the SwiftUI / reactive-state pattern, see
<doc:ReactiveState>. For development without hardware, see
<doc:GettingStartedWithDummy>.

## Topics

### Getting started

- <doc:GettingStartedWithDummy>
- <doc:ReactiveState>
- <doc:VerificationStatus>
- <doc:AddingRadios>
- <doc:HamlibMigration>

### Working with v1.1 features

- <doc:VFOOperations>
- <doc:FunctionToggles>
- <doc:SecondaryLevels>
- <doc:RigctldBridge>
- <doc:TraitProtocols>

### The radio controller

- ``RigController``
- ``RadioDefinition``
- ``ConnectionType``
- ``RigCapabilities``
- ``VendorExtensions``

### Reactive state

- ``RigStateEvent``
- ``ConnectionState``

### Transports

- ``SerialTransport``
- ``MockSerialTransport``
- ``SerialConfiguration``

### Models

- ``Mode``
- ``VFO``
- ``SignalStrength``
- ``MeterReading``
- ``RITXITState``
- ``MemoryChannel``
- ``AGCSpeed``
- ``NoiseBlanker``
- ``NoiseReduction``
- ``IFFilter``
- ``CWSpeed``
- ``CWPitch``
- ``BreakInMode``
- ``ScanKind``
- ``VFOOperation``
- ``RigFunction``

### Protocols

- ``CATProtocol``
- ``DummyCATProtocol``
- ``IcomCIVProtocol``
- ``ElecraftProtocol``
- ``YaesuCATProtocol``
- ``KenwoodProtocol``
- ``TenTecOrionProtocol``

### Capability trait protocols

Each radio opts into the features it supports by conforming to
the matching trait protocol. `RigController` checks the
conformance at runtime and throws ``RigError/unsupportedOperation(_:)``
when a feature isn't available. See <doc:TraitProtocols> for the
architecture overview.

- ``SupportsPower``
- ``SupportsSplit``
- ``SupportsSignalStrength``
- ``SupportsRIT``
- ``SupportsXIT``
- ``SupportsAGC``
- ``SupportsNoiseBlanker``
- ``SupportsNoiseReduction``
- ``SupportsIFFilter``
- ``SupportsAFGain``
- ``SupportsRFGain``
- ``SupportsSquelch``
- ``SupportsPreamp``
- ``SupportsAttenuator``
- ``SupportsRemotePowerState``
- ``SupportsMemoryChannels``
- ``SupportsTXMeters``
- ``SupportsCWKeyer``
- ``SupportsSendCW``
- ``SupportsScanning``
- ``SupportsAntenna``
- ``SupportsVFOOperations``
- ``SupportsFunctions``
- ``SupportsMicGain``
- ``SupportsCompressorLevel``
- ``SupportsMonitorGain``
- ``SupportsVOXGain``
- ``SupportsVOXDelay``
- ``SupportsIFShift``

### Network

- ``RigControlServer``

### Errors

- ``RigError``
