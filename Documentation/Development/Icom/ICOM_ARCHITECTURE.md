# Icom Radio Architecture Guide

## Overview

SwiftRigControl's Icom implementation uses a modern, scalable architecture that supports:
- **Custom CI-V addresses** for user-configured radios
- **Multiple radios of the same model** with different CI-V addresses
- **20+ Icom radio models** without method name conflicts
- **Radio-specific commands** with compile-time and runtime safety
- **Common command sharing** to eliminate code duplication

## Architecture Principles

### 1. Radio Model vs. CI-V Address Separation

**CI-V Address**: User-configurable bus routing address
- Defaults to manufacturer specification (e.g., IC-7600 = 0x7A)
- Users can change this on their radio
- Used only for physical bus communication

**Radio Model**: Immutable model identifier
- Determines which commands are available
- Determines command formatting quirks
- Never changes regardless of CI-V address

```swift
// Example: Two IC-7600s with different CI-V addresses
let rig1 = RigController(
    radio: .icomIC7600(),              // Default 0x7A
    connection: .serial(path: "/dev/ttyUSB0", baudRate: 19200)
)

let rig2 = RigController(
    radio: .icomIC7600(civAddress: 0x7B),  // Custom 0x7B
    connection: .serial(path: "/dev/ttyUSB1", baudRate: 19200)
)
```

### 2. Protocol Extension Architecture

All Icom radios share the core `IcomCIVProtocol` actor with radio-specific extensions:

```
IcomCIVProtocol (Core)
├── IcomCIVProtocol+CommonCommands.swift (58 common commands)
├── IcomCIVProtocol+IC7100.swift (IC-7100 specific)
├── IcomCIVProtocol+IC7600.swift (IC-7600 specific)
├── IcomCIVProtocol+IC9700.swift (IC-9700 specific)
└── ... (20+ more radio extensions)
```

### 3. Method Naming Convention

**Radio-Specific Methods**: Suffixed with radio model name
```swift
// IC-7100 methods
await protocol.setAttenuatorIC7100(12)
await protocol.powerOnIC7100()
await protocol.getAGCIC7100()

// IC-7600 methods
await protocol.setAttenuatorIC7600(18)
await protocol.exchangeBandsIC7600()
await protocol.getPreampIC7600()

// IC-9700 methods
await protocol.setSatelliteModeIC9700(true)  // Unique to IC-9700
await protocol.setAttenuatorIC9700(10)
```

**Common Methods**: No suffix (available on all Icom radios)
```swift
// Available on IC-7100, IC-7600, IC-9700, and all other Icom radios
await protocol.writeToMemory()
await protocol.memoryToVFO()
await protocol.setTuningStep(0x01)
await protocol.setNoiseBlanker(true)
await protocol.getSMeterLevel()
```

### 4. Runtime Safety with Guard Clauses

Every radio-specific method validates the radio model at runtime:

```swift
public func setAttenuatorIC7100(_ value: UInt8) async throws {
    guard radioModel == .ic7100 else {
        throw RigError.unsupportedOperation(
            "setAttenuatorIC7100 is only available on IC-7100"
        )
    }
    // Command implementation...
}
```

This prevents:
- Calling IC-7100 commands on an IC-7600
- Runtime crashes from incompatible commands
- Silent failures with incorrect radio behavior

## File Structure

### Core Files

**IcomCIVProtocol.swift**
- Core protocol actor implementation
- Contains `radioModel: IcomRadioModel` property
- Contains `civAddress: UInt8` property
- Base frequency, mode, PTT, VFO, power methods
- Common frame send/receive logic

**IcomRadioModel.swift**
- Enum of all supported Icom radio models (28 models)
- Default CI-V addresses per model
- Radio capability flags (D-STAR, satellite, dual receiver, etc.)

**IcomModels.swift**
- `RadioDefinition` factory functions for each radio
- All definitions are functions accepting optional `civAddress`
- Backward-compatible deprecated static properties

