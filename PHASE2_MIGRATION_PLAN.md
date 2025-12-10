# Phase 2 Migration Plan: Radio-Specific Command Tables

## Executive Summary

This document outlines the Phase 2 refactoring of SwiftRigControl's Icom CI-V implementation, transitioning from capability flags to radio-specific command tables. This migration will fix current issues (power control units) and establish a scalable architecture for supporting 30+ Icom radio models.

**Timeline**: 4-6 weeks for core refactoring + ongoing radio additions

**Status**: Phase 1 Complete (capability flags), Phase 2 Planning

---

## Phase 1 Accomplishments (Completed)

### ✅ Issues Fixed
- **Mode Command Filter Byte**: IC-7100/IC-705 reject filter byte → `requiresModeFilter: false`
- **VFO Selection**: IC-7100/IC-705 don't require VFO select → `requiresVFOSelection: false`
- **PTT Command Structure**: Updated to `0x1C 0x00` sub-command format for all radios
- **Echo Frame Handling**: Automatic detection and skip for IC-7100/IC-705 command echoes

### ⚠️ Known Issues Requiring Phase 2
1. **Power Control Units Mismatch**:
   - IC-7100/IC-705 use percentage (0-100%), not watts
   - Current code shows "196W" when radio displays "100%"
   - Affects `setPower()` and `getPower()` methods

2. **Limited Radio Support**:
   - Only 5 radios currently defined
   - Hamlib supports 30+ Icom models
   - Need systematic approach for adding radios

3. **Maintainability Concerns**:
   - Capability flags becoming unwieldy
   - Hard to document radio-specific quirks
   - Difficult to test individual radio variations

---

## Phase 2 Goals

### Primary Objectives
1. **Fix Power Control** for IC-7100/IC-705 (percentage vs watts)
2. **Implement CIVCommandSet Protocol** for radio-specific command tables
3. **Add High-Priority Radios** from Hamlib (current generation + popular models)
4. **Establish Testing Framework** for per-radio validation

### Success Criteria
- ✅ Power control displays correct units on all radios
- ✅ CIVCommandSet protocol implemented with 3+ radio examples
- ✅ 10+ additional Icom radios supported
- ✅ Per-radio test suite established
- ✅ Zero regression in existing IC-7100/IC-9700 functionality

---

## Architecture: CIVCommandSet Protocol

### Design Overview

The CIVCommandSet protocol defines radio-specific command formatting while keeping the core CI-V transport and frame structure common.

```swift
/// Protocol defining radio-specific CI-V command formatting
public protocol CIVCommandSet {
    /// Radio's CI-V address
    var civAddress: UInt8 { get }

    /// Power units used by this radio
    var powerUnits: PowerUnits { get }

    /// Whether radio echoes commands before response
    var echoesCommands: Bool { get }

    /// Format a mode set command
    /// - Parameters:
    ///   - mode: The operating mode to set
    /// - Returns: Command bytes and data bytes
    func setModeCommand(mode: UInt8) -> (command: [UInt8], data: [UInt8])

    /// Format a mode read command
    /// - Returns: Command bytes
    func readModeCommand() -> [UInt8]

    /// Parse a mode response
    /// - Parameter response: CI-V frame response
    /// - Returns: Mode code
    func parseModeResponse(_ response: CIVFrame) throws -> UInt8

    /// Format a power set command
    /// - Parameter value: Power value (watts or percentage depending on powerUnits)
    /// - Returns: Command bytes and data bytes
    func setPowerCommand(value: Int) -> (command: [UInt8], data: [UInt8])

    /// Format a power read command
    /// - Returns: Command bytes
    func readPowerCommand() -> [UInt8]

    /// Parse a power response
    /// - Parameter response: CI-V frame response
    /// - Returns: Power value (watts or percentage depending on powerUnits)
    func parsePowerResponse(_ response: CIVFrame) throws -> Int

    /// Format a PTT set command
    /// - Parameter enabled: Whether PTT should be enabled
    /// - Returns: Command bytes and data bytes
    func setPTTCommand(enabled: Bool) -> (command: [UInt8], data: [UInt8])

    /// Format a PTT read command
    /// - Returns: Command bytes
    func readPTTCommand() -> [UInt8]

    /// Parse a PTT response
    /// - Parameter response: CI-V frame response
    /// - Returns: PTT state (true = transmitting)
    func parsePTTResponse(_ response: CIVFrame) throws -> Bool

    /// Format a VFO select command
    /// - Parameter vfo: VFO to select
    /// - Returns: Command bytes and data bytes, or nil if not supported
    func selectVFOCommand(_ vfo: VFO) -> (command: [UInt8], data: [UInt8])?
}
```

