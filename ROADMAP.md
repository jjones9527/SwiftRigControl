# SwiftRigControl - Development Roadmap

**Last Updated:** February 26, 2026
**Current Version:** 1.0.4
**Swift Version:** 6.2 (strict concurrency)
**Minimum Platform:** macOS 14+
**License:** LGPL v3.0

---

## Project Overview

SwiftRigControl is a native Swift library for controlling amateur radio transceivers on macOS. It provides a modern, type-safe, actor-based API using async/await concurrency, with zero external dependencies.

### Hardware-Verified Radios

| Radio | Protocol | Verification Status |
|-------|----------|-------------------|
| Icom IC-7600 | CI-V | Fully verified (HF/6m dual receiver) |
| Icom IC-7100 | CI-V | Fully verified (HF/VHF/UHF) |
| Icom IC-9700 | CI-V | Fully verified (VHF/UHF/1.2GHz satellite) |
| Elecraft K2 | Text CAT | Fully verified (HF QRP) |

### Supported Radio Definitions

80+ radio models across 5 manufacturers (Icom, Elecraft, Yaesu, Kenwood, Xiegu) with capabilities databases and protocol implementations.

### Core Architecture

```
Sources/RigControl/
  Cache/              RadioStateCache (actor-based, 500ms TTL)
  Core/               CATProtocol (30 methods), RadioDefinition
  Models/             15 data models (Mode, VFO, SignalStrength, etc.)
  Network/            RigControlServer (rigctld-compatible TCP)
  Protocols/          5 manufacturer implementations (29 files)
    Icom/             CI-V with per-model command sets
    Elecraft/         K2/K3/K4 text protocol
    Yaesu/            CAT protocol
    Kenwood/          Text protocol
    Xiegu/            G90/X5105 protocol
  RigController/      14 extension files (modular public API)
  Transport/          SerialTransport, IOKitSerialPort
  Utilities/          BCDEncoding, VFOCodeHelper
```

---

## What's Been Accomplished

### v1.0.0 - v1.0.4 (Released)

- [x] Protocol-oriented architecture with `CATProtocol` base (30 methods)
- [x] Actor-based `RigController` with modular extensions (14 files)
- [x] Icom CI-V protocol with dedicated command sets per radio family
- [x] Elecraft text-based protocol (K2, K3, K4)
- [x] Yaesu CAT protocol
- [x] Kenwood text-based protocol
- [x] Xiegu protocol (G90, X5105)
- [x] Frequency, mode, PTT, power, VFO, split control
- [x] RIT/XIT support across all protocols
- [x] DSP controls: AGC, noise blanker, noise reduction, IF filter
- [x] Signal strength (S-meter) reading across all 4 protocol families
- [x] Memory channel operations (read/write/scan)
- [x] `RadioStateCache` actor with configurable TTL (10-20x query speedup)
- [x] Batch configuration API (`configure(frequency:mode:vfo:power:)`)
- [x] `RadioCapabilitiesDatabase` with 80+ radio definitions
- [x] Network control via rigctld-compatible TCP server
- [x] XPC helper for Mac App Store sandboxed applications
- [x] Comprehensive documentation (62 development docs, 9 user guides)
- [x] LGPL v3.0 licensing (follows Hamlib model)
- [x] Hardware validation tools for IC-7100, IC-7600, IC-9700, K2

### Recent Cleanup (February 2026 - In Progress, Uncommitted)

- [x] RigController refactored from monolithic file into 14 extension files
- [x] Swift 6.2 strict concurrency compliance (`swiftLanguageModes: [.v6]`)
- [x] All build warnings eliminated (0 warnings, 0 errors)
- [x] Test suite migrated from XCTest to Swift Testing framework
- [x] All 192 tests passing (8 unit/protocol suites + 4 hardware suites)
- [x] Hardware test suites gated by environment variables
- [x] Executable targets renamed from `main.swift` to descriptive names
- [x] Package.swift reorganized with clear MARK sections
- [x] `RadioStateCache` enhanced with `@Sendable` closure support
- [x] Legacy debug tools archived in `Tests/RigControlTests/Archived/`

---

## Current Sprint: Codebase Stabilization

**Status: IN PROGRESS**
**Goal:** Finalize the uncommitted refactoring work and prepare a clean release.

### Step 1: Commit Current Refactoring

- [ ] Review all uncommitted changes for correctness
- [ ] Commit RigController extension refactoring
- [ ] Commit Swift Testing migration
- [ ] Commit Package.swift cleanup
- [ ] Commit executable target renames
- [ ] Tag release (v1.0.5 or v1.1.0 depending on scope)

### Step 2: Remove Deprecated API Surface

The following deprecated items should be migrated to the newer APIs or removed in the next major version:

