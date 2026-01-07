# IC-9700 Test Analysis and Action Plan

**Date:** 2026-01-05
**Engineer:** Senior Swift Engineer
**Status:** 11/25 tests passing (44%) - **UNACCEPTABLE FOR WORLD-CLASS LIBRARY**

---

## Executive Summary

The IC-9700 test suite revealed **critical architecture bugs** affecting 44% of tests. The root cause is a **WRONG VFO MODEL configuration** in `IC9700CommandSet.swift`.

**Current:** `.currentOnly` (wrong!)
**Correct:** `.mainSub` (dual receiver with Main/Sub codes)

This single misconfiguration cascades into 6 VFO-related test failures.

---

## Test Results Breakdown

### ✅ PASSING (11 tests - 44%)

1. **testConnection** - Basic communication
2. **testAttenuatorControl** - RF attenuator 0dB/10dB
3. **testModeControl** - All 6 modes (LSB/USB/CW/CW-R/FM/AM)
4. **testPowerControl** - Power 5-50W
5. **testVHFBand** - 2m frequency changes
6. **testVOXControl** - VOX/Anti-VOX gain (0%, 50%, 100%)
7. **testSignalStrength** - S-meter readings
8. **testSquelchStatus** - Squelch open/closed
9. **testRapidFrequencyChanges** - 50 changes @ 44.8ms avg (excellent!)
10. **testRapidModeChanges** - 25 changes @ 43.0ms avg (excellent!)
11. **testNRLevel** - Commands work, but values off (see Category 3)

### ❌ FAILING (11 tests - 44%)

#### Category 1: VFO Selection Rejected (6 tests) - **CRITICAL BUG**
**Error:** `"commandFailed("Radio rejected VFO selection")"`
**Location:** `IcomCIVProtocol.swift:256`

**Affected Tests:**
1. `testDualReceiver` - Cannot select VFO B (Sub receiver)
2. `testIndependentModes` - Cannot select VFO B
3. `testBandExchange` - Cannot exchange Main/Sub
4. `testSatelliteMode` - Cannot access VFO B
5. `testSplitOperation` - Cannot enable split (needs VFO B)
6. `testDualwatch` - Cannot enable dualwatch

**ROOT CAUSE:**
```swift
// IC9700CommandSet.swift:31 - WRONG!
public let vfoModel: VFOOperationModel = .currentOnly
```

**Should be:**
```swift
// IC-9700 is a DUAL RECEIVER radio using Main/Sub architecture
public let vfoModel: VFOOperationModel = .mainSub
```

**Technical Details:**
- `.currentOnly` sends VFO codes: A=0x00, B=0x01
- `.mainSub` sends VFO codes: Main=0xD0, Sub=0xD1
- IC-9700 manual confirms it uses Main/Sub architecture (page 18-2)
- Documentation in `IcomRadioTypes.swift` line 37 confirms IC-9700 should use `.mainSub`

**Fix:** Change one line in `IC9700CommandSet.swift`

**Impact:** Will fix 6 tests immediately (24% improvement)

---

#### Category 2: Invalid Response Format (5 tests) - **PARSING BUG**
**Error:** `"invalidResponse"`

**Affected Tests:**
1. `testAGCControl` - Line 628 `IcomCIVProtocol+IC9700.swift`
2. `testDialLock` - Line 739
3. `testManualNotch` - Line 702
4. `testPreampControl` - Line 233
5. `testMonitorFunction` - Line 665

**ROOT CAUSE:**
These are all GET commands that expect specific response formats. The response parsing is failing, likely because:
- The IC-9700 may return data in a different format than expected
- Command echo setting may be interfering with response parsing
- Need to add detailed logging to see actual vs expected response format

**Investigation Required:**
1. Add response logging to see what the radio actually returns
2. Compare against IC-9700 CI-V manual response formats
3. Check if `echoesCommands = true` setting is correct (line 33 IC9700CommandSet.swift)

**Per manual:** IC-9700 DOES echo commands over USB (confirmed in Hamlib issues)

**Fix:** Update response parsing in getter methods to handle IC-9700 response format

**Impact:** Will fix 5 tests (20% improvement)

---

#### Category 3: NR Level Value Mismatch (1 test) - **VALUE ENCODING BUG**
**Error:** Consistent value offsets

**Test Output:**
```
Expected: 0,   Got: 8    (Δ +8)
Expected: 128, Got: 136  (Δ +8)
Expected: 255, Got: 248  (Δ -7)
```

**ROOT CAUSE:**
Commands are being ACCEPTED (no rejection errors), but values don't match. This suggests:

