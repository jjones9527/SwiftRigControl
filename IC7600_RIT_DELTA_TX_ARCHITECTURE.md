# IC-7600 RIT/ΔTX Architecture Investigation

## Discovery Summary

The IC-7600 uses a **shared offset architecture** for RIT (Receiver Incremental Tuning) and ΔTX (Delta TX / Transmitter Incremental Tuning). This is fundamentally different from radios that support separate RIT and XIT controls via CI-V.

## Key Findings

### Architecture

**Single Shared Offset:**
- The IC-7600 maintains **one offset value** that can be applied to either RX or TX
- Command 0x21 0x00 sets the offset frequency (applies to both RIT and ΔTX)
- Command 0x21 0x01 enables/disables the offset function
- The front panel RIT/ΔTX button determines whether offset applies to RX or TX

**Front Panel Control:**
- User presses RIT/ΔTX button to toggle between:
  - RIT mode: offset applied to receive frequency
  - ΔTX mode: offset applied to transmit frequency
- There is **no CI-V command** to switch between RIT and ΔTX modes
- CI-V can only set the offset value and enable/disable it

### CI-V Command Support

**Supported (Command 0x21):**
- ✅ Subcommand 0x00: Set/Read offset frequency (-9999 to +9999 Hz)
- ✅ Subcommand 0x01: Enable/Disable offset (applies to current mode)

**NOT Supported:**
- ❌ Subcommand 0x02: XIT frequency offset (returns NAK)
- ❌ Subcommand 0x03: XIT ON/OFF (returns NAK)
- ❌ No command to switch between RIT and ΔTX modes

**Related Command:**
- Command 1A 05 0085: "Quick RIT/ΔTX clear" - clears the shared offset

### Observed Behavior

When testing with hardware:
1. Command 0x21 0x00 successfully sets offset → Works
2. Command 0x21 0x01 successfully enables RIT → Works, visible on radio display
3. Command 0x21 0x02 (XIT frequency) → Returns NAK (not supported)
4. Command 0x21 0x03 (XIT ON/OFF) → Returns NAK (not supported)
5. Setting RIT offset also affects ΔTX if radio is in ΔTX mode

## Comparison with Other Radios

### IC-7600 (Shared Architecture)
```
           ┌─────────────┐
CI-V 0x21  │   Offset    │  Front Panel
Set offset │   +500 Hz   │  RIT/ΔTX Button
────────────►             ├──────────────┐
           │  Enabled    │              │
           └─────────────┘              ▼
                                  ┌──────────┐
                                  │ RIT Mode │──► RX + 500 Hz
                                  │    OR    │
                                  │ ΔTX Mode │──► TX + 500 Hz
                                  └──────────┘
```

### Radios with Separate RIT/XIT (e.g., IC-7100, IC-9700)
```
RIT: 0x21 0x00/0x01  ──► RIT Offset (+500 Hz)  ──► RX + 500 Hz
XIT: 0x21 0x02/0x03  ──► XIT Offset (-300 Hz)  ──► TX - 300 Hz
```

## Impact on SwiftRigControl

### Current Implementation
- `setRIT()` / `getRIT()` → ✅ Works correctly
- `setXIT()` / `getXIT()` → ❌ Throws `unsupportedOperation` (correct behavior)

### User Expectations
Users should understand:
1. **RIT commands work** but affect the **shared offset**
2. **XIT commands fail** because there's no separate XIT on IC-7600
3. **ΔTX is controlled** by the RIT commands + front panel mode selection
4. **No way to programmatically** switch between RIT and ΔTX modes via CI-V

### Recommended Workarounds

**For Independent TX Offset:**
Use split operation instead of trying to use XIT:

```swift
// Set RX frequency on MAIN
try await rig.setFrequency(14_200_000, vfo: .main)

// Set TX frequency on SUB (with offset)
try await rig.setFrequency(14_200_300, vfo: .sub)  // +300 Hz

// Enable split mode
try await rig.setSplit(true)
```

**For RIT/ΔTX Offset:**
Use RIT commands, but understand the offset applies based on front panel mode:

```swift
// Set offset (applies to RIT or ΔTX depending on radio state)
try await rig.setRIT(RITXITState(enabled: true, offset: 500))

// Read current offset
let state = try await rig.getRIT()
print("Offset: \(state.offset) Hz, Enabled: \(state.enabled)")
// Note: This doesn't tell you if radio is in RIT or ΔTX mode
```

## Documentation Updates

Updated files:
1. **IC7600_API_GUIDE.md**: Added "Known Limitations" section explaining shared architecture
2. **IC7600Validator/main.swift**: XIT test now skips with detailed explanation
3. **This document**: Complete technical explanation

## Conclusion

The IC-7600's shared RIT/ΔTX architecture is a **design choice by Icom**, not a limitation of SwiftRigControl. The radio physically has only one offset generator that can be switched between RX and TX via the front panel.

**Key Takeaway**: When documentation or users refer to "XIT" or "ΔTX" on the IC-7600, they're actually referring to the **RIT offset applied to transmit**, not a separate XIT function like other radios have.

---

**Date**: 2025-12-30
**Investigation By**: Hardware testing with IC-7600 via SwiftRigControl
**CI-V Manual Reference**: IC-7600 CI-V Command Reference (Command 0x21 not in table, commands 0x00/0x01 work, 0x02/0x03 return NAK)