### Power Units Enum

```swift
/// Power control units used by different Icom radios
public enum PowerUnits: Sendable, Codable {
    /// Power specified in watts (0 to max watts)
    /// Used by: IC-9700, IC-7300, IC-7610, IC-7600
    case watts(max: Int)

    /// Power specified as percentage (0-100%)
    /// Used by: IC-7100, IC-705
    case percentage

    /// Convert from watts to BCD scale (0-255)
    func wattsToScale(_ watts: Int) -> Int {
        switch self {
        case .watts(let max):
            return (watts * 255) / max
        case .percentage:
            // For percentage radios, treat input as percentage
            return (watts * 255) / 100
        }
    }

    /// Convert from BCD scale (0-255) to watts or percentage
    func scaleToWatts(_ scale: Int) -> Int {
        switch self {
        case .watts(let max):
            return (scale * max) / 255
        case .percentage:
            // For percentage radios, return percentage value
            return (scale * 100) / 255
        }
    }

    /// Display units for user interface
    var displayUnit: String {
        switch self {
        case .watts: return "W"
        case .percentage: return "%"
        }
    }
}
```

---

## Implementation Examples

### Example 1: IC-7100 Command Set

```swift
/// CI-V command set for Icom IC-7100
public struct IC7100CommandSet: CIVCommandSet {
    public let civAddress: UInt8 = 0x88
    public let powerUnits: PowerUnits = .percentage
    public let echoesCommands: Bool = true

    public func setModeCommand(mode: UInt8) -> (command: [UInt8], data: [UInt8]) {
        // IC-7100 rejects mode commands with filter byte
        return ([0x06], [mode])
    }

    public func readModeCommand() -> [UInt8] {
        return [0x04]
    }

    public func parseModeResponse(_ response: CIVFrame) throws -> UInt8 {
        guard response.command[0] == 0x04,
              !response.data.isEmpty else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }

    public func setPowerCommand(value: Int) -> (command: [UInt8], data: [UInt8]) {
        // IC-7100 uses percentage (0-100)
        let percentage = min(max(value, 0), 100)
        let scale = (percentage * 255) / 100
        let bcd = BCDEncoding.encodePower(scale)
        return ([0x14, 0x0A], bcd)
    }

    public func readPowerCommand() -> [UInt8] {
        return [0x14, 0x0A]
    }

    public func parsePowerResponse(_ response: CIVFrame) throws -> Int {
        guard response.command.count >= 2,
              response.command[0] == 0x14,
              response.command[1] == 0x0A,
              response.data.count >= 2 else {
            throw RigError.invalidResponse
        }
        let scale = BCDEncoding.decodePower(response.data)
        return (scale * 100) / 255  // Return percentage
    }

    public func setPTTCommand(enabled: Bool) -> (command: [UInt8], data: [UInt8]) {
        return ([0x1C, 0x00], [enabled ? 0x01 : 0x00])
    }

    public func readPTTCommand() -> [UInt8] {
        return [0x1C, 0x00]
    }

    public func parsePTTResponse(_ response: CIVFrame) throws -> Bool {
        guard response.command.count >= 2,
              response.command[0] == 0x1C,
              response.command[1] == 0x00,
              !response.data.isEmpty else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    public func selectVFOCommand(_ vfo: VFO) -> (command: [UInt8], data: [UInt8])? {
        // IC-7100 doesn't require VFO selection
        return nil
    }
}
```

### Example 2: IC-9700 Command Set

