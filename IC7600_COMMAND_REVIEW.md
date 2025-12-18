# IC-7600 CI-V Command Implementation Review

**Review Date:** 2025-12-12
**Reviewer:** Senior Swift Engineer
**IC-7600 CI-V Address:** 0x7A

## Command Implementation Status

### ✅ IMPLEMENTED Commands

| Cmd | Sub | Description | Implementation | Notes |
|-----|-----|-------------|----------------|-------|
| 0x03 | - | Read operating frequency | `getFrequency()` | ✅ Working |
| 0x04 | - | Read operating mode | `getMode()` | ✅ Working |
| 0x05 | - | Set operating frequency | `setFrequency()` | ✅ Working |
| 0x06 | - | Set operating mode | `setMode()` | ❌ **FAILING** - See ICOM_MODE_ISSUES.md |
| 0x07 | - | Select VFO mode | `selectVFO()` | ⚠️  Implemented, not tested |
| 0x07 | 0xB0 | Exchange main/sub bands | - | ❌ Not implemented |
| 0x07 | 0xB1 | Equalize main/sub bands | - | ❌ Not implemented |
| 0x07 | 0xC0 | Turn dualwatch OFF | - | ❌ Not implemented |
| 0x07 | 0xC1 | Turn dualwatch ON | - | ❌ Not implemented |
| 0x07 | 0xD0 | Select main band | `selectVFO(.main)` | ⚠️  Implemented, not tested |
| 0x07 | 0xD1 | Select sub band | `selectVFO(.sub)` | ⚠️  Implemented, not tested |
| 0x0F | 0x00 | Turn split OFF | `setSplit(false)` | ⚠️  Implemented, not tested |
| 0x0F | 0x01 | Turn split ON | `setSplit(true)` | ⚠️  Implemented, not tested |
| 0x14 | 0x0A | Set/read RF power level | `setPower()`, `getPower()` | ⚠️  Implemented, not tested |
| 0x15 | 0x02 | Read S-meter level | `getSignalStrength()` | ⚠️  Implemented, not tested |
| 0x1C | 0x00 | Read PTT state (RX) | `getPTT()` | ⚠️  Implemented, not tested |
| 0x1C | 0x01 | Set PTT state (TX) | `setPTT()` | ⚠️  Implemented, not tested |

### ❌ NOT IMPLEMENTED Commands (Available in Manual)

#### Memory Operations
| Cmd | Sub | Description | Priority |
|-----|-----|-------------|----------|
| 0x08 | - | Select memory mode | Low |
| 0x08 | 0x0001-0x0099 | Select memory channel | Low |
| 0x08 | 0x0100 | Select program scan edge P1 | Low |
| 0x08 | 0x0101 | Select program scan edge P2 | Low |
| 0x09 | - | Memory write | Low |
| 0x0A | - | Memory to VFO | Low |
| 0x0B | - | Memory clear | Low |

#### Scan Operations
| Cmd | Sub | Description | Priority |
|-----|-----|-------------|----------|
| 0x0E | 0x00 | Scan stop | Medium |
| 0x0E | 0x01 | Programmed/memory scan start | Medium |
| 0x0E | 0x02 | Programmed scan start | Low |
| 0x0E | 0x03 | δF scan start | Low |
| 0x0E | 0x12 | Fine programmed scan start | Low |
| 0x0E | 0x13 | Fine δF scan start | Low |
| 0x0E | 0x22 | Memory scan start | Low |
| 0x0E | 0x23 | Select memory scan start | Low |
| 0x0E | 0xA1-0xA7 | Select δF scan span | Low |
| 0x0E | 0xB0-0xB2 | Select memory scan settings | Low |
| 0x0E | 0xD0 | Set scan resume OFF | Low |
| 0x0E | 0xD3 | Set scan resume ON | Low |

#### Tuning & Controls
| Cmd | Sub | Description | Priority |
|-----|-----|-------------|----------|
| 0x10 | 0x00-0x08 | Set tuning step | Medium |
| 0x11 | - | Set/read attenuator | High |
| 0x12 | - | Set/read antenna selection | Medium |
| 0x13 | 0x00 | Announce all data with voice | Low |
| 0x13 | 0x01 | Announce frequency & S-meter | Low |
| 0x13 | 0x02 | Announce mode | Low |

