# IC-7600 API Guide for SwiftRigControl

Complete guide for controlling the Icom IC-7600 using SwiftRigControl.

## Table of Contents

- [Quick Start](#quick-start)
- [Connection](#connection)
- [Basic Operations](#basic-operations)
- [IC-7600 Specific Features](#ic-7600-specific-features)
- [Advanced Features](#advanced-features)
- [Complete Example](#complete-example)
- [API Reference](#api-reference)

## Quick Start

```swift
import RigControl

// Create controller for IC-7600
let rig = RigController(
    radio: .icomIC7600,
    connection: .serial(path: "/dev/cu.usbserial-2120", baudRate: 19200)
)

// Connect and configure
try await rig.connect()
try await rig.configure(frequency: 14_230_000, mode: .usb, power: 50)

// Use IC-7600 specific features
try await rig.setAttenuator(6)        // 6dB attenuation
try await rig.setNoiseBlanker(true)   // Enable NB
try await rig.setDualWatch(true)      // Monitor Main + Sub

await rig.disconnect()
```

## Connection

### Serial Connection

```swift
let rig = RigController(
    radio: .icomIC7600,
    connection: .serial(
        path: "/dev/cu.usbserial-2120",  // Your USB-serial adapter
        baudRate: 19200                   // IC-7600 default
    )
)

try await rig.connect()
```

### Check Connection Status

```swift
if rig.isConnected {
    print("Connected to \(rig.radioName)")
}
```

## Basic Operations

### Frequency Control

The IC-7600 has dual receivers (Main and Sub). Use `.main` and `.sub` VFOs:

```swift
// Set Main band frequency
try await rig.setFrequency(14_200_000, vfo: .main)  // 14.200 MHz

// Set Sub band frequency
try await rig.setFrequency(7_100_000, vfo: .sub)    // 7.100 MHz

// Read frequencies
let mainFreq = try await rig.frequency(vfo: .main)
let subFreq = try await rig.frequency(vfo: .sub)
print("Main: \(mainFreq / 1_000_000) MHz, Sub: \(subFreq / 1_000_000) MHz")
```

### Mode Control

```swift
// Set mode on Main band
try await rig.setMode(.usb, vfo: .main)
try await rig.setMode(.lsb, vfo: .sub)

// Available modes:
// .lsb, .usb, .am, .cw, .cwR, .rtty, .rttyR, .fm
```

#### DATA Mode (USB-D/LSB-D)

The IC-7600 handles DATA modes differently from basic modes. Instead of separate mode codes, DATA modes use a two-step process:

1. Set the base mode (USB or LSB)
2. Enable DATA mode via command 1A 06

```swift
import RigControl

// Get access to IC-7600 protocol methods
let proto = await rig.protocol
guard let icomProtocol = proto as? IcomCIVProtocol else {
    fatalError("Not an Icom protocol")
}

// Set USB-D (USB + DATA mode D1)
try await rig.setMode(.usb, vfo: .main)
try await icomProtocol.setDataModeIC7600(dataMode: 0x01, filter: 0x01)

// Set LSB-D (LSB + DATA mode D1)
try await rig.setMode(.lsb, vfo: .main)
try await icomProtocol.setDataModeIC7600(dataMode: 0x01, filter: 0x01)

// Read current DATA mode setting
let (dataMode, filter) = try await icomProtocol.getDataModeIC7600()
// dataMode: 0x00=OFF, 0x01=D1, 0x02=D2, 0x03=D3
// filter: 0x00=OFF, 0x01=FIL1, 0x02=FIL2, 0x03=FIL3

// Turn off DATA mode (return to normal USB/LSB)
try await icomProtocol.setDataModeIC7600(dataMode: 0x00, filter: 0x00)
```

**DATA Mode Settings:**
- `dataMode: 0x00` - DATA mode OFF (normal USB/LSB)
- `dataMode: 0x01` - DATA mode D1 (USB-D1 or LSB-D1)
- `dataMode: 0x02` - DATA mode D2 (USB-D2 or LSB-D2)
- `dataMode: 0x03` - DATA mode D3 (USB-D3 or LSB-D3)

**Filter Settings:**
- `filter: 0x00` - Filter OFF
- `filter: 0x01` - Filter 1 (FIL1)
- `filter: 0x02` - Filter 2 (FIL2)
- `filter: 0x03` - Filter 3 (FIL3)

**Note:** On the IC-7600, you activate USB-D or LSB-D on the front panel by pressing and holding the SSB button until the "-D" appears. This is different from radios that have a dedicated DATA button.

### Power Control

```swift
// Set transmit power (0-100 watts for IC-7600)
try await rig.setPower(50)  // 50 watts

// Read current power
let power = try await rig.power()
print("Power: \(power)W")
```

### PTT Control

```swift
// Transmit
try await rig.setPTT(true)
sleep(2)  // Transmit for 2 seconds
try await rig.setPTT(false)

// Check PTT status
let isTransmitting = try await rig.isPTTEnabled()
```

### Split Operation

```swift
// Set up split operation
try await rig.setFrequency(14_195_000, vfo: .main)  // RX on 14.195
try await rig.setFrequency(14_225_000, vfo: .sub)   // TX on 14.225
try await rig.setSplit(true)                         // Enable split

// Disable split
try await rig.setSplit(false)
```

## IC-7600 Specific Features

All of these features are available through convenient methods on `RigController`.

### Attenuator Control

```swift
// Set attenuator (0, 6, 12, or 18 dB)
try await rig.setAttenuator(6)   // 6dB
try await rig.setAttenuator(12)  // 12dB
try await rig.setAttenuator(0)   // OFF

// Read current setting
let att = try await rig.getAttenuator()
print("Attenuator: \(att) dB")
```

### Preamp Control

```swift
// Set preamp (0=OFF, 1=P.AMP1, 2=P.AMP2)
try await rig.setPreamp(1)   // Preamp 1
try await rig.setPreamp(2)   // Preamp 2
try await rig.setPreamp(0)   // OFF

// Read current setting
let preamp = try await rig.getPreamp()
```

### AGC Control

```swift
// Set AGC mode (1=FAST, 2=MID, 3=SLOW)
try await rig.setAGC(1)  // FAST
try await rig.setAGC(2)  // MID
try await rig.setAGC(3)  // SLOW

// Read current AGC
let agc = try await rig.getAGC()
```

### Noise Controls

```swift
// Noise Blanker
try await rig.setNoiseBlanker(true)   // ON
try await rig.setNoiseBlanker(false)  // OFF
let nbOn = try await rig.getNoiseBlanker()

// Noise Reduction
try await rig.setNoiseReduction(true)
let nrOn = try await rig.getNoiseReduction()

// Auto Notch
try await rig.setAutoNotch(true)
let anOn = try await rig.getAutoNotch()
```

### Level Controls

All level controls use 0-255 range:

```swift
// RF Gain
try await rig.setRFGain(255)   // Maximum
try await rig.setRFGain(128)   // Mid-level
try await rig.setRFGain(0)     // Minimum
let rfGain = try await rig.getRFGain()

// Microphone Gain
try await rig.setMicGain(128)
let micGain = try await rig.getMicGain()

// Squelch
try await rig.setSquelch(64)
let sql = try await rig.getSquelch()
```

### Function Controls

```swift
// Speech Compressor
try await rig.setSpeechCompressor(true)
let compOn = try await rig.getSpeechCompressor()

// VOX (Voice Operated Transmit)
try await rig.setVOX(true)
let voxOn = try await rig.getVOX()

// Monitor
try await rig.setMonitor(true)
let monOn = try await rig.getMonitor()
```

### Dual Receiver Features

The IC-7600 has dual receivers. These methods control both:

```swift
// Select active band
try await rig.selectVFO(.main)  // Main receiver
try await rig.selectVFO(.sub)   // Sub receiver

// Exchange Main/Sub frequencies
try await rig.exchangeBands()  // Swap Main and Sub

// Equalize bands (copy Main to Sub)
try await rig.equalizeBands()

// Dual Watch (monitor both bands)
try await rig.setDualWatch(true)   // ON
try await rig.setDualWatch(false)  // OFF
```

### Memory Operations

```swift
// Select memory channel (0-99)
try await rig.selectMemory(1)

// Transfer memory to VFO
try await rig.memoryToVFO()
```

### Scan Operations

```swift
// Start programmed scan
try await rig.startProgrammedScan()

// Start memory scan
try await rig.startMemoryScan()

// Stop any scan
try await rig.stopScan()
```

## Advanced Features

### Direct Protocol Access

For commands not yet wrapped in convenience methods, access the protocol directly:

```swift
// Cast to IcomCIVProtocol for advanced commands
if let icomProto = await rig.protocol as? IcomCIVProtocol {
    // Access any of the ~150 IC-7600 commands
    try await icomProto.setNRLevel(128)
    try await icomProto.setInnerPBT(150)
    try await icomProto.setCWPitch(600)

    // Read meters
    let rfPower = try await icomProto.getRFPowerMeter()
    let swr = try await icomProto.getSWRMeter()
    let alc = try await icomProto.getALCMeter()
}
```

### Batch Configuration

Configure multiple parameters at once:

```swift
// Quick band change for FT8
try await rig.configure(
    frequency: 14_074_000,
    mode: .usb,
    power: 50
)

// Just frequency change
try await rig.configure(frequency: 7_074_000)

// Just mode change
try await rig.configure(mode: .cw)
```

### Caching

Control when to use cached vs fresh values:

```swift
// Fast - uses cache (default)
let freq1 = try await rig.frequency(vfo: .main, cached: true)

// Slow - forces fresh read from radio
let freq2 = try await rig.frequency(vfo: .main, cached: false)

// Manually invalidate cache after manual radio changes
await rig.invalidateCache()
```

### Signal Strength

```swift
let signal = try await rig.signalStrength()
print(signal.description)  // "S7" or "S9+20"

if signal.isStrongSignal {
    print("Strong signal!")
}
```

## Complete Example

```swift
import Foundation
import RigControl

@main
struct IC7600Example {
    static func main() async {
        do {
            // 1. Connect
            let rig = RigController(
                radio: .icomIC7600,
                connection: .serial(path: "/dev/cu.usbserial-2120", baudRate: 19200)
            )

            try await rig.connect()
            print("✅ Connected to \(rig.radioName)")

            // 2. Configure for 20m SSB
            print("\n📻 Configuring for 20m SSB...")
            try await rig.configure(
                frequency: 14_230_000,  // 14.230 MHz
                mode: .usb,
                power: 50
            )

            // 3. Optimize reception
            print("\n🎛️ Optimizing reception...")
            try await rig.setAttenuator(0)        // No attenuation
            try await rig.setPreamp(1)            // Preamp 1
            try await rig.setAGC(2)               // AGC MID
            try await rig.setNoiseBlanker(true)   // NB ON
            try await rig.setAutoNotch(true)      // Auto notch ON
            try await rig.setRFGain(255)          // Full RF gain

            // 4. Set up dual watch
            print("\n👁️ Setting up dual watch...")
            try await rig.setFrequency(7_100_000, vfo: .sub)  // 40m on Sub
            try await rig.setMode(.lsb, vfo: .sub)
            try await rig.setDualWatch(true)

            // 5. Read signal strength
            print("\n📊 Checking signal...")
            let signal = try await rig.signalStrength(cached: false)
            print("Signal strength: \(signal.description)")

            // 6. Set up split for DX
            print("\n🌍 Setting up split for DX...")
            try await rig.setFrequency(14_195_000, vfo: .main)  // RX
            try await rig.setFrequency(14_225_000, vfo: .sub)   // TX
            try await rig.setSplit(true)
            print("Split mode: RX=14.195 TX=14.225")

            // 7. Access advanced features via protocol
            print("\n⚙️ Adjusting advanced settings...")
            if let icomProto = await rig.protocol as? IcomCIVProtocol {
                try await icomProto.setNRLevel(100)     // NR level
                try await icomProto.setMicGain(128)     // Mic gain
                try await icomProto.setCompLevel(50)    // Compressor
                print("Advanced settings applied")
            }

            // 8. Cleanup
            print("\n🔌 Disconnecting...")
            await rig.disconnect()
            print("✅ Done!")

        } catch {
            print("❌ Error: \(error)")
        }
    }
}
```

## API Reference

### RigController (Basic CAT)

| Method | Description |
|--------|-------------|
| `connect()` | Connect to radio |
| `disconnect()` | Disconnect from radio |
| `setFrequency(_:vfo:)` | Set frequency (Hz) |
| `frequency(vfo:cached:)` | Get frequency (Hz) |
| `setMode(_:vfo:)` | Set operating mode |
| `mode(vfo:cached:)` | Get operating mode |
| `setPTT(_:)` | Enable/disable PTT |
| `isPTTEnabled()` | Get PTT status |
| `selectVFO(_:)` | Select Main/Sub |
| `setPower(_:)` | Set power (watts) |
| `power()` | Get power (watts) |
| `setSplit(_:)` | Enable/disable split |
| `isSplitEnabled()` | Get split status |
| `signalStrength(cached:)` | Read S-meter |
| `configure(frequency:mode:vfo:power:)` | Batch configure |

### RigController (IC-7600 Extensions)

#### Attenuator & Preamp
| Method | Description |
|--------|-------------|
| `setAttenuator(_:)` | Set attenuator (0, 6, 12, 18 dB) |
| `getAttenuator()` | Get attenuator setting |
| `setPreamp(_:)` | Set preamp (0, 1, 2) |
| `getPreamp()` | Get preamp setting |

#### AGC Control
| Method | Description |
|--------|-------------|
| `setAGC(_:)` | Set AGC (1=FAST, 2=MID, 3=SLOW) |
| `getAGC()` | Get AGC setting |

#### Noise Controls
| Method | Description |
|--------|-------------|
| `setNoiseBlanker(_:)` | Enable/disable NB |
| `getNoiseBlanker()` | Get NB status |
| `setNoiseReduction(_:)` | Enable/disable NR |
| `getNoiseReduction()` | Get NR status |
| `setAutoNotch(_:)` | Enable/disable auto notch |
| `getAutoNotch()` | Get auto notch status |

#### Level Controls (0-255)
| Method | Description |
|--------|-------------|
| `setRFGain(_:)` | Set RF gain level |
| `getRFGain()` | Get RF gain level |
| `setMicGain(_:)` | Set mic gain level |
| `getMicGain()` | Get mic gain level |
| `setSquelch(_:)` | Set squelch level |
| `getSquelch()` | Get squelch level |

#### Function Controls
| Method | Description |
|--------|-------------|
| `setSpeechCompressor(_:)` | Enable/disable compressor |
| `getSpeechCompressor()` | Get compressor status |
| `setVOX(_:)` | Enable/disable VOX |
| `getVOX()` | Get VOX status |
| `setMonitor(_:)` | Enable/disable monitor |
| `getMonitor()` | Get monitor status |

#### Dual Receiver
| Method | Description |
|--------|-------------|
| `setDualWatch(_:)` | Enable/disable dual watch |
| `exchangeBands()` | Swap Main/Sub |
| `equalizeBands()` | Copy Main to Sub |

#### Memory & Scan
| Method | Description |
|--------|-------------|
| `selectMemory(_:)` | Select memory (0-99) |
| `memoryToVFO()` | Transfer memory to VFO |
| `startProgrammedScan()` | Start programmed scan |
| `startMemoryScan()` | Start memory scan |
| `stopScan()` | Stop any scan |

### IcomCIVProtocol (Direct Access)

For the complete list of ~150 IC-7600 commands available via direct protocol access, see `IC7600Protocol.swift`.

Common commands accessed via protocol:
- `setDataModeIC7600(dataMode:filter:)` - Set DATA mode (0x00-0x03) and filter (0x00-0x03)
- `getDataModeIC7600()` - Get current DATA mode and filter settings
- `setNRLevel(_:)` - Noise reduction level (0-255)
- `setInnerPBT(_:)`, `setOuterPBT(_:)` - Passband tuning
- `setCWPitch(_:)` - CW pitch (300-900 Hz)
- `setCompLevel(_:)` - Speech compressor level
- `setDriveGain(_:)` - Drive gain
- `setMonitorGain(_:)` - Monitor level
- `setVoxGain(_:)` - VOX sensitivity
- `getRFPowerMeter()` - Forward power (TX)
- `getSWRMeter()` - SWR reading (TX)
- `getALCMeter()` - ALC level (TX)
- `getCOMPMeter()` - Compression (TX)
- `getVDMeter()` - Supply voltage
- `getIDMeter()` - Supply current

## Error Handling

```swift
do {
    try await rig.setFrequency(14_230_000, vfo: .main)
} catch RigError.notConnected {
    print("Not connected to radio")
} catch RigError.commandFailed(let msg) {
    print("Command failed: \(msg)")
} catch RigError.timeout {
    print("Radio didn't respond")
} catch RigError.invalidParameter(let msg) {
    print("Invalid parameter: \(msg)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Known Limitations

### Mode-Specific Features

Some IC-7600 features only work in specific operating modes:

**CW Mode Features:**
- **Audio Peak Filter**: Only functions in CW mode
- **Break-in**: CW-only feature (Semi/Full)

**Digital Mode Features:**
- **Twin Peak Filter**: Only functions in RTTY or PSK modes

**FM Mode Features:**
- **Squelch Condition**: Only available in FM mode

When using these features via CI-V, ensure the radio is in the correct mode first:

```swift
// For Twin Peak Filter
try await rig.setMode(.rtty, vfo: .main)
try await icomProtocol.setTwinPeakFilterIC7600(true)

// For Audio Peak Filter
try await rig.setMode(.cw, vfo: .main)
try await icomProtocol.setAudioPeakFilterIC7600(true)

// For Squelch Condition
try await rig.setMode(.fm, vfo: .main)
let squelchOpen = try await icomProtocol.getSquelchConditionIC7600()
```

### XIT (Delta TX) - Shared Offset Architecture

The IC-7600 uses a **shared offset architecture** for RIT and ΔTX - there is no separate XIT control via CI-V:

**How it works:**
- **Single Offset**: Commands 0x21 0x00 (set offset) and 0x21 0x01 (enable/disable) control **both** RIT and ΔTX
- **Front Panel Switch**: The RIT/ΔTX button on the radio determines whether the offset applies to RX or TX
- **No CI-V Control**: Command 0x21 0x02/0x03 (separate XIT control) returns NAK - not supported
- **Shared Clear**: Command 1A 05 0085 "Quick RIT/ΔTX clear" clears the shared offset

**What this means for CI-V control:**

```swift
// ✅ Set RIT offset (also affects ΔTX if enabled on front panel):
try await rig.setRIT(RITXITState(enabled: true, offset: 500))
// This sets the offset to +500 Hz
// - If front panel is in RIT mode: RX offset = +500 Hz
// - If front panel is in ΔTX mode: TX offset = +500 Hz

// ❌ Separate XIT control NOT supported:
try await rig.setXIT(RITXITState(enabled: true, offset: -300))
// This will fail - IC-7600 doesn't support independent XIT commands
```

**Workaround**: Use split operation for independent TX offset:

```swift
// Set different TX/RX frequencies using split mode
try await rig.selectVFO(.main)
try await rig.setFrequency(14_200_000, vfo: .main)  // RX frequency
try await rig.selectVFO(.sub)
try await rig.setFrequency(14_200_300, vfo: .sub)   // TX frequency (+300 Hz)
try await rig.setSplit(true)
```

## Tips & Best Practices

1. **Always check connection** before sending commands
2. **Use caching** for frequent reads (default behavior)
3. **Invalidate cache** after manual radio adjustments
4. **Use batch configure** for multiple parameter changes
5. **Handle errors** gracefully - radio may be off/disconnected
6. **Use .main and .sub VFOs** (not .a and .b) for IC-7600
7. **Wait after frequency changes** before reading back
8. **For TX operations**, ensure dummy load is connected
9. **For transmit offset**, use split mode (XIT not supported via CI-V)

## See Also

- [API Reference](API_REFERENCE.md) - Complete API documentation
- [IC7600Protocol.swift](../Sources/RigControl/Protocols/Icom/IC7600Protocol.swift) - Full command implementation
- [IC7600ComprehensiveTest](../Sources/IC7600ComprehensiveTest/) - Interactive test suite
