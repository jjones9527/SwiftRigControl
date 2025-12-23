# Test Suite Cleanup and Hardware Testing Plan

**Date:** December 22, 2024
**Goal:** Production-ready test suite with hardware validation

---

## Current Test Suite Analysis

### ✅ Working Tests
1. **BCDEncodingTests.swift** - Unit tests for BCD encoding/decoding
2. **CIVFrameTests.swift** - CI-V frame construction tests
3. **RadioCapabilitiesTests.swift** - Capability validation tests

### ⚠️ Tests with Issues
1. **IcomProtocolTests.swift** - Actor isolation issues (line 163)
2. **IcomIntegrationTests.swift** - Actor isolation issues (capabilities access)
3. **ElecraftProtocolTests.swift** - May have deprecation warnings
4. **YaesuCATProtocolTests.swift** - May have deprecation warnings
5. **KenwoodProtocolTests.swift** - May have deprecation warnings

### 📝 Test Infrastructure
- **MockTransport.swift** - ✅ Good, no issues

---

## Phase 1: Fix Existing Test Issues

### 1.1 Fix MockTransport Actor Isolation
**Issue:** Line 163 tries to use `setProperty(\.shouldThrowOnRead, to: true)` which doesn't exist

**Fix:** Add proper async methods to MockTransport:
```swift
func setShouldThrowOnRead(_ value: Bool) async {
    shouldThrowOnRead = value
}

func setShouldThrowOnWrite(_ value: Bool) async {
    shouldThrowOnWrite = value
}
```

### 1.2 Fix IcomProtocolTests
**File:** Tests/RigControlTests/IcomProtocolTests.swift
**Line 163:** Replace `await mockTransport.setProperty(\.shouldThrowOnRead, to: true)`
**With:** `await mockTransport.setShouldThrowOnRead(true)`

### 1.3 Fix IcomIntegrationTests Actor Isolation
**Issues:**
- Line 54: `rig?.radioName` - actor-isolated property
- Line 162: `rig.capabilities` - actor-isolated property
- Lines 189, 220, 270: More capabilities access

**Fix:** All capabilities access should be done with `await`:
```swift
let capabilities = await rig.capabilities
guard capabilities.hasVFOB else { ... }
```

---

## Phase 2: Create Hardware Test Suites

### Available Hardware
1. **Icom IC-7600** - HF/6m flagship dual receiver
2. **Icom IC-7100** - HF/VHF/UHF multi-band with D-STAR
3. **Icom IC-9700** - VHF/UHF/1.2GHz SDR with satellite mode
4. **Elecraft K2** - HF QRP transceiver

### 2.1 IC-7600 Hardware Tests
**File:** `Tests/RigControlTests/HardwareTests/IC7600HardwareTests.swift`

**Test Coverage:**
- ✅ Connection and initialization
- ✅ Frequency control (VFO A and B)
- ✅ Mode control (all supported modes)
- ✅ Dual receiver operations
- ✅ Split operation
- ✅ Power control
- ✅ RIT/XIT functionality
- ✅ PBT (Passband Tuning) - IC-7600 specific
- ✅ Audio controls - IC-7600 specific
- ✅ Memory channel operations
- ✅ Signal strength reading

### 2.2 IC-7100 Hardware Tests
**File:** `Tests/RigControlTests/HardwareTests/IC7100HardwareTests.swift`

**Test Coverage:**
- ✅ Connection and initialization
- ✅ Frequency control (HF, VHF, UHF ranges)
- ✅ Mode control across bands
- ✅ D-STAR digital voice capabilities
- ✅ Split operation
- ✅ Power control
- ✅ Memory channel operations
- ✅ Multi-band operation (HF/VHF/UHF)

**Note:** IC-7100 does NOT have satellite mode

### 2.3 IC-9700 Hardware Tests
**File:** `Tests/RigControlTests/HardwareTests/IC9700HardwareTests.swift`

**Test Coverage:**
- ✅ Connection and initialization
- ✅ Frequency control (144 MHz, 430 MHz, 1.2 GHz)
- ✅ Mode control (all-mode operation)
- ✅ Dual receiver with independent control
- ✅ **Satellite mode and tracking** (IC-9700 DOES have satellite mode)
- ✅ D-STAR functionality
- ✅ Spectrum scope operation
- ✅ Split operation
- ✅ Memory channel operations

### 2.4 K2 Hardware Tests (Elecraft)
**File:** `Tests/RigControlTests/HardwareTests/K2HardwareTests.swift`

**Test Coverage:**
- ✅ Connection and initialization
- ✅ Frequency control
- ✅ Mode control
- ✅ Power control (QRP levels 0-15W)
- ✅ Split operation
- ✅ RIT/XIT functionality
- ✅ Text-based CAT protocol verification

---

## Phase 3: Test Organization