```swift
/// CI-V command set for Icom IC-9700
public struct IC9700CommandSet: CIVCommandSet {
    public let civAddress: UInt8 = 0xA2
    public let powerUnits: PowerUnits = .watts(max: 100)
    public let echoesCommands: Bool = false

    public func setModeCommand(mode: UInt8) -> (command: [UInt8], data: [UInt8]) {
        // IC-9700 requires filter byte (0x00 = default filter)
        return ([0x06], [mode, 0x00])
    }

    public func readModeCommand() -> [UInt8] {
        return [0x04]
    }

    public func parseModeResponse(_ response: CIVFrame) throws -> UInt8 {
        guard response.command[0] == 0x04,
              !response.data.isEmpty else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }

    public func setPowerCommand(value: Int) -> (command: [UInt8], data: [UInt8]) {
        // IC-9700 uses watts (0-100W)
        let watts = min(max(value, 0), 100)
        let scale = (watts * 255) / 100
        let bcd = BCDEncoding.encodePower(scale)
        return ([0x14, 0x0A], bcd)
    }

    public func readPowerCommand() -> [UInt8] {
        return [0x14, 0x0A]
    }

    public func parsePowerResponse(_ response: CIVFrame) throws -> Int {
        guard response.command.count >= 2,
              response.command[0] == 0x14,
              response.command[1] == 0x0A,
              response.data.count >= 2 else {
            throw RigError.invalidResponse
        }
        let scale = BCDEncoding.decodePower(response.data)
        return (scale * 100) / 255  // Return watts
    }

    public func setPTTCommand(enabled: Bool) -> (command: [UInt8], data: [UInt8]) {
        return ([0x1C, 0x00], [enabled ? 0x01 : 0x00])
    }

    public func readPTTCommand() -> [UInt8] {
        return [0x1C, 0x00]
    }

    public func parsePTTResponse(_ response: CIVFrame) throws -> Bool {
        guard response.command.count >= 2,
              response.command[0] == 0x1C,
              response.command[1] == 0x00,
              !response.data.isEmpty else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    public func selectVFOCommand(_ vfo: VFO) -> (command: [UInt8], data: [UInt8])? {
        // IC-9700 requires VFO selection
        let vfoCode: UInt8
        switch vfo {
        case .a: vfoCode = 0x00
        case .b: vfoCode = 0x01
        case .main: vfoCode = 0x00
        case .sub: vfoCode = 0x01
        }
        return ([0x07], [vfoCode])
    }
}
```

### Example 3: Standard Icom Command Set (Base Implementation)

```swift
/// Standard CI-V command set used by most modern Icom radios
/// Can be subclassed for radios with minor variations
public struct StandardIcomCommandSet: CIVCommandSet {
    public let civAddress: UInt8
    public let powerUnits: PowerUnits
    public let echoesCommands: Bool
    private let requiresVFOSelection: Bool

    public init(civAddress: UInt8, maxPower: Int, echoesCommands: Bool = false, requiresVFOSelection: Bool = true) {
        self.civAddress = civAddress
        self.powerUnits = .watts(max: maxPower)
        self.echoesCommands = echoesCommands
        self.requiresVFOSelection = requiresVFOSelection
    }

    // Standard implementations that work for most radios
    public func setModeCommand(mode: UInt8) -> (command: [UInt8], data: [UInt8]) {
        return ([0x06], [mode, 0x00])  // Standard: mode + filter
    }

    public func readModeCommand() -> [UInt8] {
        return [0x04]
    }

    public func parseModeResponse(_ response: CIVFrame) throws -> UInt8 {
        guard response.command[0] == 0x04,
              !response.data.isEmpty else {
            throw RigError.invalidResponse
        }
        return response.data[0]
    }

    public func setPowerCommand(value: Int) -> (command: [UInt8], data: [UInt8]) {
        let scale = powerUnits.wattsToScale(value)
        let bcd = BCDEncoding.encodePower(scale)
        return ([0x14, 0x0A], bcd)
    }

    public func readPowerCommand() -> [UInt8] {
        return [0x14, 0x0A]
    }

    public func parsePowerResponse(_ response: CIVFrame) throws -> Int {
        guard response.command.count >= 2,
              response.command[0] == 0x14,
              response.command[1] == 0x0A,
              response.data.count >= 2 else {
            throw RigError.invalidResponse
        }
        let scale = BCDEncoding.decodePower(response.data)
        return powerUnits.scaleToWatts(scale)
    }

    public func setPTTCommand(enabled: Bool) -> (command: [UInt8], data: [UInt8]) {
        return ([0x1C, 0x00], [enabled ? 0x01 : 0x00])
    }

    public func readPTTCommand() -> [UInt8] {
        return [0x1C, 0x00]
    }

    public func parsePTTResponse(_ response: CIVFrame) throws -> Bool {
        guard response.command.count >= 2,
              response.command[0] == 0x1C,
              response.command[1] == 0x00,
              !response.data.isEmpty else {
            throw RigError.invalidResponse
        }
        return response.data[0] == 0x01
    }

    public func selectVFOCommand(_ vfo: VFO) -> (command: [UInt8], data: [UInt8])? {
        guard requiresVFOSelection else { return nil }

        let vfoCode: UInt8
        switch vfo {
        case .a: vfoCode = 0x00
        case .b: vfoCode = 0x01
        case .main: vfoCode = 0x00
        case .sub: vfoCode = 0x01
        }
        return ([0x07], [vfoCode])
    }
}
```

