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

### Reference Documentation

- **IC-7100 CI-V Manual**: `IC-7100 CIV.pdf` (Section 20, pages 20-1 to 20-17)
- **IC-9700 CI-V Manual**: [Need to obtain]
- **IC-7300 CI-V Manual**: [Need to obtain]
- **IC-705 CI-V Manual**: [Need to obtain]

### Related Issues

- Power control shows "196W" when radio displays "100%" (IC-7100)
- PTT status read returns invalidResponse (IC-7100)
- Need to verify all commands work correctly on IC-9700, IC-7300

---

**Last Updated**: 2025-12-08
**Author**: Testing with IC-7100 hardware
**Status**: Active Investigation