### Directory Structure
```
Tests/
├── RigControlTests/
│   ├── UnitTests/
│   │   ├── BCDEncodingTests.swift
│   │   ├── CIVFrameTests.swift
│   │   ├── RadioCapabilitiesTests.swift
│   │   └── CIVCommandSetTests.swift
│   ├── ProtocolTests/
│   │   ├── IcomProtocolTests.swift
│   │   ├── ElecraftProtocolTests.swift
│   │   ├── YaesuCATProtocolTests.swift
│   │   └── KenwoodProtocolTests.swift
│   ├── HardwareTests/
│   │   ├── IC7600HardwareTests.swift
│   │   ├── IC7100HardwareTests.swift
│   │   ├── IC9700HardwareTests.swift
│   │   └── K2HardwareTests.swift
│   └── Support/
│       └── MockTransport.swift
```

---

## Test Execution Strategy

### Unit Tests
```bash
# Run all unit tests (no hardware required)
swift test --filter UnitTests
```

### Protocol Tests
```bash
# Run protocol tests with mocks
swift test --filter ProtocolTests
```

### Hardware Tests
```bash
# Require RIG_SERIAL_PORT environment variable
export RIG_SERIAL_PORT_IC7600="/dev/cu.IC7600"
export RIG_SERIAL_PORT_IC7100="/dev/cu.usbserial-2110"
export RIG_SERIAL_PORT_IC9700="/dev/cu.IC9700"
export RIG_SERIAL_PORT_K2="/dev/cu.usbserial-K2"

# Run specific hardware test
swift test --filter IC7600HardwareTests

# Run all hardware tests
swift test --filter HardwareTests
```

---

## Test Quality Standards

### Every Hardware Test Must:
1. ✅ Skip if hardware not available
2. ✅ Verify connection before proceeding
3. ✅ Save and restore radio state
4. ✅ Handle errors gracefully
5. ✅ Provide detailed failure messages
6. ✅ Test both success and error paths
7. ✅ Verify actual radio state changes

### Example Test Pattern:
```swift
final class IC7600HardwareTests: XCTestCase {
    var rig: RigController!

    override func setUp() async throws {
        guard let port = ProcessInfo.processInfo.environment["RIG_SERIAL_PORT_IC7600"] else {
            throw XCTSkip("IC-7600 not available. Set RIG_SERIAL_PORT_IC7600 environment variable.")
        }

        rig = try RigController(
            radio: .icomIC7600(civAddress: nil),
            connection: .serial(path: port, baudRate: nil)
        )

        try await rig.connect()
    }

    override func tearDown() async throws {
        await rig?.disconnect()
    }

    func testFrequencyControl() async throws {
        // Save current frequency
        let originalFreq = try await rig.frequency(vfo: .a, cached: false)

        // Set test frequency
        let testFreq: UInt64 = 14_230_000
        try await rig.setFrequency(testFreq, vfo: .a)

        // Verify change
        let newFreq = try await rig.frequency(vfo: .a, cached: false)
        XCTAssertEqual(newFreq, testFreq, "Frequency should match set value")

        // Restore original frequency
        try await rig.setFrequency(originalFreq, vfo: .a)
    }
}
```

---

## Timeline

### Week 1 (Current)
- [x] Fix MockTransport actor isolation
- [x] Fix IcomProtocolTests
- [x] Fix IcomIntegrationTests
- [ ] Create IC-7600 hardware tests
- [ ] Create IC-7100 hardware tests

### Week 2
- [ ] Create IC-9700 hardware tests
- [ ] Create K2 hardware tests
- [ ] Run full test suite on all hardware
- [ ] Document test coverage

### Week 3
- [ ] Add CI/CD test automation
- [ ] Generate test coverage reports
- [ ] Add performance benchmarks
- [ ] Document testing procedures

---

## Success Criteria

- ✅ All unit tests pass without warnings
- ✅ All protocol tests pass with mocks
- ✅ All hardware tests pass with actual radios
- ✅ Test coverage ≥ 85%
- ✅ Zero deprecation warnings in tests
- ✅ Clean actor isolation (no data races)
- ✅ Comprehensive test documentation

---

## Notes

**Serial Port Discovery:**
```bash
# List available serial ports
ls /dev/cu.* | grep -i "icom\|usb\|IC"
```

**Common Ports:**
- IC-7600: `/dev/cu.IC7600` or `/dev/cu.SLAB_USBtoUART`
- IC-7100: `/dev/cu.usbserial-2110` (based on your setup)
- IC-9700: `/dev/cu.IC9700`
- K2: `/dev/cu.usbserial-K2` or `/dev/cu.usbserial-FTDI`

**Testing Best Practices:**
1. Always test on actual hardware before release
2. Use conservative power levels (5-10W) for testing
3. Verify antenna connected before PTT tests
4. Test across multiple frequency bands
5. Test edge cases (band edges, mode boundaries)
6. Measure actual serial timing for protocol validation

---

**Ready to implement!** 🚀
