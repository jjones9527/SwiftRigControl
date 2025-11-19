# SwiftRigControl

A native Swift library for controlling amateur radio transceivers on macOS.

## Features

- ✅ **Modern Swift**: Built with Swift 5.9+, using async/await and actors
- ✅ **Mac App Store Compatible**: XPC helper pattern for sandboxed apps
- ✅ **Protocol-Based**: Clean abstraction supporting multiple radio protocols
- ✅ **Type-Safe**: Full Swift type safety with enums and error handling
- ✅ **Well-Tested**: Comprehensive unit tests with mock transport support
- ✅ **Open Source**: MIT licensed

## Supported Radios

### Icom (CI-V Protocol) ✅

- **IC-9700** - VHF/UHF/1.2GHz all-mode transceiver (115200 baud, CI-V: 0xA2)
- **IC-7610** - HF/6m SDR transceiver (115200 baud, CI-V: 0x98)
- **IC-7300** - HF/6m all-mode transceiver (115200 baud, CI-V: 0x94)
- **IC-7600** - HF/6m all-mode transceiver (19200 baud, CI-V: 0x7A)
- **IC-7100** - HF/VHF/UHF all-mode transceiver (19200 baud, CI-V: 0x88)
- **IC-705** - Portable HF/VHF/UHF transceiver (19200 baud, CI-V: 0xA4)

### Elecraft (Text-Based Protocol) ✅

- **K2** - HF transceiver (4800 baud, 15W)
- **K3** - HF/6m transceiver (38400 baud, 100W)
- **K3S** - HF/6m transceiver enhanced (38400 baud, 100W)
- **K4** - HF/6m SDR transceiver (38400 baud, 100W)
- **KX2** - Portable HF transceiver (38400 baud, 12W)
- **KX3** - Portable HF/6m transceiver (38400 baud, 15W)

### Yaesu (CAT Protocol) ✅

- **FTDX-10** - HF/6m transceiver (38400 baud, 100W)
- **FT-991A** - HF/VHF/UHF all-mode transceiver (38400 baud, 100W)
- **FT-710** - HF/6m all-mode transceiver (38400 baud, 100W)
- **FT-891** - HF/6m all-mode transceiver (38400 baud, 100W)
- **FT-817** - Portable QRP HF/VHF/UHF transceiver (38400 baud, 5W)
- **FTDX-101D** - HF/6m transceiver with dual receiver (38400 baud, 100W)

### Kenwood (Text-Based Protocol) ✅

- **TS-890S** - HF/6m transceiver with dual receiver (115200 baud, 100W)
- **TS-990S** - HF/6m flagship transceiver with dual receiver (115200 baud, 200W)
- **TS-590SG** - HF/6m all-mode transceiver (115200 baud, 100W)
- **TM-D710** - VHF/UHF dual-band transceiver (57600 baud, 50W)
- **TS-480SAT** - HF/6m all-mode transceiver (57600 baud, 100W)
- **TS-2000** - HF/VHF/UHF all-mode transceiver (57600 baud, 100W)

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftRigControl.git", from: "1.0.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter repository URL

## Quick Start

### Basic Usage (Non-Sandboxed Apps)

```swift
import RigControl

// Create a rig controller
let rig = RigController(
    radio: .icomIC9700,
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
// Get current frequency
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
| IC-9700 | 115200 | 100W | 144 MHz - 1.3 GHz | Yes | No | Yes |
| IC-7610 | 115200 | 100W | 30 kHz - 60 MHz | Yes | Yes | Yes |
| IC-7300 | 115200 | 100W | 30 kHz - 60 MHz | No | Yes | Yes |
| IC-7600 | 19200 | 100W | 30 kHz - 60 MHz | Yes | Yes | Yes |
| IC-7100 | 19200 | 100W | 30 kHz - 500 MHz | No | Yes | Yes |
| IC-705 | 19200 | 10W | 30 kHz - 500 MHz | No | Yes | Yes |

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

### Next Steps

**Week 8** - Documentation refinement
**Week 9** - v1.0.0 release

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

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Adding a New Radio (Same Protocol)

Example: Adding IC-705

1. Add radio definition in `Sources/RigControl/Protocols/Icom/IcomModels.swift`:

```swift
public static let icomIC705 = RadioDefinition(
    manufacturer: .icom,
    model: "IC-705",
    defaultBaudRate: 19200,
    capabilities: RigCapabilities(/* ... */),
    civAddress: 0xA4,
    protocolFactory: { transport in
        IcomCIVProtocol(transport: transport, civAddress: 0xA4, capabilities: /* ... */)
    }
)
```

2. Add tests
3. Test with real hardware
4. Submit PR

## License

MIT License - see [LICENSE](LICENSE) for details.

## Authors

- Your Name (@yourusername)

## Acknowledgments

- Icom CI-V protocol documentation
- Amateur radio community
- SSTV application (original implementation)

## Support

- Issues: https://github.com/yourusername/SwiftRigControl/issues
- Discussions: https://github.com/yourusername/SwiftRigControl/discussions
- Email: your.email@example.com

## Roadmap

See [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) for the complete 9-week implementation roadmap.

---

**73 de [YOUR_CALLSIGN]**
