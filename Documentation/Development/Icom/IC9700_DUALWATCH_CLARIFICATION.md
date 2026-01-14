# IC-9700 Dualwatch Clarification

**Date**: 2026-01-07
**Status**: ✅ CLARIFIED AND FIXED

---

## Issue

The IC-9700 was incorrectly assumed to support "Dualwatch" mode (CI-V commands 0x07 0xC2/0xC3) like the IC-7600.

## Discovery

During hardware validation testing, it was discovered that:

1. **IC-9700 NAKs (rejects) dualwatch commands** (0x07 0xC2 and 0x07 0xC3)
2. **IC-9700 has no "DW" button** on the front panel (unlike IC-7600)
3. **IC-9700 is a TRUE dual-receiver radio** where both receivers are always independent

## Root Cause

**Incorrect assumption**: "All dual-receiver radios support dualwatch"

**Reality**: There are two types of dual-receiver architectures:

### IC-7600: Dual-Receiver with Dualwatch Mode
- **Architecture**: One receiver that can monitor two bands
- **Dualwatch Mode**: Optional feature to enable/disable simultaneous monitoring
- **Front Panel**: Has "DW" (Dualwatch) button
- **CI-V Commands**:
  - `0x07 0xC2` = Dualwatch OFF
  - `0x07 0xC3` = Dualwatch ON
- **Use Case**: Primarily single-band operation with optional dual-band monitoring

### IC-9700: True Dual-Receiver (No Dualwatch)
- **Architecture**: Two completely independent receivers (Main and Sub)
- **Always Active**: Both receivers operate simultaneously by design
- **Sub Receiver Control**: Press and hold SUB AF/RF knob to turn Sub receiver on/off
- **No Dualwatch Mode**: Not needed - receivers are always independent
- **CI-V Commands**: `0x07 0xC2/0xC3` are **NOT supported** (NAK response)
- **Use Case**: Satellite operation, cross-band operation, independent monitoring

## Analogy

- **IC-7600**: Like a stereo with a "mono/stereo" switch (dualwatch toggle)
- **IC-9700**: Like two completely separate radios in one box (always dual)

## Fix Applied

### 1. Updated `IcomCIVProtocol+DualReceiver.swift`

**Before:**
```swift
public func setDualwatch(_ enabled: Bool) async throws {
    let dualReceiverModels: [IcomRadioModel] = [.ic7600, .ic9700, .ic9100]
    guard dualReceiverModels.contains(radioModel) else {
        throw RigError.unsupportedOperation("Dualwatch only available for dual-receiver radios")
    }
    // ... send 0x07 0xC2 or 0xC3 ...
}
```

**After:**
```swift
public func setDualwatch(_ enabled: Bool) async throws {
    // Only IC-7600 supports traditional dualwatch mode
    // IC-9700/IC-9100 are true dual-receivers (both always independent)
    let dualwatchModels: [IcomRadioModel] = [.ic7600]
    guard dualwatchModels.contains(radioModel) else {
        throw RigError.unsupportedOperation("Dualwatch mode only available on IC-7600. IC-9700/IC-9100 are true dual-receivers (both always active).")
    }
    // ... send 0x07 0xC2 or 0xC3 ...
}
```

### 2. Removed Dualwatch Test from Interactive Validator

**File**: `Sources/IC9700InteractiveValidator/main.swift`

- Removed `test3_Dualwatch()` method entirely
- Updated test numbering (Test 4 → Test 3, Test 5 → Test 4)
- Updated documentation to reflect 4 tests instead of 5

### 3. Updated Documentation

**File**: `IC9700_INTERACTIVE_VALIDATOR.md`

Added prominent note:

> **IC-9700 does NOT have a "Dualwatch" mode** like the IC-7600. The IC-9700 is a **true dual-receiver radio** where both Main and Sub receivers are always independent and fully active. You can turn the Sub receiver on/off by pressing and holding the SUB AF/RF knob, but there's no separate "dualwatch" feature to enable/disable.

## Impact on Other Radios

### IC-9100
Similar architecture to IC-9700 (satellite-capable dual-receiver). **Likely does NOT support dualwatch** either. Will need hardware testing to confirm.

**Recommendation**: Assume IC-9100 follows IC-9700 pattern (no dualwatch) until proven otherwise.

### IC-7600
**No change** - IC-7600 dualwatch support confirmed working in hardware tests.

## Command Reference Update

| Radio | Main/Sub | VFO A/B | Band Exchange | Dualwatch | Notes |
|-------|----------|---------|---------------|-----------|-------|
| IC-7600 | ✅ 0xD0/0xD1 | ❌ | ✅ 0xB0 | ✅ 0xC2/0xC3 | Dual-RX with DW mode |
| IC-9700 | ✅ 0xD0/0xD1 | ✅ 0x00/0x01 | ✅ 0xB0 | ❌ NAK | True dual-RX (no DW) |
| IC-9100 | ✅ 0xD0/0xD1 | ✅ 0x00/0x01 | ✅ 0xB0 | ❌ Likely NAK | True dual-RX (no DW) |

## Lesson Learned

**Don't assume radio capabilities based on features of similar radios.**

Even radios in the same "dual-receiver" category can have fundamentally different architectures and command support.

**Always validate with hardware** before assuming command compatibility.

## Verification

✅ IC-9700 hardware test confirmed NAK on `0x07 0xC3` (dualwatch ON)
✅ IC-9700 hardware test confirmed NAK on `0x07 0xC2` (dualwatch OFF)
✅ IC-9700 operates both receivers simultaneously by design
✅ Code updated to restrict dualwatch to IC-7600 only
✅ Documentation updated to clarify difference
✅ Interactive validator updated (dualwatch test removed)

---

**Status**: Issue resolved, code corrected, documentation updated.