**IcomCIVProtocol+CommonCommands.swift**
- 58 commands identical across all Icom radios
- Memory operations (write, transfer, clear)
- Split/duplex operations
- Tuning step control
- Level controls (AF, RF, Squelch, NR, CW Pitch, RF Power, Mic, Key Speed)
- Meter readings (S-meter, RF Power, SWR, ALC, COMP, Vd, Id)
- Function settings (Noise Blanker, Noise Reduction, Auto Notch, etc.)

### Radio-Specific Extension Files

**IcomCIVProtocol+IC7100.swift** (IC-7100 Specific)
- Memory channels: 1-109 (extended for VHF/UHF)
- Memory banks: A-E
- Attenuator: 0dB or 12dB only
- Preamp: OFF, P.AMP1, P.AMP2, ON
- D-STAR digital voice (DV mode)
- DTCS and VSC squelch systems
- Built-in GPS support
- 100+ specific commands

**IcomCIVProtocol+IC7600.swift** (IC-7600 Specific)
- Memory channels: 0-99
- Attenuator: 0dB, 6dB, 12dB, or 18dB
- Preamp: OFF, P.AMP1, P.AMP2
- Dual receiver with band independent operation
- Advanced filter controls
- Twin PBT controls
- Main/Sub band exchange and equalization
- Dualwatch capability
- 60+ specific commands

**IcomCIVProtocol+IC9700.swift** (IC-9700 Specific)
- VHF/UHF/1.2GHz coverage (144/430/1200 MHz)
- Memory channels: 1-109 per band
- Attenuator: 0dB or 10dB
- Preamp: OFF or ON
- AGC: FAST, MID, SLOW, OFF
- **Satellite mode** (unique feature)
- D-STAR digital voice (DV mode)
- Dual watch capability
- Spectrum scope
- 50+ specific commands

## Command Categories

### Common Commands (All Icom Radios)
Located in `IcomCIVProtocol+CommonCommands.swift`:

**Memory Operations**
- `writeToMemory()` - Write current VFO to memory
- `memoryToVFO()` - Transfer memory to VFO
- `clearMemory()` - Clear memory channel

**Split/Duplex Operations**
- `setSimplexOperation()` - Set simplex mode
- `setDupMinusOperation()` - Set DUP- mode
- `setDupPlusOperation()` - Set DUP+ mode

**Tuning Control**
- `setTuningStep(_ step: UInt8)` - Set tuning step size

**Level Controls (0-255)**
- `setAFLevel(_ level: UInt8)` - Audio frequency level
- `setRFGain(_ level: UInt8)` - RF gain
- `setSquelch(_ level: UInt8)` - Squelch level
- `setNRLevel(_ level: UInt8)` - Noise reduction level
- `setCWPitch(_ pitch: UInt8)` - CW pitch
- `setRFPowerLevel(_ level: UInt8)` - RF power output
- `setMicGain(_ gain: UInt8)` - Microphone gain
- `setKeySpeed(_ speed: UInt8)` - CW key speed

**Meter Readings**
- `getSMeterLevel() -> UInt8` - S-meter reading
- `getRFPowerMeter() -> UInt8` - RF power meter
- `getSWRMeter() -> UInt8` - SWR meter
- `getALCMeter() -> UInt8` - ALC meter
- `getCOMPMeter() -> UInt8` - Compression meter
- `getVDMeter() -> UInt8` - Voltage meter
- `getIDMeter() -> UInt8` - Current meter

**Function Settings**
- `setNoiseBlanker(_ enabled: Bool)` - Noise blanker ON/OFF
- `setNoiseReduction(_ enabled: Bool)` - Noise reduction ON/OFF
- `setAutoNotch(_ enabled: Bool)` - Auto notch ON/OFF
- `setRepeaterTone(_ enabled: Bool)` - Repeater tone ON/OFF
- `setToneSquelch(_ enabled: Bool)` - Tone squelch ON/OFF
- `setSpeechCompressor(_ enabled: Bool)` - Speech compressor ON/OFF
- `setVOX(_ enabled: Bool)` - VOX ON/OFF

**Transceiver ID**
- `readTransceiverID() -> UInt8` - Read transceiver model ID

### Radio-Specific Command Examples

