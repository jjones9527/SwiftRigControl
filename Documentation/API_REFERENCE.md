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

### Icom Radios (25 models)

```swift
// Flagship & High-End HF
.icomIC7851         // HF/6m flagship with spectrum scope, 200W
.icomIC7800         // HF/6m flagship dual receiver, 200W
.icomIC7700         // HF/6m high-end, 200W
.icomIC7610         // HF/6m SDR with dual receiver, 100W
.icomIC7600         // HF/6m high-performance dual receiver, 100W

// Popular HF Transceivers
.icomIC7300         // HF/6m all-mode SDR, 100W
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

### Yaesu Radios (10 models)

```swift
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
```

### Kenwood Radios (12 models)

```swift
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

The base protocol that all radio protocols implement.

```swift
public protocol CATProtocol: Actor {
    var transport: any SerialTransport { get }
    var capabilities: RigCapabilities { get }

    func connect() async throws
    func disconnect() async

    func setFrequency(_ hz: UInt64, vfo: VFO) async throws
    func getFrequency(vfo: VFO) async throws -> UInt64

    func setMode(_ mode: Mode, vfo: VFO) async throws
    func getMode(vfo: VFO) async throws -> Mode

    func setPTT(_ enabled: Bool) async throws
    func getPTT() async throws -> Bool

    func selectVFO(_ vfo: VFO) async throws

    func setSplit(_ enabled: Bool) async throws
    func getSplit() async throws -> Bool

    func setPower(_ value: Int) async throws
    func getPower() async throws -> Int

    func getSignalStrength() async throws -> SignalStrength
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

### v1.1.0 (Current)
- ✅ Signal strength monitoring
- ✅ Performance caching (10-20x faster)
- ✅ Batch configuration API
- ✅ Cache invalidation control

### v1.0.2
- ✅ Comprehensive frequency validation
- ✅ ITU regional band support
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
