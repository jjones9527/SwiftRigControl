# IC-9700 VFO Architecture - CRITICAL DISCOVERY

**Date:** 2026-01-05
**Status:** ARCHITECTURE MISUNDERSTANDING IDENTIFIED

---

## Executive Summary

The IC-9700 has **DUAL VFO architecture**: **Main/Sub receivers** (band selection) AND **VFO A/B** (frequency selection per band).

**This means there are actually 4 VFO states:**
- Main receiver, VFO A
- Main receiver, VFO B
- Sub receiver, VFO A
- Sub receiver, VFO B

**Current implementation incorrectly treats Main/Sub as equivalent to VFO A/B**, when they are actually orthogonal concepts.

---

## IC-9700 Architecture

### Dual Receiver System

The IC-9700 has **two independent receivers**:
1. **Main Receiver (0xD0)** - Primary receiver
2. **Sub Receiver (0xD1)** - Secondary receiver

Each receiver can be tuned to a **different band** (2m, 70cm, 1.2GHz).

### VFO A/B per Receiver

**EACH receiver has its own VFO A and VFO B:**
- Main receiver can switch between Main-A and Main-B
- Sub receiver can switch between Sub-A and Sub-B

This allows:
- Quick frequency switching within a band (A ↔ B)
- Independent operation of each receiver
- Full duplex operation for satellite contacts

---

## Command 07 - VFO Selection

From IC-9700 CI-V Manual (Page 5):

```
07 Select the VFO mode
   00 Select VFO A (In satellite mode, selects VFO mode)
   01 Select VFO B (In satellite mode, "FA" (NG) is returned)
   A0 Equalize VFO A and VFO B
   B0 Exchange MAIN and SUB Bands
   D0 Select the main band
   D1 Select the sub band
   D2 00=Send/read main band selection, 01=Send/read sub band selection
   C2 Dualwatch OFF
   C3 Dualwatch ON
```

### Command Breakdown

| Code | Function | Scope |
|------|----------|-------|
| 0x00 | Select VFO A | **Current receiver** (Main or Sub) |
| 0x01 | Select VFO B | **Current receiver** (Main or Sub) |
| 0xA0 | Equalize VFO A and B | **Current receiver** (copy A → B) |
| 0xB0 | Exchange Main ↔ Sub | **Swap band frequencies** |
| 0xD0 | Select Main band | **Switch to Main receiver** |
| 0xD1 | Select Sub band | **Switch to Sub receiver** |
| 0xD2 0x00 | Query Main selection | **Read Main receiver state** |
| 0xD2 0x01 | Query Sub selection | **Read Sub receiver state** |
| 0xC2 | Dualwatch OFF | **Disable simultaneous RX** |
| 0xC3 | Dualwatch ON | **Enable simultaneous RX** |

---

## Satellite Mode (Command 0x16 0x5A)

When **satellite mode is enabled**:
- Main receiver = **Downlink** (receive from satellite)
- Sub receiver = **Uplink** (transmit to satellite)
- Full duplex operation (transmit while receiving)
- Independent VFO A/B on each receiver for tracking

**In satellite mode:**
- Command 0x07 0x00 = Select VFO mode (enables VFO operation)
- Command 0x07 0x01 = Returns "FA" (NG) - not allowed in satellite mode

---

## Current Implementation Issues

### Problem 1: VFO Enum Mapping

**Current mapping in `IcomRadioTypes.swift`:**
```swift
public enum VFOCodeHelper {
    public static func mainSubCode(for vfo: VFO) -> UInt8? {
        switch vfo {
        case .main:
            return CIVFrame.VFOSelect.main  // 0xD0
        case .sub:
            return CIVFrame.VFOSelect.sub   // 0xD1
        case .a, .b:
            return nil  // Not supported for Main/Sub radios
        }
    }
}
```

**Problem:** This treats `.main` as "Main receiver" and `.sub` as "Sub receiver", but **ignores VFO A/B selection**!

### Problem 2: VFO Selection in `IcomRadioCommandSet`

The protocol default implementation sends:
- `VFO.a` → 0xD0 (Main band)
- `VFO.b` → 0xD1 (Sub band)

But it **should** send:
- `VFO.a` → 0x00 (VFO A on current receiver)
- `VFO.b` → 0x01 (VFO B on current receiver)
- `VFO.main` → 0xD0 (switch to Main receiver)
- `VFO.sub` → 0xD1 (switch to Sub receiver)

