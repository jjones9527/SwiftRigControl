# Main/Sub Dual Receiver VFO Analysis

**Date:** 2026-01-05
**Purpose:** Understand VFO architecture differences between IC-7600 and IC-9700

---

## Executive Summary

Both IC-7600 and IC-9700 are **dual receiver radios** using Main/Sub architecture, but they have **DIFFERENT VFO capabilities**:

| Radio | Main/Sub | VFO A/B per receiver | Satellite Mode | Commands 0x25/0x26 |
|-------|----------|----------------------|----------------|-------------------|
| **IC-7600** | ✅ Yes (HF + HF) | **❓ UNKNOWN** | ❌ No | ✅ Yes (Main only) |
| **IC-9700** | ✅ Yes (VHF + UHF + 1.2GHz) | **✅ YES** | ✅ Yes | ✅ Yes (Main only) |

**Critical Discovery:** IC-9700 manual **explicitly documents** Command 0x07 0x00/0x01 (VFO A/B selection), but IC-7600 manual is **unclear** whether VFO A/B exists on Main/Sub receivers.

---

## IC-9700 VFO Architecture (CONFIRMED)

### Official Manual Documentation

**IC-9700 CI-V Manual, Page 5, Command 07:**
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

### 4-State VFO Model

IC-9700 has **4 independent VFO states:**

```
IC-9700
├── Main Receiver (0xD0) - e.g., 2m VHF
│   ├── VFO A (0x00) - e.g., 145.500 MHz
│   └── VFO B (0x01) - e.g., 145.600 MHz
└── Sub Receiver (0xD1) - e.g., 70cm UHF
    ├── VFO A (0x00) - e.g., 435.000 MHz
    └── VFO B (0x01) - e.g., 435.100 MHz
```

### Key Features

1. **Band Selection (Main/Sub):**
   - Command 0x07 0xD0 = Select Main receiver
   - Command 0x07 0xD1 = Select Sub receiver
   - Main and Sub must be on **different bands** (2m, 70cm, 1.2GHz)

2. **VFO Selection (A/B) per receiver:**
   - Command 0x07 0x00 = Select VFO A on **current receiver**
   - Command 0x07 0x01 = Select VFO B on **current receiver**
   - Each receiver maintains independent VFO A/B state

3. **Satellite Mode Integration:**
   - Command 0x16 0x5A 0x01 = Enable satellite mode
   - In satellite mode: Main = downlink RX, Sub = uplink TX
   - Full duplex operation with independent VFO tracking
   - Command 0x07 0x00 = Select VFO mode (allows VFO switching)
   - Command 0x07 0x01 = Returns "FA" (NG) - not allowed

4. **Band Operations:**
   - Command 0x07 0xA0 = Equalize VFO A and B (current receiver)
   - Command 0x07 0xB0 = Exchange Main ↔ Sub bands
   - Command 0x07 0xC2/0xC3 = Dualwatch OFF/ON

---

## IC-7600 VFO Architecture (UNCLEAR)

### Official Manual Documentation

**IC-7600 CI-V Manual** lists these Command 07 codes:
```
07 Select the VFO mode
   B0 Exchange MAIN and SUB Bands
   B1 Equalize MAIN and SUB Bands
   C0 Dualwatch OFF
   C1 Dualwatch ON
   D0 Select the main band
   D1 Select the sub band
```

**⚠️ CRITICAL OBSERVATION:** The IC-7600 manual does **NOT explicitly list**:
- 0x07 0x00 (Select VFO A)
- 0x07 0x01 (Select VFO B)
- 0x07 0xA0 (Equalize VFO A and B)

### Two Possible Interpretations

#### Interpretation 1: IC-7600 has NO VFO A/B per receiver

IC-7600 may be a simpler dual receiver:
```
IC-7600
├── Main Receiver (0xD0) - Single VFO, HF band
└── Sub Receiver (0xD1) - Single VFO, HF band
```

