# IC-7600 Break-in Implementation Issue

## Discovery

During hardware validation testing, discovered that the IC-7600 Break-in feature has **3 states**, not 2:

- **OFF** (0x00)
- **Semi Break-in** (0x01)
- **Full Break-in** (0x02)

## Current Implementation Problem

**File**: `Sources/RigControl/Protocols/Icom/RadioExtensions/IcomCIVProtocol+IC7600.swift`

```swift
/// Set break-in (IC-7600)
/// - Parameter enabled: true=ON, false=OFF
public func setBreakInIC7600(_ enabled: Bool) async throws {
    guard radioModel == .ic7600 else {
        throw RigError.unsupportedOperation("setBreakInIC7600 is only available on IC-7600")
    }
    try await setFunctionIC7600(CIVFrame.FunctionCode.breakIn, value: enabled ? 0x01 : 0x00)
}

/// Read break-in setting (IC-7600)
public func getBreakInIC7600() async throws -> Bool {
    guard radioModel == .ic7600 else {
        throw RigError.unsupportedOperation("getBreakInIC7600 is only available on IC-7600")
    }
    let value = try await getFunctionIC7600(CIVFrame.FunctionCode.breakIn)
    return value != 0x00
}
```

**Problem**:
- `setBreakInIC7600(true)` sets to **Semi** (0x01), but there's no way to set **Full** (0x02)
- `getBreakInIC7600()` returns `true` for both Semi and Full, losing state information

## Manual Reference

From IC-7600 CI-V Manual (page 153, command 0x16 0x47):

```
00: BK-IN function OFF
01: Semi BK-IN function ON
02: Full BK-IN function ON
```

## Recommended Fix

Replace boolean API with enum-based API:

```swift
public enum BreakInMode: UInt8 {
    case off = 0x00
    case semi = 0x01
    case full = 0x02
}

/// Set break-in mode (IC-7600)
/// - Parameter mode: OFF, Semi, or Full break-in
public func setBreakInModeIC7600(_ mode: BreakInMode) async throws {
    guard radioModel == .ic7600 else {
        throw RigError.unsupportedOperation("setBreakInModeIC7600 is only available on IC-7600")
    }
    try await setFunctionIC7600(CIVFrame.FunctionCode.breakIn, value: mode.rawValue)
}

/// Read break-in mode (IC-7600)
/// - Returns: Current break-in mode (OFF, Semi, or Full)
public func getBreakInModeIC7600() async throws -> BreakInMode {
    guard radioModel == .ic7600 else {
        throw RigError.unsupportedOperation("getBreakInModeIC7600 is only available on IC-7600")
    }
    let value = try await getFunctionIC7600(CIVFrame.FunctionCode.breakIn)
    guard let mode = BreakInMode(rawValue: value) else {
        throw RigError.invalidResponse
    }
    return mode
}
```

## Migration Path

To maintain backwards compatibility:

1. Add new `BreakInMode` enum
2. Add new `setBreakInModeIC7600()` and `getBreakInModeIC7600()` methods
3. **Deprecate** (but don't remove) existing boolean methods
4. Update documentation to recommend new methods
5. Update validator to use new enum-based API

## Impact

**Breaking Change**: No (old methods remain)
**API Addition**: Yes (new enum and methods)
**Documentation Update**: Yes
**Validator Update**: Yes

## Similar Issues

Check other IC-7600 functions that might have >2 states but use boolean API:
- AGC (already uses UInt8: FAST=1, MID=2, SLOW=3) ✅ Correct
- Attenuator (uses UInt8 for dB levels) ✅ Correct
- Preamp (uses UInt8: OFF=0, P.AMP1=1, P.AMP2=2) ✅ Correct

Break-in appears to be the only boolean API that should be multi-state.

---

**Date**: 2025-12-30
**Discovered During**: IC-7600 hardware validation testing
**Status**: Documented, awaiting implementation decision
