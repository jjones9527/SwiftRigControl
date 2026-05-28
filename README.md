# SwiftRigControl

[![CI](https://github.com/jjones9527/SwiftRigControl/actions/workflows/ci.yml/badge.svg)](https://github.com/jjones9527/SwiftRigControl/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/docs-DocC-blue)](https://jjones9527.github.io/SwiftRigControl/documentation/rigcontrol/)

A native Swift library for controlling amateur radio transceivers on macOS.

**Current release:** v1.0.6

## Features

- ✅ **Modern Swift**: Swift 6.2 strict concurrency, async/await, actors
- ✅ **Dummy radio**: Develop and preview SwiftUI apps with no hardware via `RadioDefinition.dummy()` (Hamlib Model 1 equivalent)
- ✅ **Event stream**: `RigController.events` as `AsyncStream<RigStateEvent>` — push-style state updates for SwiftUI with no polling loop in user code
- ✅ **Polled state broadcaster**: opt-in `startPolling()` for S-meter monitoring and front-panel-driven changes; per-field intervals; events fan into the same stream
- ✅ **Connection-health monitor**: opt-in `startHealthMonitor()` with heartbeat probing and optional exponential-backoff auto-reconnect; degraded and reconnecting states fan into the same stream
- ✅ **Compound VFO operations** *(v1.1)*: one-call A↔B swap, copy, memory write/recall, ATU tune cycle via `performVFOOperation(.exchange)` etc.
- ✅ **Function toggles** *(v1.1)*: 21 on/off radio bits — compressor, VOX, CTCSS, lock, ATU enable, satellite mode, scope, … via `setFunction(.compressor, enabled: true)`
- ✅ **Secondary level controls** *(v1.1)*: mic gain, compressor level, monitor gain, VOX gain/delay, IF shift — the second-tier knobs every SSB/CW operator touches
- ✅ **rigctld TCP bridge**: drive a SwiftRigControl-backed app from WSJT-X, fldigi, JS8Call, or any Hamlib-compatible client via `RigControlServer`
- ✅ **Mac App Store Compatible**: XPC helper pattern for sandboxed apps
- ✅ **Protocol-Based**: Clean abstraction supporting multiple radio protocols
- ✅ **Type-Safe**: Full Swift type safety with enums and error handling
- ✅ **Well-Tested**: 420+ tests on Swift Testing framework with mock transport
- ✅ **Frequency Validation**: Safety-critical validation with amateur band support
- ✅ **S-Meter Reading**: Real-time signal strength monitoring
- ✅ **Performance Caching**: 10-20x faster queries with intelligent caching
- ✅ **Batch Configuration**: Set multiple parameters in one call
- ✅ **RIT/XIT Support**: Receiver/Transmitter incremental tuning across all protocols
- ✅ **Memory Channels**: Universal memory channel model with manufacturer-specific features
- ✅ **Level & DSP Controls**: AF/RF gain, squelch, preamp, attenuator, AGC, NB, NR, IF filter
- ✅ **Open Source**: LGPL v3.0 licensed

## Hardware verification status

SwiftRigControl ships with **~80 radio definitions**, but only a subset
has been validated against real hardware. Status categories:

- **Hardware** — exercised against the real radio via the matching
  validator in `Tools/SwiftRigControlTools/HardwareValidation/`.
  Frequency, mode, PTT, and at least one read-back operation
  confirmed working.
- **Definition** — protocol, capabilities, and command set are
  implemented (typically cross-referenced against the manufacturer
  manual and Hamlib source), but **no real-radio verification has been
  performed**. These may work; they have not been proven.

| Radio        | Status     | Validator                                                          |
| ------------ | ---------- | ------------------------------------------------------------------ |
| Icom IC-7100 | Hardware   | `Tools/SwiftRigControlTools/HardwareValidation/IC7100Validator`    |
| Icom IC-7600 | Hardware   | `Tools/SwiftRigControlTools/HardwareValidation/IC7600Validator`    |
| Icom IC-9700 | Hardware   | `Tools/SwiftRigControlTools/HardwareValidation/IC9700Validator`    |
| Elecraft K2  | Hardware   | `Tools/SwiftRigControlTools/HardwareValidation/K2Validator`        |
| *all others* | Definition | —                                                                  |

Validators live in a separate SwiftPM project so library consumers
don't transitively compile them. To run one:

```bash
cd Tools/SwiftRigControlTools
IC7600_SERIAL_PORT="/dev/cu.usbserial-XXXX" swift run IC7600Validator
```

If you use SwiftRigControl with a Definition-status radio and confirm
that core operations (frequency, mode, PTT) work, please open an issue
or PR so we can promote it.

## Supported Radios

**~95 radio definitions across 7 manufacturers.** Radios marked
*Hardware* in the table above are field-tested; all others are
definition-only.

### Icom (CI-V Protocol) — 44 models

**Flagship & High-End HF:**
- **IC-7851** - HF/6m flagship with spectrum scope (200W, CI-V: 0x8E)
- **IC-7850** - HF/6m flagship (200W, CI-V: 0x8E)
- **IC-7800** - HF/6m flagship dual receiver (200W, CI-V: 0x6A)
- **IC-7760** - HF/6m next-gen flagship (200W, CI-V: 0xB0)
- **IC-7700** - HF/6m high-end (200W, CI-V: 0x74)
- **IC-7610** - HF/6m SDR with dual receiver (100W, CI-V: 0x98)
- **IC-7600** - HF/6m high-performance dual receiver (100W, CI-V: 0x7A)

**Popular HF Transceivers:**
- **IC-7300** - HF/6m all-mode SDR (100W, CI-V: 0x94)
- **IC-7300MK2** - HF/6m all-mode SDR successor (100W, CI-V: 0x94)
- **IC-7410** - HF/6m all-mode (100W, CI-V: 0x80)
- **IC-7400** - HF/6m + 2m (100W, CI-V: 0x66)
- **IC-7200** - HF/6m mid-range (100W, CI-V: 0x76)
- **IC-718** - HF entry-level (100W, CI-V: 0x5E)
- **IC-751** - HF legacy (100W, CI-V: 0x1C)
- **IC-735** - HF legacy (100W, CI-V: 0x04)
- **IC-703** - HF/6m portable QRP (10W, CI-V: 0x68)
- **IC-756PRO III** - HF/6m dual receiver (100W, CI-V: 0x6E)
- **IC-756PRO II** - HF/6m dual receiver (100W, CI-V: 0x64)
- **IC-756PRO** - HF/6m dual receiver (100W, CI-V: 0x5C)
- **IC-756** - HF/6m dual receiver (100W, CI-V: 0x50)
- **IC-746PRO** - HF/6m + 2m receive (100W, CI-V: 0x66)
- **IC-746** - HF/6m + 2m receive (100W, CI-V: 0x56)

**HF + VHF/UHF Multi-Band:**
- **IC-9100** - HF/VHF/UHF dual receiver with satellite (100W, CI-V: 0x7C)
- **IC-7100** - HF/VHF/UHF all-mode (100W, CI-V: 0x88)
- **IC-705** - HF/VHF/UHF portable (10W, CI-V: 0xA4)
- **IC-7000** - HF/VHF/UHF mobile (100W HF/50W VHF/35W UHF, CI-V: 0x70)
- **IC-706MKIIG** - HF/VHF/UHF mobile (100W HF/50W VHF/20W UHF, CI-V: 0x58)
- **IC-706MKII** - HF/VHF mobile (100W HF, CI-V: 0x4E)
- **IC-706** - HF/VHF mobile (100W HF, CI-V: 0x48)

**VHF/UHF:**
- **IC-9700** - VHF/UHF/1.2GHz all-mode dual receiver (100W, CI-V: 0xA2)
- **IC-905** - VHF/UHF/SHF microwave (10W, CI-V: 0xAC)
- **IC-910H** - VHF/UHF satellite transceiver (100W 2m/75W 70cm, CI-V: 0x60)
- **IC-970** - VHF/UHF all-mode legacy (100W, CI-V: 0x2E)
- **IC-820H** - VHF/UHF satellite legacy (45W, CI-V: 0x42)
- **IC-2730** - VHF/UHF dual-band FM mobile (50W, CI-V: 0x90)
- **ID-5100** - VHF/UHF D-STAR mobile (50W, CI-V: 0x8C)
- **ID-4100** - VHF/UHF D-STAR mobile (50W, CI-V: 0x9A)

**D-STAR Handhelds:**
- **ID-31A/E** - Single-band UHF D-STAR HT (5W, CI-V: 0xA0)
- **ID-51A/E / ID-51A Plus2** - Dual-band V/U D-STAR HT (5W, CI-V: 0x86)
- **ID-52A/E / ID-52A Plus2** - Dual-band V/U D-STAR HT (5W, CI-V: 0xB4)
- **IC-92AD / IC-E92D** - Dual-band D-STAR HT (5W, CI-V: 0x01)

**Receivers:**
- **IC-R9500** - Professional wideband receiver (1.2kHz-3.3GHz, CI-V: 0x72)
- **IC-R8600** - Wideband receiver (10kHz-3GHz, CI-V: 0x96)
- **IC-R75** - HF receiver (30kHz-60MHz, CI-V: 0x5A)
- **IC-R30** - Wideband digital handheld receiver (100kHz-3.3GHz, CI-V: 0x9C)

### Yaesu (CAT Protocol) — 25 models

**Flagship HF:**
- **FTDX-9000** - HF/6m 200W/400W flagship (38400 baud)
- **FTDX-5000** - HF/6m 200W flagship dual receiver (38400 baud)
- **FTDX-101MP** - HF/6m 200W flagship (38400 baud)
- **FTDX-101D** - HF/6m 100W dual receiver (38400 baud)
- **FTDX-3000** - HF/6m 100W (38400 baud)
- **FTDX-1200** - HF/6m 100W with DSP (38400 baud)

**Popular HF:**
- **FTDX-10** - HF/6m 100W entry-level SDR (38400 baud)
- **FT-991** - HF/VHF/UHF all-mode (38400 baud)
- **FT-991A** - HF/VHF/UHF all-mode (38400 baud)
- **FT-950** - HF/6m 100W with ATU (38400 baud)
- **FT-920** - HF/6m 100W with DSP (38400 baud)
- **FT-710** - HF/6m AESS (38400 baud)
- **FT-891** - HF/6m field transceiver (38400 baud)
- **FT-450** - HF/6m budget (38400 baud)
- **FT-450D** - HF/6m budget with DSP (38400 baud)
- **FT-2000** - HF/6m 100W (38400 baud)
- **FT-1000MP** - HF/6m flagship legacy (4800 baud)

**HF + VHF/UHF Mobile:**
- **FT-897** - HF/VHF/UHF base/mobile (38400 baud)
- **FT-897D** - HF/VHF/UHF base/mobile with DSP (38400 baud)
- **FT-857** - HF/VHF/UHF mobile (38400 baud)
- **FT-857D** - HF/VHF/UHF mobile with DSP (38400 baud)
- **FT-847** - HF/VHF/UHF all-band (38400 baud)
- **FT-100** - HF/VHF/UHF mobile (38400 baud)

**Portable/QRP:**
- **FT-818** - HF/VHF/UHF portable (38400 baud)
- **FT-817** - HF/VHF/UHF portable QRP (38400 baud)

### Elecraft (Text-Based Protocol) — 6 models

**High-Performance:**
- **K4** - HF/6m SDR transceiver (100W, 38400 baud)
- **K3S** - HF/6m enhanced (100W, 38400 baud)
- **K3** - HF/6m all-mode (100W, 38400 baud)

**QRP/Portable:**
- **KX3** - HF/6m portable (15W, 38400 baud)
- **KX2** - HF portable (12W, 38400 baud)
- **K2** - HF transceiver (15W, 4800 baud)

### Xiegu (CI-V Compatible) — 3 models

**Budget HF:**
- **G90** - HF 20W SDR transceiver (19200 baud, CI-V: 0xA4)
- **X6100** - HF/6m 10W portable SDR (19200 baud, CI-V: 0xA4)
- **X6200** - HF/6m 8W portable SDR (19200 baud, CI-V: 0xA4)

### Kenwood (Text-Based Protocol) — 17 models

**HF Flagships:**
- **TS-990S** - HF/6m flagship with dual receiver (200W, 115200 baud)
- **TS-890S** - HF/6m with dual receiver (100W, 115200 baud)

**HF Transceivers:**
- **TS-590SG** - HF/6m all-mode (100W, 115200 baud)
- **TS-590S** - HF/6m all-mode (100W, 115200 baud)
- **TS-870S** - HF/6m all-mode (100W, 115200 baud)
- **TS-850S** - HF 100W transceiver (legacy, 4800 baud)
- **TS-570D** - HF/6m with DSP (100W, 57600 baud)
- **TS-570S** - HF/6m with DSP (100W, 57600 baud)
- **TS-480SAT** - HF/6m with antenna tuner (100W, 57600 baud)
- **TS-480HX** - HF/6m high power (200W, 57600 baud)

**HF + VHF/UHF:**
- **TS-2000** - HF/VHF/UHF all-mode (100W, 57600 baud)

**VHF/UHF:**
- **TM-D710** - VHF/UHF dual-band mobile (50W, 57600 baud)
- **TM-V71** - VHF/UHF dual-band mobile (50W, 57600 baud)
- **TH-D75** - Tri-band handheld with D-STAR and APRS (5W, 9600 baud)
- **TH-D74** - VHF/UHF handheld with D-STAR (5W, 57600 baud)
- **TH-D72A** - VHF/UHF handheld with APRS (5W, 57600 baud)
- **TH-D72** - VHF/UHF handheld with APRS (5W, 57600 baud)

### Lab599 — 1 model

- **TX-500** - Portable HF transceiver (10W, Kenwood-compatible CAT)

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jjones9527/SwiftRigControl.git", from: "1.0.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter repository URL

## Quick Start

### Develop without hardware (SwiftUI previews, demos, tutorials)

SwiftRigControl ships an in-memory **dummy radio** — the Swift
analogue of Hamlib's Model 1. It implements the full `RigController`
API but holds state in memory instead of talking to a serial port,
so you can build, preview, and demo apps with no rig connected.

```swift
import RigControl

// No radio? No problem.
let rig = try RigController(radio: .dummy(), connection: .mock)
try await rig.connect()

try await rig.setFrequency(14_230_000, vfo: .a)
try await rig.setMode(.usb, vfo: .a)
let f = try await rig.frequency()   // 14_230_000
```

Override capabilities to simulate a different rig (VHF-only, QRP,
receive-only):

```swift
let vhf = RigCapabilities(
    supportedModes: [.fm, .fmN],
    frequencyRange: FrequencyRange(min: 144_000_000, max: 148_000_000)
)
let rig = try RigController(
    radio: .dummy(name: "2m FM Mobile", capabilities: vhf),
    connection: .mock
)
```

See `Examples/BasicUsage/DummyRadioExample.swift` for the full pattern
including a SwiftUI preview snippet.

### Push-style state updates (no polling)

`RigController.events` is an `AsyncStream<RigStateEvent>` that fires
whenever the radio's state changes. SwiftUI views and `@Observable`
view models can react to state changes without a polling loop:

```swift
Task {
    for await event in rig.events {
        switch event {
        case .frequencyChanged(let vfo, let hz):
            viewModel.frequency[vfo] = hz
        case .modeChanged(let vfo, let mode):
            viewModel.mode[vfo] = mode
        case .pttChanged(let on):
            viewModel.transmitting = on
        case .connectionStateChanged(let state):
            viewModel.connectionState = state
        default:
            break
        }
    }
}
```

Multiple subscribers can observe the same controller simultaneously
(each `rig.events` access returns its own stream; the controller
fans events out). Buffering is bounded — slow consumers see the most
recent 64 events. See `Examples/BasicUsage/DummyRadioExample.swift`
for the full `@Observable` view-model pattern.

For state the radio doesn't push (S-meter, front-panel knob and mic
PTT), opt into the polled broadcaster:

```swift
await rig.startPolling()   // sensible defaults: 200 ms S-meter,
                            // 1 s frequency, 2 s mode, 100 ms PTT
// ... events arrive on rig.events as state changes ...
await rig.stopPolling()
```

Polled values feed the same `events` stream, so consumer code
doesn't have to distinguish setter-driven from poll-driven changes.
`disconnect()` stops polling automatically.

For long-running sessions where the radio could disappear (USB
cable yanked, RF interference, etc.), enable the connection-health
monitor — optionally with auto-reconnect:

```swift
// Heartbeat only — surfaces .degraded on the events stream when
// the radio stops responding, recovers to .connected when it
// answers again.
await rig.startHealthMonitor()

// Or with auto-reconnect: exponential backoff, retries forever.
await rig.startHealthMonitor(.init(
    heartbeatInterval: 5,
    degradeAfter: 3,
    retryPolicy: RigController.RetryPolicy()
))
```

State transitions emit `.connectionStateChanged(.degraded(...))`
and `.connectionStateChanged(.reconnecting(attempt: N))` so UI can
show a "Reconnecting…" indicator without any extra plumbing.

### Basic Usage (Non-Sandboxed Apps)

```swift
import RigControl

// Create a rig controller
let rig = try RigController(
    radio: .Icom.ic9700(),
    connection: .serial(path: "/dev/cu.usbserial-A1B2C3", baudRate: 115200)
)

// Connect to the radio
try await rig.connect()

// Set frequency to 14.230 MHz (20m SSTV calling frequency)
try await rig.setFrequency(14_230_000, vfo: .a)

// Set mode to USB
try await rig.setMode(.usb, vfo: .a)

// Key the transmitter
try await rig.setPTT(true)

// ... transmit audio ...

// Unkey the transmitter
try await rig.setPTT(false)

// Disconnect
await rig.disconnect()
```

### Reading Radio State

```swift
// Get current frequency (with caching for performance)
let freq = try await rig.frequency(vfo: .a)
print("Current frequency: \(freq) Hz")

// Get current mode
let mode = try await rig.mode(vfo: .a)
print("Current mode: \(mode)")

// Get PTT state
let isTransmitting = try await rig.isPTTEnabled()
print("Transmitting: \(isTransmitting)")

// Get RF power level (if supported)
if rig.capabilities.powerControl {
    let power = try await rig.power()
    print("Power: \(power) watts")
}

// NEW in v1.1.0: Read signal strength
let signal = try await rig.signalStrength()
print("Signal: \(signal.description)")  // "S7" or "S9+20"

if signal.isStrongSignal {
    print("Strong signal: S9 or better!")
}
```

### Batch Configuration

```swift
// Set up for FT8 on 20m in one call
try await rig.configure(
    frequency: 14_074_000,
    mode: .dataUSB,
    power: 50
)

// Quick band change
try await rig.configure(frequency: 7_074_000)

// Mode change only
try await rig.configure(mode: .cw)
```

### Compound VFO Operations (v1.1)

Front-panel "swap A↔B", "copy A→B", and "tune ATU" buttons map
to single-call operations:

```swift
// Swap VFO A and B contents.
try await rig.performVFOOperation(.exchange)

// Copy the active VFO to the other VFO.
try await rig.performVFOOperation(.copyVFO)

// Start an ATU tune cycle (radios with built-in tuner).
try await rig.performVFOOperation(.tune)

// Recall the selected memory channel into the active VFO.
try await rig.performVFOOperation(.memoryToVFO)
```

Per-radio support is gated by `capabilities.supportedVFOOperations` — calling
an op the radio doesn't support throws `RigError.unsupportedOperation`.
See `VFOOperation` for the full set of 11 cases.

### Function Toggles (v1.1)

On/off radio bits — speech compressor, VOX, CTCSS, lock, ATU
enable, satellite mode, scope, etc. — via a single curated enum
covering 21 of Hamlib's most-used `RIG_FUNC_*` bits:

```swift
// Engage the speech compressor.
try await rig.setFunction(.compressor, enabled: true)

// Engage front-panel lock so the operator can't fiddle.
try await rig.setFunction(.lock, enabled: true)

// IC-9700 satellite mode.
try await rig.setFunction(.satelliteMode, enabled: true)

// Read a function bit.
let voxOn = try await rig.getFunction(.vox)
```

Per-radio support is gated by `capabilities.supportedFunctions`.
See `RigFunction` for the full set.

### Secondary Level Controls (v1.1)

The second-tier knobs every SSB/CW operator touches — exposed
as a 0-100 normalized scale:

```swift
try await rig.setMicGain(60)
try await rig.setCompressorLevel(40)        // distinct from on/off toggle
try await rig.setMonitorGain(20)             // sidetone monitor
try await rig.setVOXGain(50)
try await rig.setVOXDelay(30)
try await rig.setIFShift(50)                 // 50 = center, 0 = -1200 Hz, 100 = +1200 Hz
```

### Performance Caching

```swift
// Cached reads are 10-20x faster (default behavior)
let freq1 = try await rig.frequency(cached: true)  // ~50ms first time
let freq2 = try await rig.frequency(cached: true)  // <5ms from cache

// Force fresh query when needed
let freshFreq = try await rig.frequency(cached: false)

// Manually invalidate cache after manual radio adjustments
await rig.invalidateCache()
```

### Frequency Validation

SwiftRigControl includes comprehensive frequency validation to prevent invalid commands and ensure safe operation:

```swift
// Access radio capabilities
let capabilities = rig.capabilities

// Check if a frequency is valid for the radio
if capabilities.isFrequencyValid(14_200_000) {
    try await rig.setFrequency(14_200_000)
}

// Check if radio can transmit on a frequency
if capabilities.canTransmit(on: 14_200_000) {
    print("Can transmit on 20m")
} else {
    print("Receive only on this frequency")
}

// Get supported modes for a specific frequency
let modes = capabilities.supportedModes(for: 14_200_000)
print("Supported modes: \(modes)")  // [.usb, .cw, .rtty, .dataUSB]

// Get band name for a frequency
if let band = capabilities.bandName(for: 14_200_000) {
    print("Frequency is in \(band) band")  // "20m"
}

// Look up amateur band allocations
// Region 2 (Americas - default)
if let band = Region2AmateurBand.band(for: 14_200_000) {
    print("Amateur band: \(band.displayName)")  // "20m"
    print("Band range: \(band.frequencyRange)")
    print("Common modes: \(band.commonModes)")
}

// Region 1 (Europe/Africa/Middle East)
if let band40m = Region1AmateurBand.band(for: 7_100_000) {
    print("\(band40m.displayName): \(band40m.frequencyRange)")  // "40m: 7000000...7200000"
}

// Region 3 (Asia-Pacific)
if let band40m = Region3AmateurBand.band(for: 7_100_000) {
    print("\(band40m.displayName): \(band40m.frequencyRange)")  // "40m: 7000000...7300000"
}

// Check if frequency is in amateur band for configured region
if capabilities.isInAmateurBand(14_200_000) {
    print("Frequency is within amateur allocation")
}

// Get amateur band name based on radio's region
if let amateurBand = capabilities.amateurBandName(for: 14_200_000) {
    print("Amateur band: \(amateurBand)")  // "20m"
}
```

**Safety Features:**
- Prevents transmitting outside radio capabilities (protects hardware)
- Identifies receive-only frequency ranges
- Validates modes for specific frequency ranges
- Supports all 3 ITU regions (Region 1: Europe/Africa, Region 2: Americas, Region 3: Asia-Pacific)
- Regional amateur band validation (configurable per radio)
- Comprehensive error messages with recovery suggestions

**Regional Band Differences:**

Amateur radio frequency allocations vary by ITU region. Key differences:
- **40m**: Region 1 (7.0-7.2 MHz), Region 2 (7.0-7.3 MHz), Region 3 (7.0-7.3 MHz)
- **80m**: Region 1 (3.5-3.8 MHz), Region 2 (3.5-4.0 MHz), Region 3 (3.5-3.9 MHz)
- **6m**: Region 1 (50-52 MHz), Region 2 (50-54 MHz), Region 3 (50-54 MHz)

Configure radio region during initialization (defaults to Region 2):

```swift
let caps = RigCapabilities(
    region: .region1,  // Europe/Africa/Middle East
    // ... other properties
)
```

```swift
do {
    try await rig.setFrequency(150_000_000)  // Outside IC-7300 range
} catch RigError.frequencyOutOfRange(let freq, let model) {
    print("Frequency \(freq) Hz is outside \(model) capabilities")
    // Check error.recoverySuggestion for guidance
}
```

### Error Handling

```swift
do {
    try await rig.setFrequency(14_230_000, vfo: .a)
} catch RigError.notConnected {
    print("Radio is not connected")
} catch RigError.timeout {
    print("Radio did not respond - check cables")
} catch RigError.commandFailed(let reason) {
    print("Command failed: \(reason)")
} catch {
    print("Unexpected error: \(error)")
}
```

### Mac App Store / Sandboxed Apps

For Mac App Store applications, use the XPC helper:

```swift
import RigControlXPC

// Connect to the XPC helper
let client = XPCClient.shared
try await client.connect()

// Connect to radio through helper
try await client.connectToRadio(radio: "IC-9700", port: "/dev/cu.IC9700")

// Use same API as RigControl
try await client.setFrequency(14_230_000, vfo: .a)
try await client.setMode(.usb, vfo: .a)
try await client.setPTT(true)

// Disconnect
await client.disconnectRadio()
await client.disconnect()
```

**Note:** The XPC helper must be installed once (requires admin password). See [XPC Helper Guide](Documentation/XPC_HELPER_GUIDE.md) for complete details.

## Finding Serial Ports

On macOS, Icom radios typically appear as:

```bash
ls /dev/cu.* | grep -i icom
```

Common patterns:
- `/dev/cu.SLAB_USBtoUART` - Silicon Labs USB-to-serial
- `/dev/cu.usbserial-*` - Generic USB serial
- `/dev/cu.IC9700` - Direct Icom naming (if driver installed)

## Quick Reference

### Radio Specifications

#### Icom Radios (CI-V Protocol)

| Model | Baud Rate | Max Power | Frequency Range | Dual RX | ATU | Split |
|-------|-----------|-----------|-----------------|---------|-----|-------|
| IC-7851 | 19200 | 200W | 30 kHz - 60 MHz | Yes | Yes | Yes |
| IC-7800 | 19200 | 200W | 30 kHz - 60 MHz | Yes | Yes | Yes |
| IC-7700 | 19200 | 200W | 30 kHz - 60 MHz | No | Yes | Yes |
| IC-7610 | 115200 | 100W | 30 kHz - 60 MHz | Yes | Yes | Yes |
| IC-7600 | 19200 | 100W | 30 kHz - 60 MHz | Yes | Yes | Yes |
| IC-7300 | 115200 | 100W | 30 kHz - 60 MHz | No | Yes | Yes |
| IC-7410 | 19200 | 100W | 30 kHz - 60 MHz | No | Yes | Yes |
| IC-7200 | 19200 | 100W | 30 kHz - 60 MHz | No | Yes | Yes |
| IC-7100 | 19200 | 100W | 30 kHz - 500 MHz | No | Yes | Yes |
| IC-7000 | 19200 | 100W | 30 kHz - 500 MHz | No | Yes | Yes |
| IC-9700 | 115200 | 100W | 144 MHz - 1.3 GHz | Yes | No | Yes |
| IC-9100 | 19200 | 100W | 30 kHz - 1.3 GHz | Yes | Yes | Yes |
| IC-705 | 19200 | 10W | 30 kHz - 500 MHz | No | Yes | Yes |
| IC-756PRO III | 19200 | 100W | 30 kHz - 60 MHz | Yes | Yes | Yes |
| IC-756PRO II | 19200 | 100W | 30 kHz - 60 MHz | Yes | Yes | Yes |
| IC-756PRO | 19200 | 100W | 30 kHz - 60 MHz | Yes | Yes | Yes |
| IC-756 | 19200 | 100W | 30 kHz - 60 MHz | Yes | No | Yes |
| IC-746PRO | 19200 | 100W | 30 kHz - 148 MHz | No | Yes | Yes |
| IC-746 | 19200 | 100W | 30 kHz - 148 MHz | No | Yes | Yes |
| IC-706MKIIG | 19200 | 100W | 30 kHz - 450 MHz | No | No | Yes |
| IC-706MKII | 19200 | 100W | 30 kHz - 148 MHz | No | No | Yes |
| IC-706 | 19200 | 100W | 30 kHz - 148 MHz | No | No | Yes |
| IC-910H | 19200 | 100W | 144-1300 MHz | Yes | No | Yes |
| ID-5100 | 19200 | 50W | 118-524 MHz | Yes | No | No |
| ID-4100 | 19200 | 50W | 118-524 MHz | Yes | No | No |
| ID-52A/E | 9600 | 5W | 108-550 MHz | Yes | No | No |
| ID-51A/E | 9600 | 5W | 118-550 MHz | Yes | No | No |
| ID-31A/E | 9600 | 5W | 400-479 MHz | No | No | No |
| IC-92D | 9600 | 5W | 495 kHz-1 GHz | Yes | No | No |
| IC-R8600 | 19200 | N/A | 10 kHz - 3 GHz | No | No | No |
| IC-R30 | 9600 | N/A | 100 kHz - 3.3 GHz | Yes | No | No |

#### Elecraft Radios (Text Protocol)

| Model | Baud Rate | Max Power | Frequency Range | Dual RX | ATU | Split |
|-------|-----------|-----------|-----------------|---------|-----|-------|
| K4 | 38400 | 100W | 30 kHz - 60 MHz | Yes | Yes | Yes |
| K3S | 38400 | 100W | 30 kHz - 60 MHz | Yes | Yes | Yes |
| K3 | 38400 | 100W | 30 kHz - 60 MHz | Yes | Yes | Yes |
| KX3 | 38400 | 15W | 30 kHz - 60 MHz | No | Yes | Yes |
| KX2 | 38400 | 12W | 30 kHz - 60 MHz | No | Yes | Yes |
| K2 | 4800 | 15W | 30 kHz - 30 MHz | No | Yes | Yes |

#### Yaesu Radios (CAT Protocol)

| Model | Baud Rate | Max Power | Frequency Range | Dual RX | ATU | Split |
|-------|-----------|-----------|-----------------|---------|-----|-------|
| FTDX-101D | 38400 | 100W | 30 kHz - 60 MHz | Yes | Yes | Yes |
| FTDX-10 | 38400 | 100W | 30 kHz - 60 MHz | No | Yes | Yes |
| FT-991A | 38400 | 100W | 30 kHz - 500 MHz | No | Yes | Yes |
| FT-710 | 38400 | 100W | 30 kHz - 60 MHz | No | Yes | Yes |
| FT-891 | 38400 | 100W | 30 kHz - 60 MHz | No | Yes | Yes |
| FT-817 | 38400 | 5W | 30 kHz - 500 MHz | No | No | Yes |

#### Kenwood Radios (Text Protocol)

| Model | Baud Rate | Max Power | Frequency Range | Dual RX | ATU | Split |
|-------|-----------|-----------|-----------------|---------|-----|-------|
| TS-990S | 115200 | 200W | 30 kHz - 60 MHz | Yes | Yes | Yes |
| TS-890S | 115200 | 100W | 30 kHz - 60 MHz | Yes | Yes | Yes |
| TS-590SG | 115200 | 100W | 30 kHz - 60 MHz | No | Yes | Yes |
| TS-2000 | 57600 | 100W | 30 kHz - 1.3 GHz | No | Yes | Yes |
| TS-480SAT | 57600 | 100W | 30 kHz - 60 MHz | No | Yes | Yes |
| TM-D710 | 57600 | 50W | 118 - 524 MHz | Yes | No | No |
| TH-D75 | 9600 | 5W | 118-524 MHz | Yes | No | No |

#### Lab599 Radios (Kenwood-Compatible CAT)

| Model | Baud Rate | Max Power | Frequency Range | Dual RX | ATU | Split |
|-------|-----------|-----------|-----------------|---------|-----|-------|
| TX-500 | 115200 | 10W | 300 kHz - 30 MHz | No | No | Yes |

### Protocol Command Comparison

| Feature | Icom CI-V | Elecraft | Yaesu CAT | Kenwood |
|---------|-----------|----------|-----------|---------|
| **Protocol Type** | Binary | Text (ASCII) | Text (ASCII) | Text (ASCII) |
| **Terminator** | 0xFD | ; (semicolon) | ; (semicolon) | ; (semicolon) |
| **Set Frequency** | Binary BCD | `FA14230000;` | `FA14230000;` | `FA14230000;` |
| **Get Frequency** | Cmd 0x03 | `FA;` | `FA;` | `FA;` |
| **Set Mode** | Cmd 0x06 | `MD2;` (USB) | `MD2;` (USB) | `MD2;` (USB) |
| **PTT On** | Cmd 0x1C 0x00 0x01 | `TX;` | `TX1;` | `TX1;` |
| **PTT Off** | Cmd 0x1C 0x00 0x00 | `RX;` | `TX0;` | `TX0;` |
| **VFO Select** | Cmd 0x07 | `FT0;`/`FT1;` | `FT0;`/`FT1;` | `FR0;`/`FR1;` |
| **Split On** | Cmd 0x0F 0x01 | `FT1;` | `FT1;` | `FT1;` |
| **S-Meter** | Cmd 0x15 0x02 | `SM0;` | `RM5;` | `SM0;` |
| **Response** | Echo + ACK/NAK | Echo command | Echo command | Echo command |

### Supported Modes by Manufacturer

| Mode | Icom | Elecraft | Yaesu | Kenwood |
|------|------|----------|-------|---------|
| LSB | ✅ | ✅ | ✅ | ✅ |
| USB | ✅ | ✅ | ✅ | ✅ |
| CW | ✅ | ✅ | ✅ | ✅ |
| CW-R | ✅ | ✅ | ✅ | ✅ |
| AM | ✅ | ✅ | ✅ | ✅ |
| FM | ✅ | ✅ | ✅ | ✅ |
| FM-N | ✅ | ❌ | ✅ | ❌ |
| RTTY | ✅ | ❌ | ✅ | ✅ |
| DATA-LSB | ✅ | ❌ | ✅ | ✅ |
| DATA-USB | ✅ | ✅ | ✅ | ❌ |

### Common Use Cases

| Task | Command |
|------|---------|
| **Set 20m SSTV frequency** | `try await rig.setFrequency(14_230_000, vfo: .a)` |
| **Set USB mode** | `try await rig.setMode(.usb, vfo: .a)` |
| **Enable split (+5kHz)** | `try await rig.setFrequency(14_195_000, vfo: .a)`<br>`try await rig.setFrequency(14_200_000, vfo: .b)`<br>`try await rig.setSplit(true)` |
| **Set QRP power (5W)** | `try await rig.setPower(5)` |
| **Read current frequency** | `let freq = try await rig.frequency()` |
| **Check if transmitting** | `let isTX = try await rig.isPTTEnabled()` |

## Architecture

### Module Structure

```
SwiftRigControl/
├── RigControl/              # Core library
│   ├── Core/                # RigController, protocols
│   ├── Transport/           # Serial communication
│   ├── Protocols/           # Radio protocol implementations
│   │   └── Icom/           # CI-V protocol
│   ├── Models/              # VFO, Mode, errors
│   └── Utilities/           # BCD encoding
│
├── RigControlXPC/           # XPC helper (Mac App Store)
└── RigControlHelper/        # XPC service executable
```

### Protocol Abstraction

All radio protocols implement the `CATProtocol`:

```swift
public protocol CATProtocol: Actor {
    func setFrequency(_ hz: UInt64, vfo: VFO) async throws
    func getFrequency(vfo: VFO) async throws -> UInt64
    func setMode(_ mode: Mode, vfo: VFO) async throws
    func getMode(vfo: VFO) async throws -> Mode
    func setPTT(_ enabled: Bool) async throws
    func getPTT() async throws -> Bool
    // ... and more
}
```

Current implementations:
- ✅ **IcomCIVProtocol** - Icom CI-V binary protocol
- ✅ **ElecraftProtocol** - Elecraft text-based protocol
- ✅ **YaesuCATProtocol** - Yaesu CAT text-based protocol
- ✅ **KenwoodProtocol** - Kenwood text-based protocol

## Development Status

### Week 1 ✅ COMPLETE

- [x] Directory structure
- [x] Core protocol definitions (CATProtocol, SerialTransport)
- [x] IOKit serial port implementation
- [x] Type-safe models (VFO, Mode, RigCapabilities)
- [x] Icom CI-V protocol implementation
- [x] BCD encoding utilities
- [x] Radio registry (6 Icom radios)
- [x] RigController API
- [x] Unit tests (BCD encoding, CI-V frames, protocol)

### Week 2 & 3 ✅ COMPLETE

- [x] Split operation support
- [x] Integration tests for real hardware
- [x] Elecraft protocol implementation
- [x] 6 Elecraft radio definitions (K2, K3, K3S, K4, KX2, KX3)
- [x] Unit tests for Elecraft protocol

### Week 4 & 5 ✅ COMPLETE

- [x] XPC protocol definition
- [x] XPCClient (async/await interface)
- [x] XPCServer (bridges to RigControl)
- [x] RigControlHelper executable
- [x] XPC Helper documentation

### Week 6 & 7 ✅ COMPLETE

- [x] Yaesu CAT protocol implementation
- [x] 6 Yaesu radio definitions (FTDX-10, FT-991A, FT-710, FT-891, FT-817, FTDX-101D)
- [x] Kenwood protocol implementation
- [x] 6 Kenwood radio definitions (TS-890S, TS-990S, TS-590SG, TM-D710, TS-480SAT, TS-2000)
- [x] Unit tests for Yaesu protocol
- [x] Unit tests for Kenwood protocol
- [x] XPC server support for all new radios

### Week 8 ✅ COMPLETE

- [x] Comprehensive usage examples (615 lines)
- [x] Troubleshooting guide (580 lines)
- [x] Serial port configuration guide (645 lines)
- [x] Hamlib migration guide (570 lines)
- [x] Quick reference tables in README
- [x] Error message clarity review
- [x] Code consistency review

### Week 9 - v1.0.0 Release 🚀

- [x] Release notes complete
- [x] CHANGELOG.md complete
- [x] CONTRIBUTING.md complete
- [ ] Final testing verification
- [x] Version 1.0.0 tag
- [ ] GitHub release

## Testing

### Unit Tests

```bash
swift test
```

Tests include:
- BCD encoding/decoding
- CI-V frame construction and parsing
- Protocol implementation with mock transport
- Error handling

### Integration Tests (Requires Hardware)

```bash
# Set your radio's serial port
export RIG_SERIAL_PORT="/dev/cu.IC9700"

swift test --filter IntegrationTests
```

## Documentation

The canonical reference is the **[hosted DocC site](https://jjones9527.github.io/SwiftRigControl/documentation/rigcontrol/)** —
built from `Sources/RigControl/RigControl.docc/` on every push to
main. Includes the landing page, curated topic groups, and full
symbol-level reference plus articles on the reactive event stream,
the dummy radio, verification status, adding radios, and Hamlib
migration.

### For App Developers

- **[API Reference](Documentation/API_REFERENCE.md)** - Complete API documentation (markdown form; see DocC site above for symbol-linked version)
- **[Usage Examples](Documentation/USAGE_EXAMPLES.md)** - Common use cases and patterns
- **[Troubleshooting Guide](Documentation/TROUBLESHOOTING.md)** - Problem solving
- **[Serial Port Guide](Documentation/SERIAL_PORT_GUIDE.md)** - Connection setup
- **[XPC Helper Guide](Documentation/XPC_HELPER_GUIDE.md)** - Mac App Store integration
- **[Hamlib Migration](Documentation/HAMLIB_MIGRATION.md)** - Migrating from Hamlib

### For Contributors

- **[Contributing Guide](CONTRIBUTING.md)** - How to contribute
- **[Adding Radio Support](Documentation/ADDING_RADIOS.md)** - Step-by-step guide for adding new radios
- **[Icom Radio Architectures](ICOM_RADIO_ARCHITECTURES.md)** - Detailed Icom VFO models and quirks

## Contributing

Contributions are welcome! We have extensive documentation to help you get started.

### Adding a New Radio

See our comprehensive [Adding Radio Support Guide](Documentation/ADDING_RADIOS.md) for step-by-step instructions.

**Quick Start:**

1. Check the [Adding Radios Guide](Documentation/ADDING_RADIOS.md)
2. Study similar radios in the codebase
3. Reference official CAT command manual
4. Add radio definition and capabilities
5. Create tests
6. Test with real hardware
7. Submit PR

**We currently support:**
- Icom CI-V protocol (38 radios)
- Yaesu CAT protocol (21 radios)
- Kenwood text protocol (12 radios, includes TH-D72/TH-D74)
- Elecraft text protocol (6 radios)
- Ten-Tec protocol (5 radios — Orion family + Legacy)
- Xiegu (CI-V compatible) (3 radios)

Adding a radio using an existing protocol typically takes 30-60 minutes!

## License

GNU Lesser General Public License v3.0 (LGPL v3.0) - see [LICENSE](LICENSE) for details.

**What this means for you:**
- ✅ **Use freely** in commercial or open source applications
- ✅ **Link as a library** - your application code remains under your chosen license
- ✅ **Distribute freely** - no restrictions on redistribution
- ⚠️ **Share modifications** - if you modify SwiftRigControl itself, those changes must be shared under LGPL v3.0
- ✅ **Attribution** - minimal requirement to mention you use SwiftRigControl

This follows the same licensing model as [Hamlib](https://hamlib.github.io/), the industry-standard radio control library.

## Authors

- VA3ZTF (Jeremy Jones)

## Acknowledgments

- Icom CI-V protocol documentation
- Amateur radio community
- SSTV application (original implementation)

## Support

- Issues: https://github.com/jjones9527/SwiftRigControl/issues
- Discussions: https://github.com/jjones9527/SwiftRigControl/discussions
- Email: va3ztf@gmail.com

## Roadmap

See [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) for the complete 9-week implementation roadmap.

---

**73 de VA3ZTF**
