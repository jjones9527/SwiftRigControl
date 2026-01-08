# IC-7600 Comprehensive Test Suite

**Status**: ✅ Ready for Hardware Validation  
**Test Count**: 13 Tests  
**Build**: Successful (2.52s)

---

## Overview

Comprehensive CI-V protocol validation for the IC-7600 HF/6m dual-receiver transceiver. This test suite validates all core radio functionality plus IC-7600-specific protocol extensions introduced in the dual-receiver architecture refactoring.

## Test Environment

```bash
IC7600_SERIAL_PORT="/dev/cu.usbserial-XXXX" swift run IC7600ComprehensiveTest
```

**Radio Configuration**:
- Model: IC-7600
- CI-V Address: 0x7A
- Baud Rate: 19200 (default)
- VFO Model: `.mainSub` (2-state Main/Sub only)
- Bands: 160m-6m (HF/6m)
- Max Power: 100W
- Architecture: Dual independent receivers (Main + Sub)

---

## Test Coverage (13 Tests)

### 📡 Test 1: Multi-Band Frequency Control
**Coverage**: All HF/6m amateur bands  
**Bands Tested**: 160m, 80m, 40m, 30m, 20m, 17m, 15m, 12m, 10m, 6m

Validates:
- Frequency setting across all bands
- Frequency readback verification
- Band boundary handling

**CI-V Commands**: `0x05` (Set/Read Frequency)

---

### 📻 Test 2: Mode Control
**Modes Tested**: USB, LSB, CW, CW-R, RTTY, RTTY-R, AM, FM, Data-USB, Data-LSB

Validates:
- Mode setting commands
- Mode readback verification
- All supported modulation types

**CI-V Commands**: `0x06` (Set/Read Mode)

---

### 🔀 Test 3: Dual Receiver Operations (Main/Sub)
**Architecture**: IC-7600 2-state Main/Sub receivers

Validates:
- Main receiver selection and control
- Sub receiver selection and control
- Independent frequency/mode per receiver
- Simultaneous dual-receiver operation

**CI-V Commands**: 
- `0x07 0xD0` (Select Main)
- `0x07 0xD1` (Select Sub)
- `0x05` (Set/Read Frequency)
- `0x06` (Set/Read Mode)

**Example Output**:
```
✓ Main Receiver (20m): 14.200000 MHz USB
✓ Sub Receiver (40m): 7.100000 MHz LSB
```

---

### 🔊 Test 4: Split Operation
**Coverage**: TX/RX frequency split for DX operation

Validates:
- Split mode enable
- Split mode disable
- Split status verification

**CI-V Commands**: `0x0F` (Set/Read Split)

---

### ⚡ Test 5: Power Control
**Range**: 10W - 100W (IC-7600 max)  
**Test Points**: 10W, 25W, 50W, 75W, 100W

Validates:
- RF power output setting
- Power readback verification
- Tolerance: ±5W

**CI-V Commands**: `0x14 0x0A` (Set/Read RF Power)

---

### 📡 Test 6: PTT Control
**Safety**: Low power (10W) for testing

Validates:
- PTT ON command
- PTT OFF command
- PTT status verification
- Safe transmit duration (200ms)

**CI-V Commands**: `0x1C 0x00` (Set/Read PTT)

**⚠️ Requires**: Dummy load or antenna

---

### 📊 Test 7: Signal Strength (S-meter)
**Readings**: 5 consecutive samples

Validates:
- S-meter reading command
- Signal strength parsing
- S-unit conversion
- Raw value access

**CI-V Commands**: `0x15 0x02` (Read S-meter)

**Example Output**:
```
Reading 1: S7 +10dB (Raw: 142, S7)
Reading 2: S5 +5dB (Raw: 105, S5)
```

---

### 🎚️ Test 8: RIT Control
**Offsets Tested**: +500 Hz, 0 Hz (disabled)

Validates:
- RIT enable with offset
- RIT state verification
- RIT disable
- Offset accuracy

**CI-V Commands**: `0x21` (Set/Read RIT Offset)

---

### 🎛️ Test 9: XIT Control
**Offsets Tested**: -300 Hz, 0 Hz (disabled)

Validates:
- XIT enable with offset
- XIT state verification
- XIT disable
- Offset accuracy

**CI-V Commands**: `0x21` (Set/Read XIT Offset)

---

### ⚡ Test 10: Rapid Frequency Switching
**Scenario**: Fast band-hopping performance test

Validates:
- Rapid frequency changes
- Command throughput
- Verification latency
- Average command time

**Bands**: 160m, 80m, 40m, 20m, 15m, 10m (6 changes)

**Example Output**:
```
✓ 6 band changes in 0.85s
✓ Average: 141.7ms per change
```

---

## NEW PROTOCOL EXTENSION TESTS

### 🔀 Test 11: Band Selection API
**Protocol Extension**: `IcomCIVProtocol+DualReceiver.swift`  
**Method**: `selectBand(_ band: Band)`

Validates:
- Alternative band selection API
- `.main` band selection
- `.sub` band selection
- API equivalence with `selectVFO(.main/.sub)`

**CI-V Commands**: 
- `0x07 0xD0` (Select Main via Band API)
- `0x07 0xD1` (Select Sub via Band API)