**Evidence:**
- Commands 0x00/0x01 not documented in manual
- Commands 0x25/0x26 (selected/unselected VFO) work on Main
- No satellite mode (doesn't need independent VFO tracking)
- Simpler architecture for HF dual receiver

#### Interpretation 2: IC-7600 DOES have VFO A/B (undocumented)

IC-7600 may have the same 4-state model as IC-9700:
```
IC-7600
├── Main Receiver (0xD0) - HF band
│   ├── VFO A (0x00) - e.g., 14.200 MHz
│   └── VFO B (0x01) - e.g., 14.250 MHz
└── Sub Receiver (0xD1) - HF band
    ├── VFO A (0x00) - e.g., 7.100 MHz
    └── VFO B (0x01) - e.g., 7.150 MHz
```

**Evidence:**
- Commands 0x25/0x26 refer to "selected" and "unselected" VFO
- If there's only one VFO per receiver, what is "selected" vs "unselected"?
- Split operation on Main implies VFO A (RX) and VFO B (TX)
- May be undocumented but functionally present

---

## Commands 0x25/0x26 (Selected/Unselected VFO)

Both radios support these commands **ONLY on Main receiver:**

| Command | IC-7600 | IC-9700 | Function |
|---------|---------|---------|----------|
| 0x25 | ✅ Yes | ✅ Yes | Read/Write frequency of **selected VFO** (Main-A or Main-B) |
| 0x26 | ✅ Yes | ✅ Yes | Read/Write frequency of **unselected VFO** (Main-B or Main-A) |

**Observation:** If VFO A/B didn't exist, what would "selected" vs "unselected" mean?

### For IC-9700:
- If Main is on VFO A: 0x25 = Main-A frequency, 0x26 = Main-B frequency
- If Main is on VFO B: 0x25 = Main-B frequency, 0x26 = Main-A frequency
- **Sub receiver:** Commands 0x25/0x26 do NOT work, must use 0x03/0x05

### For IC-7600:
- If Main has VFO A/B: Same as IC-9700
- If Main has single VFO: What does 0x26 (unselected VFO) return?
- **Testing required** to determine actual behavior

---

## Split Operation

Both radios support split operation **ONLY on Main receiver:**

| Radio | Split Command | RX VFO | TX VFO |
|-------|---------------|--------|--------|
| IC-7600 | 0x0F 0x01 = ON | Main (selected VFO) | Main (unselected VFO?) |
| IC-9700 | 0x0F 0x01 = ON | Main VFO A | Main VFO B |

**For IC-9700:**
- Command sequence: Select Main, Select VFO A (RX), Set RX freq, Select VFO B (TX), Set TX freq, Enable split
- VFO A = Receive frequency
- VFO B = Transmit frequency

**For IC-7600:**
- If VFO A/B exists: Same as IC-9700
- If VFO A/B doesn't exist: How does split work?
- **Testing required**

---

## Current Implementation Issues

### Problem 1: VFO Enum Mapping

**Current implementation in `IcomRadioTypes.swift`:**
```swift
public enum VFOCodeHelper {
    public static func mainSubCode(for vfo: VFO) -> UInt8? {
        switch vfo {
        case .main:
            return CIVFrame.VFOSelect.main  // 0xD0
        case .sub:
            return CIVFrame.VFOSelect.sub   // 0xD1
        case .a, .b:
            return nil  // "Not supported for Main/Sub radios"
        }
    }
}
```

**Problem:** This assumes Main/Sub radios **never** use VFO A/B codes, but IC-9700 **explicitly supports** 0x00/0x01!

### Problem 2: Radio Differences

Both IC-7600 and IC-9700 are configured with `.mainSub` model, but they may have **different VFO capabilities:**

| Radio | VFOOperationModel | VFO A/B Support | Status |
|-------|-------------------|-----------------|--------|
| IC-7600 | `.mainSub` | **UNKNOWN** | Needs hardware testing |
| IC-9700 | `.mainSub` | **✅ CONFIRMED** | Manual Page 5 |

The `.mainSub` enum value is **insufficient** to capture this distinction.

---

## Hardware Testing Required

### IC-7600 Tests

These tests will determine if IC-7600 has VFO A/B per receiver:

#### Test 1: VFO A/B Selection
```swift
// Test if IC-7600 accepts VFO A/B commands
try await sendCommand(0x07, data: [0xD0])  // Select Main
try await sendCommand(0x07, data: [0x00])  // Try Select VFO A
// Expected: ACK if supported, NAK if not

try await sendCommand(0x07, data: [0x01])  // Try Select VFO B
// Expected: ACK if supported, NAK if not
```

#### Test 2: Commands 0x25/0x26 Behavior
```swift
// Set Main to 14.200 MHz
try await sendCommand(0x07, data: [0xD0])   // Select Main
try await sendCommand(0x05, data: [BCD(14.200)])

// Read selected VFO frequency
let freq1 = try await sendCommand(0x25)

// Try to set unselected VFO frequency
try await sendCommand(0x26, data: [BCD(14.250)])

// Read unselected VFO frequency
let freq2 = try await sendCommand(0x26)

// Analysis:
// - If freq2 = 14.250 MHz: VFO A/B exists (we just set VFO B)
// - If freq2 = 14.200 MHz: No VFO A/B (only one VFO, "unselected" is same as "selected")
// - If command NAKs: Command 0x26 not supported
```

#### Test 3: Split Operation Behavior
```swift
// Try split operation
try await sendCommand(0x07, data: [0xD0])   // Select Main
try await sendCommand(0x25, data: [BCD(14.200)])  // Set RX frequency
try await sendCommand(0x26, data: [BCD(14.225)])  // Set TX frequency (if VFO B exists)
try await sendCommand(0x0F, data: [0x01])   // Enable split

// PTT and verify:
// - Radio transmits on 14.225 MHz: VFO B exists
// - Radio transmits on 14.200 MHz: VFO B doesn't exist or split not working
```

---

## Proposed Solutions

### Solution A: Extend VFOOperationModel Enum

Add a new enum case for "Main/Sub with VFO A/B per receiver":

```swift
public enum VFOOperationModel: Sendable {
    case targetable       // VFO A/B directly targetable (IC-7300, IC-7610)
    case currentOnly      // Must switch to VFO first (IC-7100, IC-705)
    case mainSub          // Main/Sub only, NO VFO A/B (IC-7600?)
    case mainSubDualVFO   // Main/Sub PLUS VFO A/B per receiver (IC-9700)
    case none             // No VFO support (receivers)
}
```

**Usage:**
```swift
// IC-7600 (if testing confirms NO VFO A/B)
public let vfoModel: VFOOperationModel = .mainSub

// IC-9700 (confirmed has VFO A/B)
public let vfoModel: VFOOperationModel = .mainSubDualVFO
```

### Solution B: Add Capability Flag

Keep `.mainSub` enum, add boolean flag:

```swift
public protocol IcomRadioCommandSet: CIVCommandSet {
    var vfoModel: VFOOperationModel { get }
    var supportsVFOABPerReceiver: Bool { get }  // NEW
}
```

**Usage:**
```swift
// IC-7600 (pending hardware testing)
public let vfoModel: VFOOperationModel = .mainSub
public let supportsVFOABPerReceiver: Bool = false  // Assumed, needs testing

// IC-9700
public let vfoModel: VFOOperationModel = .mainSub
public let supportsVFOABPerReceiver: Bool = true   // Confirmed by manual
```

### Solution C: Radio-Specific VFO Methods

Add IC-9700-specific methods for 4-state VFO control:

```swift
extension IcomCIVProtocol {
    // Generic Main/Sub selection (works for IC-7600 and IC-9700)
    public func selectBand(_ band: Band) async throws {
        let code: UInt8 = (band == .main) ? 0xD0 : 0xD1
        try await sendVFOCommand(code)
    }

    // IC-9700 ONLY: VFO A/B selection on current receiver
    public func selectVFOIC9700(_ vfo: VFO) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("VFO A/B per receiver only supported on IC-9700")
        }
        let code: UInt8 = (vfo == .a) ? 0x00 : 0x01
        try await sendVFOCommand(code)
    }

    // IC-9700 ONLY: Composite band+VFO selection
    public func selectBandVFOIC9700(band: Band, vfo: VFO) async throws {
        guard radioModel == .ic9700 else {
            throw RigError.unsupportedOperation("4-state VFO only supported on IC-9700")
        }
        try await selectBand(band)
        try await selectVFOIC9700(vfo)
    }
}
```

---

## Recommendations

### Phase 1: Verify IC-7600 Capabilities (IMMEDIATE - 15 minutes)

Run hardware tests on IC-7600 to answer:
1. ✅ Does IC-7600 accept Command 0x07 0x00/0x01 (VFO A/B)?
2. ✅ What does Command 0x26 (unselected VFO) return?
3. ✅ How does split operation work?

**Action:** Create `IC7600VFOTest` program to run these 3 tests.

### Phase 2: Document Findings (NEXT - 10 minutes)

Based on test results, update documentation:
- If IC-7600 has VFO A/B: Both radios share 4-state model
- If IC-7600 NO VFO A/B: IC-9700 is unique, needs special handling

### Phase 3: Implement Solution (THEN - 30-60 minutes)

Choose one of the proposed solutions:
- **Preferred:** Solution C (radio-specific methods)
  - Keeps API clean for IC-7600 (no confusing VFO A/B)
  - Exposes full 4-state model for IC-9700
  - Backward compatible
  - Easy to extend for future radios

### Phase 4: Update Tests (FINAL - 30 minutes)

Update IC-9700 tests to use correct 4-state model:
- Use `selectBandVFOIC9700(band:vfo:)` for explicit selection
- Test all 4 states: Main-A, Main-B, Sub-A, Sub-B
- Test satellite mode with independent VFO tracking

---

## Open Questions

1. **IC-7600 VFO A/B:** Does IC-7600 support VFO A/B per receiver?
   - **Answer:** Requires hardware testing (Test 1-3 above)

2. **Other Main/Sub radios:** What about IC-9100?
   - IC-9100 has satellite mode like IC-9700
   - Likely has VFO A/B per receiver
   - **Action:** Check IC-9100 manual

3. **Command 0x25/0x26 on Sub:** Why don't these work on Sub receiver?
   - Manual doesn't explain this limitation
   - May be hardware constraint
   - Sub receiver accessed via 0x03/0x05 after selecting Sub

4. **Satellite mode VFO switching:** How does 0x07 0x00 work in satellite mode?
   - Manual says "selects VFO mode" - unclear what this means
   - Does it toggle between Main-A/Main-B?
   - **Action:** Test on IC-9700 hardware

---

## References

1. **IC-9700 CI-V Manual** - Page 5 (Command 07 - explicit VFO A/B documentation)
2. **IC-7600 CI-V Manual** - Page 5 (Command 07 - NO VFO A/B documentation)
3. **IC-9700 Operating Manual** - Chapter 18 (Satellite mode operation)
4. **Current Implementation** - `IcomRadioTypes.swift` lines 30-42 (VFOCodeHelper)
5. **User Discovery** - Identified IC-9700 4-state model from testing

---

## Conclusion

**IC-9700 architecture is CONFIRMED:** Main/Sub receivers EACH have VFO A/B (4 states total).

**IC-7600 architecture is UNCLEAR:** Manual doesn't document VFO A/B codes, but Commands 0x25/0x26 (selected/unselected VFO) suggest they may exist.

**Next Step:** Run hardware tests on IC-7600 to determine if it has the same 4-state VFO model as IC-9700, or if it's simpler (Main/Sub only, no VFO A/B per receiver).

**Impact:** This determines whether we need:
- **Radio-specific implementations** (IC-9700 unique 4-state model)
- **OR shared architecture** (both IC-7600 and IC-9700 have 4-state model)

---

**Status:** Analysis complete, awaiting IC-7600 hardware testing
**Blocking:** API design decision depends on IC-7600 test results
