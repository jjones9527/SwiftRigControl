# Icom CI-V Architecture Refactoring Plan

**Date**: 2025-12-10
**Purpose**: Create inheritance-based architecture for better Icom radio support

## Problem Statement

Current architecture issues discovered during testing:
1. **IC-7100**: VFO selection was disabled (returned nil) - had to fix
2. **IC-7600**: VFO selection rejected (Main/Sub vs VFO A/B) - had to disable
3. **Fragility**: Each radio quirk requires modifying protocol/command set logic
4. **Poor extensibility**: Hard for users to add new Icom radios
5. **Unclear semantics**: `requiresVFOSelection` means different things

## Current Architecture (Problems)

```
┌─────────────────┐
│ CIVCommandSet   │ (Protocol)
│   - civAddress  │
│   - powerUnits  │
│   - echoes      │
│   - requiresVFO │
└────────┬────────┘
         │
    ┌────┴─────────────┬──────────────────────┐
    │                  │                      │
┌───▼────────────┐ ┌──▼──────────────┐ ┌────▼──────────┐
│ IC7100CommandSet│ │StandardIcomSet │ │IC9700CommandSet│
│ (struct)        │ │ (struct)       │ │ (struct)       │
└─────────────────┘ └─────────────────┘ └────────────────┘
```

**Problems**:
- Structs can't inherit or share code
- Each radio reimplements similar logic
- Boolean flags try to capture complex behavior
- No clear "base" vs "override" pattern
- Command selection logic scattered across protocol methods

## Proposed Architecture (Solution)

```
┌──────────────────────┐
│ IcomRadioProtocol    │ (Base Class)
│                      │
│ + Standard CI-V impl │
│ + Default behaviors  │
│ + Virtual methods    │
└──────────┬───────────┘
           │
     ┌─────┴──────────────────────┬─────────────────────┐
     │                            │                     │
┌────▼────────┐          ┌────────▼────────┐    ┌─────▼──────────┐
│ IC7100Radio │          │ StandardIcomRadio│    │ IC9700Radio    │
│             │          │                  │    │                │
│ + VFO quirks│          │ (most radios)    │    │ + Dual RX      │
└─────────────┘          └──────────────────┘    └────────────────┘
```

## Design Principles

### 1. **Inheritance over Composition**
- Base class provides standard CI-V implementation
- Subclasses override only what's different
- Clear "default" vs "custom" behavior

### 2. **Explicit Methods over Flags**
```swift
// Bad (current):
let requiresVFOSelection: Bool  // Unclear what this means

// Good (proposed):
func needsVFOSelectionBeforeFrequency() -> Bool
func vfoSelectionCommand(vfo: VFO) -> CIVCommand?
func vfoOperationModel() -> VFOOperationModel
```

### 3. **Separation of Concerns**
- **Command Construction**: How to build CI-V frames
- **Command Timing**: When to send commands
- **Command Validation**: What commands are supported
- **Response Handling**: How to parse responses

### 4. **Easy Extensibility**
```swift
// Adding a new radio should be simple:
class IC7700Radio: StandardIcomRadio {
    override var civAddress: UInt8 { 0x74 }
    override var maxPower: Int { 200 }
    // Done! Everything else inherited
}
```

## Detailed Design

### Base Class: IcomRadioProtocol