---

## Migration Steps

### Step 1: Add PowerUnits Enum (Week 1)

**Files to Modify**:
- `Sources/RigControl/Models/RigCapabilities.swift`

**Changes**:
1. Add `PowerUnits` enum with watts/percentage cases
2. Add `powerUnits: PowerUnits` property to `RigCapabilities`
3. Update existing radio definitions in `RadioCapabilitiesDatabase.swift`

**Testing**:
- Unit tests for PowerUnits conversion methods
- Verify no regression in existing functionality

### Step 2: Fix Power Control (Week 1)

**Files to Modify**:
- `Sources/RigControl/Protocols/Icom/IcomCIVProtocol.swift`

**Changes**:
1. Update `setPower(_ watts: Int)` to use `capabilities.powerUnits`
2. Update `getPower()` to return correct units based on `capabilities.powerUnits`
3. Update method documentation to clarify units

**Testing**:
- IC-7100 hardware test: Set 50%, verify radio shows 50% (not ~50W)
- IC-9700 hardware test: Set 50W, verify radio shows 50W

### Step 3: Create CIVCommandSet Protocol (Week 2)

**Files to Create**:
- `Sources/RigControl/Protocols/Icom/CIVCommandSet.swift`
- `Sources/RigControl/Protocols/Icom/CommandSets/IC7100CommandSet.swift`
- `Sources/RigControl/Protocols/Icom/CommandSets/IC9700CommandSet.swift`
- `Sources/RigControl/Protocols/Icom/CommandSets/StandardIcomCommandSet.swift`

**Changes**:
1. Define `CIVCommandSet` protocol
2. Implement IC7100CommandSet, IC9700CommandSet, StandardIcomCommandSet
3. Add unit tests for each command set

**Testing**:
- Unit tests for command formatting
- Response parsing tests with sample data

### Step 4: Refactor IcomCIVProtocol (Week 3)

**Files to Modify**:
- `Sources/RigControl/Protocols/Icom/IcomCIVProtocol.swift`

**Changes**:
1. Add `commandSet: any CIVCommandSet` property
2. Update `setMode()`, `getMode()`, `setPower()`, `getPower()`, `setPTT()`, `getPTT()` to use command set
3. Keep capability flags for backward compatibility (mark as deprecated)
4. Update initializer to accept command set

**Testing**:
- IC-7100 regression test (all commands)
- IC-9700 regression test (all commands)
- Verify backward compatibility with old initialization

### Step 5: Add High-Priority Radios (Weeks 4-6)

**Priority Order**:

**Tier 1 (Current Generation - Week 4)**:
- IC-705 (HF/VHF/UHF portable) - Similar to IC-7100
- IC-7300 (HF entry-level) - Standard command set
- IC-7610 (HF high-end) - Standard command set

**Tier 2 (Popular Models - Week 5)**:
- IC-9100 (HF/VHF/UHF) - Standard command set
- IC-7200 (HF mid-range) - Standard command set
- IC-7600 (HF high-end) - Standard command set

