# SwiftRigControl Technical Notes

## CI-V Protocol Command Variations by Radio Model

### Issue Identified: 2025-12-08

During IC-7100 live testing, we discovered that **each Icom radio model has unique CI-V command implementations**, despite using the same base CI-V protocol. This affects multiple command types and response formats.

### Current Implementation

The current `IcomCIVProtocol` assumes a uniform command structure for all Icom radios. We handle variations through capability flags:

- `requiresVFOSelection: Bool` - Whether radio needs VFO select command (0x07)
- `requiresModeFilter: Bool` - Whether mode command (0x06) includes filter byte

**Limitations:**
- This approach becomes unwieldy as more radio-specific variations are discovered
- Difficult to maintain and extend for additional radio models
- Does not capture the full complexity of per-radio command variations

### Discovered Command Variations

#### Mode Setting (Command 0x06)

**Standard Icom Radios (IC-9700, IC-7300, etc.):**
```
FE FE [addr] E0 06 [mode] [filter] FD
```

**IC-7100 / IC-705:**
```
FE FE [addr] E0 06 [mode] FD
```
*Filter byte causes NAK rejection*

#### PTT Control

**Most Icom Radios:**
```
Command: 0x16 [data]
```

**IC-7100 (Per Official Manual):**
```
Command: 0x1C 00 [data]
Sub-command 0x00 required
```

#### Power Control

**IC-9700, IC-7300:**
- Command: 0x14 0x0A
- Units: Watts (converted to 0-255 scale)
- Max power defined by radio model

**IC-7100:**
- Command: 0x14 0x0A
- Units: **Percentage (0-100%)**
- Radio displays percentage, not watts
- Current implementation incorrectly treats as watts

### Proposed Refactoring

#### Option 1: Radio-Specific Command Tables

Create per-radio command definitions:

```swift
protocol CIVCommandSet {
    func setModeCommand(mode: UInt8) -> (command: [UInt8], data: [UInt8])
    func setPTTCommand(enabled: Bool) -> (command: [UInt8], data: [UInt8])
    func setPowerCommand(value: Int) -> (command: [UInt8], data: [UInt8])
    // ... etc
}

struct IC7100Commands: CIVCommandSet {
    func setModeCommand(mode: UInt8) -> (command: [UInt8], data: [UInt8]) {
        return ([0x06], [mode])  // No filter byte
    }

    func setPTTCommand(enabled: Bool) -> (command: [UInt8], data: [UInt8]) {
        return ([0x1C, 0x00], [enabled ? 0x01 : 0x00])
    }

    func setPowerCommand(value: Int) -> (command: [UInt8], data: [UInt8]) {
        // IC-7100 uses percentage (0-100)
        let percentage = min(max(value, 0), 100)
        let bcd = BCDEncoding.encodePower(percentage * 255 / 100)
        return ([0x14, 0x0A], bcd)
    }
}

struct IC9700Commands: CIVCommandSet {
    func setModeCommand(mode: UInt8) -> (command: [UInt8], data: [UInt8]) {
        return ([0x06], [mode, 0x00])  // Includes filter byte
    }

    func setPTTCommand(enabled: Bool) -> (command: [UInt8], data: [UInt8]) {
        return ([0x1C], [enabled ? 0x01 : 0x00])
    }

    func setPowerCommand(value: Int) -> (command: [UInt8], data: [UInt8]) {
        // IC-9700 uses watts
        let percentage = value * 255 / 100  // Convert watts to scale
        let bcd = BCDEncoding.encodePower(percentage)
        return ([0x14, 0x0A], bcd)
    }
}
```