#### Level Controls (0x14 sub-commands)
| Sub | Description | Priority |
|-----|-------------|----------|
| 0x01 | AF level | High |
| 0x02 | RF level | High |
| 0x03 | SQL level | High |
| 0x06 | NR level | Medium |
| 0x07 | Inner TWIN PBT | Medium |
| 0x08 | Outer TWIN PBT | Medium |
| 0x09 | CW pitch | Medium |
| 0x0B | MIC GAIN level | Medium |
| 0x0C | KEY SPEED level | Medium |
| 0x0D | NOTCH position | Medium |
| 0x0E | COMP level | Medium |
| 0x0F | BK-IN DELAY | Low |
| 0x10 | BAL position | Low |
| 0x12 | NB level | Medium |
| 0x14 | DRIVE gain | Medium |
| 0x15 | Monitor gain | Low |
| 0x16 | VOX gain | Medium |
| 0x17 | Anti VOX gain | Medium |
| 0x19 | BRIGHT level | Low |

#### Meter Readings (0x15 sub-commands)
| Sub | Description | Priority |
|-----|-------------|----------|
| 0x01 | Squelch condition | Medium |
| 0x11 | RF power meter | High |
| 0x12 | SWR meter | High |
| 0x13 | ALC meter | Medium |
| 0x14 | COMP meter | Medium |
| 0x15 | VD meter (voltage) | Medium |
| 0x16 | ID meter (current) | Medium |

#### Function Controls (0x16 sub-commands)
| Sub | Description | Priority |
|-----|-------------|----------|
| 0x02 | Preamp control | High |
| 0x12 | AGC control | High |
| 0x22 | Noise blanker | High |
| 0x32 | Audio peak filter | Medium |
| 0x40 | Noise reduction | High |
| 0x41 | Auto notch | Medium |
| 0x42 | Repeater tone | Medium |
| 0x43 | Tone squelch | Medium |
| 0x44 | Speech compressor | Medium |
| 0x45 | Monitor function | Low |
| 0x46 | VOX function | Medium |
| 0x47 | Break-in function | Medium |
| 0x48 | Manual notch | Medium |
| 0x4F | Twin peak filter | Low |
| 0x50 | Dial lock | Low |

#### Advanced Settings (0x1A sub-commands)
| Sub | Sub2 | Description | Priority |
|-----|------|-------------|----------|
| 0x00 | - | Memory contents | Low |
| 0x01 | - | Band stacking register | Low |
| 0x02 | - | Memory keyer contents | Low |
| 0x03 | 0x00-0x49 | Filter width selection | High |
| 0x04 | 0x00-0x13 | AGC time constant | High |
| 0x05 | 0x0001 | SSB RX HPF/LPF | Medium |
| 0x05 | 0x0002-0x0003 | SSB RX Tone (Bass/Treble) | Low |
| 0x05 | Many... | Extensive settings list | Low-Medium |

#### Other Commands
| Cmd | Sub | Description | Priority |
|-----|-----|-------------|----------|
| 0x02 | - | Read band edge frequencies | Low |
| 0x19 | 0x00 | Read transceiver ID | Medium |
| 0x1B | 0x00 | Repeater tone frequency | Medium |
| 0x1B | 0x01 | Tone squelch frequency | Medium |
| 0x1C | 0x01 | Antenna tuner control | Medium |
| 0x1E | - | TX frequency band operations | Low |

## Critical Issues

### 1. Mode Setting Failure (Command 0x06)

**Status:** ❌ CRITICAL FAILURE
**Affected Radios:** IC-7600, IC-9700, IC-7100
**Documentation:** See `ICOM_MODE_ISSUES.md`

**Problem:**
- Radio rejects setMode commands with NAK (0xFA)
- Even when setting to current mode
- Filter byte hardcoded to 0x00 may be invalid
- Echo handling may be incorrect

**Test Results with IC-7600:**
```
Command: FE FE 7A E0 06 01 00 FD  (setMode USB, filter 0x00)
Response: FE FE E0 7A FA FD        (NAK - rejected)
```