**Tier 3 (Legacy Popular - Week 6)**:
- IC-7000 (HF/VHF/UHF mobile) - May need custom command set
- IC-746PRO (HF/6M) - Older CI-V format
- IC-756PROIII (HF/6M) - Older CI-V format

**Files to Modify**:
- `Sources/RigControl/Models/RadioCapabilitiesDatabase.swift`
- `Sources/RigControl/Protocols/Icom/CommandSets/` (new command sets as needed)

**Testing Strategy per Radio**:
1. Find official CI-V manual
2. Create radio-specific command set (or use StandardIcomCommandSet)
3. Define capabilities in RadioCapabilitiesDatabase
4. Create unit tests
5. If hardware available, run live tests
6. Document in TECHNICAL_NOTES.md

---

## Complete Radio Support List (from Hamlib)

### Current Generation (2020+) - PRIORITY 1
| Radio | CI-V Addr | Max Power | Notes |
|-------|-----------|-----------|-------|
| IC-705 | 0xA4 | 10W | HF/VHF/UHF portable, similar to IC-7100 |
| IC-9700 | 0xA2 | 100W | VHF/UHF/1.2GHz, dual receiver |
| IC-7610 | 0x98 | 100W | HF/50MHz, dual receiver, network control |
| IC-7300 | 0x94 | 100W | HF/50MHz entry-level, very popular |
| IC-905 | 0xAC | 10W | Microwave transceiver (10/24/47/122 GHz) |

### Popular Models (2010-2020) - PRIORITY 2
| Radio | CI-V Addr | Max Power | Notes |
|-------|-----------|-----------|-------|
| IC-7100 | 0x88 | 100W | HF/VHF/UHF mobile, already supported |
| IC-9100 | 0x7C | 100W | HF/VHF/UHF, dual receiver |
| IC-7200 | 0x76 | 100W | HF/50MHz mid-range |
| IC-7600 | 0x7A | 100W | HF/50MHz high-end |
| IC-7410 | 0x80 | 100W | HF/50MHz |
| ID-5100 | 0x86 | 50W | VHF/UHF mobile with D-STAR |
| ID-4100 | 0x76 | 65W | VHF/UHF mobile with D-STAR |

### Legacy Models (2000-2010) - PRIORITY 3
| Radio | CI-V Addr | Max Power | Notes |
|-------|-----------|-----------|-------|
| IC-7000 | 0x70 | 100W | HF/VHF/UHF mobile |
| IC-7700 | 0x74 | 200W | HF/50MHz high-end |
| IC-7800 | 0x6A | 200W | HF/50MHz flagship |
| IC-746PRO | 0x66 | 100W | HF/VHF |
| IC-756PROIII | 0x6E | 100W | HF/6M |
| IC-910H | 0x60 | 100W | VHF/UHF/1.2GHz |

### Receivers - PRIORITY 4
| Radio | CI-V Addr | Notes |
|-------|-----------|-------|
| IC-R8600 | 0x96 | Wideband receiver |
| IC-R9500 | 0x7A | Communications receiver |
| IC-R75 | 0x5A | HF receiver |
| IC-R30 | 0x9C | Handheld receiver |
| IC-R20 | 0x6C | Handheld receiver |

### Older Models (1990s-2000s) - PRIORITY 5
| Radio | CI-V Addr | Max Power | Notes |
|-------|-----------|-----------|-------|
| IC-706MkIIG | 0x58 | 100W | HF/VHF/UHF compact |
| IC-706MkII | 0x4E | 100W | HF/VHF compact |
| IC-706 | 0x48 | 100W | HF/VHF compact |
| IC-718 | 0x5E | 100W | HF entry-level |
| IC-707 | 0x3E | 100W | HF mobile |

---

## Testing Framework

### Unit Tests (Required for Each Radio)

**Test File Template**: `Tests/RigControlTests/CommandSets/IC{MODEL}CommandSetTests.swift`