```swift
/// Base class for all Icom CI-V radios
/// Provides standard CI-V protocol implementation
open class IcomRadioProtocol {
    // MARK: - Properties (overridable)

    open var civAddress: UInt8 { fatalError("Must override") }
    open var defaultBaudRate: Int { 19200 }
    open var maxPower: Int { 100 }

    // MARK: - Behavioral Properties

    /// Does this radio echo commands before responding?
    open var echoesCommands: Bool { false }

    /// What power units does this radio use?
    open var powerUnits: PowerUnits { .percentage }

    /// What VFO operation model does this radio use?
    open var vfoModel: VFOOperationModel {
        .targetable  // Most radios can target VFO directly
    }

    // MARK: - VFO Operations (overridable)

    /// Build VFO selection command
    open func makeVFOSelectionCommand(_ vfo: VFO) -> CIVCommand? {
        switch vfoModel {
        case .targetable:
            // Standard VFO A/B selection
            return CIVCommand(command: 0x07, data: [vfoCodeFor(vfo)])
        case .currentOnly:
            // Must switch active VFO
            return CIVCommand(command: 0x07, data: [vfoCodeFor(vfo)])
        case .mainSub:
            // Dual receiver - use Main/Sub codes
            return CIVCommand(command: 0x07, data: [mainSubCodeFor(vfo)])
        case .none:
            return nil
        }
    }

    /// Does this radio need VFO selection before frequency commands?
    open func needsVFOSelectionBeforeFrequency(vfo: VFO) -> Bool {
        switch vfoModel {
        case .targetable:
            return true  // Send VFO selection before each command
        case .currentOnly:
            return true  // Must switch to VFO first
        case .mainSub:
            return true  // Must select Main/Sub first
        case .none:
            return false  // Doesn't support VFO operations
        }
    }

    // MARK: - Mode Commands (overridable)

    /// Does this radio require filter byte in mode commands?
    open var requiresModeFilter: Bool { true }

    open func makeModeCommand(mode: UInt8) -> CIVCommand {
        if requiresModeFilter {
            return CIVCommand(command: 0x06, data: [mode, 0x00])
        } else {
            return CIVCommand(command: 0x06, data: [mode])
        }
    }

    // MARK: - Standard Implementations

    func makeFrequencyCommand(frequency: UInt64) -> CIVCommand {
        let bcd = BCDEncoding.encodeFrequency(frequency)
        return CIVCommand(command: 0x05, data: bcd)
    }

    func makePowerCommand(value: Int) -> CIVCommand {
        let percentage = min(max(value, 0), 100)
        let scale = (percentage * 255) / 100
        let bcd = BCDEncoding.encodePower(scale)
        return CIVCommand(command: 0x14, subCommand: 0x0A, data: bcd)
    }

    // ... more standard implementations
}

enum VFOOperationModel {
    case targetable      // Can target VFO A/B directly (IC-7300, IC-9700)
    case currentOnly     // Operates on "current" VFO (IC-7100, IC-705)
    case mainSub         // Uses Main/Sub bands (IC-7600)
    case none            // No VFO support (receivers, etc.)
}
```

### Standard Radio Implementation

```swift
/// Standard Icom radio implementation
/// Used by most HF/VHF/UHF transceivers
open class StandardIcomRadio: IcomRadioProtocol {
    // Inherits everything from base class
    // Uses default targetable VFO model
    // Requires mode filter
}
```

### IC-7100 Implementation

```swift
/// Icom IC-7100 - HF/VHF/UHF all-mode transceiver
class IC7100Radio: IcomRadioProtocol {
    override var civAddress: UInt8 { 0x88 }
    override var defaultBaudRate: Int { 19200 }
    override var echoesCommands: Bool { true }
    override var requiresModeFilter: Bool { false }  // KEY DIFFERENCE
    override var vfoModel: VFOOperationModel { .currentOnly }  // KEY DIFFERENCE

    // Everything else inherited from base!
}
```

### IC-7600 Implementation

```swift
/// Icom IC-7600 - HF/6m dual receiver transceiver
class IC7600Radio: IcomRadioProtocol {
    override var civAddress: UInt8 { 0x7A }
    override var defaultBaudRate: Int { 19200 }
    override var vfoModel: VFOOperationModel { .mainSub }  // KEY DIFFERENCE
    override var maxPower: Int { 100 }

    // Main/Sub VFO codes
    override func vfoCodeFor(_ vfo: VFO) -> UInt8? {
        switch vfo {
        case .main: return 0xD0
        case .sub: return 0xD1
        case .a, .b: return nil  // Not supported
        }
    }
}
```

### IC-7300 Implementation

```swift
/// Icom IC-7300 - HF/6m SDR transceiver
class IC7300Radio: StandardIcomRadio {
    override var civAddress: UInt8 { 0x94 }
    override var defaultBaudRate: Int { 115200 }
    // Everything else uses StandardIcomRadio defaults!
}
```

### IC-9700 Implementation

```swift
/// Icom IC-9700 - VHF/UHF/1.2GHz dual receiver transceiver
class IC9700Radio: IcomRadioProtocol {
    override var civAddress: UInt8 { 0xA2 }
    override var defaultBaudRate: Int { 115200 }
    override var vfoModel: VFOOperationModel { .mainSub }  // Dual receiver

    // Custom frequency range validation (VHF/UHF)
    override func validateFrequency(_ hz: UInt64) throws {
        // 144-148 MHz, 430-450 MHz, 1240-1300 MHz
    }
}
```

