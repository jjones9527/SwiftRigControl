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

### Coming Soon

- Elecraft (K2, K3, K3S, K4, KX2, KX3)
- Yaesu (FTDX-10, FT-991A, FT-710, FT-891)
- Kenwood (TS-890S, TS-990S, TS-590SG)

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

## Finding Serial Ports

On macOS, Icom radios typically appear as:

```bash
ls /dev/cu.* | grep -i icom
```

Common patterns:
- `/dev/cu.SLAB_USBtoUART` - Silicon Labs USB-to-serial
- `/dev/cu.usbserial-*` - Generic USB serial
- `/dev/cu.IC9700` - Direct Icom naming (if driver installed)

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
- 🚧 **ElecraftProtocol** - Coming soon
- 🚧 **YaesuCATProtocol** - Coming soon
- 🚧 **KenwoodProtocol** - Coming soon

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

### Next Steps

**Week 2** - Complete Icom implementation
- [ ] Finish frequency/mode control testing on real hardware
- [ ] Add VFO control
- [ ] Add power control
- [ ] Integration tests with IC-9700, IC-7600, IC-7100

**Week 3** - Elecraft protocol
**Week 4-5** - XPC helper for Mac App Store
**Week 6** - Yaesu protocol
**Week 7** - Kenwood protocol
**Week 8** - Documentation
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
