# IC-7600 Twin Peak Filter Mode Requirement

## Discovery

During hardware validation testing, discovered that the IC-7600 Twin Peak Filter (TPF) requires the radio to be in **RTTY or PSK mode** to function.

## Mode Requirements

### Twin Peak Filter
- **Required Modes**: RTTY or PSK
- **Does NOT work in**: USB, LSB, CW, AM, FM
- **Indicator**: "TPF" appears on display when enabled (only in RTTY/PSK modes)

### Audio Peak Filter
- **Required Mode**: CW
- **Does NOT work in**: Other modes

### Manual Notch
- **Works in**: All modes
- **Indicator**: "MN" appears on display

### Break-in
- **Required Mode**: CW (CW mode only feature)
- **Indicator**: "BK-IN" appears on display

## Implementation Impact

### IC7600Validator
Updated `testAudioDSPControls()` to:
1. Save current mode
2. Switch to **RTTY mode** for Twin Peak Filter test
3. Test TPF ON/OFF
4. Restore original mode

### IC7600ManualValidation
Updated `testTwinPeakFilter()` to:
1. Display "Twin Peak Filter (RTTY/PSK mode required)" header
2. Save current mode
3. Switch to **RTTY mode** with 300ms delay
4. Test TPF control
5. Restore original mode

## API Documentation

The API methods `setTwinPeakFilterIC7600()` and `getTwinPeakFilterIC7600()` will work in any mode, but the radio will only actually activate the filter in RTTY or PSK modes. Applications using this API should:

1. **Either**: Ensure radio is in RTTY/PSK mode before calling
2. **Or**: Document that the feature only works in RTTY/PSK modes

Example:
```swift
// Switch to RTTY mode for Twin Peak Filter
try await rig.setMode(.rtty, vfo: .main)

// Now Twin Peak Filter will actually work
try await icomProtocol.setTwinPeakFilterIC7600(true)
```

## Mode Requirements Summary

| Feature | Required Mode(s) | Notes |
|---------|-----------------|-------|
| Preamp | All modes | Always works |
| AGC | All modes | Always works |
| Attenuator | All modes | Always works |
| Manual Notch | All modes | Always works |
| Audio Peak Filter | **CW only** | CW-specific feature |
| Twin Peak Filter | **RTTY or PSK only** | Digital modes feature |
| Break-in | **CW only** | CW-specific feature |
| Monitor | All modes | Always works |
| TWIN PBT | All modes | Always works |
| Squelch Condition | **FM only** | FM squelch status |

## Files Modified

1. **HardwareValidation/IC7600Validator/main.swift** (Lines 567-587)
   - Added mode save/restore for Twin Peak Filter test
   - Switches to RTTY mode
   - Added error handling for GET failures

2. **Sources/IC7600ManualValidation/main.swift** (Lines 214-290)
   - Added rig parameter to function
   - Added mode save/restore
   - Updated header to indicate mode requirement

## Recommendation for API Documentation

Update `IC7600_API_GUIDE.md` to include a section on "Mode-Specific Features":

```markdown
## Mode-Specific Features

Some IC-7600 features only work in specific operating modes:

### CW Mode Features
- **Audio Peak Filter**: Only functions in CW mode
- **Break-in**: CW-only feature (Semi/Full)

### Digital Mode Features
- **Twin Peak Filter**: Only functions in RTTY or PSK modes

When using these features via CI-V, ensure the radio is in the correct mode first:

\`\`\`swift
// For Twin Peak Filter
try await rig.setMode(.rtty, vfo: .main)
try await icomProtocol.setTwinPeakFilterIC7600(true)

// For Audio Peak Filter
try await rig.setMode(.cw, vfo: .main)
try await icomProtocol.setAudioPeakFilterIC7600(true)
\`\`\`
```

---

**Date**: 2025-12-30
**Discovered During**: IC-7600 manual validation testing
**Status**: Documented and implemented in validators