#### IC-7100 Unique Features
```swift
// Memory operations
await protocol.selectMemoryChannelIC7100(109)  // Channels 1-109
await protocol.selectMemoryBankIC7100(3)       // Bank C

// Scan operations
await protocol.startDeltaFScanIC7100()
await protocol.startFineProgrammedScanIC7100()
await protocol.startSelectMemoryScanIC7100()

// Twin PBT controls
await protocol.setInnerPBTIC7100(128)  // Center
await protocol.setOuterPBTIC7100(128)

// D-STAR specific
await protocol.setDigitalSquelchIC7100(0x01)  // DSQL ON
await protocol.setDTCSIC7100(true)
await protocol.setVSCIC7100(true)  // Voice Squelch Control

// Power control
await protocol.powerOnIC7100()  // With baud rate specific preambles
await protocol.powerOffIC7100()

// RIT control
await protocol.setRITFrequencyIC7100(2500)  // ±9.999 kHz
await protocol.setRITIC7100(true)
```

#### IC-7600 Unique Features
```swift
// Attenuator (4 levels)
await protocol.setAttenuatorIC7600(18)  // 0, 6, 12, or 18 dB

// Preamp (3 levels)
await protocol.setPreampIC7600(2)  // 0=OFF, 1=P.AMP1, 2=P.AMP2

// Dual receiver operations
await protocol.exchangeBandsIC7600()  // Swap Main/Sub
await protocol.equalizeBandsIC7600()  // Copy Main to Sub
await protocol.setDualwatchIC7600(true)

// Advanced filter controls
await protocol.setFilterWidthIC7600(25)  // 0-49 filter index
await protocol.setAGCTimeConstantIC7600(8)  // 0-13

// Twin PBT
await protocol.setInnerPBTIC7600(128)
await protocol.setOuterPBTIC7600(128)

// Balance control (Main/Sub audio balance)
await protocol.setBalanceIC7600(128)

// Band edge frequencies
let (lower, upper) = try await protocol.getBandEdgeIC7600()
```

#### IC-9700 Unique Features
```swift
// Satellite mode (UNIQUE to IC-9700)
await protocol.setSatelliteModeIC9700(true)  // Enable satellite mode
let satMode = try await protocol.getSatelliteModeIC9700()

// Dual watch (VHF/UHF specific)
await protocol.setDualwatchIC9700(true)

// D-STAR digital voice
await protocol.setDigitalSquelchIC9700(0x02)  // CSQL ON

// VFO operations for satellite tracking
await protocol.exchangeBandsIC9700()  // Swap Main/Sub for doppler
await protocol.equalizeBandsIC9700()

// Selected/unselected VFO queries
let mainFreq = try await protocol.readVFOFrequencyIC9700(0x00)  // Selected
let subFreq = try await protocol.readVFOFrequencyIC9700(0x01)   // Unselected

let (mode, dataMode, filter) = try await protocol.readVFOModeIC9700(0x00)

// Power control (higher baud rate = more preambles)
await protocol.powerOnIC9700()  // 150 preambles for 115200 baud
await protocol.powerOffIC9700()
```

## Radio Characteristics Comparison

| Feature | IC-7100 | IC-7600 | IC-9700 |
|---------|---------|---------|---------|
| Default CI-V Address | 0x88 | 0x7A | 0xA2 |
| Default Baud Rate | 19200 | 19200 | 115200 |
| Command Echo | YES | NO | YES |
| Mode Filter Byte | NO | YES | NO |
| VFO Model | currentOnly | targetable | mainSub |
| Bands | HF/VHF/UHF | HF/6m | VHF/UHF/1.2GHz |
| Memory Channels | 1-109 | 0-99 | 1-109 per band |
| Attenuator Options | 0, 12 dB | 0, 6, 12, 18 dB | 0, 10 dB |
| Preamp Options | OFF, P.AMP1, P.AMP2, ON | OFF, P.AMP1, P.AMP2 | OFF, ON |
| AGC Options | FAST, MID, SLOW | FAST, MID, SLOW | OFF, FAST, MID, SLOW |
| D-STAR | YES | NO | YES |
| Satellite Mode | NO | NO | YES |
| Dual Receiver | NO | YES | YES |
| Spectrum Scope | NO | NO | YES |

