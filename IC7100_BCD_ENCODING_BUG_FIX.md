# IC-7100 BCD Encoding Bug - Critical Fix

## Date
2025-12-30

## Severity
**CRITICAL** - Affected all IC-7100 Level commands (0x14) with values 100-255

## Problem Discovery

User reported that VOX gain settings at 50% (128) and 100% (255) were not working, but 0% (0) worked correctly.

## Root Cause

All IC-7100 Level command setters (0x14) had **incorrect BCD encoding** for values 100-255.

### Incorrect Formula
```swift
let bcd = [value % 10 | (value / 10) << 4, value / 100]
```

### Why It Failed

For value **128**:
- `value % 10` = 8 (ones digit) ✓
- `value / 10` = **12** (integer division) ❌ Should be 2!
- `12 << 4` = 192 (0xC0) ❌ Invalid BCD!
- `8 | 192` = 200 (0xC8) ❌
- `value / 100` = 1 (hundreds digit) ✓
- **Result**: `[0xC8, 0x01]` ❌ **INVALID BCD** (0xC is not a valid BCD digit)

The tens position had value 12 (0xC) instead of 2, making it invalid BCD.

For value **255**:
- Incorrect: `[5 | (25 << 4), 2]` = `[5 | 144, 2]` = `[149, 2]` = `[0x95, 0x02]` ❌
- The tens digit was 25, which is completely invalid!

For value **0**:
- Incorrect: `[0 | (0 << 4), 0]` = `[0, 0]` ✓ **Happened to work!**
- This is why 0% worked but higher values didn't

## Correct Formula

```swift
let bcd = [(value / 10 % 10) << 4 | (value % 10), value / 100]
```

### Why It Works

For value **128**:
- Ones digit: `128 % 10` = 8 ✓
- Tens digit: `(128 / 10) % 10` = `12 % 10` = 2 ✓
- `2 << 4` = 32 (0x20) ✓
- `32 | 8` = 40 (0x28) ✓
- Hundreds digit: `128 / 100` = 1 ✓
- **Result**: `[0x28, 0x01]` ✓ **VALID BCD** (represents decimal 128)

For value **255**:
- Ones: `255 % 10` = 5 ✓
- Tens: `(255 / 10) % 10` = `25 % 10` = 5 ✓
- `5 << 4 | 5` = 85 (0x55) ✓
- Hundreds: `255 / 100` = 2 ✓
- **Result**: `[0x55, 0x02]` ✓ **VALID BCD** (represents decimal 255)

## Decimal Digit Extraction

The correct formula properly extracts decimal digits:
- **Ones digit**: `value % 10`
- **Tens digit**: `(value / 10) % 10` - Takes quotient, then gets remainder
- **Hundreds digit**: `value / 100`

Examples:
- 128 → ones=8, tens=2, hundreds=1 → BCD: 0x28, 0x01
- 255 → ones=5, tens=5, hundreds=2 → BCD: 0x55, 0x02
- 99  → ones=9, tens=9, hundreds=0 → BCD: 0x99, 0x00
- 100 → ones=0, tens=0, hundreds=1 → BCD: 0x00, 0x01

## Affected Commands

This bug affected **ALL** IC-7100 Level commands (Command 0x14) with values 100-255:

| Command | Subcommand | Function | Range |
|---------|------------|----------|-------|
| 0x14 | 0x07 | Inner Twin PBT | 0-255 |
| 0x14 | 0x08 | Outer Twin PBT | 0-255 |
| 0x14 | 0x0D | Notch Position | 0-255 |
| 0x14 | 0x0E | Compression Level | 0-255 (0-10) |
| 0x14 | 0x0F | Break-In Delay | 0-255 |
| 0x14 | 0x12 | NB Level | 0-255 (0-100%) |
| 0x14 | 0x15 | Monitor Gain | 0-255 (0-100%) |
| 0x14 | 0x16 | **VOX Gain** | 0-255 (0-100%) ⚠️ |
| 0x14 | 0x17 | **Anti-VOX Gain** | 0-255 (0-100%) ⚠️ |
| 0x14 | 0x18 | LCD Contrast | 0-255 (0-100%) |
| 0x14 | 0x19 | LCD Backlight | 0-255 (0-100%) |

⚠️ = User-reported failures

## Why Only Values ≥100 Failed

- Values 0-99: The incorrect formula `(value / 10)` gives 0-9, which are valid BCD digits
  - Example 99: `[9 | (9 << 4), 0]` = `[0x99, 0x00]` ✓ Still works!
- Values 100-255: `(value / 10)` gives 10-25, which are **invalid** BCD digits
  - Example 128: `[8 | (12 << 4), 1]` = `[0xC8, 0x01]` ❌ 0xC invalid!

## Fix Applied

Modified all BCD encoding in the following methods:
- `setInnerPBTIC7100(_ position: UInt8)`
- `setOuterPBTIC7100(_ position: UInt8)`
- `setNotchPositionIC7100(_ position: UInt8)`
- `setCompLevelIC7100(_ level: UInt8)`
- `setBreakInDelayIC7100(_ delay: UInt8)`
- `setNBLevelIC7100(_ level: UInt8)`
- `setMonitorGainIC7100(_ gain: UInt8)`
- `setVoxGainIC7100(_ gain: UInt8)` ⚠️
- `setAntiVoxGainIC7100(_ gain: UInt8)` ⚠️
- `setLCDContrastIC7100(_ contrast: UInt8)`
- `setLCDBacklightIC7100(_ backlight: UInt8)`

## Testing Recommendation

All Level commands with values 100-255 should be retested:
- VOX Gain: 0%, 50% (128), 100% (255) ✓ NOW FIXED
- Anti-VOX Gain: 0%, 50% (128), 100% (255)
- Twin PBT: Center (128), extremes (0, 255)
- LCD Contrast/Backlight: Mid-high values (100-255)

## Impact on Other Radios

This bug was **IC-7100 specific** because:
- IC-7100 uses 2-byte BCD for Level commands (0x14)
- Other radios may use different encoding or different command structures
- Need to verify if IC-7600 or IC-9700 have similar issues

## Lessons Learned

1. **BCD encoding is tricky** - Integer division truncates, not rounds
2. **Test edge cases** - Values 0-99 worked, hiding the bug for 100-255
3. **Hardware validation is critical** - Simulator wouldn't catch this
4. **User feedback is invaluable** - "0% works but 50% and 100% don't" was the key clue

## Files Modified

- `Sources/RigControl/Protocols/Icom/RadioExtensions/IcomCIVProtocol+IC7100.swift`
  - Fixed 11 methods with incorrect BCD encoding
  - Added explanatory comments about BCD digit extraction

---

**Status**: ✅ FIXED
**Commit**: b2f2ca4
**Build**: Successful
**Ready for Testing**: YES