- [ ] `IcomCIVProtocol.init(transport:civAddress:capabilities:)` - Replace with `init(transport:civAddress:radioModel:commandSet:capabilities:)`
- [ ] 6 deprecated `RadioDefinition` static properties (`.icomIC9700`, `.icomIC7300`, etc.) - Replace with function-based factory methods (`.icomIC9700()`, `.icomIC7300()`, etc.)

### Step 3: Debug Tool Consolidation

There are currently 16 standalone executable targets for hardware debugging/validation. These add build complexity and maintenance burden.

- [ ] Audit which debug tools are still actively used
- [ ] Archive unused tools (move to `Examples/Archived/`)
- [ ] Consider consolidating into fewer multi-purpose validators
- [ ] Remove archived executable targets from Package.swift

### Step 4: Documentation Refresh

- [ ] Update `ROADMAP.md` with current state (this document)
- [ ] Review and update `README.md` with accurate feature list and version
- [ ] Verify all user-facing docs reflect current API
- [ ] Remove or update stale development docs that reference pre-v1.0 work
- [ ] Update `ADDING_RADIOS.md` to reference new command set architecture

---

## v1.1.0 - State Observation & Developer Experience

**Priority:** HIGH
**Theme:** Reactive state updates and improved developer ergonomics

### Features

#### RigStateObserver Protocol (Not Yet Implemented)

The only major v1.1.0 feature from the development plan that hasn't been implemented yet. All other v1.1.0 features (S-meter, caching, batch config) are already in the codebase.

- [ ] Design `RigStateObserver` protocol with async callbacks
- [ ] Implement weak observer registration in `RigController`
- [ ] Notify observers on frequency, mode, PTT, and power changes
- [ ] Provide default empty implementations for optional methods
- [ ] Add observer unit tests with `MockTransport`
- [ ] Document observer pattern with SwiftUI `@Observable` example

```swift
// Target API
public protocol RigStateObserver: AnyObject, Sendable {
    func frequencyChanged(rig: RigController, vfo: VFO, frequency: UInt64) async
    func modeChanged(rig: RigController, vfo: VFO, mode: Mode) async
    func pttChanged(rig: RigController, enabled: Bool) async
    func signalStrengthChanged(rig: RigController, strength: SignalStrength) async
}
```

#### Connection Health Monitoring

- [ ] Auto-reconnection support with configurable retry policy
- [ ] Connection state change notifications via observer pattern
- [ ] Heartbeat polling (periodic frequency read to detect disconnection)
- [ ] Graceful degradation when connection drops

#### Additional Protocol Tests

- [ ] Add S-meter response parsing tests to all 4 protocol test suites
- [ ] Add DSP control mock tests (AGC, NB, NR, IF filter)
- [ ] Add memory channel operation mock tests
- [ ] Add RIT/XIT mock tests for Icom protocol suite

#### DocC Documentation Generation

- [ ] Add DocC catalog to `Sources/RigControl/`
- [ ] Generate and verify DocC documentation site
- [ ] Host documentation (GitHub Pages or similar)
- [ ] Add code examples to all major public API symbols

---

## v1.2.0 - Multi-Rig & Advanced Control

**Priority:** MEDIUM
**Theme:** Contest and multi-radio operation support

### Features

- [ ] `RigManager` actor for coordinating multiple `RigController` instances
- [ ] VFO synchronization between radios (SO2R support)
- [ ] Band stacking register support
- [ ] CW keyer configuration and message sending
- [ ] Scanning operations (VFO scan, memory scan, programmable scan)
- [ ] Antenna selection control
- [ ] TX meter reading (power out, SWR, ALC)

---

## v1.3.0 - SwiftUI Components

**Priority:** MEDIUM
**Theme:** Pre-built UI components for rapid app development

### Features

- [ ] New `RigControlUI` module (separate library product)
- [ ] `RadioControlView` - Full radio control panel
- [ ] `FrequencyDisplay` - VFO frequency with tuning
- [ ] `ModeSelector` - Mode picker
- [ ] `MeterView` - S-meter and TX meters
- [ ] `BandSelector` - Quick band changes
- [ ] `@Observable` view models using `RigStateObserver`
- [ ] Example SwiftUI application

---

## v2.0.0 - Network & Integration

**Priority:** LOW
**Theme:** Remote operation and ecosystem integration

### Features

- [ ] Enhanced network rig control (multi-client, authentication)
- [ ] Audio routing integration (Core Audio)
- [ ] ADIF export for logging integration
- [ ] Digital mode app integration (WSJT-X, fldigi)
- [ ] Radio simulator for development without hardware
- [ ] CLI tool for testing and scripting
- [ ] Automatic radio detection (serial port scanning)

### Potential Breaking Changes

