# Build Errors Summary

**Date:** Thursday, November 20, 2025  
**Last Updated:** After resolving type alias errors

---

## ✅ RESOLVED: Type Alias Self-Reference Errors

~~Previously had 11 type alias self-reference errors - these have been fixed.~~

---

## ❌ CURRENT ERRORS

### 1. RigCapabilities Codable Conformance Issues

**File:** `RigCapabilities.swift`

#### Errors:
- **Error:** Type 'RigCapabilities' does not conform to protocol 'Decodable'
- **Error:** Type 'RigCapabilities' does not conform to protocol 'Encodable'

#### Root Cause:

The `RigCapabilities` struct declares conformance to `Codable`, but contains properties that are not automatically `Codable`:

1. **Tuple property is not Codable:**
   ```swift
   public let frequencyRange: (min: UInt64, max: UInt64)?
   ```
   - Swift tuples do not conform to `Codable`
   - This prevents automatic synthesis of `Codable` conformance

2. **Set<Mode> may not be Codable:**
   ```swift
   public let supportedModes: Set<Mode>
   ```
   - Requires that `Mode` conforms to `Codable` and `Hashable`
   - If `Mode` doesn't conform to `Codable`, this will fail

#### Resolution Options:

**Option 1: Replace tuple with a Codable struct**
```swift
public struct FrequencyRange: Codable, Sendable {
    public let min: UInt64
    public let max: UInt64
}

public let frequencyRange: FrequencyRange?
```

**Option 2: Manually implement Codable**
Provide custom `encode(to:)` and `init(from:)` methods to handle the tuple encoding/decoding.

**Option 3: Remove Codable conformance**
If serialization is not needed, remove the `Codable` conformance.

#### Additional Requirements:

- Ensure `Mode` type conforms to `Codable` and `Hashable`
- Verify all other properties are `Codable`-compatible

---

### 2. Actor Isolation Errors in XPCServer

**File:** `XPCServer.swift`  
**Related:** `RigController.swift` (actor)

#### Errors (6 occurrences):
- **Error:** Actor-isolated property 'capabilities' can not be referenced from a nonisolated context (2×)
- **Error:** Actor-isolated property 'radioName' can not be referenced from a nonisolated context (2×)
- **Error:** Actor-isolated property 'isConnected' can not be referenced from a nonisolated context (2×)

#### Problematic Code Locations:

**1. `getCapabilities(withReply:)` - Line ~325**
```swift
public func getCapabilities(
    withReply reply: @escaping ([String: Any]?, NSError?) -> Void
) {
    guard let rig = rigController else { ... }
    
    let caps = rig.capabilities  // ❌ Error - accessing actor property synchronously
    let dict: [String: Any] = [
        "hasVFOB": caps.hasVFOB,
        // ...
    ]
    reply(dict, nil)
}
```

**2. `getRadioName(withReply:)` - Line ~342**
```swift
public func getRadioName(
    withReply reply: @escaping (String?, NSError?) -> Void
) {
    guard let rig = rigController else { ... }
    
    reply(rig.radioName, nil)  // ❌ Error - accessing actor property synchronously
}
```

**3. `isConnected(withReply:)` - Line ~352**
```swift
public func isConnected(
    withReply reply: @escaping (Bool) -> Void
) {
    reply(rigController?.isConnected ?? false)  // ❌ Error - accessing actor property synchronously
}
```

#### Root Cause:

`RigController` is defined as an `actor`:
```swift
public actor RigController {
    // These computed properties are actor-isolated:
    public var isConnected: Bool { connected }
    public var capabilities: RigCapabilities { radio.capabilities }
    public var radioName: String { radio.fullName }
}
```

The three XPCServer methods are **non-async** functions trying to access actor-isolated properties **synchronously**, which violates Swift Concurrency's isolation rules.

#### Resolution:

**Wrap the property accesses in `Task` blocks** (like the other methods do):

```swift
// ✅ Fixed version of getCapabilities
public func getCapabilities(
    withReply reply: @escaping ([String: Any]?, NSError?) -> Void
) {
    Task {
        guard let rig = rigController else {
            reply(nil, createError(.notConnected, message: "Radio not connected"))
            return
        }
        
        let caps = await rig.capabilities
        let dict: [String: Any] = [
            "hasVFOB": caps.hasVFOB,
            "hasSplit": caps.hasSplit,
            "powerControl": caps.powerControl,
            "maxPower": caps.maxPower,
            "hasDualReceiver": caps.hasDualReceiver,
            "hasATU": caps.hasATU
        ]
        
        reply(dict, nil)
    }
}

// ✅ Fixed version of getRadioName
public func getRadioName(
    withReply reply: @escaping (String?, NSError?) -> Void
) {
    Task {
        guard let rig = rigController else {
            reply(nil, createError(.notConnected, message: "Radio not connected"))
            return
        }
        
        reply(await rig.radioName, nil)
    }
}

// ✅ Fixed version of isConnected
public func isConnected(
    withReply reply: @escaping (Bool) -> Void
) {
    Task {
        reply(await rigController?.isConnected ?? false)
    }
}
```

#### Alternative (if properties don't need actor isolation):

Mark the properties as `nonisolated` in RigController.swift:
```swift
public actor RigController {
    nonisolated public var capabilities: RigCapabilities { radio.capabilities }
    nonisolated public var radioName: String { radio.fullName }
    // Note: isConnected accesses mutable state, so should remain isolated
}
```

**Recommendation:** Use the `Task` wrapper approach to maintain proper actor isolation.

---

## Summary

- **Total Active Errors:** 8 (2 Codable + 6 Actor Isolation)
- **Affected Files:** 
  - `RigCapabilities.swift` (2 errors)
  - `XPCServer.swift` (6 errors in 3 methods)
- **Error Categories:** 
  - Protocol Conformance (2 errors)
  - Actor Isolation (6 errors)
- **Priority:** High (blocks compilation)

## Next Steps

1. **Fix Codable conformance in RigCapabilities.swift:**
   - Check if `Mode` type conforms to `Codable`
   - Replace the tuple `frequencyRange` with a proper `Codable` struct
   
2. **Fix Actor Isolation in XPCServer.swift:**
   - Wrap property accesses in `Task` blocks for:
     - `getCapabilities(withReply:)` - line ~325
     - `getRadioName(withReply:)` - line ~342
     - `isConnected(withReply:)` - line ~352
   - Add `await` when accessing `rigController` properties
   
3. Recompile to verify fixes

## Pattern Observed

Note that most XPCServer methods already use the correct pattern (wrapping in `Task` and using `await`). The three problematic methods need to be updated to match this pattern.