## Migration Strategy

### Phase 1: Create Base Class (No Breaking Changes)
1. Create `IcomRadioProtocol` base class
2. Keep existing `CIVCommandSet` protocol (deprecated)
3. Create adapter that wraps old command sets in new class

### Phase 2: Implement Radio Classes
1. Create `StandardIcomRadio` base class
2. Implement specific radio classes:
   - `IC7100Radio`
   - `IC7300Radio`
   - `IC7600Radio`
   - `IC7610Radio`
   - `IC9700Radio`
   - `IC705Radio`
   - etc.

### Phase 3: Update Protocol Layer
1. Update `IcomCIVProtocol` to use radio classes
2. Add protocol factory that creates appropriate radio class
3. Maintain backward compatibility with command sets

### Phase 4: Migrate Radio Definitions
1. Update `RadioDefinition` to use radio classes
2. Update `IcomModels.swift` to instantiate classes
3. Deprecate old command set structs

### Phase 5: Remove Old Code
1. Remove deprecated `CIVCommandSet` protocol
2. Remove old command set struct implementations
3. Update documentation

## Benefits

### 1. **Clear Behavior**
```swift
// Before (unclear):
if commandSet.requiresVFOSelection { ... }

// After (explicit):
if radio.needsVFOSelectionBeforeFrequency(vfo) { ... }
if radio.vfoModel == .mainSub { ... }
```

### 2. **Easy to Add Radios**
```swift
// Adding IC-7700 (200W flagship):
class IC7700Radio: StandardIcomRadio {
    override var civAddress: UInt8 { 0x74 }
    override var maxPower: Int { 200 }
}
// Done! 5 lines of code.
```

### 3. **Easy to Override**
```swift
// IC-756 PRO doesn't support PTT via CI-V:
class IC756ProRadio: StandardIcomRadio {
    override var civAddress: UInt8 { 0x5C }

    override func makePTTCommand(enabled: Bool) -> CIVCommand? {
        return nil  // PTT not supported via CI-V
    }
}
```

### 4. **Better Documentation**
Each radio class is self-documenting:
```swift
/// IC-7100 - HF/VHF/UHF all-mode transceiver
///
/// Key characteristics:
/// - Echoes commands (must handle echo frames)
/// - No filter byte in mode commands
/// - Operates on "current" VFO (must switch first)
/// - Power displayed as percentage
class IC7100Radio: IcomRadioProtocol { ... }
```

### 5. **Testability**
```swift
// Easy to test specific radio behavior:
func testIC7100VFOBehavior() {
    let radio = IC7100Radio()
    XCTAssertEqual(radio.vfoModel, .currentOnly)
    XCTAssertTrue(radio.echoesCommands)
    XCTAssertFalse(radio.requiresModeFilter)
}
```

## User Extensibility

Users can easily add their own radios:

```swift
// User adds IC-7800 support:
import RigControl

class IC7800Radio: StandardIcomRadio {
    override var civAddress: UInt8 { 0x6A }
    override var defaultBaudRate: Int { 19200 }
    override var maxPower: Int { 200 }
}

// Register and use:
let myRadio = RadioDefinition.custom(
    manufacturer: .icom,
    model: "IC-7800",
    radioClass: IC7800Radio.self
)

let rig = RigController(radio: myRadio, ...)
```

## Implementation Timeline

- **Week 1**: Design and base class implementation
- **Week 2**: Migrate existing radios to new classes
- **Week 3**: Testing and bug fixes
- **Week 4**: Documentation and deprecation warnings
- **Week 5**: Remove old code

## Success Metrics

- [ ] All existing tests pass
- [ ] IC-7100 VFO operations work correctly
- [ ] IC-7600 frequency operations work without VFO selection
- [ ] Adding a new radio takes < 20 lines of code
- [ ] Code coverage maintained or improved
- [ ] No breaking changes for existing users

## Open Questions

1. Should we use protocols or classes? (Leaning toward classes for inheritance)
2. How to handle radio capabilities (RigCapabilities) integration?
3. Should VFO enum have .mainA, .mainB, .sub for dual receiver radios?
4. How to handle "Selected/Unselected VFO" commands (0x25)?
5. Should we support runtime radio discovery/auto-detection?

## References

- Current command set implementations
- Hamlib source code (icom.c, frame.c)
- Icom CI-V reference manuals
- User feedback from testing
