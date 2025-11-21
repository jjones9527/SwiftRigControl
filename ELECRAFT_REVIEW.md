# Elecraft Radio Implementation Review

**Review Date:** 2025-11-21
**Review Scope:** V1.0.1 Elecraft Protocol Implementation
**Reviewer:** Claude Code

## Executive Summary

This review examined the Elecraft protocol implementation in V1.0.1. The implementation is mostly correct and functional, but **one critical issue** was identified with VFO selection and split operation logic that could cause unexpected behavior with real hardware.

**Overall Assessment:** ⚠️ **REQUIRES FIXES**

---

## Files Reviewed

1. `Sources/RigControl/Protocols/Elecraft/ElecraftProtocol.swift` (346 lines)
2. `Sources/RigControl/Protocols/Elecraft/ElecraftModels.swift` (197 lines)
3. `Tests/RigControlTests/ElecraftProtocolTests.swift` (327 lines)

---

## Critical Issues Found

### 🔴 Issue #1: VFO Selection Incomplete (CRITICAL)

**Location:** `ElecraftProtocol.swift:159-174`

**Problem:**
The `selectVFO()` function only sets the **FT** (transmit VFO) command, but doesn't set the **FR** (receive VFO) command. This means selecting a VFO only changes where you transmit, not where you receive.

**Current Implementation:**
```swift
public func selectVFO(_ vfo: VFO) async throws {
    let command: String
    switch vfo {
    case .a, .main:
        command = "FT0"  // Select VFO A - ONLY SETS TX VFO!
    case .b, .sub:
        command = "FT1"  // Select VFO B - ONLY SETS TX VFO!
    }

    try await sendCommand(command)
    let response = try await receiveResponse()

    guard response.hasPrefix(command) else {
        throw RigError.commandFailed("VFO selection failed")
    }
}
```

**Elecraft Protocol Reference:**
- **FR** command: Sets the receive VFO (FR0 = VFO A, FR1 = VFO B)
- **FT** command: Sets the transmit VFO (FT0 = VFO A, FT1 = VFO B)
- To properly select a VFO for both RX and TX, **both FR and FT must be set**

**Expected Behavior:**
When `selectVFO(.a)` is called:
- Both RX and TX should use VFO A (FR0 and FT0)

When `selectVFO(.b)` is called:
- Both RX and TX should use VFO B (FR1 and FT1)

**Impact:**
- **HIGH** - Users calling `selectVFO()` will only change their transmit VFO
- Radio will receive on one VFO and transmit on another (unintentional split)
- Confusing behavior that doesn't match user expectations
- Could cause transmission on wrong frequency

**Recommended Fix:**
```swift
public func selectVFO(_ vfo: VFO) async throws {
    let frCommand: String
    let ftCommand: String

    switch vfo {
    case .a, .main:
        frCommand = "FR0"  // Receive on VFO A
        ftCommand = "FT0"  // Transmit on VFO A
    case .b, .sub:
        frCommand = "FR1"  // Receive on VFO B
        ftCommand = "FT1"  // Transmit on VFO B
    }

    // Set receive VFO
    try await sendCommand(frCommand)
    let frResponse = try await receiveResponse()
    guard frResponse.hasPrefix(frCommand) else {
        throw RigError.commandFailed("VFO RX selection failed")
    }

    // Set transmit VFO
    try await sendCommand(ftCommand)
    let ftResponse = try await receiveResponse()
    guard ftResponse.hasPrefix(ftCommand) else {
        throw RigError.commandFailed("VFO TX selection failed")
    }
}
```

---

### 🟡 Issue #2: Split Operation Incomplete (MEDIUM)

**Location:** `ElecraftProtocol.swift:222-234`

**Problem:**
The `setSplit()` function only sets the **FT** command but doesn't explicitly set **FR**. While this may work in some cases (assuming FR is already set to VFO A), it's not robust and doesn't guarantee correct split operation.

