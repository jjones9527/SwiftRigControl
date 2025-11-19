# Changelog

All notable changes to SwiftRigControl will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-19

### Added

#### Core Library
- Native Swift library for amateur radio transceiver control on macOS
- Modern async/await API for all radio operations
- Actor-based concurrency for thread-safe operations
- Protocol-oriented design with `CATProtocol` abstraction
- Type-safe enums for VFO, Mode, and error handling
- Automatic memory management with ARC

#### Radio Support (24 Radios)

**Icom CI-V Protocol (6 Radios)**
- IC-9700 (VHF/UHF/1.2GHz, 115200 baud, 100W)
- IC-7610 (HF/6m SDR, 115200 baud, 100W, Dual RX)
- IC-7300 (HF/6m, 115200 baud, 100W)
- IC-7600 (HF/6m, 19200 baud, 100W, Dual RX)
- IC-7100 (HF/VHF/UHF, 19200 baud, 100W)
- IC-705 (Portable, 19200 baud, 10W)

**Elecraft Protocol (6 Radios)**
- K4 (HF/6m SDR, 38400 baud, 100W, Dual RX)
- K3S (HF/6m Enhanced, 38400 baud, 100W, Dual RX)
- K3 (HF/6m, 38400 baud, 100W, Dual RX)
- KX3 (Portable HF/6m, 38400 baud, 15W)
- KX2 (Portable HF, 38400 baud, 12W)
- K2 (HF, 4800 baud, 15W)

**Yaesu CAT Protocol (6 Radios)**
- FTDX-101D (HF/6m, 38400 baud, 100W, Dual RX)
- FTDX-10 (HF/6m, 38400 baud, 100W)
- FT-991A (HF/VHF/UHF, 38400 baud, 100W)
- FT-710 (HF/6m, 38400 baud, 100W)
- FT-891 (HF/6m, 38400 baud, 100W)
- FT-817 (Portable QRP, 38400 baud, 5W)

**Kenwood Protocol (6 Radios)**
- TS-990S (Flagship HF/6m, 115200 baud, 200W, Dual RX)
- TS-890S (HF/6m, 115200 baud, 100W, Dual RX)
- TS-590SG (HF/6m, 115200 baud, 100W)
- TS-2000 (HF/VHF/UHF, 57600 baud, 100W)
- TS-480SAT (HF/6m, 57600 baud, 100W)
- TM-D710 (VHF/UHF, 57600 baud, 50W, Dual RX)

#### Protocol Implementations

**IcomCIVProtocol (Binary Protocol)**
- CI-V binary protocol with BCD frequency encoding
- Automatic ACK/NAK response handling
- Address-based radio communication
- Supports all Icom-specific features
- 42+ unit tests

**ElecraftProtocol (Text-Based)**
- ASCII text-based command protocol
- Echo-based acknowledgment
- Auto-info disable on connect
- 15 unit tests

**YaesuCATProtocol (Text-Based)**
- Kenwood-compatible CAT commands
- TX1/TX0 PTT control (Yaesu-specific)
- 9 mode mappings including DATA modes
- 15 unit tests

**KenwoodProtocol (Text-Based)**
- Native Kenwood command set
- FR0/FR1 VFO selection (Kenwood-specific)
- Supports up to 200W power control
- 17 unit tests including dual receiver tests

#### Operations

- Frequency control (set/get) for VFO A/B and Main/Sub
- Mode control (LSB, USB, CW, CW-R, FM, FM-N, AM, RTTY, DATA-LSB, DATA-USB)
- PTT (Push-To-Talk) control with enable/disable and status query
- VFO selection (A/B, Main/Sub with automatic mapping)
- Split operation (enable/disable/query)
- Power control in watts with automatic percentage conversion
- Radio capabilities query

#### Transport Layer

**IOKitSerialPort**
- Direct IOKit integration for serial communication
- No external dependencies
- Terminator-based frame reading
- Proper termios configuration for raw mode
- Automatic buffer flushing
- Timeout support

#### XPC Helper (Mac App Store Compatibility)

**XPCProtocol**
- Objective-C protocol for cross-process communication
- Complete operation coverage

**XPCClient**
- Actor-based client with async/await interface
- Singleton pattern for app-wide access
- Automatic reconnection support
- Type-safe Swift API wrapping XPC callbacks

**XPCServer**
- Bridges XPC calls to RigControl library
- String-based radio model lookup for all 24 radios
- Error translation to XPC-compatible types

**RigControlHelper**
- Standalone XPC service executable
- Mach service: com.swiftrigcontrol.helper
- SMJobBless compatible

#### Testing

**Unit Tests (89+ tests)**
- BCD encoding/decoding tests
- CI-V frame construction tests
- Protocol command generation tests
- Mock transport for hardware-free testing
- Error handling validation
- All protocol implementations tested

**Integration Tests (10 tests)**
- Real hardware testing support
- Auto-detection of radio model from port name
- Frequency control validation
- Mode switching verification
- PTT operation testing
- Split operation validation
- VFO control testing

#### Documentation (3,300+ lines)

**README.md**
- Quick start guide
- Installation instructions
- Supported radios list
- Architecture overview
- Quick reference tables (radio specs, protocol comparison, modes)
- Common use cases