## Adding New Radio Models

To add a new Icom radio model, follow these steps:

### Step 1: Add to IcomRadioModel enum
```swift
// In IcomRadioModel.swift
public enum IcomRadioModel: String, Sendable, CaseIterable {
    // ... existing models
    case ic7851 = "IC-7851"  // Add new model

    public var defaultCIVAddress: UInt8 {
        switch self {
        // ... existing addresses
        case .ic7851: return 0x8E  // Add default address
        }
    }
}
```

### Step 2: Create capabilities definition
```swift
// In RadioCapabilitiesDatabase.swift
static let icomIC7851 = RigCapabilities(
    manufacturer: .icom,
    model: "IC-7851",
    supportedModes: [.lsb, .usb, .am, .cw, .cwR, .rtty, .rttyR, .fm],
    // ... other capabilities
)
```

### Step 3: Create radio definition function
```swift
// In IcomModels.swift
public static func icomIC7851(civAddress: UInt8? = nil) -> RadioDefinition {
    RadioDefinition(
        manufacturer: .icom,
        model: "IC-7851",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.icomIC7851,
        civAddress: civAddress ?? IcomRadioModel.ic7851.defaultCIVAddress,
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                civAddress: civAddress,
                radioModel: .ic7851,
                commandSet: StandardIcomCommandSet.ic7851,
                capabilities: RadioCapabilitiesDatabase.icomIC7851
            )
        }
    )
}
```

### Step 4: Create protocol extension
```swift
// Create: IcomCIVProtocol+IC7851.swift
import Foundation

/// IC-7851 specific CI-V protocol implementation
extension IcomCIVProtocol {

    // Radio-specific commands with IC7851 suffix
    public func setAttenuatorIC7851(_ value: UInt8) async throws {
        guard radioModel == .ic7851 else {
            throw RigError.unsupportedOperation(
                "setAttenuatorIC7851 is only available on IC-7851"
            )
        }
        // Implementation...
    }

    // More commands...
}
```

### Step 5: Build and test
```bash
swift build
swift test
```

## Best Practices

### 1. Always Use Radio Model for Command Selection
❌ **Bad**: Using CI-V address for logic
```swift
if civAddress == 0x88 {  // WRONG - users can change this!
    // IC-7100 logic
}
```

✅ **Good**: Using radio model for logic
```swift
guard radioModel == .ic7100 else {  // CORRECT
    throw RigError.unsupportedOperation(...)
}
```

### 2. Provide Clear Error Messages
```swift
guard radioModel == .ic7100 else {
    throw RigError.unsupportedOperation(
        "setDTCSIC7100 is only available on IC-7100"
    )
}
```

### 3. Document Radio-Specific Quirks
```swift
/// Turn ON the transceiver (IC-7100)
/// Command: Multiple 0xFE preambles + 0x18 0x01
/// Note: Requires extra preamble codes based on baud rate
/// - 19200bps = 25 preambles
/// - 9600bps = 13 preambles
/// - 4800bps = 7 preambles
public func powerOnIC7100() async throws {
    // Implementation with radio-specific quirk handling
}
```

### 4. Use Helper Methods for Radio-Specific Formatting
```swift
// IC-7100 specific helper (private, suffixed)
private func frequencyToBCDIC7100(_ hz: UInt64) -> [UInt8] {
    // IC-7100 specific BCD encoding
}

// IC-7600 specific helper (private, suffixed)
private func setLevelIC7600(_ subCommand: UInt8, value: Int) async throws {
    // IC-7600 specific level control logic
}
```

## Migration Guide

### From Old Architecture (Single Protocol File)

**Before** (All commands in one file, conflicts):
```swift
// IC7600Protocol.swift
extension IcomCIVProtocol {
    func setAttenuator(_ value: UInt8) { }  // Conflict!
    func setPreamp(_ value: UInt8) { }      // Conflict!
}

// IC7100Protocol.swift
extension IcomCIVProtocol {
    func setAttenuator(_ value: UInt8) { }  // Conflict!
    func setPreamp(_ value: UInt8) { }      // Conflict!
}
```

