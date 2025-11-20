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

### 2. Actor Isolation Errors

**Location:** Unknown file (likely in XPC or controller code)

#### Errors:
- **Error:** Actor-isolated property 'radioName' can not be referenced from a nonisolated context
- **Error:** Actor-isolated property 'isConnected' can not be referenced from a nonisolated context
- **Error:** Actor-isolated property 'capabilities' can not be referenced from a nonisolated context

#### Root Cause:

These errors occur when trying to access actor-isolated properties from outside the actor's isolation domain. In Swift Concurrency:

- Properties on an actor are isolated to that actor by default
- Accessing them from non-actor code (nonisolated context) requires `await`
- Synchronous access to actor properties is not allowed from outside the actor

#### Common Scenarios:

1. **Accessing actor properties synchronously:**
   ```swift
   let name = rigController.radioName  // ❌ Error
   ```

2. **Using actor properties in computed properties:**
   ```swift
   var description: String {
       return rigController.radioName  // ❌ Error - computed property is nonisolated
   }
   ```

3. **Passing actor properties to non-async functions:**
   ```swift
   updateUI(rigController.isConnected)  // ❌ Error
   ```

#### Resolution Options:

**Option 1: Use async/await**
```swift
let name = await rigController.radioName  // ✅ Correct
```

**Option 2: Mark properties as nonisolated**
If the property doesn't need actor isolation (e.g., immutable or thread-safe):
```swift
actor RigController {
    nonisolated let radioName: String  // ✅ Can be accessed synchronously
}
```

**Option 3: Mark properties with @MainActor if UI-related**
For properties that need to be accessed from the main thread:
```swift
@MainActor
class RigController {
    var radioName: String  // ✅ Main actor isolated
}
```

**Option 4: Create async getter methods**
```swift
actor RigController {
    private var _radioName: String
    
    func getRadioName() async -> String {
        return _radioName
    }
}
```

#### Additional Considerations:

- If these properties are frequently accessed together, consider creating a struct that combines them
- Use `nonisolated` carefully - only for truly thread-safe properties
- Consider using `@Published` with `@MainActor` for SwiftUI integration

---

## Summary

- **Total Active Errors:** 5 (2 Codable + 3 Actor Isolation)
- **Affected Files:** 2+ (`RigCapabilities.swift` + unknown actor/controller file)
- **Error Categories:** 
  - Protocol Conformance (2 errors)
  - Actor Isolation (3 errors)
- **Priority:** High (blocks compilation)

## Next Steps

1. **Fix Codable conformance:**
   - Check if `Mode` type conforms to `Codable`
   - Replace the tuple `frequencyRange` with a proper `Codable` struct
   
2. **Fix Actor Isolation:**
   - Locate where `radioName`, `isConnected`, and `capabilities` are being accessed
   - Add `await` to async contexts or mark properties as `nonisolated` if appropriate
   - Consider the concurrency model for the affected actor
   
3. Recompile to verify fixes