### Problem 3: Command 0x25/0x26 (Selected/Unselected VFO)

These commands work **only on the Main receiver**:
- 0x25 = Read/Write frequency of **selected VFO** (Main-A or Main-B)
- 0x26 = Read/Write frequency of **unselected VFO** (Main-B or Main-A)

**These do NOT work on the Sub receiver!**

Sub receiver frequency is accessed via:
- Command 0x03 (read operating frequency) after selecting Sub (0x07 0xD1)
- Command 0x05 (set operating frequency) after selecting Sub (0x07 0xD1)

---

## Correct Architecture Model

```
IC-9700
├── Main Receiver (0xD0)
│   ├── VFO A (0x00) - Can be 2m, 70cm, or 1.2GHz
│   └── VFO B (0x01) - Can be 2m, 70cm, or 1.2GHz
│       └── Commands 0x25/0x26 work here (selected/unselected VFO)
└── Sub Receiver (0xD1)
    ├── VFO A (0x00) - Can be 2m, 70cm, or 1.2GHz (must differ from Main)
    └── VFO B (0x01) - Can be 2m, 70cm, or 1.2GHz (must differ from Main)
        └── Commands 0x25/0x26 DO NOT work here
```

### Operating Constraints

1. **Main and Sub must be on different bands** for independent operation
2. If Main and Sub are on the **same band**, they share mode settings
3. Each receiver has independent VFO A/B for quick frequency switching
4. Command 0x07 0x00/0x01 selects VFO A/B on the **currently selected receiver**
5. Command 0x07 0xD0/0xD1 switches between Main and Sub receivers

---

## Example Command Sequences

### Sequence 1: Set Main receiver to VFO A at 145.500 MHz
```
1. FE FE A2 E0 07 D0 FD    // Select Main receiver
2. FE FE A2 E0 07 00 FD    // Select VFO A
3. FE FE A2 E0 05 00 00 50 54 41 01 FD  // Set 145.500 MHz
```

### Sequence 2: Set Sub receiver to VFO B at 435.000 MHz
```
1. FE FE A2 E0 07 D1 FD    // Select Sub receiver
2. FE FE A2 E0 07 01 FD    // Select VFO B
3. FE FE A2 E0 05 00 00 00 53 43 FD     // Set 435.000 MHz
```

### Sequence 3: Split operation (Main RX, Main VFO B TX)
```
1. FE FE A2 E0 07 D0 FD    // Select Main receiver
2. FE FE A2 E0 07 00 FD    // Select VFO A (RX frequency)
3. FE FE A2 E0 05 [freq] FD // Set RX frequency
4. FE FE A2 E0 07 01 FD    // Select VFO B (TX frequency)
5. FE FE A2 E0 05 [freq] FD // Set TX frequency
6. FE FE A2 E0 0F 01 FD    // Enable split (TX on VFO B)
```

### Sequence 4: Satellite mode (Main RX 145.900, Sub TX 435.000)
```
1. FE FE A2 E0 16 5A 01 FD // Enable satellite mode
2. FE FE A2 E0 07 D0 FD    // Select Main (downlink RX)
3. FE FE A2 E0 05 [145.9] FD // Set downlink frequency
4. FE FE A2 E0 07 D1 FD    // Select Sub (uplink TX)
5. FE FE A2 E0 05 [435.0] FD // Set uplink frequency
```

---

## Required Implementation Changes

### 1. VFO Enum Expansion

The `VFO` enum needs to support the 4-state model:

**Option A: Extend VFO enum**
```swift
public enum VFO: String, Sendable {
    case a = "VFO A"
    case b = "VFO B"
    case main = "Main"
    case sub = "Sub"

    // For IC-9700 composite operations
    case mainA = "Main-A"
    case mainB = "Main-B"
    case subA = "Sub-A"
    case subB = "Sub-B"
}
```

**Option B: Separate Band and VFO concepts**
```swift
public enum Band: String, Sendable {
    case main = "Main"
    case sub = "Sub"
}

public enum VFO: String, Sendable {
    case a = "VFO A"
    case b = "VFO B"
}

// Operations specify both
rig.setFrequency(145_500_000, band: .main, vfo: .a)
```

### 2. Command Set Updates