**Immediate Action Required:**
1. Add detailed frame-level logging
2. Test filter byte values: 0x01, 0x02, 0x03
3. Compare with Hamlib implementation
4. Verify echo consumption logic

### 2. Missing Filter Width Selection (0x1A 0x03)

**Status:** ❌ NOT IMPLEMENTED
**Priority:** HIGH
**Reason:** May be related to mode setting failure

The IC-7600 manual shows filter width is sent with mode:
- Command 0x06: Mode + Filter setting (1-3)
- Command 0x1A 0x03: Actual filter width selection (0-49)

Current implementation sends hardcoded 0x00 as filter, which may not be valid.

**Required Implementation:**
```swift
// In IcomRadioCommandSet.swift
public func setModeCommand(mode: UInt8, filter: UInt8 = 0x01) -> (command: [UInt8], data: [UInt8]) {
    if requiresModeFilter {
        return ([CIVFrame.Command.setMode], [mode, filter])  // filter should default to 0x01 (FIL1)
    } else {
        return ([CIVFrame.Command.setMode], [mode])
    }
}
```

## Recommendations

### Immediate (Critical Path)

1. **Fix Mode Setting (Command 0x06)**
   - Change default filter from 0x00 to 0x01 (FIL1)
   - Add filter parameter to setMode API
   - Add frame-level debug logging
   - Test with IC-7600 hardware

2. **Implement Attenuator Control (0x11)**
   - High priority for RX operations
   - Simple command structure
   - Easy to test

3. **Implement Preamp Control (0x16 0x02)**
   - High priority for RX operations
   - Works with attenuator
   - Simple command structure

### Short Term (High Value)

4. **Implement Filter Width Selection (0x1A 0x03)**
   - May resolve mode setting issues
   - Essential for proper mode operation
   - Test with all modes

5. **Implement AGC Control (0x16 0x12)**
   - Common user control
   - Simple command structure

6. **Implement Noise Reduction (0x16 0x40)**
   - Common user control
   - Simple on/off command

7. **Implement Level Controls (0x14)**
   - AF level (0x01)
   - RF level (0x02)
   - SQL level (0x03)
   - All use same command structure

8. **Implement Meter Readings (0x15)**
   - RF power meter (0x11)
   - SWR meter (0x12)
   - Important for TX operations

### Medium Term (Complete Coverage)

9. **Implement Function Controls (0x16)**
   - Noise blanker (0x22)
   - Auto notch (0x41)
   - Manual notch (0x48)
   - VOX function (0x46)

10. **Implement Tuning Step (0x10)**
    - User convenience feature
    - Simple command structure

11. **Implement Antenna Selection (0x12)**
    - Important for multi-antenna setups

### Long Term (Nice to Have)

12. **Memory Operations (0x08-0x0B)**
13. **Scan Operations (0x0E)**
14. **Band Stacking (0x1A 0x01)**
15. **Advanced Settings (0x1A 0x05 xxx)**

## Testing Requirements

All implemented commands must be tested with:
1. **Unit tests** with MockTransport
2. **Integration tests** with real IC-7600 hardware
3. **User verification** - what user sees vs. what software reports
4. **Error conditions** - invalid parameters, radio rejection
5. **Edge cases** - min/max values, boundary conditions

## Command Format Reference

### Frequency (BCD Encoding)
```
10 digits in BCD: [1GHz][100MHz][10MHz][1MHz][100kHz][10kHz][1kHz][100Hz][10Hz][1Hz]
Example: 14.230 MHz = 00 00 14 23 00 00
```

### Mode + Filter
```
Mode byte: 0x00=LSB, 0x01=USB, 0x02=AM, 0x03=CW, 0x04=RTTY, 0x05=FM
Filter byte: 0x01=FIL1, 0x02=FIL2, 0x03=FIL3
```

### Levels (0x14, 0x15)
```
2 bytes: 0x0000 to 0x0255 (0-255 decimal)
Percentage: (value / 255) * 100
```

## Next Steps

1. ✅ Document current implementation status
2. ⏳ Create comprehensive IC-7600 test script
3. ⏳ Fix mode setting with proper filter byte
4. ⏳ Add frame-level debug logging
5. ⏳ Test with IC-7600 hardware
6. ⏳ Implement high-priority missing commands
7. ⏳ Create integration tests for all commands