```swift
import XCTest
@testable import RigControl

final class IC7100CommandSetTests: XCTestCase {
    var commandSet: IC7100CommandSet!

    override func setUp() {
        super.setUp()
        commandSet = IC7100CommandSet()
    }

    func testSetModeCommand() {
        let (command, data) = commandSet.setModeCommand(mode: 0x01)
        XCTAssertEqual(command, [0x06])
        XCTAssertEqual(data, [0x01])  // No filter byte for IC-7100
    }

    func testSetPowerCommand() {
        // Test 50% power
        let (command, data) = commandSet.setPowerCommand(value: 50)
        XCTAssertEqual(command, [0x14, 0x0A])
        // 50% = 127.5 scale ≈ 0x0127 BCD
        // Verify BCD encoding
    }

    func testParsePowerResponse() throws {
        // Mock response with 100% power (0x0255 BCD)
        let frame = CIVFrame(
            to: 0xE0,
            from: 0x88,
            command: [0x14, 0x0A],
            data: [0x55, 0x02]
        )
        let power = try commandSet.parsePowerResponse(frame)
        XCTAssertEqual(power, 100)  // Should return percentage
    }

    func testVFOSelectionNotSupported() {
        let cmd = commandSet.selectVFOCommand(.a)
        XCTAssertNil(cmd)  // IC-7100 doesn't support VFO select
    }
}
```

### Hardware Tests (Optional but Recommended)

**Test File Template**: `Tests/IC{MODEL}LiveTest.swift`

```swift
import Foundation
import RigControl

@main
struct IC7100LiveTest {
    static func main() async {
        print("IC-7100 Live Hardware Test")
        print("===========================\n")

        // Connection setup
        let config = SerialConfiguration(path: "/dev/cu.usbserial-XXXX", baudRate: 19200)
        let transport = IOKitSerialPort(configuration: config)

        do {
            let commandSet = IC7100CommandSet()
            let capabilities = RadioCapabilitiesDatabase.icomIC7100
            let protocol = IcomCIVProtocol(
                transport: transport,
                civAddress: commandSet.civAddress,
                capabilities: capabilities,
                commandSet: commandSet
            )

            try await protocol.connect()
            print("✓ Connected\n")

            // Test 1: Mode control
            print("TEST 1: Mode Control")
            try await protocol.setMode(.usb, vfo: .main)
            let mode = try await protocol.getMode(vfo: .main)
            print("Mode set to USB, read back: \(mode)")
            XCTAssert(mode == .usb, "Mode mismatch")
            print("✓ PASS\n")

            // Test 2: Power control (percentage)
            print("TEST 2: Power Control (Percentage)")
            try await protocol.setPower(50)  // 50%
            let power = try await protocol.getPower()
            print("Power set to 50%, read back: \(power)%")
            print("👉 Verify radio display shows 50% (not ~50W)")
            XCTAssert(abs(power - 50) <= 2, "Power mismatch")
            print("✓ PASS\n")

            // Test 3: PTT control
            print("TEST 3: PTT Control")
            try await protocol.setPTT(true)
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let pttOn = try await protocol.getPTT()
            print("PTT enabled: \(pttOn)")
            XCTAssert(pttOn, "PTT should be enabled")

            try await protocol.setPTT(false)
            let pttOff = try await protocol.getPTT()
            print("PTT disabled: \(!pttOff)")
            XCTAssert(!pttOff, "PTT should be disabled")
            print("✓ PASS\n")

            await protocol.disconnect()
            print("✓ All tests passed!")

        } catch {
            print("❌ ERROR: \(error)")
        }
    }
}
```

### Test Checklist (Per Radio)

- [ ] Official CI-V manual obtained and reviewed
- [ ] CIVCommandSet implementation created (or StandardIcomCommandSet used)
- [ ] Capabilities defined in RadioCapabilitiesDatabase
- [ ] Unit tests for command formatting written and passing
- [ ] Unit tests for response parsing written and passing
- [ ] CI-V address verified against official manual
- [ ] Power units verified (watts vs percentage)
- [ ] Mode filter byte requirement verified
- [ ] VFO selection requirement verified
- [ ] PTT command format verified
- [ ] Echo behavior verified
- [ ] Live hardware test created (if hardware available)
- [ ] Live hardware test executed and passed (if hardware available)
- [ ] Documentation updated in TECHNICAL_NOTES.md