`IC9700CommandSet.swift` needs:
```swift
public struct IC9700CommandSet: IcomRadioCommandSet {
    public let civAddress: UInt8 = 0xA2
    public let vfoModel: VFOOperationModel = .mainSub  // CORRECT!
    public let requiresModeFilter = false
    public let echoesCommands = true
    public let powerUnits: PowerUnits = .percentage

    // NEW: IC-9700 has BOTH band selection AND VFO selection
    public let supportsDualVFO = true  // Main/Sub EACH have VFO A/B
}
```

### 3. Protocol Extension for IC-9700

Add IC-9700-specific VFO management:
```swift
extension IcomCIVProtocol {
    /// Select band (Main or Sub receiver)
    public func selectBandIC9700(_ band: Band) async throws {
        let code: UInt8 = (band == .main) ? 0xD0 : 0xD1
        try await sendVFOCommand(code)
    }

    /// Select VFO (A or B) on currently selected band
    public func selectVFOIC9700(_ vfo: VFO) async throws {
        let code: UInt8 = (vfo == .a) ? 0x00 : 0x01
        try await sendVFOCommand(code)
    }

    /// Composite: Select band AND VFO in one operation
    public func selectBandVFOIC9700(band: Band, vfo: VFO) async throws {
        try await selectBandIC9700(band)
        try await selectVFOIC9700(vfo)
    }
}
```

### 4. Update Tests

Tests need to reflect the 4-state model:
```swift
func testDualVFO() async throws {
    // Test Main-A
    try await selectBandVFOIC9700(band: .main, vfo: .a)
    try await rig.setFrequency(145_500_000)

    // Test Main-B
    try await selectBandVFOIC9700(band: .main, vfo: .b)
    try await rig.setFrequency(145_600_000)

    // Test Sub-A (must be different band)
    try await selectBandVFOIC9700(band: .sub, vfo: .a)
    try await rig.setFrequency(435_000_000)

    // Test Sub-B
    try await selectBandVFOIC9700(band: .sub, vfo: .b)
    try await rig.setFrequency(435_100_000)
}
```

---

## Impact Analysis

### Tests Affected

All IC-9700 VFO-related tests are affected:
1. ❌ **testDualReceiver** - Currently tries to select "VFO B (Sub)" which is mixing concepts
2. ❌ **testIndependentModes** - Needs band+VFO selection
3. ❌ **testBandExchange** - This works (swaps Main ↔ Sub bands)
4. ❌ **testSatelliteMode** - Needs proper band+VFO management
5. ❌ **testSplitOperation** - Needs Main-A/Main-B selection
6. ❌ **testDualwatch** - Works but needs band selection

### API Impact

**Breaking changes required** to properly support IC-9700:
- `selectVFO(.a)` on IC-9700 is ambiguous (Main-A or Sub-A?)
- Need to introduce band+VFO selection for IC-9700
- May need radio-specific extensions for dual-VFO radios

---

## Recommendations

### Phase 1: Documentation (IMMEDIATE)
1. ✅ Create this architecture document
2. Document the 4-state VFO model in code comments
3. Update IC-9700 command set documentation

### Phase 2: API Design (NEXT)
1. Design clean API for dual-VFO radios
2. Maintain backward compatibility for single-VFO radios
3. Consider radio-specific extensions vs. protocol changes

### Phase 3: Implementation (THEN)
1. Implement band+VFO selection for IC-9700
2. Update all IC-9700 methods to use correct VFO model
3. Update tests to reflect correct architecture

### Phase 4: Validation (FINAL)
1. Hardware test all 4 VFO states
2. Test satellite mode operation
3. Verify split operation on Main-A/Main-B

---

## References

1. **IC-9700 CI-V Manual** - Page 5 (Command 07 VFO Selection)
2. **IC-9700 Operating Manual** - Chapter 18 (CI-V Remote Control)
3. **Hamlib IC-9700 Source** - `ic9700.c` (confirms Main/Sub + VFO A/B)
4. **User Discovery** - Identified the dual architecture from testing

---

## Conclusion

The IC-9700's architecture is **more sophisticated** than initially understood:
- **Band selection** (Main/Sub) is **orthogonal** to **VFO selection** (A/B)
- This creates a **4-state VFO model** unique to dual-receiver radios
- Current implementation incorrectly conflates band and VFO selection
- Proper support requires **API design changes** to expose both concepts

This discovery explains **ALL** the VFO-related test failures. Once we properly model the 4-state architecture, the IC-9700 implementation will be correct.

---

**Status:** Architecture documented, awaiting API design decision
**Next Step:** Design clean API for dual-VFO radio support