**Current Implementation:**
```swift
public func setSplit(_ enabled: Bool) async throws {
    guard capabilities.hasSplit else {
        throw RigError.unsupportedOperation("Split operation not supported")
    }

    let command = enabled ? "FT1" : "FT0"  // FT1 enables split
    try await sendCommand(command)
    let response = try await receiveResponse()

    guard response.hasPrefix(command) else {
        throw RigError.commandFailed("Split operation failed")
    }
}
```

**Expected Behavior:**
For split operation (enabled = true):
- RX on VFO A, TX on VFO B (FR0; FT1;)

For normal operation (enabled = false):
- RX and TX on same VFO (FR0; FT0; or FR1; FT1; depending on selected VFO)

**Impact:**
- **MEDIUM** - May work if FR is already set to 0, but relies on radio state
- Not explicit about which VFO to receive on during split
- Could fail if user previously selected VFO B

**Recommended Fix:**
```swift
public func setSplit(_ enabled: Bool) async throws {
    guard capabilities.hasSplit else {
        throw RigError.unsupportedOperation("Split operation not supported")
    }

    if enabled {
        // Split: RX on VFO A, TX on VFO B
        try await sendCommand("FR0")
        let frResponse = try await receiveResponse()
        guard frResponse.hasPrefix("FR0") else {
            throw RigError.commandFailed("Split RX VFO selection failed")
        }

        try await sendCommand("FT1")
        let ftResponse = try await receiveResponse()
        guard ftResponse.hasPrefix("FT1") else {
            throw RigError.commandFailed("Split TX VFO selection failed")
        }
    } else {
        // Normal: RX and TX on VFO A (or query current VFO first)
        try await sendCommand("FR0")
        let frResponse = try await receiveResponse()
        guard frResponse.hasPrefix("FR0") else {
            throw RigError.commandFailed("Normal RX VFO selection failed")
        }

        try await sendCommand("FT0")
        let ftResponse = try await receiveResponse()
        guard ftResponse.hasPrefix("FT0") else {
            throw RigError.commandFailed("Normal TX VFO selection failed")
        }
    }
}
```

---

## Minor Issues and Observations

### 🟢 Issue #3: Signal Strength Calculation Needs Verification (LOW)

**Location:** `ElecraftProtocol.swift:254-280`

**Observation:**
The signal strength calculation assumes the SM command returns dB values, with a range of 0-30 dB. However, the comment states "S0 to S9 = 54 dB", which would require a range of 0-54, not 0-30.

**Current Implementation:**
```swift
// Elecraft: 0-30 represents dB over S0
// S0 to S9 = 54 dB (6 dB per S-unit)
// So: S1 = 6 dB, S2 = 12 dB, ..., S9 = 54 dB
let sUnits = min(rawValue / 6, 9)
let overS9 = sUnits >= 9 ? max(rawValue - 54, 0) : 0
```

**Analysis:**
- If rawValue ranges 0-30, then rawValue/6 gives 0-5, not 0-9
- The comment about S9 = 54 dB is correct in RF theory (6 dB per S-unit)
- But the SM command likely returns a bar graph value (0-30), not dB
- The actual mapping should be approximately: sUnits = min(rawValue / 3, 9)

**Impact:**
- **LOW** - Signal strength reading may be inaccurate
- May show S5 when radio actually shows S9
- Needs verification with actual hardware

**Recommendation:**
Test with real hardware and adjust the scaling factor. Consider:
```swift
// SM returns 0-30 bar graph units (approximately 3-4 units per S-unit)
let sUnits = min(rawValue / 3, 9)  // Approximate: 0-27 maps to S0-S9
let overS9 = rawValue > 27 ? (rawValue - 27) * 2 : 0  // Remaining maps to over S9
```

---

### 🟢 Issue #4: Missing RTTY Mode (LOW)

**Location:** `ElecraftProtocol.swift:315-344`

**Observation:**
The mode mappings don't include RTTY mode (code 8), which is supported by Elecraft radios.