---

## Risk Mitigation

### Backward Compatibility

**Strategy**: Maintain dual code paths during migration
- Keep existing capability flag methods
- Mark as deprecated with migration instructions
- Remove after 2 major versions

```swift
@available(*, deprecated, message: "Use commandSet-based initialization instead")
public init(transport: any SerialTransport, civAddress: UInt8, capabilities: RigCapabilities) {
    // Legacy initialization path
    // Automatically create appropriate command set based on capabilities
}
```

### Testing Coverage

**Requirements**:
- Unit test coverage: 90%+ for command set implementations
- Integration test coverage: 80%+ for protocol operations
- Hardware testing: At least 3 radios from different generations

### Rollback Plan

**If Issues Arise**:
1. Revert to capability flags (keep old code in place)
2. Fix command set implementation
3. Re-run full test suite
4. Gradual rollout: Enable command sets per-radio via feature flag

---

## Timeline

### Week 1: Immediate Fixes
- [ ] Add PowerUnits enum
- [ ] Fix power control for IC-7100/IC-705
- [ ] Hardware validation on IC-7100
- [ ] Release v1.0.3 with power fix

### Week 2: Foundation
- [ ] Create CIVCommandSet protocol
- [ ] Implement IC7100CommandSet
- [ ] Implement IC9700CommandSet
- [ ] Implement StandardIcomCommandSet
- [ ] Unit tests for all command sets

### Week 3: Protocol Refactoring
- [ ] Refactor IcomCIVProtocol to use command sets
- [ ] Backward compatibility layer
- [ ] Integration tests
- [ ] Hardware validation (IC-7100, IC-9700)

### Week 4: Tier 1 Radios
- [ ] Add IC-705 (similar to IC-7100)
- [ ] Add IC-7300 (standard command set)
- [ ] Add IC-7610 (standard command set)
- [ ] Documentation updates
- [ ] Release v1.1.0

### Week 5: Tier 2 Radios
- [ ] Add IC-9100
- [ ] Add IC-7200
- [ ] Add IC-7600
- [ ] Documentation updates
- [ ] Release v1.2.0

### Week 6: Tier 3 Radios
- [ ] Add IC-7000 (may need custom command set)
- [ ] Add IC-746PRO
- [ ] Add IC-756PROIII
- [ ] Documentation updates
- [ ] Release v1.3.0

### Ongoing: Additional Radios
- Add radios from Priority 4 and 5 as requested by users
- Community contributions for radios with hardware access

---

## Success Metrics

### Code Quality
- [ ] Unit test coverage ≥ 90% for command sets
- [ ] Integration test coverage ≥ 80% for protocol
- [ ] Zero SwiftLint warnings
- [ ] API documentation coverage 100%

### Functionality
- [ ] Power control displays correct units (watts vs percentage)
- [ ] All 10+ radios pass unit tests
- [ ] Hardware-tested radios (3+) pass live tests
- [ ] Zero regression in existing IC-7100/IC-9700 support

### Documentation
- [ ] Each radio documented in TECHNICAL_NOTES.md
- [ ] Migration guide for existing code
- [ ] API documentation for CIVCommandSet protocol
- [ ] Example code for adding new radios

### Community
- [ ] Documentation for contributing new radio support
- [ ] Template files for command sets and tests
- [ ] CI/CD pipeline for automated testing

---

## Conclusion

Phase 2 represents a significant architectural improvement that will:
1. **Fix immediate issues** (power control units)
2. **Scale to 30+ radios** with maintainable code
3. **Enable community contributions** through clear patterns
4. **Establish testing framework** for quality assurance

The CIVCommandSet protocol provides the right abstraction: common CI-V transport with radio-specific command formatting. This mirrors Hamlib's proven architecture while leveraging Swift's type safety and protocol-oriented design.

**Next Steps**: Begin Week 1 implementation with PowerUnits enum and power control fixes.

---

**Document Version**: 1.0
**Date**: 2025-12-09
**Status**: Approved for Implementation
**Author**: Phase 2 Planning Team