**Usage**:
```swift
let proto = await rig.protocol as? IcomCIVProtocol
try await proto.selectBand(.main)  // Alternative to selectVFO(.main)
try await proto.selectBand(.sub)   // Alternative to selectVFO(.sub)
```

---

### 🔄 Test 12: Band Exchange (Main ↔ Sub)
**Protocol Extension**: `IcomCIVProtocol+DualReceiver.swift`  
**Method**: `exchangeBands()`

Validates:
- Swap Main and Sub frequencies
- Swap Main and Sub modes
- Complete state exchange
- Bidirectional swap verification

**CI-V Command**: `0x07 0xB0` (Exchange Main/Sub)

**Test Scenario**:
```
Before exchange:
  Main: 14.200 MHz USB
  Sub:  7.100 MHz LSB

After exchange:
  Main: 7.100 MHz LSB
  Sub:  14.200 MHz USB
```

**Usage**:
```swift
try await proto.exchangeBands()  // Instant Main ↔ Sub swap
```

---

### 👁️ Test 13: Dualwatch Mode (IC-7600 Exclusive)
**Protocol Extension**: `IcomCIVProtocol+DualReceiver.swift`  
**Method**: `setDualwatch(_ enabled: Bool)`

Validates:
- Dualwatch enable command
- Dualwatch disable command
- IC-7600-exclusive feature

**CI-V Commands**:
- `0x07 0xC3` (Dualwatch ON)
- `0x07 0xC2` (Dualwatch OFF)

**Important**: This feature is **ONLY available on IC-7600**. IC-9700 and IC-9100 are true dual-receivers where both are always active.

**Usage**:
```swift
try await proto.setDualwatch(true)   // Enable simultaneous Main+Sub monitoring
try await proto.setDualwatch(false)  // Disable dualwatch
```

---

## State Restoration

After all tests complete, the test suite automatically restores:
- ✅ Original frequency
- ✅ Original mode
- ✅ Original power level
- ✅ Original VFO selection

---

## Architecture Validation

This test suite specifically validates the IC-7600's **2-state Main/Sub architecture**:

### IC-7600 VFO Model
- **Type**: `.mainSub` (2-state)
- **States**: Main receiver OR Sub receiver
- **VFO Commands**: 
  - ✅ `.main` / `.sub` - Supported
  - ❌ `.a` / `.b` - NOT supported (returns error)

### Protocol Compatibility
The test validates that IC-7600 correctly:
- ✅ Accepts Main/Sub commands (`0x07 0xD0/0xD1`)
- ✅ Rejects VFO A/B commands (`0x07 0x00/0x01`)
- ✅ Supports band exchange (`0x07 0xB0`)
- ✅ Supports dualwatch (`0x07 0xC2/0xC3`)

---

## Success Criteria

**All 13 Tests Must Pass**:
- ✅ All frequency set/read operations succeed
- ✅ All mode set/read operations succeed
- ✅ Main/Sub selection and control works
- ✅ Split, power, PTT operations succeed
- ✅ S-meter, RIT, XIT operations succeed
- ✅ Rapid frequency switching performs well
- ✅ Protocol extension APIs work correctly
- ✅ State restoration succeeds

**Output**:
```
======================================================================
Test Summary
======================================================================
✅ Passed:  13
❌ Failed:  0
📊 Total:   13
======================================================================
Success Rate: 100.0%
======================================================================

🎉 All tests PASSED! IC-7600 implementation fully validated.
```

---

## Running the Test

### Prerequisites
1. IC-7600 connected via USB (CI-V)
2. Serial port device path identified
3. Dummy load or antenna connected (for PTT test)

### Execution
```bash
# Find serial port
ls /dev/cu.usbserial-*

# Run test
IC7600_SERIAL_PORT="/dev/cu.usbserial-XXXX" swift run IC7600ComprehensiveTest
```

### Expected Duration
- **Typical runtime**: 10-15 seconds
- **Tests**: 13 comprehensive validations
- **Commands sent**: ~100+ CI-V frames

---

## Validation Results

| Test # | Feature | Status |
|--------|---------|--------|
| 1 | Multi-Band Frequency Control | ⏳ Pending |
| 2 | Mode Control | ⏳ Pending |
| 3 | Dual Receiver Operations | ⏳ Pending |
| 4 | Split Operation | ⏳ Pending |
| 5 | Power Control | ⏳ Pending |
| 6 | PTT Control | ⏳ Pending |
| 7 | Signal Strength | ⏳ Pending |
| 8 | RIT Control | ⏳ Pending |
| 9 | XIT Control | ⏳ Pending |
| 10 | Rapid Frequency Switching | ⏳ Pending |
| 11 | Band Selection API | ⏳ Pending |
| 12 | Band Exchange | ⏳ Pending |
| 13 | Dualwatch Mode | ⏳ Pending |

---

## Related Documentation

- `IC9700_VFO_ARCHITECTURE.md` - 4-state VFO architecture explanation
- `MAIN_SUB_VFO_ANALYSIS.md` - IC-7600 vs IC-9700 comparison
- `IC9700_DUALWATCH_CLARIFICATION.md` - Dualwatch vs true dual-receiver
- `Sources/RigControl/Protocols/Icom/IcomCIVProtocol+DualReceiver.swift` - Protocol extension source

---

**Last Updated**: 2026-01-08  
**Build Status**: ✅ Compiles successfully  
**Hardware Validation**: ⏳ Pending user testing