- Potential `CATProtocol` refinements
- Swift 7 language mode adoption (when available)
- Minimum macOS version bump if needed

---

## Future Considerations

### Additional Manufacturer Support

| Manufacturer | Priority | Notes |
|-------------|----------|-------|
| FlexRadio | Medium | SmartSDR CAT over TCP/IP; Flex-6400/6600/6700 |
| Lab599 | Low | TX-500 QRP portable; Kenwood-like protocol |
| QRP Labs | Low | QDX/QMX digital transceivers |

### Cross-Platform

| Platform | Priority | Challenges |
|----------|----------|------------|
| Linux | Low | No IOKit; needs SwiftNIO or similar for serial |
| visionOS | Low | UI components would need adaptation |

### Advanced Radio Features

| Feature | Radios | Priority |
|---------|--------|----------|
| Spectrum scope streaming | IC-7300, IC-7610 | Medium |
| Satellite Doppler correction | IC-9700 | Medium |
| Dual receiver independent control | IC-7610, FTDX-101D/MP | Low |
| Roofing filter selection | IC-7610, TS-890S | Low |

---

## Out of Scope

The following are explicitly not planned, to maintain focus:

- **Vintage radio support** (pre-1990s, no CAT control)
- **Rotator control** (different domain, well-served by other tools)
- **Amplifier control** (niche use case)
- **DX cluster integration** (application-level concern)
- **Contest logging** (application responsibility)
- **Windows support** (Swift on Windows immaturity)

---

## Development Principles

1. **Zero dependencies** - Keep the library self-contained
2. **No breaking changes in v1.x** - Additive API only; use deprecation
3. **Test before merge** - All changes must include appropriate tests
4. **Hardware-verify before claiming support** - Don't claim "verified" without real hardware testing
5. **Swift 6 best practices** - Strict concurrency, actors, Sendable types
6. **Document as you go** - Update docs alongside code changes
7. **Quality over quantity** - Deep support for popular radios over breadth

---

## Hardware Available for Testing

| Radio | Interface | Notes |
|-------|-----------|-------|
| Icom IC-7100 | USB (serial) | HF/VHF/UHF, 100W |
| Icom IC-7600 | USB (serial) | HF/6m dual receiver, 100W |
| Icom IC-9700 | USB (serial) | VHF/UHF/1.2GHz SDR, satellite capable |
| Elecraft K2 | USB (serial) | HF QRP, 0-15W |

---

## Test Suite Summary

| Suite | Tests | Status | Notes |
|-------|-------|--------|-------|
| BCDEncodingTests | 14 | Passing | BCD encode/decode for Icom CI-V |
| CIVFrameTests | 12 | Passing | CI-V frame construction and parsing |
| CIVCommandSetTests | 23 | Passing | IC-7100, IC-9700, Standard command sets |
| RadioCapabilitiesTests | 17 | Passing | Frequency ranges, modes, transmit checks |
| IcomProtocolTests | 10 | Passing | Mock transport, PTT/freq/mode/errors |
| ElecraftProtocolTests | ~15 | Passing | Mock transport protocol tests |
| KenwoodProtocolTests | ~15 | Passing | Mock transport protocol tests |
| YaesuCATProtocolTests | ~15 | Passing | Mock transport protocol tests |
| IC7100HardwareTests | ~12 | Skipped (no hardware) | Gated by `IC7100_SERIAL_PORT` env var |
| IC7600HardwareTests | ~14 | Skipped (no hardware) | Gated by `IC7600_SERIAL_PORT` env var |
| IC9700HardwareTests | ~20 | Skipped (no hardware) | Gated by `IC9700_SERIAL_PORT` env var |
| K2HardwareTests | ~14 | Skipped (no hardware) | Gated by `K2_SERIAL_PORT` env var |
| **Total** | **192** | **All passing** | Swift Testing framework |

---

## Competitive Positioning

### vs. Hamlib

| Aspect | SwiftRigControl | Hamlib |
|--------|----------------|--------|
| **Language** | Swift 6.2 | C (C89/C99) |
| **Radio Coverage** | 80+ definitions, 4 hardware-verified | 350+ |
| **Platform** | macOS 14+ | Cross-platform |
| **API Design** | Modern, type-safe, async/await | Function pointers |
| **Concurrency** | Actors, structured concurrency | Synchronous + locks |
| **Type Safety** | Full Swift types, enums | Integer codes |
| **Performance** | 10-20x (cached queries) | Baseline |
| **Testing** | Swift Testing framework | C test suite |
| **Dependencies** | Zero | Multiple C libraries |

**Positioning:** The modern, Swift-native alternative to Hamlib for macOS developers who want type safety, modern concurrency, and a clean API.

---

*73 de VA3ZTF*