**After** (Radio-specific suffixes, no conflicts):
```swift
// IcomCIVProtocol+IC7600.swift
extension IcomCIVProtocol {
    func setAttenuatorIC7600(_ value: UInt8) { }  // Unique!
    func setPreampIC7600(_ value: UInt8) { }      // Unique!
}

// IcomCIVProtocol+IC7100.swift
extension IcomCIVProtocol {
    func setAttenuatorIC7100(_ value: UInt8) { }  // Unique!
    func setPreampIC7100(_ value: UInt8) { }      // Unique!
}
```

### From Static Radio Definitions to Functions

**Before** (Fixed CI-V address):
```swift
public static let icomIC7600 = RadioDefinition(
    // ...
    civAddress: 0x7A  // Fixed!
)
```

**After** (Configurable CI-V address):
```swift
public static func icomIC7600(civAddress: UInt8? = nil) -> RadioDefinition {
    RadioDefinition(
        // ...
        civAddress: civAddress ?? 0x7A  // Configurable!
    )
}
```

**Backward Compatibility Maintained**:
```swift
// Still works (uses default address)
let rig = RigController(radio: .icomIC7600(), connection: ...)

// New capability (custom address)
let rig = RigController(radio: .icomIC7600(civAddress: 0x7B), connection: ...)
```

## Testing

### Unit Testing Radio-Specific Commands
```swift
func testIC7100AttenuatorWithWrongRadio() async throws {
    let transport = MockSerialTransport()
    let protocol = IcomCIVProtocol(
        transport: transport,
        civAddress: 0x7A,
        radioModel: .ic7600,  // IC-7600, not IC-7100
        commandSet: StandardIcomCommandSet.ic7600,
        capabilities: RadioCapabilitiesDatabase.icomIC7600
    )

    // Should throw because this is IC-7600, not IC-7100
    await XCTAssertThrowsError(
        try await protocol.setAttenuatorIC7100(12)
    ) { error in
        XCTAssertEqual(error as? RigError, .unsupportedOperation(...))
    }
}
```

### Integration Testing Multiple Radios
```swift
func testMultipleRadiosSameModel() async throws {
    // Two IC-7600s with different addresses
    let rig1 = RigController(
        radio: .icomIC7600(civAddress: 0x7A),
        connection: .serial(path: "/dev/ttyUSB0", baudRate: 19200)
    )

    let rig2 = RigController(
        radio: .icomIC7600(civAddress: 0x7B),
        connection: .serial(path: "/dev/ttyUSB1", baudRate: 19200)
    )

    // Both can use IC-7600 specific commands
    try await rig1.setAttenuatorIC7600(18)
    try await rig2.setAttenuatorIC7600(12)
}
```

## Future Roadmap

### Planned Radio Additions
- IC-7851 (HF flagship)
- IC-7850 (HF flagship predecessor)
- IC-7800 (HF flagship)
- IC-756 Pro series
- IC-910H (VHF/UHF satellite)
- IC-2730 (VHF/UHF mobile)
- IC-R8600 (wideband receiver)
- And 10+ more...

### Architecture Enhancements
- Command set versioning for firmware updates
- Automatic command discovery/capability detection
- CI-V transceive mode support
- Multi-radio bus arbitration
- Radio-specific logging and debugging
- Performance profiling per radio model

## Support and Resources

- **CI-V Manuals**: `~/Developer/XCode/SwiftRigControl/Icom CI-V Manuals/`
- **Hamlib Reference**: https://github.com/Hamlib/Hamlib
- **Icom CI-V Specification**: Contact Icom for official documentation
- **Package Documentation**: Generated via `swift package generate-documentation`

## Contributors

This architecture was designed to scale to 20+ Icom radio models while maintaining:
- Code clarity and maintainability
- Compile-time type safety
- Runtime error detection
- Zero method name conflicts
- Backward compatibility
- User configurability

Last Updated: December 2025