**Current Modes:**
- LSB (1), USB (2), CW (3), FM (4), AM (5)
- DATA-USB (6), CW-R (7), DATA-LSB (9)
- **Missing:** RTTY (8)

**Impact:**
- **LOW** - RTTY mode cannot be set or detected
- Not critical for most users, as DATA-USB is often used for digital modes

**Recommendation:**
Add RTTY mode support if Mode enum includes it:
```swift
case 8: return .rtty  // Add if .rtty exists in Mode enum
```

---

### 🟢 Issue #5: Test Coverage Missing dataLSB Mode (LOW)

**Location:** `ElecraftProtocolTests.swift:127-155`

**Observation:**
The mode mapping test doesn't include `.dataLSB` (code 9), even though it's supported in the protocol.

**Impact:**
- **LOW** - dataLSB mode is not tested
- Protocol supports it, but test coverage is incomplete

**Recommendation:**
Add to test cases:
```swift
(.dataLSB, "MD9;"),
```

---

## What's Working Well ✅

### Command Format and Termination ✅
- Correct semicolon termination (line 24, 288)
- Proper ASCII encoding
- Command echo validation
- Good error handling for invalid responses

### Frequency Control ✅
- Correct 11-digit frequency format (FA%011llu)
- Proper handling of VFO A and VFO B
- Frequency parsing looks correct
- Good validation of responses

### Mode Control ✅
- Mode codes are correct for supported modes
- Good mode conversion logic
- Proper error handling for unsupported modes

### Power Control ✅
- Correct percentage-based power control
- Proper conversion between watts and percentage
- Respects maxPower from capabilities
- Good bounds checking (min/max)

### PTT Control ✅
- Simple TX/RX commands
- Appropriate handling of no-echo behavior
- Correct 50ms delay for command processing
- Good note about getPTT() not being supported

### Protocol Structure ✅
- Good use of async/await
- Actor isolation for thread safety
- Clean separation of concerns
- Good documentation and comments

### Radio Definitions ✅
- Six radio models properly defined
- Correct baud rates for each model
- Appropriate power levels
- Good frequency range definitions

### Test Coverage ✅
- Comprehensive test suite (15 tests)
- Good use of MockTransport
- Tests cover all major operations
- Integration test validates workflow

---

## Recommendations Summary

### Priority 1 - MUST FIX:
1. ✅ **Fix `selectVFO()`** to set both FR and FT commands
2. ✅ **Fix `setSplit()`** to explicitly set both FR and FT

### Priority 2 - SHOULD FIX:
3. ⚠️ **Verify signal strength calculation** with real hardware
4. 📝 **Add RTTY mode** if Mode enum supports it

### Priority 3 - NICE TO HAVE:
5. 📋 **Add dataLSB test** for completeness

---

## Testing Recommendations

Before deploying to production:

1. **Test with real K3/K3S hardware:**
   - Verify VFO selection switches both RX and TX
   - Verify split operation uses correct VFOs
   - Verify signal strength readings are accurate

2. **Test edge cases:**
   - Switch VFOs multiple times
   - Enable/disable split multiple times
   - Test split with different VFO configurations

3. **Integration testing:**
   - Test with logging software that uses VFO/split features
   - Verify no unexpected frequency changes
   - Verify split behavior matches radio display

---

## Conclusion

The Elecraft implementation is well-structured and mostly correct, but has **one critical bug** in VFO selection that needs to be fixed before use with real hardware. The split operation also needs improvement for robustness.

**Status:** ⚠️ **NOT READY FOR PRODUCTION**
**Action Required:** Fix VFO and split operations before v1.0.1 release

---

## References

- Elecraft K3 Programmer's Reference Manual
- Elecraft K3S/K4 CAT Protocol Documentation
- Amateur Radio S-meter standard (6 dB per S-unit)

---

**Document Version:** 1.0
**Last Updated:** 2025-11-21