**USAGE_EXAMPLES.md (615 lines)**
- Basic operations examples
- Digital mode applications (SSTV, FT8/FT4, PSK31)
- Split operation examples
- Power control patterns
- Multi-VFO operations
- Error handling patterns
- Mac App Store/XPC usage
- SwiftUI integration examples
- Logging and monitoring patterns

**TROUBLESHOOTING.md (580 lines)**
- Connection issue solutions
- Command failure diagnosis
- Serial port problem resolution
- XPC helper troubleshooting
- Radio-specific issues
- Performance optimization
- Build and integration issues
- Complete diagnostic checklist

**SERIAL_PORT_GUIDE.md (645 lines)**
- Finding serial ports on macOS
- Radio-specific configuration for all 24 radios
- USB driver installation guides
- Testing serial communication
- Advanced configuration
- Quick reference for all manufacturers

**HAMLIB_MIGRATION.md (570 lines)**
- Complete migration guide from Hamlib C library
- Architecture comparison
- Side-by-side code examples
- Error handling conversion
- Feature comparison matrix
- Complete migration example
- Common gotchas and solutions

**XPC_HELPER_GUIDE.md (580 lines)**
- SMJobBless setup and installation
- XPC client/server implementation
- Mac App Store sandboxing solutions
- Complete SwiftUI example application
- Troubleshooting XPC issues

**Week Completion Documents**
- WEEK1_COMPLETION.md - Foundation and Icom
- WEEK2_AND_3_COMPLETION.md - Elecraft and split operation
- WEEK4_AND_5_COMPLETION.md - XPC helper
- WEEK6_AND_7_COMPLETION.md - Yaesu and Kenwood
- RELEASE_NOTES_v1.0.0.md - v1.0.0 release details

#### Utilities

**BCDEncoding**
- Little-endian BCD encoding for Icom frequency representation
- 5-byte frequency encoding/decoding
- Error handling for invalid BCD values

**RadioDefinition**
- Type-safe radio model registry
- Protocol factory pattern
- Capabilities metadata
- Manufacturer enum

**RigCapabilities**
- Feature flags (VFO B, split, power control, etc.)
- Supported modes list
- Frequency range
- Maximum power
- Dual receiver indication
- ATU (Antenna Tuner) indication

**RigError**
- Typed error enum for all failure cases
- notConnected, timeout, commandFailed
- unsupportedOperation, invalidParameter
- invalidResponse

### Development Process

#### Week 1 - Foundation and Icom CI-V
- Project structure and module organization
- Core protocol definitions
- IOKit serial port implementation
- Type-safe models
- Icom CI-V protocol implementation
- BCD encoding utilities
- 6 Icom radio definitions
- RigController API
- 42+ unit tests

#### Week 2 & 3 - Split Operation and Elecraft
- Split operation support across all protocols
- Integration tests for real hardware
- ElecraftProtocol implementation
- 6 Elecraft radio definitions
- 15 Elecraft unit tests

#### Week 4 & 5 - XPC Helper
- XPC protocol definition
- XPCClient with async/await interface
- XPCServer bridging to RigControl
- RigControlHelper executable
- XPC helper documentation

#### Week 6 & 7 - Yaesu and Kenwood
- YaesuCATProtocol implementation
- 6 Yaesu radio definitions
- 15 Yaesu unit tests
- KenwoodProtocol implementation
- 6 Kenwood radio definitions
- 17 Kenwood unit tests
- XPC server support for all new radios

#### Week 8 - Documentation Refinement
- USAGE_EXAMPLES.md (615 lines)
- TROUBLESHOOTING.md (580 lines)
- SERIAL_PORT_GUIDE.md (645 lines)
- HAMLIB_MIGRATION.md (570 lines)
- README.md quick reference tables

#### Week 9 - v1.0.0 Release
- Release notes
- CHANGELOG.md
- CONTRIBUTING.md
- Final testing and verification
- Version tagging
- GitHub release

### Technical Details

**Requirements**
- macOS 13.0 or later
- Swift 5.9 or later
- Xcode 15.0 or later (for development)

**Architecture**
- Protocol-oriented design
- Actor-based concurrency
- Async/await throughout
- No external dependencies
- Direct IOKit integration

**Performance**
- Command latency: 10-80ms (varies by radio/operation)
- Memory footprint: 2-3 MB typical
- Zero memory leaks (ARC-managed)
- Thread-safe by design

**Code Metrics**
- Core library: ~3,500 lines
- Protocol implementations: ~2,800 lines
- XPC helper: ~800 lines
- Test suite: ~2,200 lines
- Documentation: ~3,300 lines
- Total: ~12,600 lines

## [Unreleased]

### Planned for v1.1.0
- S-meter reading support
- TX meter reading (power, SWR, ALC)
- Additional radio models
- RIT/XIT (clarifier) support
- Antenna selection

### Planned for v1.2.0
- Channel memory operations
- Scanning functionality
- Preamp/attenuator control
- Filter selection
- Band stacking registers

### Planned for v2.0.0
- Network rig control (rigctld protocol)
- Audio routing integration
- Automatic radio detection
- CI/CD pipeline
- Performance optimizations

## Version History

- **1.0.0** (2025-11-19) - Initial production release

---

**Note:** This is the initial v1.0.0 release. Future versions will continue to document changes in this file following the [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format.

For detailed information about the v1.0.0 release, see [RELEASE_NOTES_v1.0.0.md](RELEASE_NOTES_v1.0.0.md).
