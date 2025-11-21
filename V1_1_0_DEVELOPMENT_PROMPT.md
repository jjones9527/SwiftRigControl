# SwiftRigControl v1.1.0 Development Prompt
**Author:** VA3ZTF (Jeremy Jones)
**Date:** November 19, 2025
**Version:** 1.0
**Target Release:** Q1 2026 (~6 weeks)

---

## Overview

This prompt provides actionable guidance for implementing **SwiftRigControl v1.1.0 - Monitoring & Performance**. This release focuses on adding radio monitoring capabilities and performance optimizations to make SwiftRigControl production-ready for logging and monitoring applications.

**Reference Document:** [POST_V1_DEVELOPMENT_PLAN.md](https://github.com/jjones9527/SwiftRigControl/tree/claude/plan-swiftrigcontrol-development-012F1XxHECjZb4EFyBeKbNiD/POST_V1_DEVELOPMENT_PLAN.md)

---

## Release Goals

### Theme
Make SwiftRigControl production-ready for logging/monitoring applications

### Success Metrics
- ✅ Query latency <10ms (from cache)
- ✅ 15+ new use cases enabled
- ✅ 5+ new radio models supported
- ✅ Maintain 95%+ test coverage
- ✅ Zero breaking changes (backward compatible)

---

## Priority 1: S-Meter Reading (HIGHEST VALUE)

### Objective
Add signal strength reading capability across all 4 protocols to enable monitoring applications.

### User Value: 10/10
Currently, applications are "blind" to signal conditions. S-meter reading is essential for:
- Monitoring applications
- Proper antenna tuning
- Contest logging
- Signal quality assessment

### Technical Complexity: 4/10
Straightforward protocol additions with well-documented commands.

---

### Implementation Tasks

#### Task 1.1: Create SignalStrength Model
**File:** `Sources/RigControl/Models/SignalStrength.swift` (new file)

**Requirements:**
```swift
/// Represents radio signal strength in S-units
public struct SignalStrength: Sendable, Equatable, CustomStringConvertible {
    /// S-units (0-9), where S9 is the strongest standard reading
    public let sUnits: Int

    /// Decibels over S9 (0-60), used when signal exceeds S9
    public let overS9: Int

    /// Raw protocol-specific value for debugging
    public let raw: Int

    /// Human-readable description (e.g., "S5", "S9+20")
    public var description: String {
        if sUnits < 9 {
            return "S\(sUnits)"
        } else {
            return "S9+\(overS9)"
        }
    }

    /// Initialize from S-units and over-S9 value
    public init(sUnits: Int, overS9: Int = 0, raw: Int) {
        self.sUnits = max(0, min(9, sUnits))
        self.overS9 = max(0, min(60, overS9))
        self.raw = raw
    }
}
```

**Acceptance Criteria:**
- [ ] Struct is `Sendable` for actor safety
- [ ] Validates S-units (0-9) and over-S9 (0-60)
- [ ] Provides clear `description` output
- [ ] Includes unit tests for edge cases
- [ ] Documented with examples

---

#### Task 1.2: Add Protocol Method to CATProtocol
**File:** `Sources/RigControl/Protocols/CATProtocol.swift`

**Add Method:**
```swift
/// Read current signal strength (S-meter)
/// - Returns: Signal strength in S-units
/// - Throws: RigError if reading fails or radio doesn't support S-meter
func getSignalStrength() async throws -> SignalStrength
```

**Acceptance Criteria:**
- [ ] Method added to protocol
- [ ] Documentation includes protocol support notes
- [ ] Throws appropriate error if unsupported

---

#### Task 1.3: Implement for Icom CI-V Protocol
**File:** `Sources/RigControl/Protocols/IcomCIVProtocol.swift`

**Command:** `0x15 0x02` (Read S-meter)

**Implementation Guide:**
```swift
public func getSignalStrength() async throws -> SignalStrength {
    let frame = CIVFrame(
        to: civAddress,
        command: [0x15, 0x02]  // Read S-meter
    )

    try await sendFrame(frame)
    let response = try await receiveFrame()

    guard response.command == [0x15, 0x02],
          response.data.count >= 2 else {
        throw RigError.invalidResponse
    }

    // Icom returns BCD: 0x0000 to 0x0255
    let rawValue = decodeBCD(response.data[0...1])

    // Convert to S-units (0-241 range, roughly 24 per S-unit)
    let sUnits = min(rawValue / 24, 9)
    let overS9 = sUnits >= 9 ? (rawValue - 216) / 4 : 0

    return SignalStrength(sUnits: sUnits, overS9: overS9, raw: rawValue)
}
```

**Testing Requirements:**
- [ ] Unit test with mock transport
- [ ] Test S0-S9 range
- [ ] Test S9+ range (over S9)
- [ ] Test invalid responses
- [ ] Integration test with real IC-7300 (if available)

**Reference:** Icom CI-V Reference Manual, command `15 02`

---

#### Task 1.4: Implement for Elecraft Protocol
**File:** `Sources/RigControl/Protocols/ElecraftProtocol.swift`

**Command:** `SM;` (Read S-meter) or `SM0;` for Main RX

**Implementation Guide:**
```swift
public func getSignalStrength() async throws -> SignalStrength {
    try await send("SM0;")  // Main receiver
    let response = try await receive()

    // Response format: "SM0nnnn;" where nnnn is 0000-0030 (0-30 dB over S0)
    guard response.hasPrefix("SM0"),
          response.hasSuffix(";"),
          response.count == 8 else {
        throw RigError.invalidResponse
    }

    let valueStr = response.dropFirst(3).dropLast()
    guard let rawValue = Int(valueStr) else {
        throw RigError.invalidResponse
    }

    // Elecraft: 0-30 represents dB over S0
    // S0 to S9 = 54 dB (6 dB per S-unit)
    let sUnits = min(rawValue / 6, 9)
    let overS9 = sUnits >= 9 ? rawValue - 54 : 0

    return SignalStrength(sUnits: sUnits, overS9: overS9, raw: rawValue)
}
```

**Testing Requirements:**
- [ ] Unit test with mock transport
- [ ] Test response parsing
- [ ] Test edge cases (S0, S9, S9+60)
- [ ] Integration test with K3/K4 (if available)

**Reference:** Elecraft K3 Programmer's Reference, `SM` command

---

#### Task 1.5: Implement for Yaesu CAT Protocol
**File:** `Sources/RigControl/Protocols/YaesuCATProtocol.swift`

**Command:** `RM5;` (Read Main S-meter)

**Implementation Guide:**
```swift
public func getSignalStrength() async throws -> SignalStrength {
    try await send("RM5;")
    let response = try await receive()

    // Response format: "RM5nnn;" where nnn is 000-255
    guard response.hasPrefix("RM5"),
          response.hasSuffix(";"),
          response.count == 7 else {
        throw RigError.invalidResponse
    }

    let valueStr = response.dropFirst(3).dropLast()
    guard let rawValue = Int(valueStr) else {
        throw RigError.invalidResponse
    }

    // Yaesu: 0-255 scale
    // Roughly: 0-120 = S0-S9, 121-255 = S9+1 to S9+60
    let sUnits = min(rawValue / 13, 9)
    let overS9 = sUnits >= 9 ? (rawValue - 117) / 2 : 0

    return SignalStrength(sUnits: sUnits, overS9: overS9, raw: rawValue)
}
```

**Note:** Command may vary by model. FT-991A uses `RM5;`, older models may differ.

**Testing Requirements:**
- [ ] Unit test with mock transport
- [ ] Test multiple radio models
- [ ] Verify command compatibility
- [ ] Integration test with FT-991A/FTDX-10 (if available)

**Reference:** Yaesu CAT Computer Control Manual

---

#### Task 1.6: Implement for Kenwood Protocol
**File:** `Sources/RigControl/Protocols/KenwoodProtocol.swift`

**Command:** `SM;` (Read S-meter) or `SM0;`

**Implementation Guide:**
```swift
public func getSignalStrength() async throws -> SignalStrength {
    try await send("SM0;")  // Main receiver
    let response = try await receive()

    // Response format: "SM0nnnn;" where nnnn is 0000-0030
    guard response.hasPrefix("SM0"),
          response.hasSuffix(";") else {
        throw RigError.invalidResponse
    }

    let valueStr = response.dropFirst(3).dropLast()
    guard let rawValue = Int(valueStr) else {
        throw RigError.invalidResponse
    }

    // Kenwood: Similar to Elecraft (0-30 scale)
    let sUnits = min(rawValue / 3, 9)
    let overS9 = sUnits >= 9 ? (rawValue - 27) * 2 : 0

    return SignalStrength(sUnits: sUnits, overS9: overS9, raw: rawValue)
}
```

**Testing Requirements:**
- [ ] Unit test with mock transport
- [ ] Test TS-590/TS-890 compatibility
- [ ] Integration test with TS-590SG (if available)

**Reference:** Kenwood CAT Command Reference

---

#### Task 1.7: Add to RigController Public API
**File:** `Sources/RigControl/RigController.swift`

**Add Method:**
```swift
/// Read current signal strength from the radio's S-meter
/// - Parameter cached: Use cached value if available (default: true)
/// - Returns: Current signal strength
/// - Throws: RigError if not connected or read fails
public func signalStrength(cached: Bool = true) async throws -> SignalStrength {
    guard connected else { throw RigError.notConnected }

    if cached {
        return try await stateCache.get("signal_strength", maxAge: 0.5) {
            try await proto.getSignalStrength()
        }
    } else {
        stateCache.invalidate("signal_strength")
        return try await proto.getSignalStrength()
    }
}
```

**Acceptance Criteria:**
- [ ] Public API method added
- [ ] Integrates with state cache (Task 3)
- [ ] Comprehensive documentation
- [ ] Example usage in documentation

---

#### Task 1.8: Update RadioCapabilities
**File:** `Sources/RigControl/Models/RadioCapabilities.swift`

**Add Field:**
```swift
/// Indicates if the radio supports S-meter reading
public let supportsSignalStrength: Bool
```

**Update for Each Radio:**
- Set `supportsSignalStrength: true` for radios with confirmed support
- Set `supportsSignalStrength: false` for untested/unsupported radios

**Acceptance Criteria:**
- [ ] Capability flag added
- [ ] All 24 radios have accurate flag values
- [ ] Documentation updated

---

### Testing Strategy for S-Meter Feature

**Unit Tests** (`Tests/RigControlTests/SignalStrengthTests.swift`):
```swift
final class SignalStrengthTests: XCTestCase {
    func testSignalStrengthDescription() {
        let s5 = SignalStrength(sUnits: 5, raw: 120)
        XCTAssertEqual(s5.description, "S5")

        let s9plus20 = SignalStrength(sUnits: 9, overS9: 20, raw: 236)
        XCTAssertEqual(s9plus20.description, "S9+20")
    }

    func testSignalStrengthValidation() {
        let invalid = SignalStrength(sUnits: 15, overS9: 100, raw: 999)
        XCTAssertEqual(invalid.sUnits, 9)  // Clamped
        XCTAssertEqual(invalid.overS9, 60) // Clamped
    }

    // More tests...
}
```

**Protocol Tests** (for each protocol):
```swift
func testIcomSMeterReading() async throws {
    let mockTransport = MockTransport()
    await mockTransport.setResponse(
        for: Data([0xFE, 0xFE, 0xA2, 0xE0, 0x15, 0x02, 0xFD]),
        response: Data([0xFE, 0xFE, 0xE0, 0xA2, 0x15, 0x02, 0x20, 0x01, 0xFD])
    )

    let proto = IcomCIVProtocol(transport: mockTransport, address: 0xA2)
    let signal = try await proto.getSignalStrength()

    XCTAssertEqual(signal.sUnits, 5)
    XCTAssertEqual(signal.overS9, 0)
}
```

**Integration Tests** (`Tests/RigControlTests/Integration/SMeterIntegrationTests.swift`):
- Test with real hardware (if available)
- Verify accuracy against radio display
- Test across different signal strengths

---

## Priority 2: State Caching Layer

### Objective
Implement an actor-based caching layer to reduce serial port queries and improve UI responsiveness.

### User Value: 8/10
**Problem:** Every query hits the serial port (50-100ms latency), making UIs sluggish.
**Solution:** Cache recent values for fast reads (target: <10ms).
**Impact:** 10-20x faster UI updates for logging/monitoring apps.

### Technical Complexity: 5/10
Requires careful actor design for thread-safety and cache invalidation.

---

### Implementation Tasks

#### Task 2.1: Create RadioStateCache Actor
**File:** `Sources/RigControl/Cache/RadioStateCache.swift` (new file)

**Implementation:**
```swift
import Foundation

/// Thread-safe cache for radio state values
public actor RadioStateCache {

    /// Cached value with timestamp
    private struct CachedValue<T> {
        let value: T
        let timestamp: Date

        func isValid(maxAge: TimeInterval) -> Bool {
            Date().timeIntervalSince(timestamp) < maxAge
        }
    }

    /// Internal cache storage (type-erased)
    private var cache: [String: Any] = [:]

    /// Default maximum age for cached values (500ms)
    private let defaultMaxAge: TimeInterval = 0.5

    /// Get a cached value or fetch fresh if expired
    /// - Parameters:
    ///   - key: Cache key identifier
    ///   - maxAge: Maximum age in seconds (uses default if nil)
    ///   - fetch: Async closure to fetch fresh value
    /// - Returns: Cached or fresh value
    public func get<T>(_ key: String,
                       maxAge: TimeInterval? = nil,
                       fetch: () async throws -> T) async throws -> T {
        let age = maxAge ?? defaultMaxAge

        // Check cache
        if let cached = cache[key] as? CachedValue<T>,
           cached.isValid(maxAge: age) {
            return cached.value
        }

        // Fetch fresh
        let value = try await fetch()
        cache[key] = CachedValue(value: value, timestamp: Date())
        return value
    }

    /// Invalidate a specific cache entry
    /// - Parameter key: Cache key to invalidate (nil = invalidate all)
    public func invalidate(_ key: String? = nil) {
        if let key = key {
            cache.removeValue(forKey: key)
        } else {
            cache.removeAll()
        }
    }

    /// Get cache statistics (for debugging)
    public func statistics() -> CacheStatistics {
        CacheStatistics(entryCount: cache.count, keys: Array(cache.keys))
    }
}

/// Cache statistics for debugging
public struct CacheStatistics: Sendable {
    public let entryCount: Int
    public let keys: [String]
}
```

**Acceptance Criteria:**
- [ ] Actor ensures thread-safety
- [ ] Generic `get` method supports any `Sendable` type
- [ ] Invalidation works for single key or all
- [ ] Timestamp-based expiration
- [ ] Statistics method for debugging
- [ ] Comprehensive unit tests

---

#### Task 2.2: Integrate Cache into RigController
**File:** `Sources/RigControl/RigController.swift`

**Add Property:**
```swift
/// State cache for performance optimization
private let stateCache = RadioStateCache()
```

**Update Methods to Support Caching:**
```swift
/// Get frequency with optional caching
public func frequency(vfo: VFO = .a, cached: Bool = true) async throws -> UInt64 {
    guard connected else { throw RigError.notConnected }

    if cached {
        return try await stateCache.get("freq_\(vfo)", maxAge: 0.5) {
            try await proto.getFrequency(vfo: vfo)
        }
    } else {
        stateCache.invalidate("freq_\(vfo)")
        return try await proto.getFrequency(vfo: vfo)
    }
}

/// Get mode with optional caching
public func mode(vfo: VFO = .a, cached: Bool = true) async throws -> Mode {
    guard connected else { throw RigError.notConnected }

    if cached {
        return try await stateCache.get("mode_\(vfo)", maxAge: 0.5) {
            try await proto.getMode(vfo: vfo)
        }
    } else {
        stateCache.invalidate("mode_\(vfo)")
        return try await proto.getMode(vfo: vfo)
    }
}

/// Set frequency (invalidates cache)
public func setFrequency(_ hz: UInt64, vfo: VFO = .a) async throws {
    guard connected else { throw RigError.notConnected }

    try await proto.setFrequency(hz, vfo: vfo)
    await stateCache.invalidate("freq_\(vfo)")

    // Notify observers (Task 3.3)
    await notifyObservers { observer in
        await observer.frequencyChanged(rig: self, vfo: vfo, frequency: hz)
    }
}

/// Set mode (invalidates cache)
public func setMode(_ mode: Mode, vfo: VFO = .a) async throws {
    guard connected else { throw RigError.notConnected }

    try await proto.setMode(mode, vfo: vfo)
    await stateCache.invalidate("mode_\(vfo)")

    // Notify observers
    await notifyObservers { observer in
        await observer.modeChanged(rig: self, vfo: vfo, mode: mode)
    }
}

/// Invalidate all cached state (e.g., after disconnect/reconnect)
public func invalidateCache() async {
    await stateCache.invalidate()
}
```

**Acceptance Criteria:**
- [ ] All read methods support `cached` parameter (default: true)
- [ ] All write methods invalidate relevant cache entries
- [ ] Cache invalidated on disconnect
- [ ] Public method to manually invalidate cache
- [ ] Documentation includes caching behavior

---

#### Task 2.3: Performance Testing & Benchmarks
**File:** `Tests/RigControlTests/Performance/CachingPerformanceTests.swift` (new)

**Create Benchmark Tests:**
```swift
import XCTest
@testable import RigControl

final class CachingPerformanceTests: XCTestCase {

    func testCachedFrequencyPerformance() async throws {
        let mockTransport = MockTransport()
        // Configure mock with 50ms delay to simulate serial port
        await mockTransport.setResponseDelay(0.05)

        let rig = try await RigController(...)
        try await rig.connect()

        // First read (cache miss) - should take ~50ms
        let start1 = Date()
        _ = try await rig.frequency(cached: true)
        let duration1 = Date().timeIntervalSince(start1)
        XCTAssertGreaterThan(duration1, 0.04) // At least 40ms

        // Second read (cache hit) - should take <10ms
        let start2 = Date()
        _ = try await rig.frequency(cached: true)
        let duration2 = Date().timeIntervalSince(start2)
        XCTAssertLessThan(duration2, 0.01) // Less than 10ms

        print("Cache miss: \(duration1 * 1000)ms, Cache hit: \(duration2 * 1000)ms")
        print("Speedup: \(duration1 / duration2)x")
    }

    func testCacheExpiration() async throws {
        // Test that cache expires after maxAge
        // ...
    }

    func testCacheInvalidation() async throws {
        // Test that setters invalidate cache
        // ...
    }
}
```

**Performance Goals:**
- [ ] Cached reads <10ms (vs ~50ms uncached)
- [ ] 10-20x speedup demonstrated
- [ ] No race conditions under concurrent access
- [ ] Memory usage remains reasonable

---

## Priority 3: RigStateObserver Protocol

### Objective
Add observer pattern for real-time state change notifications to simplify UI development.

### User Value: 9/10
Dramatically improves developer experience by enabling reactive UI updates without polling.

### Technical Complexity: 3/10
Straightforward protocol addition with weak reference management.

---

### Implementation Tasks

#### Task 3.1: Create RigStateObserver Protocol
**File:** `Sources/RigControl/Observers/RigStateObserver.swift` (new)

**Implementation:**
```swift
import Foundation

/// Protocol for observing radio state changes
public protocol RigStateObserver: AnyObject {

    /// Called when frequency changes
    /// - Parameters:
    ///   - rig: The rig controller
    ///   - vfo: Which VFO changed
    ///   - frequency: New frequency in Hz
    func frequencyChanged(rig: RigController, vfo: VFO, frequency: UInt64) async

    /// Called when mode changes
    /// - Parameters:
    ///   - rig: The rig controller
    ///   - vfo: Which VFO changed
    ///   - mode: New mode
    func modeChanged(rig: RigController, vfo: VFO, mode: Mode) async

    /// Called when PTT state changes
    /// - Parameters:
    ///   - rig: The rig controller
    ///   - enabled: New PTT state
    func pttChanged(rig: RigController, enabled: Bool) async

    /// Called when transmit power changes
    /// - Parameters:
    ///   - rig: The rig controller
    ///   - watts: New power in watts
    func powerChanged(rig: RigController, watts: Int) async

    /// Called when signal strength updates
    /// - Parameters:
    ///   - rig: The rig controller
    ///   - strength: New signal strength
    func signalStrengthChanged(rig: RigController, strength: SignalStrength) async

    /// Called when VFO selection changes
    /// - Parameters:
    ///   - rig: The rig controller
    ///   - vfo: New active VFO
    func vfoChanged(rig: RigController, vfo: VFO) async

    /// Called when split mode changes
    /// - Parameters:
    ///   - rig: The rig controller
    ///   - enabled: New split state
    func splitChanged(rig: RigController, enabled: Bool) async
}

/// Default implementations (all optional)
public extension RigStateObserver {
    func frequencyChanged(rig: RigController, vfo: VFO, frequency: UInt64) async {}
    func modeChanged(rig: RigController, vfo: VFO, mode: Mode) async {}
    func pttChanged(rig: RigController, enabled: Bool) async {}
    func powerChanged(rig: RigController, watts: Int) async {}
    func signalStrengthChanged(rig: RigController, strength: SignalStrength) async {}
    func vfoChanged(rig: RigController, vfo: VFO) async {}
    func splitChanged(rig: RigController, enabled: Bool) async {}
}
```

**Acceptance Criteria:**
- [ ] Protocol methods are async
- [ ] All methods have default implementations (optional)
- [ ] Clear documentation with usage examples
- [ ] Sendable-compatible design

---

#### Task 3.2: Add Weak Reference Wrapper
**File:** `Sources/RigControl/Observers/WeakBox.swift` (new)

**Implementation:**
```swift
/// Weak reference wrapper for observers
final class WeakBox<T: AnyObject> {
    weak var value: T?

    init(_ value: T) {
        self.value = value
    }
}
```

---

#### Task 3.3: Integrate Observers into RigController
**File:** `Sources/RigControl/RigController.swift`

**Add Properties:**
```swift
/// Registered state observers
private var observers: [WeakBox<RigStateObserver>] = []

/// Serial queue for observer notifications
private let observerQueue = DispatchQueue(label: "com.swiftrigcontrol.observers")
```

**Add Public Methods:**
```swift
/// Add a state observer
/// - Parameter observer: Observer to add
public func addObserver(_ observer: RigStateObserver) {
    observerQueue.async { [weak self] in
        guard let self = self else { return }
        self.observers.append(WeakBox(observer))
        self.cleanupObservers()
    }
}

/// Remove a state observer
/// - Parameter observer: Observer to remove
public func removeObserver(_ observer: RigStateObserver) {
    observerQueue.async { [weak self] in
        guard let self = self else { return }
        self.observers.removeAll { $0.value === observer }
    }
}

/// Remove nil observers
private func cleanupObservers() {
    observers.removeAll { $0.value == nil }
}

/// Notify all observers
private func notifyObservers(_ notification: (RigStateObserver) async -> Void) async {
    let currentObservers = observerQueue.sync { observers.compactMap { $0.value } }

    for observer in currentObservers {
        await notification(observer)
    }

    observerQueue.async { [weak self] in
        self?.cleanupObservers()
    }
}
```

**Update Setter Methods:**
```swift
public func setFrequency(_ hz: UInt64, vfo: VFO = .a) async throws {
    guard connected else { throw RigError.notConnected }

    try await proto.setFrequency(hz, vfo: vfo)
    await stateCache.invalidate("freq_\(vfo)")

    // Notify observers
    await notifyObservers { observer in
        await observer.frequencyChanged(rig: self, vfo: vfo, frequency: hz)
    }
}

// Similar for setMode, setPTT, setPower, etc.
```

**Acceptance Criteria:**
- [ ] Weak references prevent retain cycles
- [ ] Thread-safe observer management
- [ ] Automatic cleanup of deallocated observers
- [ ] All state changes trigger notifications
- [ ] Unit tests for observer pattern

---

#### Task 3.4: Create Example SwiftUI Integration
**File:** `Examples/ObserverExample/RadioViewModel.swift` (new)

**Implementation:**
```swift
import SwiftUI
import Combine
import RigControl

/// Example SwiftUI view model using RigStateObserver
@MainActor
class RadioViewModel: ObservableObject, RigStateObserver {

    @Published var frequency: UInt64 = 0
    @Published var mode: Mode = .lsb
    @Published var signalStrength: SignalStrength?
    @Published var isPTTEnabled: Bool = false

    private var rig: RigController?

    func connect(to rig: RigController) {
        self.rig = rig
        rig.addObserver(self)
    }

    func disconnect() {
        rig?.removeObserver(self)
        rig = nil
    }

    // MARK: - RigStateObserver

    func frequencyChanged(rig: RigController, vfo: VFO, frequency: UInt64) async {
        self.frequency = frequency
    }

    func modeChanged(rig: RigController, vfo: VFO, mode: Mode) async {
        self.mode = mode
    }

    func signalStrengthChanged(rig: RigController, strength: SignalStrength) async {
        self.signalStrength = strength
    }

    func pttChanged(rig: RigController, enabled: Bool) async {
        self.isPTTEnabled = enabled
    }
}

/// Example SwiftUI view
struct RadioControlView: View {
    @StateObject private var viewModel = RadioViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // Frequency display
            Text("\(viewModel.frequency) Hz")
                .font(.system(size: 48, design: .monospaced))

            // Mode
            Text("Mode: \(viewModel.mode.rawValue)")
                .font(.title2)

            // S-meter
            if let signal = viewModel.signalStrength {
                Text("Signal: \(signal.description)")
                    .font(.title3)
            }

            // PTT indicator
            Circle()
                .fill(viewModel.isPTTEnabled ? Color.red : Color.gray)
                .frame(width: 30, height: 30)
        }
        .padding()
    }
}
```

**Acceptance Criteria:**
- [ ] Example compiles and runs
- [ ] Demonstrates reactive UI updates
- [ ] Shows best practices for SwiftUI integration
- [ ] Documented in USAGE_EXAMPLES.md

---

## Priority 4: Batch Configuration API

### Objective
Add convenience method to configure multiple radio parameters in one call.

### User Value: 8/10
Simplifies common operations like "set up for FT8 on 40m".

### Technical Complexity: 2/10
Simple API wrapper around existing methods.

---

### Implementation Tasks

#### Task 4.1: Add Batch Configuration Method
**File:** `Sources/RigControl/RigController.swift`

**Implementation:**
```swift
/// Configure multiple radio parameters in one call
/// - Parameters:
///   - frequency: Frequency in Hz (optional)
///   - mode: Operating mode (optional)
///   - vfo: Target VFO (default: .a)
///   - power: Transmit power in watts (optional)
/// - Throws: RigError if any operation fails
public func configure(
    frequency: UInt64? = nil,
    mode: Mode? = nil,
    vfo: VFO = .a,
    power: Int? = nil
) async throws {
    guard connected else { throw RigError.notConnected }

    // Apply in optimal order (frequency, mode, power)
    if let frequency = frequency {
        try await setFrequency(frequency, vfo: vfo)
    }

    if let mode = mode {
        try await setMode(mode, vfo: vfo)
    }

    if let power = power {
        try await setPower(watts: power)
    }
}
```

**Usage Examples:**
```swift
// Set up for FT8 on 20m
try await rig.configure(
    frequency: 14_074_000,
    mode: .dataUSB,
    power: 50
)

// Quick band change
try await rig.configure(frequency: 7_074_000)

// Mode change only
try await rig.configure(mode: .cw)
```

**Acceptance Criteria:**
- [ ] All parameters are optional
- [ ] Executes in optimal order
- [ ] Atomic operation (all or nothing)
- [ ] Comprehensive documentation with examples
- [ ] Unit tests

---

## Priority 5: RF Gain Control

### Objective
Add RF gain control for receive sensitivity adjustment.

### User Value: 7/10
Important for contest operators and those dealing with strong local signals.

### Technical Complexity: 4/10
Similar complexity to power control.

---

### Implementation Tasks

#### Task 5.1: Add Protocol Method
**File:** `Sources/RigControl/Protocols/CATProtocol.swift`

**Add Methods:**
```swift
/// Get RF gain level
/// - Returns: RF gain as percentage (0-100)
/// - Throws: RigError if unsupported or read fails
func getRFGain() async throws -> Int

/// Set RF gain level
/// - Parameter percent: RF gain percentage (0-100)
/// - Throws: RigError if unsupported or invalid
func setRFGain(_ percent: Int) async throws
```

---

#### Task 5.2: Implement for All Protocols

**Icom:** Command `0x14 0x02` (RF Gain)
**Elecraft:** `RG;` / `RGnnn;`
**Yaesu:** `RG;` / `RGnnn;`
**Kenwood:** `RG;` / `RGnnn;`

Follow similar pattern to power control implementation.

---

#### Task 5.3: Add to RigController
**File:** `Sources/RigControl/RigController.swift`

```swift
/// Get RF gain percentage
public func rfGain(cached: Bool = true) async throws -> Int {
    guard connected else { throw RigError.notConnected }

    if cached {
        return try await stateCache.get("rf_gain", maxAge: 1.0) {
            try await proto.getRFGain()
        }
    } else {
        stateCache.invalidate("rf_gain")
        return try await proto.getRFGain()
    }
}

/// Set RF gain percentage (0-100)
public func setRFGain(_ percent: Int) async throws {
    guard connected else { throw RigError.notConnected }
    guard (0...100).contains(percent) else {
        throw RigError.invalidParameter("RF gain must be 0-100")
    }

    try await proto.setRFGain(percent)
    await stateCache.invalidate("rf_gain")

    // Note: No observer notification needed (less critical than frequency/mode)
}
```

**Acceptance Criteria:**
- [ ] Get/set methods implemented
- [ ] Validation (0-100 range)
- [ ] Cached reads
- [ ] All 4 protocols supported
- [ ] Unit tests

---

## Priority 6: Additional Radio Models

### Objective
Add 3-5 new radio models within existing protocol families.

### User Value: 7/10
Expands user base and demonstrates protocol flexibility.

### Target Models

**Icom:**
- IC-7850/7851 (high-end)
- IC-9100 (multi-band)

**Elecraft:**
- K3 (if not already included)
- KX3 (QRP portable)

**Yaesu:**
- FT-897D (classic multi-mode)
- FT-DX3000 (mid-range)

**Kenwood:**
- TS-480HX (mobile)

---

### Implementation Tasks

#### Task 6.1: Research Radio Specifications
For each new radio:
- [ ] Confirm CAT protocol compatibility
- [ ] Document CI-V address (Icom) or baud rate requirements
- [ ] Identify unique features or limitations
- [ ] Confirm command set compatibility with existing protocol

---

#### Task 6.2: Add Radio Definitions
**File:** `Sources/RigControl/Models/RadioModels.swift`

**Example:**
```swift
public extension RadioModels {
    static let ic7851 = RadioModel(
        manufacturer: "Icom",
        model: "IC-7851",
        protocol: .icomCIV,
        baudRate: 19200,
        civAddress: 0x8E,
        capabilities: RadioCapabilities(
            supportedVFOs: [.a, .b],
            supportedModes: Mode.allCases,
            minFrequency: 30_000,
            maxFrequency: 60_000_000,
            maxPower: 200,
            supportsSignalStrength: true,
            // ...
        )
    )
}
```

---

#### Task 6.3: Add Integration Tests
For each radio (if hardware available):
- [ ] Connection test
- [ ] Frequency set/get
- [ ] Mode set/get
- [ ] S-meter reading
- [ ] Power control

---

#### Task 6.4: Update Documentation
- [ ] Add to README.md radio table
- [ ] Update SERIAL_PORT_GUIDE.md with setup instructions
- [ ] Add example code to USAGE_EXAMPLES.md

---

## Priority 7: Connection Health Monitoring

### Objective
Add connection state monitoring and automatic reconnection.

### User Value: 7/10
Improves reliability for long-running applications.

### Technical Complexity: 6/10
Requires careful state management and error handling.

---

### Implementation Tasks

#### Task 7.1: Add ConnectionState Enum
**File:** `Sources/RigControl/Models/ConnectionState.swift` (new)

```swift
/// Radio connection state
public enum ConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case failed(error: RigError)
}
```

---

#### Task 7.2: Add Connection Health Checking
**File:** `Sources/RigControl/RigController.swift`

**Add Properties:**
```swift
/// Current connection state
@Published public private(set) var connectionState: ConnectionState = .disconnected

/// Auto-reconnect settings
public var autoReconnect: Bool = false
public var maxReconnectAttempts: Int = 3
public var reconnectDelay: TimeInterval = 2.0

/// Health check timer
private var healthCheckTimer: Timer?
```

**Add Methods:**
```swift
/// Start connection health monitoring
private func startHealthMonitoring() {
    healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
        Task { @MainActor in
            await self?.performHealthCheck()
        }
    }
}

/// Perform connection health check
private func performHealthCheck() async {
    guard connectionState == .connected else { return }

    do {
        // Simple ping (get frequency)
        _ = try await frequency(cached: false)
    } catch {
        // Connection lost
        await handleConnectionLoss()
    }
}

/// Handle connection loss
private func handleConnectionLoss() async {
    connectionState = .disconnected

    if autoReconnect {
        await attemptReconnect()
    }
}

/// Attempt to reconnect
private func attemptReconnect(attempt: Int = 1) async {
    guard attempt <= maxReconnectAttempts else {
        connectionState = .failed(error: .connectionFailed)
        return
    }

    connectionState = .reconnecting(attempt: attempt)

    try? await Task.sleep(nanoseconds: UInt64(reconnectDelay * 1_000_000_000))

    do {
        try await connect()
        connectionState = .connected
    } catch {
        await attemptReconnect(attempt: attempt + 1)
    }
}
```

**Acceptance Criteria:**
- [ ] Connection state published via Combine
- [ ] Health check every 5 seconds
- [ ] Auto-reconnect with exponential backoff
- [ ] Configurable retry limits
- [ ] Unit tests with mock failures

---

## Testing Requirements

### Overall Test Coverage Goal: 95%+

### Unit Test Requirements
- [ ] All new models have unit tests
- [ ] All protocol methods have unit tests
- [ ] Cache behavior fully tested
- [ ] Observer pattern fully tested
- [ ] Edge cases and error conditions tested

### Integration Test Requirements
- [ ] S-meter reading tested with real hardware (if available)
- [ ] Cache performance benchmarks
- [ ] Observer notifications verified
- [ ] Multi-threaded access tested

### Performance Test Requirements
- [ ] Cache speedup verified (10-20x)
- [ ] Query latency <10ms (cached)
- [ ] No memory leaks under load
- [ ] Concurrent access performance

---

## Documentation Updates

### Files to Update

#### README.md
- [ ] Add S-meter reading to features list
- [ ] Update radio count (24 → 28+)
- [ ] Add performance metrics section
- [ ] Update quick start example with observers

#### USAGE_EXAMPLES.md
- [ ] Add S-meter monitoring example
- [ ] Add observer pattern example
- [ ] Add batch configuration examples
- [ ] Add SwiftUI integration example

#### CHANGELOG.md
- [ ] Create v1.1.0 section
- [ ] List all new features
- [ ] Note performance improvements
- [ ] Credit contributors

#### NEW: MIGRATION_GUIDE_v1.1.md
Create migration guide covering:
- [ ] New caching behavior (cached: Bool parameter)
- [ ] Observer pattern usage
- [ ] Batch configuration API
- [ ] Breaking changes (if any)

---

## Release Checklist

### Pre-Release
- [ ] All features implemented and tested
- [ ] Test coverage ≥95%
- [ ] Documentation updated
- [ ] Examples compile and run
- [ ] Performance benchmarks pass
- [ ] No compiler warnings
- [ ] All radio models tested (if hardware available)

### Version Bump
- [ ] Update Package.swift version to 1.1.0
- [ ] Update CHANGELOG.md
- [ ] Create RELEASE_NOTES_v1.1.0.md

### Git & Release
- [ ] Create release branch: `release/v1.1.0`
- [ ] Run full test suite
- [ ] Create git tag: `v1.1.0`
- [ ] Push to GitHub
- [ ] Create GitHub release
- [ ] Publish release notes

### Post-Release
- [ ] Announce on social media (Reddit, Twitter)
- [ ] Update discussions forum
- [ ] Reach out to app developers
- [ ] Monitor for issues

---

## Success Metrics

Track these metrics to measure v1.1.0 success:

### Technical Metrics
- ✅ Query latency <10ms (cached reads)
- ✅ 95%+ test coverage maintained
- ✅ Zero critical bugs in first month
- ✅ All 4 protocols support S-meter

### Adoption Metrics
- ✅ 50+ GitHub stars
- ✅ 5+ production apps using v1.1.0
- ✅ 10+ contributors
- ✅ 100+ downloads in first month

### Community Metrics
- ✅ 10+ issues/questions in first month
- ✅ 3+ pull requests from community
- ✅ Positive feedback on Reddit/forums

---

## Risk Mitigation

### Technical Risks

**Risk:** S-meter readings vary significantly across radios
**Mitigation:** Document variations, provide raw value access

**Risk:** Caching causes stale data issues
**Mitigation:** Conservative default maxAge (500ms), easy invalidation

**Risk:** Observer memory leaks
**Mitigation:** Weak references, automatic cleanup, thorough testing

**Risk:** Performance regression on older Macs
**Mitigation:** Benchmark on older hardware, make caching optional

### Project Risks

**Risk:** Feature creep delays release
**Mitigation:** Strict scope, defer non-critical features to v1.2

**Risk:** Insufficient testing without all hardware
**Mitigation:** Strong unit tests, community testing, mock transport

**Risk:** Breaking changes sneak in
**Mitigation:** API review before release, maintain v1.0 compatibility

---

## Getting Help

### Resources
- **GitHub Issues:** [SwiftRigControl Issues](https://github.com/jjones9527/SwiftRigControl/issues)
- **Discussions:** [GitHub Discussions](https://github.com/jjones9527/SwiftRigControl/discussions)
- **Email:** va3ztf@gmail.com

### Protocol References
- **Icom CI-V:** [Icom CI-V Reference Manual](https://www.icomamerica.com/)
- **Elecraft:** [K3/K4 Programmer's Reference](https://www.elecraft.com/)
- **Yaesu:** [CAT Operation Reference Book](https://www.yaesu.com/)
- **Kenwood:** [PC Control Command Reference](https://www.kenwood.com/)

---

## Timeline

**Week 1-2:** S-meter implementation (all protocols)
**Week 3:** State caching layer
**Week 4:** Observer pattern & batch API
**Week 5:** RF gain, additional radios, connection monitoring
**Week 6:** Testing, documentation, release prep

**Target Release:** End of Q1 2026

---

## Next Steps

1. **Create v1.1.0 milestone** on GitHub
2. **Create feature branches** for each major task
3. **Set up GitHub Actions** for automated testing
4. **Begin with Priority 1** (S-meter reading - highest value)
5. **Iterate and test** frequently
6. **Engage community** for testing and feedback

---

**73 de VA3ZTF!** 📻

*Let's make SwiftRigControl the premier macOS amateur radio control library!*

---

**Document Version:** 1.0
**Created:** November 19, 2025
**Next Review:** After v1.1.0 release
