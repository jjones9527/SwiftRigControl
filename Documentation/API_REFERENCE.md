# SwiftRigControl API Reference

Complete API documentation for SwiftRigControl library.

## Table of Contents

1. [Core Classes](#core-classes)
2. [Radio Definitions](#radio-definitions)
3. [Models and Types](#models-and-types)
4. [Error Handling](#error-handling)
5. [Protocols](#protocols)
6. [XPC Integration](#xpc-integration)
7. [Utilities](#utilities)

---

## Core Classes

### RigController

The main controller for amateur radio transceiver operations. All radio control happens through this actor.

```swift
public actor RigController
```

#### Initialization

```swift
public init(radio: RadioDefinition, connection: ConnectionType)
```

**Parameters:**
- `radio`: The radio definition (e.g., `.icomIC9700`, `.yaesuFTDX10`, `.kenwoodTS890S`)
- `connection`: How to connect to the radio

**Example:**
```swift
let rig = RigController(
    radio: .icomIC9700,
    connection: .serial(path: "/dev/cu.IC9700", baudRate: 115200)
)
```

#### Connection Management

##### connect()

```swift
public func connect() async throws
```

Establishes connection to the radio.

**Throws:** `RigError` if connection fails

**Example:**
```swift
try await rig.connect()
```

##### disconnect()

```swift
public func disconnect() async
```

Closes connection to the radio.

**Example:**
```swift
await rig.disconnect()
```

##### isConnected

```swift
public var isConnected: Bool { get }
```

Returns connection status.

#### Frequency Control

##### setFrequency(_:vfo:)

```swift
public func setFrequency(_ hz: UInt64, vfo: VFO = .a) async throws
```

Sets the operating frequency.

**Parameters:**
- `hz`: Frequency in Hertz (e.g., `14_230_000` for 14.230 MHz)
- `vfo`: The VFO to set (defaults to `.a`)

**Throws:**
- `RigError.notConnected` - Not connected to radio
- `RigError.commandFailed` - Radio rejected frequency
- `RigError.timeout` - No response from radio
- `RigError.frequencyOutOfRange` - Frequency outside radio's capability

**Example:**
```swift
try await rig.setFrequency(14_230_000, vfo: .a)  // 14.230 MHz
```

##### frequency(vfo:cached:)

```swift
public func frequency(vfo: VFO = .a, cached: Bool = true) async throws -> UInt64
```

Reads the current frequency.

**Parameters:**
- `vfo`: The VFO to read (defaults to `.a`)
- `cached`: Use cached value if available (defaults to `true`)

**Returns:** Frequency in Hertz

**Throws:** `RigError` if operation fails

**Example:**
```swift
let freq = try await rig.frequency(vfo: .a)
print("Current frequency: \(Double(freq) / 1_000_000) MHz")

// Force fresh query
let freshFreq = try await rig.frequency(cached: false)
```

#### Mode Control

##### setMode(_:vfo:)

```swift
public func setMode(_ mode: Mode, vfo: VFO = .a) async throws
```

Sets the operating mode.

**Parameters:**
- `mode`: Operating mode (e.g., `.usb`, `.lsb`, `.cw`, `.fm`)
- `vfo`: The VFO to set (defaults to `.a`)

**Throws:** `RigError` if operation fails

**Example:**
```swift
try await rig.setMode(.usb, vfo: .a)
```

##### mode(vfo:cached:)

```swift
public func mode(vfo: VFO = .a, cached: Bool = true) async throws -> Mode
```

Reads the current mode.

**Parameters:**
- `vfo`: The VFO to read (defaults to `.a`)
- `cached`: Use cached value if available (defaults to `true`)

**Returns:** Current operating mode

**Example:**
```swift
let mode = try await rig.mode()
print("Current mode: \(mode)")
```

#### PTT Control

##### setPTT(_:)

```swift
public func setPTT(_ enabled: Bool) async throws
```

Controls the Push-To-Talk state.

**Parameters:**
- `enabled`: `true` to transmit, `false` to receive

**Throws:** `RigError` if operation fails

**Example:**
```swift
try await rig.setPTT(true)   // Start transmitting
try await rig.setPTT(false)  // Return to receive
```

##### isPTTEnabled()

```swift
public func isPTTEnabled() async throws -> Bool
```

Reads the current PTT state.

**Returns:** `true` if transmitting, `false` if receiving

**Example:**
```swift
let transmitting = try await rig.isPTTEnabled()
if transmitting {
    print("Radio is transmitting")
}
```

#### Power Control

##### setPower(_:)

```swift
public func setPower(_ watts: Int) async throws
```

Sets the RF power level.

**Parameters:**
- `watts`: Power level in watts

**Throws:**
- `RigError.unsupportedOperation` - If radio doesn't support power control
- `RigError` if operation fails

**Example:**
```swift
if rig.capabilities.powerControl {
    try await rig.setPower(50)  // 50 watts
}
```

##### power(cached:)

```swift
public func power(cached: Bool = true) async throws -> Int
```

Reads the current power level.

**Parameters:**
- `cached`: Use cached value if available (defaults to `true`)

**Returns:** Power level in watts

**Example:**
```swift
let power = try await rig.power()
print("Power: \(power)W")
```

#### VFO Control

##### selectVFO(_:)

```swift
public func selectVFO(_ vfo: VFO) async throws
```

Selects the active VFO.

**Parameters:**
- `vfo`: VFO to select (`.a`, `.b`, `.main`, `.sub`)

**Throws:** `RigError` if operation fails

**Example:**
```swift
try await rig.selectVFO(.b)
```

#### Split Operation

##### setSplit(_:)

```swift
public func setSplit(_ enabled: Bool) async throws
```

Enables or disables split operation.

**Parameters:**
- `enabled`: `true` to enable split, `false` to disable

**Throws:**
- `RigError.unsupportedOperation` - If radio doesn't support split
- `RigError` if operation fails

**Example:**
```swift
if rig.capabilities.hasSplit {
    try await rig.setFrequency(14_195_000, vfo: .a)  // RX frequency
    try await rig.setFrequency(14_225_000, vfo: .b)  // TX frequency
    try await rig.setSplit(true)
}
```

##### isSplitEnabled()

```swift
public func isSplitEnabled() async throws -> Bool
```

Reads the current split operation state.

**Returns:** `true` if split is enabled

#### Signal Strength (v1.1.0)

##### signalStrength()

```swift
public func signalStrength() async throws -> SignalStrength
```

Reads the current signal strength.

**Returns:** Signal strength measurement

**Example:**
```swift
let signal = try await rig.signalStrength()
print("Signal: \(signal.description)")  // "S7" or "S9+20"

if signal.isStrongSignal {
    print("S9 or better!")
}
```

#### RIT/XIT Control (v1.1.0)

RIT (Receiver Incremental Tuning) and XIT (Transmitter Incremental Tuning) allow fine-tuning of receive and transmit frequencies independently from the displayed VFO frequency.

##### setRIT(_:)

```swift
public func setRIT(_ state: RITXITState) async throws
```

Sets the RIT (Receiver Incremental Tuning) state.

**Parameters:**
- `state`: The desired RIT state including enabled status and offset

**Throws:**
- `RigError.notConnected` - Not connected to radio
- `RigError.unsupportedOperation` - Radio doesn't support RIT
- `RigError.invalidParameter` - Offset out of range (±9999 Hz)

**Example:**
```swift
// Enable RIT with +500 Hz offset
try await rig.setRIT(RITXITState(enabled: true, offset: 500))

// Disable RIT
try await rig.setRIT(.disabled)

// Adjust offset while keeping RIT enabled
try await rig.setRIT(RITXITState(enabled: true, offset: -200))
```

##### getRIT(cached:)

```swift
public func getRIT(cached: Bool = true) async throws -> RITXITState
```

Gets the current RIT state.

**Parameters:**
- `cached`: Use cached value if available (default: `true`)

**Returns:** Current RIT state including enabled status and offset

**Throws:**
- `RigError.notConnected` - Not connected to radio
- `RigError.unsupportedOperation` - Radio doesn't support RIT

**Example:**
```swift
let ritState = try await rig.getRIT()
print("RIT: \(ritState.description)")  // "ON (+500 Hz)" or "OFF"

if ritState.enabled {
    print("RIT offset: \(ritState.offset) Hz")
}
```

##### setXIT(_:)

```swift
public func setXIT(_ state: RITXITState) async throws
```

Sets the XIT (Transmitter Incremental Tuning) state.

**Note:** Not all radios support separate XIT control. Some radios (like IC-7100, many Yaesu models) only support RIT, which affects both RX and TX when transmitting.

**Parameters:**
- `state`: The desired XIT state including enabled status and offset

**Throws:**
- `RigError.notConnected` - Not connected to radio
- `RigError.unsupportedOperation` - Radio doesn't support XIT
- `RigError.invalidParameter` - Offset out of range (±9999 Hz)

**Example:**
```swift
// Enable XIT with -1000 Hz offset for split operation
try await rig.setXIT(RITXITState(enabled: true, offset: -1000))

// Disable XIT
try await rig.setXIT(.disabled)
```

##### getXIT(cached:)

```swift
public func getXIT(cached: Bool = true) async throws -> RITXITState
```

Gets the current XIT state.

**Parameters:**
- `cached`: Use cached value if available (default: `true`)

**Returns:** Current XIT state including enabled status and offset

**Throws:**
- `RigError.notConnected` - Not connected to radio
- `RigError.unsupportedOperation` - Radio doesn't support XIT

**Example:**
```swift
let xitState = try await rig.getXIT()
print("XIT: \(xitState.description)")  // "ON (-1000 Hz)" or "OFF"
```

#### Level Controls (v1.3.0)

##### setAFGain(_:)

```swift
public func setAFGain(_ level: Int) async throws
```

Sets the audio frequency (AF) gain (volume).

**Parameters:**
- `level`: AF gain level (0–255)

**Throws:** `RigError` if operation fails

**Example:**
```swift
try await rig.setAFGain(128)  // ~50% volume
```

##### afGain(cached:)

```swift
public func afGain(cached: Bool = true) async throws -> Int
```

Reads the current AF gain level.

**Returns:** AF gain level (0–255)

##### setRFGain(_:)

```swift
public func setRFGain(_ level: Int) async throws
```

Sets the RF gain (receiver sensitivity).

**Parameters:**
- `level`: RF gain level (0–255)

**Example:**
```swift
try await rig.setRFGain(200)  // High RF gain
```

##### rfGain(cached:)

```swift
public func rfGain(cached: Bool = true) async throws -> Int
```

Reads the current RF gain level.

**Returns:** RF gain level (0–255)

##### setSquelch(_:)

```swift
public func setSquelch(_ level: Int) async throws
```

Sets the squelch level.

**Parameters:**
- `level`: Squelch level (0–255)

**Example:**
```swift
try await rig.setSquelch(0)    // Open squelch
try await rig.setSquelch(100)  // Moderate squelch
```

##### squelch(cached:)

```swift
public func squelch(cached: Bool = true) async throws -> Int
```

Reads the current squelch level.

**Returns:** Squelch level (0–255)

##### setPreamp(_:)

```swift
public func setPreamp(_ level: Int) async throws
```

Sets the preamplifier state.

**Parameters:**
- `level`: Preamp level (0 = off, 1 = preamp 1, 2 = preamp 2)

**Throws:**
- `RigError.unsupportedOperation` - Radio doesn't support preamp control

**Example:**
```swift
try await rig.setPreamp(1)  // Enable preamp 1
try await rig.setPreamp(0)  // Disable preamp
```

##### preamp(cached:)

```swift
public func preamp(cached: Bool = true) async throws -> Int
```

Reads the current preamp state (0 = off, 1 = preamp 1, 2 = preamp 2).

##### setAttenuator(_:)

```swift
public func setAttenuator(_ level: Int) async throws
```

Sets the attenuator level.

**Parameters:**
- `level`: Attenuation level — protocol-specific. Elecraft K2: 0/10/20 dB; K3/K4: 0/6/12/18 dB; Yaesu/Kenwood: 0/6/12/18 dB.

**Throws:**
- `RigError.unsupportedOperation` - Radio doesn't support attenuator control

**Example:**
```swift
try await rig.setAttenuator(6)   // 6 dB attenuation
try await rig.setAttenuator(0)   // No attenuation
```

##### attenuator(cached:)

```swift
public func attenuator(cached: Bool = true) async throws -> Int
```

Reads the current attenuator level in dB.

##### setPowerState(_:)

```swift
public func setPowerState(_ on: Bool) async throws
```

Controls radio power state (soft power on/off via CAT).

**Parameters:**
- `on`: `true` to power on, `false` to power off

**Throws:**
- `RigError.unsupportedOperation` - Radio doesn't support remote power control

**Example:**
```swift
try await rig.setPowerState(true)   // Power on
try await rig.setPowerState(false)  // Power off (standby)
```

##### getPowerState()

```swift
public func getPowerState() async throws -> Bool
```

Reads the current power state.

**Returns:** `true` if radio is on, `false` if in standby

#### DSP Controls (v1.3.0)

##### setAGC(_:)

```swift
public func setAGC(_ speed: AGCSpeed) async throws
```

Sets the AGC (Automatic Gain Control) speed.

**Parameters:**
- `speed`: AGC speed (`.off`, `.fast`, `.medium`, `.slow`, `.auto`)

**Throws:**
- `RigError.unsupportedOperation` - Radio doesn't support AGC control

**Example:**
```swift
try await rig.setAGC(.fast)    // CW/digital modes
try await rig.setAGC(.slow)    // Weak signal SSB DX
try await rig.setAGC(.off)     // Manual RF gain only
```

##### agc(cached:)

```swift
public func agc(cached: Bool = true) async throws -> AGCSpeed
```

Reads the current AGC speed.

**Returns:** Current `AGCSpeed`

**Note:** Available speeds vary by radio. Elecraft K2: `.fast`/`.slow` only. Most Icom/Kenwood: `.off`/`.fast`/`.medium`/`.slow`. Select Yaesu models add `.auto`.

##### setNoiseBlanker(_:)

```swift
public func setNoiseBlanker(_ config: NoiseBlanker) async throws
```

Sets the noise blanker state and optional level.

**Parameters:**
- `config`: `NoiseBlanker` configuration

**Example:**
```swift
try await rig.setNoiseBlanker(.enabled(level: 5))  // Enable with level
try await rig.setNoiseBlanker(.enabled())           // Enable (simple on/off radios)
try await rig.setNoiseBlanker(.off)                 // Disable
```

##### noiseBlanker(cached:)

```swift
public func noiseBlanker(cached: Bool = true) async throws -> NoiseBlanker
```

Reads the noise blanker state.

**Returns:** Current `NoiseBlanker` configuration

##### setNoiseReduction(_:)

```swift
public func setNoiseReduction(_ config: NoiseReduction) async throws
```

Sets the DSP noise reduction state and level.

**Parameters:**
- `config`: `NoiseReduction` configuration

**Example:**
```swift
try await rig.setNoiseReduction(.enabled(level: 8))   // Enable with level
try await rig.setNoiseReduction(.enabled(level: 15))  // Maximum NR
try await rig.setNoiseReduction(.off)                 // Disable
```

##### noiseReduction(cached:)

```swift
public func noiseReduction(cached: Bool = true) async throws -> NoiseReduction
```

Reads the noise reduction state.

**Returns:** Current `NoiseReduction` configuration

##### setIFFilter(_:)

```swift
public func setIFFilter(_ filter: IFFilter) async throws
```

Selects the IF (intermediate frequency) filter bandwidth.

**Parameters:**
- `filter`: Filter selection (`.filter1`, `.filter2`, `.filter3`)

**Example:**
```swift
try await rig.setIFFilter(.filter1)  // Widest (SSB)
try await rig.setIFFilter(.filter3)  // Narrowest (CW)
```

**Approximate bandwidths (protocol-dependent):**
- `.filter1` ≈ 2700 Hz (standard SSB)
- `.filter2` ≈ 2100 Hz (narrow SSB)
- `.filter3` ≈ 500 Hz (CW)

##### ifFilter(cached:)

```swift
public func ifFilter(cached: Bool = true) async throws -> IFFilter
```

Reads the current IF filter selection.

#### Memory Channel Operations (v1.2.0)

Memory channels allow storing complete radio configurations (frequency, mode, name, and optional parameters) in non-volatile memory for quick recall. SwiftRigControl provides a universal memory channel model that works across all radio manufacturers.

##### setMemoryChannel(_:)

```swift
public func setMemoryChannel(_ channel: MemoryChannel) async throws
```

Stores a configuration to a memory channel.

**Parameters:**
- `channel`: Memory channel configuration to store

**Throws:**
- `RigError.notConnected` - Not connected to radio
- `RigError.unsupportedOperation` - Memory channels not supported
- `RigError.commandFailed` - Radio rejected the configuration

**Example:**
```swift
// Create a memory channel for 20m FT8
let channel = MemoryChannel(
    number: 1,
    frequency: 14_074_000,
    mode: .dataUSB,
    name: "20m FT8"
)
try await rig.setMemoryChannel(channel)
```

##### getMemoryChannel(_:)

```swift
public func getMemoryChannel(_ number: Int) async throws -> MemoryChannel
```

Reads a memory channel configuration from the radio.

**Parameters:**
- `number`: Memory channel number to read

**Returns:** Memory channel configuration

**Throws:**
- `RigError.notConnected` - Not connected to radio
- `RigError.unsupportedOperation` - Memory channels not supported
- `RigError.commandFailed` - Channel is empty or invalid

**Example:**
```swift
let channel = try await rig.getMemoryChannel(1)
print("Channel \(channel.number): \(channel.description)")
// Output: "Ch 1 (20m FT8): 14.074 MHz dataUSB"
```

##### memoryChannelCount()

```swift
public func memoryChannelCount() async throws -> Int
```

Gets the total number of memory channels supported by the radio.

**Returns:** Number of memory channels (e.g., 99, 100, 109)

**Throws:**
- `RigError.notConnected` - Not connected to radio
- `RigError.unsupportedOperation` - Memory not supported

**Example:**
```swift
let count = try await rig.memoryChannelCount()
print("\(rig.radioName) supports \(count) memory channels")
// Output: "Icom IC-7600 supports 100 memory channels"
```

##### clearMemoryChannel(_:)

```swift
public func clearMemoryChannel(_ number: Int) async throws
```

Clears (erases) a memory channel.

**Parameters:**
- `number`: Memory channel number to clear

**Throws:**
- `RigError.notConnected` - Not connected to radio
- `RigError.unsupportedOperation` - Memory not supported
- `RigError.commandFailed` - Operation failed

**Example:**
```swift
try await rig.clearMemoryChannel(1)
```

##### recallMemoryChannel(_:to:)

```swift
public func recallMemoryChannel(_ number: Int, to vfo: VFO = .a) async throws
```

Recalls a memory channel configuration to the current VFO. This convenience method reads the channel and applies its frequency and mode settings.

**Parameters:**
- `number`: Memory channel number to recall
- `vfo`: Target VFO (defaults to `.a`)

**Throws:** `RigError` if operation fails or channel is empty

**Example:**
```swift
// Recall channel 1 settings to VFO A
try await rig.recallMemoryChannel(1)
```

##### storeCurrentToMemory(_:from:name:)

```swift
public func storeCurrentToMemory(_ number: Int, from vfo: VFO = .a, name: String? = nil) async throws
```

Stores the current VFO configuration to a memory channel. Convenience method that reads current settings and creates a memory channel.

**Parameters:**
- `number`: Memory channel number to store to
- `vfo`: Source VFO to read from (defaults to `.a`)
- `name`: Optional channel name (max 10 characters for Icom)

**Throws:** `RigError` if operation fails

**Example:**
```swift
// Store current VFO A settings to channel 5 with name
try await rig.storeCurrentToMemory(5, name: "Contest")
```

#### Batch Configuration (v1.1.0)

##### configure(frequency:mode:power:vfo:)

```swift
public func configure(
    frequency: UInt64? = nil,
    mode: Mode? = nil,
    power: Int? = nil,
    vfo: VFO = .a
) async throws
```

Configures multiple radio parameters in one call.

**Parameters:**
- `frequency`: Frequency in Hertz (optional)
- `mode`: Operating mode (optional)
- `power`: Power in watts (optional)
- `vfo`: Target VFO (defaults to `.a`)

**Example:**
```swift
// Complete configuration
try await rig.configure(
    frequency: 14_074_000,
    mode: .dataUSB,
    power: 50
)

// Partial configuration
try await rig.configure(frequency: 7_074_000)  // Change band only
try await rig.configure(mode: .cw)              // Change mode only
```

#### Cache Management

##### invalidateCache()

```swift
public func invalidateCache() async
```

Invalidates all cached radio state values.

Call this after making manual adjustments on the radio's front panel.

**Example:**
```swift
await rig.invalidateCache()
let freshFreq = try await rig.frequency()  // Forces fresh read
```

#### Radio Information

##### radioName

```swift
public var radioName: String { get }
```

Returns the full name of the radio (manufacturer + model).

**Example:**
```swift
print("Connected to: \(rig.radioName)")  // "Icom IC-9700"
```

##### capabilities

```swift
public var capabilities: RigCapabilities { get }
```

Returns the capabilities of the radio.

**Example:**
```swift
let caps = rig.capabilities
print("Max power: \(caps.maxPower)W")
print("Has split: \(caps.hasSplit)")
print("Dual receiver: \(caps.hasDualReceiver)")
```

---

## Radio Definitions

All supported radios are available as static properties on `RadioDefinition`.

### Icom Radios (27 models)

```swift
// Flagship & High-End HF
.icomIC7851         // HF/6m flagship with spectrum scope, 200W
.icomIC7800         // HF/6m flagship dual receiver, 200W
.icomIC7760         // HF/6m flagship SDR, 200W (new in v1.3.0)
.icomIC7700         // HF/6m high-end, 200W
.icomIC7610         // HF/6m SDR with dual receiver, 100W
.icomIC7600         // HF/6m high-performance dual receiver, 100W

// Popular HF Transceivers
.icomIC7300         // HF/6m all-mode SDR, 100W
.icomIC7300mk2      // HF/6m all-mode SDR (revised), 100W (new in v1.3.0)
.icomIC7410         // HF/6m all-mode, 100W
.icomIC7200         // HF/6m mid-range, 100W
.icomIC756PROIII    // HF/6m dual receiver, 100W
.icomIC756PROII     // HF/6m dual receiver, 100W
.icomIC756PRO       // HF/6m dual receiver, 100W
.icomIC756          // HF/6m dual receiver, 100W
.icomIC746PRO       // HF/6m + 2m receive, 100W
.icomIC746          // HF/6m + 2m receive, 100W

// HF + VHF/UHF Multi-Band
.icomIC9100         // HF/VHF/UHF dual receiver with satellite, 100W
.icomIC7100         // HF/VHF/UHF all-mode, 100W
.icomIC705          // HF/VHF/UHF portable, 10W
.icomIC7000         // HF/VHF/UHF mobile, 100W
.icomIC706MKIIG     // HF/VHF/UHF mobile, 100W
.icomIC706MKII      // HF/VHF mobile, 100W
.icomIC706          // HF/VHF mobile, 100W

// VHF/UHF
.icomIC9700         // VHF/UHF/1.2GHz all-mode dual receiver, 100W
.icomIC910H         // VHF/UHF satellite transceiver, 100W
.icomIC2730         // VHF/UHF dual-band FM mobile, 50W
.icomID5100         // VHF/UHF D-STAR mobile, 50W
.icomID4100         // VHF/UHF D-STAR mobile, 50W

// Receivers
.icomICR9500        // Professional wideband receiver, 1.2kHz-3.3GHz
.icomICR8600        // Wideband receiver, 10kHz-3GHz
.icomICR75          // HF receiver, 30kHz-60MHz
```

### Elecraft Radios (6 models)

```swift
.elecraftK2         // HF, 15W
.elecraftK3         // HF/6m, 100W
.elecraftK3S        // HF/6m, 100W enhanced
.elecraftK4         // HF/6m SDR, 100W
.elecraftKX2        // HF portable, 12W
.elecraftKX3        // HF/6m portable, 15W
```

### Yaesu Radios (14 models)

```swift
// Modern (2010+)
.yaesuFTDX10        // HF/6m, 100W
.yaesuFT991A        // HF/VHF/UHF, 100W
.yaesuFT710         // HF/6m AESS, 100W
.yaesuFT891         // HF/6m field, 100W
.yaesuFT817         // HF/VHF/UHF portable, 5W
.yaesuFTDX101D      // HF/6m, 100W
.yaesuFTDX101MP     // HF/6m flagship, 200W
.yaesuFT857D        // HF/VHF/UHF mobile, 100W
.yaesuFT897D        // HF/VHF/UHF base/mobile, 100W
.yaesuFT450D        // HF/6m budget, 100W

// Legacy (Pre-2005) — new in v1.3.0
.yaesuFT1000MP      // HF flagship, 200W, dual receiver
.yaesuFT857         // HF/VHF/UHF mobile, 100W
.yaesuFT897         // HF/VHF/UHF portable, 100W
.yaesuFT450         // HF/6m, 100W
```

### Kenwood Radios (15 models)

```swift
// Modern
.kenwoodTS890S      // HF/6m, 100W, dual RX
.kenwoodTS990S      // HF/6m flagship, 200W, dual RX
.kenwoodTS590SG     // HF/6m, 100W
.kenwoodTMD710      // VHF/UHF, 50W
.kenwoodTS480SAT    // HF/6m, 100W
.kenwoodTS2000      // HF/VHF/UHF, 100W
.kenwoodTS590S      // HF/6m, 100W
.kenwoodTS870S      // HF/6m, 100W
.kenwoodTS480HX     // HF/6m, 200W
.kenwoodTMV71       // VHF/UHF, 50W
.kenwoodTHD74       // VHF/UHF handheld, 5W
.kenwoodTHD72A      // VHF/UHF handheld, 5W

// Legacy HF — new in v1.3.0
.kenwoodTS850S      // HF, 100W, ATU
.kenwoodTS570D      // HF/6m, 100W, ATU
.kenwoodTS570S      // HF, 100W
```

---

## Models and Types

### ConnectionType

```swift
public enum ConnectionType {
    case serial(path: String, baudRate: Int? = nil)
    case mock
}
```

**Usage:**
```swift
// Automatic baud rate (uses radio's default)
.serial(path: "/dev/cu.IC9700", baudRate: nil)

// Explicit baud rate
.serial(path: "/dev/cu.IC7300", baudRate: 115200)

// Mock connection for testing
.mock
```

### VFO

```swift
public enum VFO: String, Sendable {
    case a      // VFO A
    case b      // VFO B
    case main   // Main receiver (dual RX radios)
    case sub    // Sub receiver (dual RX radios)
}
```

**Usage:**
```swift
try await rig.setFrequency(14_230_000, vfo: .a)
try await rig.setFrequency(14_230_000, vfo: .main)  // IC-9700, IC-7610, etc.
```

### Mode

```swift
public enum Mode: String, Sendable, CaseIterable {
    case lsb        // Lower Sideband
    case usb        // Upper Sideband
    case cw         // Morse Code
    case cwR        // CW Reverse
    case am         // Amplitude Modulation
    case fm         // Frequency Modulation
    case fmN        // FM Narrow
    case wfm        // Wide FM (receivers)
    case rtty       // Radio Teletype
    case rttyR      // RTTY Reverse
    case dataLSB    // Digital modes (LSB)
    case dataUSB    // Digital modes (USB)
    case dataFM     // Digital modes (FM)
}
```

**Usage:**
```swift
try await rig.setMode(.usb, vfo: .a)    // Voice
try await rig.setMode(.cw, vfo: .a)     // Morse code
try await rig.setMode(.dataUSB, vfo: .a) // FT8, RTTY, etc.
```

### SignalStrength (v1.1.0)

```swift
public struct SignalStrength: Sendable {
    public let sUnits: Int        // 0-9
    public let overS9: Int        // dB over S9 (0-60)
    public let raw: Int           // Raw S-meter value

    public var isStrongSignal: Bool  // S9 or better
    public var description: String   // "S7", "S9+20", etc.
}
```

**Usage:**
```swift
let signal = try await rig.signalStrength()
print("S-meter: \(signal.description)")

if signal.sUnits >= 9 {
    print("Signal is S9+\(signal.overS9)")
}
```

### RITXITState (v1.1.0)

```swift
public struct RITXITState: Sendable, Equatable, Codable {
    public let enabled: Bool   // Whether RIT/XIT is enabled
    public let offset: Int     // Frequency offset in Hz (typically -9999 to +9999)

    public init(enabled: Bool, offset: Int = 0)

    public static let disabled: RITXITState  // Convenience for disabled state
    public var description: String           // Human-readable description
}
```

Represents the state of RIT (Receiver Incremental Tuning) or XIT (Transmitter Incremental Tuning).

RIT and XIT allow fine-tuning of the receiver or transmitter frequency independently from the displayed VFO frequency. This is useful for:
- Split operation in contests and DX work
- Zero-beating CW signals
- Compensating for slight frequency offsets

**Usage:**
```swift
// Enable RIT with +500 Hz offset
let ritState = RITXITState(enabled: true, offset: 500)
try await rig.setRIT(ritState)

// Disable RIT
try await rig.setRIT(.disabled)

// Read current RIT state
let currentRIT = try await rig.getRIT()
print("RIT: \(currentRIT.description)")  // "ON (+500 Hz)" or "OFF"

if currentRIT.enabled {
    print("Offset: \(currentRIT.offset) Hz")
}
```

**Typical Range:**
Most radios support offsets between -9999 Hz and +9999 Hz, though this varies by manufacturer. Check your radio's capabilities before setting extreme values.

### MemoryChannel (v1.2.0)

```swift
public struct MemoryChannel: Sendable, Equatable, Codable {
    // Core properties (universal)
    public let number: Int           // Memory channel number
    public let frequency: UInt64     // Operating frequency in Hz
    public let mode: Mode            // Operating mode
    public let name: String?         // Optional channel name (max 10 chars for Icom)

    // Optional features (manufacturer-dependent)
    public let splitEnabled: Bool?       // Split operation enabled
    public let txFrequency: UInt64?      // Transmit frequency when split
    public let toneFrequency: Double?    // CTCSS tone (67.0-254.1 Hz)
    public let toneSqelchFrequency: Double? // CTCSS tone squelch
    public let dcsCode: Int?             // DCS code (023-754 octal)
    public let duplexOffset: Int?        // Duplex offset in Hz
    public let skipScan: Bool?           // Skip during scanning
    public let lockout: Bool?            // Channel locked
    public let filterSelection: Int?     // Filter bandwidth selection
    public let dataMode: Bool?           // Data mode enabled
    public let powerLevel: Int?          // TX power level

    // Initialization
    public init(
        number: Int,
        frequency: UInt64,
        mode: Mode,
        name: String? = nil,
        splitEnabled: Bool? = nil,
        txFrequency: UInt64? = nil,
        toneFrequency: Double? = nil,
        toneSqelchFrequency: Double? = nil,
        dcsCode: Int? = nil,
        duplexOffset: Int? = nil,
        skipScan: Bool? = nil,
        lockout: Bool? = nil,
        filterSelection: Int? = nil,
        dataMode: Bool? = nil,
        powerLevel: Int? = nil
    )

    // Convenience properties
    public var isSimplex: Bool          // No duplex offset
    public var hasTone: Bool            // Any tone configured
    public var description: String       // Human-readable description
}
```

Represents a memory channel configuration for radio transceivers.

Memory channels allow storing frequency, mode, and other settings for quick recall. This model provides a unified interface across all radio manufacturers while allowing for manufacturer-specific features through optional properties.

**Manufacturer-Specific Features:**
- **Icom**: Supports split, data mode, filter selection, duplex offset, CTCSS tones
- **Yaesu**: Supports CTCSS/DCS tones, skip settings, power levels
- **Kenwood**: Supports tone squelch, lockout, reverse
- **Elecraft**: Supports extended settings via menu commands

**Usage:**
```swift
// Create a basic memory channel
let channel = MemoryChannel(
    number: 1,
    frequency: 14_230_000,  // 14.230 MHz
    mode: .usb,
    name: "20m Net"
)

// Store to radio
try await rig.setMemoryChannel(channel)

// Recall from radio
let stored = try await rig.getMemoryChannel(1)
print("Channel \(stored.number): \(stored.name ?? "Unnamed")")
print("Frequency: \(stored.frequency) Hz, Mode: \(stored.mode)")

// Create a VHF/UHF repeater channel with CTCSS tone and offset
let repeater = MemoryChannel(
    number: 10,
    frequency: 146_520_000,  // 2m calling frequency
    mode: .fm,
    name: "2m Call",
    toneFrequency: 100.0,    // 100 Hz CTCSS
    duplexOffset: 600_000    // +600 kHz standard 2m offset
)
try await rig.setMemoryChannel(repeater)

// Create a split operation channel
let splitChannel = MemoryChannel(
    number: 15,
    frequency: 14_195_000,   // Receive frequency
    mode: .usb,
    name: "DX Split",
    splitEnabled: true,
    txFrequency: 14_225_000  // Transmit frequency
)
try await rig.setMemoryChannel(splitChannel)
```

**Validation:**
The `validate(for:)` method checks the configuration against radio capabilities:
```swift
try channel.validate(for: rig.capabilities)  // Throws if invalid
```

**Channel Number Ranges:**
Different radios support different channel counts:
- IC-7300, IC-705: 0-98 (99 channels)
- IC-7600: 0-99 (100 channels)
- IC-7100, IC-9700: 1-109 (includes special channels)
- Most Yaesu: 1-99 or 1-117
- Most Kenwood: 0-99 or 0-299

### AGCSpeed (v1.3.0)

```swift
public enum AGCSpeed: String, Sendable, Codable, CaseIterable {
    case off    // AGC disabled (manual RF gain control)
    case fast   // Fast AGC — CW, digital modes, contest
    case medium // Medium AGC — general SSB, AM
    case slow   // Slow AGC — weak signal DX, QRP
    case auto   // Automatic selection by mode (select Yaesu radios only)
}
```

**Usage:**
```swift
try await rig.setAGC(.fast)    // CW/digital modes
try await rig.setAGC(.slow)    // Weak signal SSB DX
let current = try await rig.agc()
```

### NoiseBlanker (v1.3.0)

```swift
public enum NoiseBlanker: Sendable, Equatable {
    case off
    case enabled(level: Int? = nil)  // level: 0-10 on supported radios

    var isEnabled: Bool
    var level: Int?
}
```

**Usage:**
```swift
try await rig.setNoiseBlanker(.enabled(level: 5))  // NB with level control
try await rig.setNoiseBlanker(.enabled())           // Simple on/off radios
try await rig.setNoiseBlanker(.off)
let nb = try await rig.noiseBlanker()
```

### NoiseReduction (v1.3.0)

```swift
public enum NoiseReduction: Sendable, Equatable {
    case off
    case enabled(level: Int)  // level: 0-15 typical, some radios 0-255

    var isEnabled: Bool
    var level: Int?
}
```

**Usage:**
```swift
try await rig.setNoiseReduction(.enabled(level: 8))
try await rig.setNoiseReduction(.off)
let nr = try await rig.noiseReduction()
```

### NoiseControlConfig (v1.3.0)

Convenience struct for configuring NB and NR together.

```swift
public struct NoiseControlConfig: Sendable, Equatable {
    public var blanker: NoiseBlanker
    public var reduction: NoiseReduction

    public static let off: NoiseControlConfig     // Both off
    public static let light: NoiseControlConfig   // NB 3, NR 5
    public static let medium: NoiseControlConfig  // NB 5, NR 8
    public static let heavy: NoiseControlConfig   // NB 8, NR 12
}
```

**Usage:**
```swift
try await rig.setNoiseBlanker(NoiseControlConfig.medium.blanker)
try await rig.setNoiseReduction(NoiseControlConfig.medium.reduction)
```

### IFFilter (v1.3.0)

```swift
public enum IFFilter: Int, Sendable, CaseIterable {
    case filter1 = 1  // Widest (≈2700 Hz SSB)
    case filter2 = 2  // Medium (≈2100 Hz)
    case filter3 = 3  // Narrowest (≈500 Hz CW)
}
```

Selects the IF filter bandwidth. Exact bandwidths depend on the radio model and installed filter options.

**Protocol-specific bandwidths:**

| Filter | Yaesu/Kenwood | Elecraft K3/K4 (BW) | Elecraft K2 (FW) |
|--------|---------------|---------------------|------------------|
| filter1 | SH07 (~2700 Hz) | 2700 Hz | 2700 Hz |
| filter2 | SH05 (~2100 Hz) | 2100 Hz | 2100 Hz |
| filter3 | SH02 (~500 Hz) | 500 Hz | 500 Hz |

**Usage:**
```swift
try await rig.setIFFilter(.filter1)  // Wide for SSB
try await rig.setIFFilter(.filter3)  // Narrow for CW
let current = try await rig.ifFilter()
```

### RigCapabilities

```swift
public struct RigCapabilities: Sendable {
    public let hasVFOB: Bool              // Has VFO B
    public let hasSplit: Bool             // Supports split operation
    public let powerControl: Bool         // Can set RF power
    public let maxPower: Int              // Maximum power in watts
    public let supportedModes: [Mode]     // Available modes
    public let frequencyRange: (UInt64, UInt64)  // Min/max frequency
    public let hasDualReceiver: Bool      // Has main/sub receivers
    public let hasATU: Bool               // Has antenna tuner
    public let requiresVFOSelection: Bool // Needs VFO select before ops
    public let requiresModeFilter: Bool   // Mode commands need filter byte
    public let region: AmateurRadioRegion // ITU region for band validation
    public let supportsRIT: Bool          // Supports RIT (v1.1.0)
    public let supportsXIT: Bool          // Supports XIT (v1.1.0)
}
```

**Methods:**

##### isFrequencyValid(_:)

```swift
public func isFrequencyValid(_ frequency: UInt64) -> Bool
```

Checks if frequency is within radio's range.

##### canTransmit(on:)

```swift
public func canTransmit(on frequency: UInt64) -> Bool
```

Checks if radio can transmit on frequency (not receive-only).

##### supportedModes(for:)

```swift
public func supportedModes(for frequency: UInt64) -> [Mode]
```

Returns modes available for the given frequency.

##### bandName(for:)

```swift
public func bandName(for frequency: UInt64) -> String?
```

Returns band name (e.g., "20m", "2m") for frequency.

##### isInAmateurBand(_:)

```swift
public func isInAmateurBand(_ frequency: UInt64) -> Bool
```

Checks if frequency is in amateur radio allocation for radio's region.

##### amateurBandName(for:)

```swift
public func amateurBandName(for frequency: UInt64) -> String?
```

Returns amateur band name based on radio's configured region.

**Usage:**
```swift
let caps = rig.capabilities

// Check capabilities
if caps.hasSplit {
    try await rig.setSplit(true)
}

// Validate frequency
if caps.isFrequencyValid(14_230_000) {
    try await rig.setFrequency(14_230_000)
}

// Check if can transmit
if caps.canTransmit(on: 14_230_000) {
    print("Can transmit on 20m")
}

// Get available modes
let modes = caps.supportedModes(for: 14_230_000)
print("Available: \(modes)")  // [.usb, .cw, .rtty, .dataUSB]
```

### AmateurRadioRegion

```swift
public enum AmateurRadioRegion: String, Sendable {
    case region1  // Europe, Africa, Middle East
    case region2  // Americas (default)
    case region3  // Asia-Pacific
}
```

Amateur band allocations vary by ITU region. Configure during initialization:

```swift
let caps = RigCapabilities(
    region: .region1,  // Europe
    // ... other properties
)
```

### Regional Band Types

```swift
// Region 1 (Europe/Africa/Middle East)
Region1AmateurBand.band(for: frequency)

// Region 2 (Americas - default)
Region2AmateurBand.band(for: frequency)

// Region 3 (Asia-Pacific)
Region3AmateurBand.band(for: frequency)
```

**Example:**
```swift
if let band = Region2AmateurBand.band(for: 14_200_000) {
    print("Band: \(band.displayName)")        // "20m"
    print("Range: \(band.frequencyRange)")
    print("Modes: \(band.commonModes)")
}
```

---

## Error Handling

### RigError

```swift
public enum RigError: Error {
    case notConnected
    case timeout
    case commandFailed(String)
    case unsupportedOperation(String)
    case invalidParameter(String)
    case invalidResponse
    case frequencyOutOfRange(UInt64, String)
}
```

#### Error Cases

- **notConnected**: Radio is not connected. Call `connect()` first.
- **timeout**: Radio did not respond. Check cables, baud rate, radio settings.
- **commandFailed(reason)**: Radio rejected command. Reason provided.
- **unsupportedOperation(message)**: Operation not supported by this radio.
- **invalidParameter(message)**: Invalid parameter value.
- **invalidResponse**: Radio sent unexpected response.
- **frequencyOutOfRange(freq, model)**: Frequency outside radio's capabilities.

#### Usage

```swift
do {
    try await rig.setFrequency(14_230_000, vfo: .a)
} catch RigError.notConnected {
    print("Not connected - call connect() first")
} catch RigError.timeout {
    print("Radio didn't respond - check connection")
} catch RigError.commandFailed(let reason) {
    print("Command failed: \(reason)")
} catch RigError.frequencyOutOfRange(let freq, let model) {
    print("\(freq) Hz is outside \(model) range")
} catch {
    print("Unexpected error: \(error)")
}
```

---

## Protocols

### CATProtocol

The base protocol that all radio protocols implement. All methods beyond the core set have default implementations that throw `.unsupportedOperation`, so protocols only need to implement what the hardware supports.

```swift
public protocol CATProtocol: Actor {
    var transport: any SerialTransport { get }
    var capabilities: RigCapabilities { get }

    // Connection
    func connect() async throws
    func disconnect() async

    // Frequency
    func setFrequency(_ hz: UInt64, vfo: VFO) async throws
    func getFrequency(vfo: VFO) async throws -> UInt64

    // Mode
    func setMode(_ mode: Mode, vfo: VFO) async throws
    func getMode(vfo: VFO) async throws -> Mode

    // PTT
    func setPTT(_ enabled: Bool) async throws
    func getPTT() async throws -> Bool

    // VFO
    func selectVFO(_ vfo: VFO) async throws

    // Split
    func setSplit(_ enabled: Bool) async throws
    func getSplit() async throws -> Bool

    // RF Power
    func setPower(_ value: Int) async throws
    func getPower() async throws -> Int

    // S-Meter
    func getSignalStrength() async throws -> SignalStrength

    // RIT/XIT (v1.1.0)
    func setRIT(_ state: RITXITState) async throws
    func getRIT() async throws -> RITXITState
    func setXIT(_ state: RITXITState) async throws
    func getXIT() async throws -> RITXITState

    // Memory Channels (v1.2.0)
    func setMemoryChannel(_ channel: MemoryChannel) async throws
    func getMemoryChannel(_ number: Int) async throws -> MemoryChannel
    func getMemoryChannelCount() async throws -> Int
    func clearMemoryChannel(_ number: Int) async throws

    // Level Controls (v1.3.0)
    func setAFGain(_ level: Int) async throws
    func getAFGain() async throws -> Int
    func setRFGain(_ level: Int) async throws
    func getRFGain() async throws -> Int
    func setSquelch(_ level: Int) async throws
    func getSquelch() async throws -> Int
    func setPreamp(_ level: Int) async throws
    func getPreamp() async throws -> Int
    func setAttenuator(_ level: Int) async throws
    func getAttenuator() async throws -> Int
    func setPowerState(_ on: Bool) async throws
    func getPowerState() async throws -> Bool

    // DSP Controls (v1.3.0)
    func setAGC(_ speed: AGCSpeed) async throws
    func getAGC() async throws -> AGCSpeed
    func setNoiseBlanker(_ config: NoiseBlanker) async throws
    func getNoiseBlanker() async throws -> NoiseBlanker
    func setNoiseReduction(_ config: NoiseReduction) async throws
    func getNoiseReduction() async throws -> NoiseReduction
    func setIFFilter(_ filter: IFFilter) async throws
    func getIFFilter() async throws -> IFFilter
}
```

**Implementations:**
- `IcomCIVProtocol` - Icom CI-V binary protocol
- `ElecraftProtocol` - Elecraft text protocol
- `YaesuCATProtocol` - Yaesu CAT text protocol
- `KenwoodProtocol` - Kenwood text protocol

### SerialTransport

Low-level serial port communication.

```swift
public protocol SerialTransport: Actor {
    func open() async throws
    func close() async
    func write(_ data: Data) async throws
    func read(count: Int, timeout: TimeInterval) async throws -> Data
    func readUntil(terminator: UInt8, timeout: TimeInterval) async throws -> Data
    func flush() async throws
}
```

**Implementation:**
- `IOKitSerialPort` - macOS IOKit-based serial port

---

## XPC Integration

For sandboxed Mac App Store applications.

### XPCClient

```swift
public class XPCClient {
    public static let shared: XPCClient

    public func connect() async throws
    public func disconnect() async

    public func connectToRadio(radio: String, port: String, baudRate: Int?) async throws
    public func disconnectRadio() async

    // Same API as RigController
    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws
    public func frequency(vfo: VFO) async throws -> UInt64

    public func setMode(_ mode: Mode, vfo: VFO) async throws
    public func mode(vfo: VFO) async throws -> Mode

    public func setPTT(_ enabled: Bool) async throws
    public func isPTTEnabled() async throws -> Bool

    // ... all other RigController methods
}
```

**Usage:**
```swift
import RigControlXPC

let client = XPCClient.shared
try await client.connect()
try await client.connectToRadio(radio: "IC-9700", port: "/dev/cu.IC9700")

try await client.setFrequency(14_230_000, vfo: .a)
try await client.setPTT(true)

await client.disconnectRadio()
await client.disconnect()
```

---

## Utilities

### BCDEncoding

Binary Coded Decimal encoding/decoding for Icom radios.

```swift
public enum BCDEncoding {
    public static func encodeFrequency(_ frequency: UInt64) -> [UInt8]
    public static func decodeFrequency(_ data: [UInt8]) -> UInt64

    public static func encodePower(_ power: Int) -> [UInt8]
    public static func decodePower(_ data: [UInt8]) -> Int
}
```

**Example:**
```swift
let bytes = BCDEncoding.encodeFrequency(14_230_000)
// [0x00, 0x00, 0x23, 0x14, 0x00] (little-endian BCD)

let freq = BCDEncoding.decodeFrequency(bytes)
// 14230000
```

### RadioStateCache

Internal caching mechanism for performance optimization.

```swift
actor RadioStateCache {
    func get<T>(_ key: CacheKey) -> T?
    func set<T>(_ key: CacheKey, value: T)
    func invalidate()
    func invalidate(_ key: CacheKey)
}
```

Cache entries expire after 500ms by default. Used internally by `RigController`.

---

## Version History

### v1.3.0 (Current)
- ✅ Level controls: AF gain, RF gain, squelch, preamp, attenuator
- ✅ DSP controls: AGC, noise blanker, noise reduction, IF filter
- ✅ Power state control (remote on/off)
- ✅ Level control implemented for Yaesu, Kenwood, and Elecraft protocols
- ✅ New radio models: IC-7760, IC-7300 MK2, FT-1000MP, FT-857, FT-897, FT-450, TS-850S, TS-570D, TS-570S
- ✅ CATProtocol extended to 31 methods with graceful default fallbacks

### v1.2.0
- ✅ Memory channel operations (set, get, clear, recall)
- ✅ Universal MemoryChannel model (CTCSS, DCS, duplex, split)
- ✅ Icom CI-V memory channel implementation (all 25 models)
- ✅ Yaesu/Kenwood/Elecraft memory channel support

### v1.1.0
- ✅ Signal strength monitoring
- ✅ RIT/XIT incremental tuning control
- ✅ Performance caching (10-20x faster)
- ✅ Batch configuration API
- ✅ Cache invalidation control

### v1.0.4
- ✅ Elecraft K2 power control and PTT timing fixes
- ✅ LGPL v3.0 licensing
- ✅ GitHub issue/PR templates
- ✅ Hardware test suite (IC-7600, IC-7100, IC-9700, K2 verified)

### v1.0.2
- ✅ Comprehensive frequency validation
- ✅ ITU regional band support (Region 1/2/3)
- ✅ Amateur band validation
- ✅ Extended Icom radio database

### v1.0.0
- ✅ Core API (frequency, mode, PTT, power, split)
- ✅ 4 manufacturer support (Icom, Elecraft, Yaesu, Kenwood)
- ✅ 30 radio models
- ✅ XPC helper for sandboxed apps

---

## See Also

- [Usage Examples](USAGE_EXAMPLES.md) - Common use cases and patterns
- [Troubleshooting Guide](TROUBLESHOOTING.md) - Problem solving
- [Serial Port Guide](SERIAL_PORT_GUIDE.md) - Connection setup
- [XPC Helper Guide](XPC_HELPER_GUIDE.md) - Mac App Store integration
- [Hamlib Migration](HAMLIB_MIGRATION.md) - Migrating from Hamlib

---

**73 de VA3ZTF**