**Advantages:**
- Clear separation of radio-specific behavior
- Easy to add new radio models
- Self-documenting (each radio's commands in one place)
- Testable in isolation

**Disadvantages:**
- More code structure required
- Need to define command set for each radio

#### Option 2: Enhanced Capability Flags

Continue expanding capability flags but make them more granular:

```swift
public struct IcomCIVCapabilities {
    let modeCommandFormat: ModeCommandFormat
    let pttCommandFormat: PTTCommandFormat
    let powerUnits: PowerUnits

    enum ModeCommandFormat {
        case withFilter        // [mode, filter]
        case modeOnly          // [mode]
    }

    enum PTTCommandFormat {
        case simple            // 0x1C [data]
        case withSubCommand    // 0x1C 0x00 [data]
    }

    enum PowerUnits {
        case watts(max: Int)
        case percentage
    }
}
```

**Advantages:**
- Less structural change
- Backward compatible approach
- Easier initial implementation

**Disadvantages:**
- Still becomes unwieldy with many variations
- Less clear organization
- Harder to maintain as variations grow

### Recommendation

**Phase 1 (Current):** Use capability flags for immediate IC-7100 fixes
**Phase 2 (Future):** Refactor to radio-specific command tables

The command table approach is more maintainable long-term, especially as we add:
- IC-705 (similar to IC-7100 but has unique variations)
- IC-7610 (different command set)
- IC-R8600 (receiver-only, different capabilities)
- Future Icom models

### Implementation Priority

1. ✅ **Fixed**: Mode command (requiresModeFilter flag)
2. ✅ **Fixed**: VFO selection (requiresVFOSelection flag)
3. ⚠️ **In Progress**: PTT command structure (updated format, response parsing needs work)
4. ⚠️ **TODO**: Power control units (watts vs percentage)
5. 📋 **TODO**: Refactor to command tables (long-term)

### Testing Strategy

For each new Icom radio added:
1. Obtain official CI-V manual PDF
2. Create radio-specific test suite (like IC7100InteractiveTest)
3. Verify each command against actual hardware
4. Document variations in this file
5. Implement appropriate command table or capability flags

### CI-V Command Comparison Matrix

| Feature | IC-7100 | IC-705 | IC-9700 | IC-7300 | IC-7610 |
|---------|---------|--------|---------|---------|---------|
| **CI-V Address** | 0x88 | 0xA4 | 0xA2 | 0x94 | 0x98 |
| **Mode Filter Byte (0x06)** | ❌ NO | ❌ NO | ✅ YES | ✅ YES | ✅ YES |
| **VFO Selection Required (0x07)** | ❌ NO | ❌ NO | ✅ YES | ✅ YES | ✅ YES |
| **PTT Sub-command (0x1C)** | 0x1C 0x00 | 0x1C 0x00 | 0x1C 0x00 | 0x1C 0x00 | 0x1C 0x00 |
| **Power Units (0x14 0x0A)** | % (0-100%) | % (0-100%) | Watts | Watts | Watts |
| **Echo Commands** | ✅ YES | ✅ YES | ❌ NO (USB) | ❌ NO | ❌ NO |
| **Network Control** | ❌ NO | ✅ YES | ✅ YES | ❌ NO | ✅ YES |
| **Max Power** | 100W (HF/50) | 10W | 100W | 100W | 100W |
| **Dual Receiver** | ❌ NO | ❌ NO | ✅ YES | ❌ NO | ✅ YES |

### Reference Documentation

#### Official Icom CI-V Manuals

- **IC-7100 CI-V Manual**: `IC-7100 CIV.pdf` (Section 20, pages 20-1 to 20-17)
  - Local file in project root
  - Command table: pages 20-3 to 20-10
  - Data format descriptions: pages 20-11 to 20-17

- **IC-9700 CI-V Manual**: https://www.icomfrance.com/uploads/files/produit/not-IC-9700_ENG_CI-V_1-en.pdf
  - Official Icom France reference
  - VHF/UHF All Mode Transceiver

- **IC-7610 CI-V Manual**: https://static.dxengineering.com/global/images/technicalarticles/ico-ic-7610_yj.pdf
  - HF/50MHz Transceiver
  - Includes network control commands

- **IC-705 CI-V Manual**: https://www.icomeurope.com/wp-content/uploads/2020/08/IC-705_ENG_CI-V_1_20200721.pdf
  - Official Icom Europe reference
  - HF/VHF/UHF All Mode Portable Transceiver
  - Similar command structure to IC-7100

- **IC-7300 CI-V Reference**: Chapter 19 in main instruction manual
  - No standalone CI-V manual available
  - Commands integrated into full manual

- **IC-7600 CI-V Reference**: Section on CI-V in main instruction manual
  - No standalone CI-V manual available

#### Additional Resources

- **Hamlib Source Code**: https://github.com/Hamlib/Hamlib
  - `rigs/icom/` directory contains per-radio implementations
  - Proven architecture for handling CI-V variations
  - 30+ Icom transceivers implemented

- **Icom Official Sites**:
  - Icom Japan: https://www.icomjapan.com/support/manual/
  - Icom Europe: https://www.icomeurope.com/en/support/download/downloads-amateur/
  - Icom Canada: https://icomcanada.com/support/manual/

### Key Command Details from Official Manuals

#### Mode Command (0x06) - From IC-7100 Manual Page 20-3

**IC-7100/IC-705 Format:**
```
FE FE 88 E0 06 [mode] FD
```
- Mode codes: 00=LSB, 01=USB, 02=AM, 03=CW, 04=RTTY, 05=FM, 06=WFM, 07=CW-R, 08=RTTY-R, 17=DV
- **NO filter byte** - sending filter byte causes NAK

**IC-9700/IC-7300/IC-7610 Format:**
```
FE FE [addr] E0 06 [mode] [filter] FD
```
- Filter byte: 01=FIL1, 02=FIL2, 03=FIL3
- Filter byte can be omitted (defaults to FIL1)

#### Power Control (0x14 0x0A)

**IC-7100/IC-705 (Percentage):**
- Command: `FE FE 88 E0 14 0A [BCD 0-255] FD`
- Units: 0-255 scale represents 0-100% power
- Radio displays percentage, not watts
- Calculation: `percentage = (bcd_value * 100) / 255`

**IC-9700/IC-7300/IC-7610 (Watts):**
- Command: `FE FE [addr] E0 14 0A [BCD 0-255] FD`
- Units: 0-255 scale represents 0-max_watts
- Radio displays watts
- Calculation: `watts = (bcd_value * max_power) / 255`

#### PTT Control (0x1C 0x00) - From IC-7100 Manual Page 20-10

**All Modern Icom Radios:**
```
Set:  FE FE [addr] E0 1C 00 [00/01] FD
Read: FE FE [addr] E0 1C 00 FD
```
- Sub-command 0x00 is required
- Data: 0x00=RX, 0x01=TX
- Response includes command echo: `FE FE E0 [addr] 1C 00 [00/01] FD`

### Related Issues

- ✅ **Fixed**: Mode command filter byte handling (requiresModeFilter flag)
- ✅ **Fixed**: VFO selection requirement (requiresVFOSelection flag)
- ✅ **Fixed**: PTT command structure (0x1C 0x00 format)
- ⚠️ **In Progress**: PTT status read response parsing
- ⚠️ **TODO**: Power control units (watts vs percentage)
  - IC-7100 shows "196W" when set to 100% (displays "100%")
  - IC-705 has same issue
- 📋 **TODO**: Verify all commands work correctly on IC-9700, IC-7300, IC-7610

### Hamlib Icom Radio Support

The following Icom radios are implemented in Hamlib (as of v4.6):

**HF/Multi-band Transceivers:**
- IC-706, IC-706MkII, IC-706MkIIG
- IC-707, IC-718
- IC-746, IC-746PRO
- IC-756, IC-756PRO, IC-756PROII, IC-756PROIII
- IC-7000, IC-7100, IC-7200, IC-7300
- IC-7410, IC-7600, IC-7610
- IC-7700, IC-7760 (Alpha), IC-7800, IC-7850/7851

**VHF/UHF Transceivers:**
- IC-910, IC-9100, IC-9700
- IC-705, IC-905
- ID-4100, ID-5100

**Receivers:**
- IC-R6, IC-R10, IC-R20, IC-R30
- IC-R75, IC-R8600, IC-R9000, IC-R9500

**Priority for SwiftRigControl:**
1. **Current Generation** (2020+): IC-705, IC-9700, IC-7610, IC-7300
2. **Popular Models** (2010-2020): IC-7100, IC-7200, IC-7600, IC-9100
3. **Legacy Models** (2000-2010): IC-7000, IC-746PRO, IC-756PROIII

---

## Power Control BCD Encoding Issue - RESOLVED

**Date**: 2025-12-09
**Issue**: Power control was reading 196% instead of 100%, and setPower commands were rejected.

### Root Cause
The `encodePower()` and `decodePower()` functions in `BCDEncoding.swift` were using **little-endian** BCD byte order, but the IC-7100 (and likely all Icom radios) use **big-endian** BCD for power control command 0x14 0x0A.

**Incorrect encoding (before fix):**
```swift
// encodePower(255) returned [0x55, 0x02] - WRONG!
return [(high << 4) | low, hundreds]
```

**Correct encoding (after fix):**
```swift
// encodePower(255) returns [0x02, 0x55] - CORRECT!
return [hundreds, (tens << 4) | ones]
```

### Byte Order Details

**Frequency encoding** (command 0x05): Uses **little-endian** BCD
- Example: 14.230 MHz → `00 00 23 14 00`
- Least significant digits first

**Power encoding** (command 0x14 0x0A): Uses **big-endian** BCD
- Example: 255 (100%) → `02 55`
- Most significant digit first (hundreds in byte 0, tens/ones in byte 1)

### Testing Results

Hardware verification on IC-7100:
- ✅ Read power: 100% (was 196%)
- ✅ Set 50%: Radio display shows 50%, read back 49%
- ✅ Set 25%: Radio display shows 25%, read back 24%
- ✅ Set 100%: Radio display shows 100%, read back 100%
- ✅ Set 10%: Radio display shows 10%, read back 9%

Minor variance (±1%) due to BCD rounding: 0-255 scale → 0-100% conversion.

### Files Modified
1. `/Sources/RigControl/Utilities/BCDEncoding.swift:61-99` - Fixed byte order
2. `/Sources/RigControl/Models/RigCapabilities.swift:48-103` - Added PowerUnits enum
3. `/Sources/RigControl/Protocols/Icom/IcomCIVProtocol.swift:230-282` - Updated power methods
4. `/Sources/RigControl/Models/RadioCapabilitiesDatabase.swift` - Updated all 6 Icom radios

### Applicability to Other Radios

**Research findings:**
- Hamlib has both `to_bcd()` (little-endian) and `to_bcd_be()` (big-endian) functions
- All Icom radios use **percentage** for power display (confirmed via Hamlib issue #533)
- BCD byte order for power control should be consistent across Icom models

**Recommendation**: The big-endian BCD fix should apply to all Icom radios (IC-9700, IC-7300, IC-7610, IC-705, etc.). When testing additional radios, verify power control works correctly.

---

## PTT Command Parsing Issue - RESOLVED

**Date**: 2025-12-09
**Issue**: PTT status query (`getPTT()`) was failing with `invalidResponse` error.

### Root Cause
The `CIVFrame.parse()` function only recognized commands 0x14 and 0x15 as having sub-commands, but PTT command 0x1C also requires sub-command parsing.

**PTT command format:**
- Query: `FE FE 88 E0 1C 00 FD`
- Response: `FE FE E0 88 1C 00 [00/01] FD`
  - Command: `1C 00` (2 bytes)
  - Data: `00` = RX, `01` = TX

### Fix Applied
Updated `CIVFrame.swift:108` to recognize 0x1C as multi-byte command:

```swift
// Before:
let hasSubCommand = (firstByte == 0x14 || firstByte == 0x15) && commandAndData.count > 1

// After:
let hasSubCommand = (firstByte == 0x14 || firstByte == 0x15 || firstByte == 0x1C) && commandAndData.count > 1
```

### Testing Results

Hardware verification on IC-7100:
- ✅ Read PTT status: Correctly reports RX
- ✅ Enable PTT (TX): Radio transmits, TX indicator lights up
- ✅ Read PTT during TX: Correctly reports TX status
- ✅ Disable PTT (RX): Radio returns to receive, TX indicator off
- ✅ Quick toggle test: TX indicator flashed 3 times correctly

### Files Modified
1. `/Sources/RigControl/Protocols/Icom/CIVFrame.swift:105-108` - Added 0x1C to multi-byte command list

---

**Last Updated**: 2025-12-09
**Author**: Testing with IC-7100 hardware + Official Manual Analysis
**Status**: Power Control ✅ Fixed, PTT Control ✅ Fixed, Phase 2 Planning