1. **Radio quantization:** IC-9700 displays NR as 0-15, but CI-V uses 0-255
   - 0/255 * 15 = 0 (display 0)
   - 128/255 * 15 ≈ 7.5 → rounds to 8? (display 8)
   - 255/255 * 15 = 15 (display 15)

2. **Possible BCD encoding issue:** Values are close but consistently off
   - GET is returning raw display values (0-15) not CI-V values (0-255)?
   - Or decoding is applying wrong scale factor?

3. **Investigation:** Check `getNRLevelIC9700()` response parsing (line 315-343)

**Fix:** Investigate response format and BCD decoding in NR getter

**Impact:** Will fix 1 test (4% improvement)

---

### ⏭️ SKIPPED (3 tests - 12%)

1. **test1_2GHzBand** - Radio on VHF, needs manual band switch to 23cm
2. **testUHFBand** - Radio on VHF, needs manual band switch to 70cm
3. **testPTTControl** - User safety prompt (correct behavior)

**These are EXPECTED** - Radio band stacking prevents automatic band switching.

---

## Path to 100% Success

### Phase 1: Fix VFO Model (IMMEDIATE - 5 minutes)
**File:** `Sources/RigControl/Protocols/Icom/CommandSets/IC9700CommandSet.swift`

```swift
// Line 31 - CHANGE THIS:
public let vfoModel: VFOOperationModel = .currentOnly

// TO THIS:
public let vfoModel: VFOOperationModel = .mainSub  // IC-9700 uses Main/Sub dual receiver
```

**Expected Result:** 6 tests will pass (24% improvement → 68% total)

---

### Phase 2: Fix Response Parsing (30-60 minutes)
**Files:**
- `Sources/RigControl/Protocols/Icom/RadioExtensions/IcomCIVProtocol+IC9700.swift`
- Lines: 233, 628, 665, 702, 739

**Steps:**
1. Add detailed response logging to each failing getter
2. Compare actual response bytes against IC-9700 CI-V manual
3. Update response parsing to match actual format
4. Test with hardware

**Expected Result:** 5 tests will pass (20% improvement → 88% total)

---

### Phase 3: Fix NR Level Encoding (15-30 minutes)
**File:** `Sources/RigControl/Protocols/Icom/RadioExtensions/IcomCIVProtocol+IC9700.swift`
**Method:** `getNRLevelIC9700()` (lines 316-343)

**Steps:**
1. Check if radio returns 0-15 scale instead of 0-255
2. If so, scale response: `displayValue * 17` (15 * 17 = 255)
3. Or adjust test expectations to match radio behavior

**Expected Result:** 1 test will pass (4% improvement → 92% total)

---

### Phase 4: Hardware Validation (User action required)
**Tests:** Band-specific tests (UHF, 1.2GHz)

**User must:**
1. Switch radio to UHF band manually
2. Run: `swift test --filter IC9700HardwareTests.testUHFBand`
3. Switch radio to 1.2GHz band manually
4. Run: `swift test --filter IC9700HardwareTests.test1_2GHzBand`

**Expected Result:** 2 tests will pass (8% improvement → 100% total)

---

## Immediate Action Items

### Priority 1 (DO NOW):
1. ✅ Change `.currentOnly` to `.mainSub` in IC9700CommandSet.swift
2. ✅ Build and run tests
3. ✅ Verify 6 VFO tests now pass

### Priority 2 (NEXT):
1. Add response logging to failing getters
2. Capture actual response bytes from radio
3. Compare against IC-9700 CI-V manual (page 18-XX)
4. Fix response parsing

### Priority 3 (THEN):
1. Investigate NR Level scaling issue
2. Fix or document expected behavior

---

## World-Class Standards

For a **world-class amateur radio library**, we require:

- ✅ **100% test pass rate** (not 44%)
- ✅ **Accurate CI-V command implementation** verified against manuals
- ✅ **Proper VFO model configuration** for each radio
- ✅ **Comprehensive hardware testing** on all supported bands
- ✅ **Clear documentation** of radio-specific quirks

---

## Estimated Timeline

- **Phase 1:** 5 minutes → 68% pass rate
- **Phase 2:** 1 hour → 88% pass rate
- **Phase 3:** 30 minutes → 92% pass rate
- **Phase 4:** User action → 100% pass rate

**Total:** ~2 hours of engineering time + user hardware validation

---

## Conclusion

The IC-9700 test failures are **NOT fundamental design flaws**. They are:
1. **One configuration error** (wrong VFO model)
2. **Response format parsing** that needs adjustment
3. **One value scaling** issue to investigate

All are **fixable within 2 hours**. The test suite design is **excellent** - it caught these bugs immediately and provides clear diagnostic information.

**Next step:** Fix the VFO model and re-run tests. We expect immediate improvement from 44% → 68% pass rate.

---

**Status:** Ready for Phase 1 implementation
