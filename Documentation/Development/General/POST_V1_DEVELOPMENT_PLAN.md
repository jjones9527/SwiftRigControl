# SwiftRigControl Post-v1.0.0 Development Plan
**Author:** VA3ZTF (Jeremy Jones)
**Date:** November 19, 2025
**Version:** 1.0

---

## Executive Summary

SwiftRigControl v1.0.0 represents a **production-ready, well-architected foundation** for amateur radio control on macOS. The codebase demonstrates:

✅ **Strengths:**
- Clean protocol-oriented architecture with excellent separation of concerns
- Modern Swift concurrency (actors, async/await) used correctly
- 95% test coverage with comprehensive unit tests
- Excellent documentation (~4,755 lines across 7 guides)
- Zero known bugs, stable API
- Strong type safety and error handling

⚠️ **Areas for Improvement:**
- Limited radio monitoring capabilities (no S-meter, TX meters)
- No memory/scanning features for typical ham operations
- Missing advanced tuning controls (RIT/XIT)
- Single protocol instance per controller (no multi-rig support)
- No state caching/optimization for rapid queries

---

## Top 5 Immediate Priorities

### 1. **Radio Status Monitoring (v1.1.0)** 🔥 **HIGHEST VALUE**
- **User Value:** 10/10 - Essential for proper radio operation
- **Complexity:** 4/10 - Straightforward protocol additions
- **Impact:** Enables monitoring apps, proper tuning, contest logging

**What to Add:**
- S-meter reading (receive signal strength)
- TX meter (power out, SWR, ALC)
- Basic implementation across all 4 protocols

**Why Critical:** Currently blind to signal conditions - this is table stakes for radio control software.

---

### 2. **API Enhancements for Real-World Apps (v1.1.0)** 🎯
- **User Value:** 9/10 - Dramatically improves developer experience
- **Complexity:** 3/10 - Mainly API additions, minimal protocol changes

**What to Add:**
```swift
// State observation
public protocol RigStateObserver {
    func frequencyChanged(_ freq: UInt64, vfo: VFO)
    func modeChanged(_ mode: Mode, vfo: VFO)
    func pttChanged(_ enabled: Bool)
}

// Batch operations
public func configure(frequency: UInt64, mode: Mode, vfo: VFO) async throws

// Radio discovery
public static func discoverRadios() async -> [RadioInfo]
```

---

### 3. **Performance & Caching Layer (v1.1.0)** ⚡
- **User Value:** 8/10 - Critical for responsive UI
- **Complexity:** 5/10 - Requires careful actor design

**Problem:** Every query hits serial port (50-100ms latency)

**Solution:**
```swift
actor RadioStateCache {
    private var frequency: (value: UInt64, timestamp: Date)?
    private var mode: (value: Mode, timestamp: Date)?

    func getCachedOrFetch<T>(_ key: String, maxAge: TimeInterval,
                             fetch: () async throws -> T) async throws -> T
}
```

**Impact:** 10-20x faster UI updates for logging/monitoring apps

---

### 4. **Memory Operations (v1.2.0)** 📻
- **User Value:** 8/10 - Core ham radio workflow
- **Complexity:** 6/10 - Protocol-specific implementations vary

**Features:**
- Store/recall frequencies with mode (memory channels)
- Quick band changes (memory scan)
- Integration with logging apps

**Use Cases:**
- Contest operators: Quick band/frequency changes
- DXers: Store pile-up frequencies
- Digital mode operators: Save common frequencies

---

### 5. **Multi-Rig Support (v1.2.0)** 🔀
- **User Value:** 7/10 - Growing use case (SO2R, satellite ops)
- **Complexity:** 6/10 - Architectural change required

**Current Limitation:** One RigController per radio, no coordination

**Solution:**
```swift
actor RigManager {
    private var rigs: [String: RigController] = [:]

    func addRig(id: String, controller: RigController) async
    func rig(id: String) -> RigController?
    func syncVFOs(from: String, to: String) async throws
}
```

---

## Version Roadmap

### v1.1.0 - Monitoring & Performance (Q1 2026, ~6 weeks)

**Theme:** Make SwiftRigControl production-ready for logging/monitoring applications

**Features:**
1. ✅ S-meter reading (all protocols)
2. ✅ TX meter reading (power, SWR, ALC)
3. ✅ State caching layer
4. ✅ Batch configuration API
5. ✅ RigStateObserver protocol
6. ✅ Connection health monitoring
7. ✅ RF gain control
8. ✅ 3-5 additional radio models

**Breaking Changes:** None (backward compatible)

**Success Metrics:**
- Query latency <10ms (from cache)
- 15+ new use cases enabled
- 5+ new radio models

---

### v1.2.0 - Memory & Advanced Control (Q2 2026, ~8 weeks)

**Theme:** Add core ham radio workflow features

**Features:**
1. ✅ Memory channel operations (read/write/scan)
2. ✅ RIT/XIT clarifier support
3. ✅ Antenna selection
4. ✅ Preamp/Attenuator control
5. ✅ Filter bandwidth selection
6. ✅ AGC mode control
7. ✅ Multi-rig manager
8. ✅ Band stacking registers
9. ✅ Noise blanker/reduction

**Breaking Changes:** Minimal (additive API)

**Success Metrics:**
- Support 90% of common ham operations
- Multi-rig coordination working
- Contest-ready feature set

---

### v1.3.0 - SwiftUI Components (Q3 2026, ~4 weeks)

**Theme:** Pre-built UI components for rapid app development

**Features:**
1. ✅ `RadioControlView` - Full radio control panel
2. ✅ `FrequencyDisplay` - VFO frequency with tuning
3. ✅ `ModeSelector` - Mode picker
4. ✅ `MeterView` - S-meter and TX meters
5. ✅ `MemoryManager` - Channel list/selector
6. ✅ `BandSelector` - Quick band changes
7. ✅ View models and Combine publishers
8. ✅ Example SwiftUI app

**Breaking Changes:** None (new module: RigControlUI)

---

### v2.0.0 - Network & Integration (Q4 2026, ~12 weeks)

**Theme:** Remote operation and ecosystem integration

**Major Features:**
1. ✅ Network rig control (rigctld protocol compatibility)
2. ✅ Multi-client support (TCP server)
3. ✅ Audio routing integration (Core Audio)
4. ✅ ADIF export for logging integration
5. ✅ Digital mode app integration (WSJT-X, fldigi)
6. ✅ Radio simulator for development
7. ✅ CLI tool for testing
8. ✅ Automatic radio detection

**Breaking Changes:**
- Swift 6 adoption (strict concurrency)
- macOS 14+ minimum
- Potential CATProtocol refinements

---

## Feature Prioritization Matrix

### High Priority (v1.1.0)

| Feature | User Value | Complexity | Dependencies | Effort |
|---------|-----------|------------|--------------|--------|
| S-meter reading | 10 | 4 | None | M |
| TX meter reading | 10 | 5 | S-meter | M |
| State caching | 8 | 5 | None | M |
| State observers | 9 | 3 | None | S |
| Batch operations | 8 | 2 | None | S |
| RF gain control | 7 | 4 | None | S |

### Medium Priority (v1.2.0)

| Feature | User Value | Complexity | Dependencies | Effort |
|---------|-----------|------------|--------------|--------|
| Memory operations | 8 | 6 | None | L |
| RIT/XIT | 7 | 5 | None | M |
| Antenna selection | 6 | 4 | None | S |
| Preamp/Attenuator | 7 | 4 | None | M |
| Multi-rig support | 7 | 6 | None | M |
| Filter selection | 6 | 5 | None | M |
| Band stacking | 6 | 6 | Memory | M |

### Lower Priority (v1.3.0+)

| Feature | User Value | Complexity | Dependencies | Effort |
|---------|-----------|------------|--------------|--------|
| Scanning | 5 | 7 | Memory | L |
| SwiftUI components | 8 | 4 | v1.2 APIs | M |
| Network control | 6 | 8 | None | XL |
| Audio integration | 7 | 9 | None | XL |
| ADIF export | 6 | 3 | None | S |

**Effort:** S=1-2 weeks, M=3-4 weeks, L=5-8 weeks, XL=8+ weeks

---

## Implementation Guides (Top 3 Priorities)

### 1. S-Meter Reading Implementation

**API Design:**
```swift
// Add to CATProtocol
func getSignalStrength() async throws -> SignalStrength

// New model
public struct SignalStrength: Sendable {
    public let sUnits: Int        // 0-9 (S0 to S9)
    public let overS9: Int         // 0-60 (dB over S9)
    public let raw: Int            // Protocol-specific raw value

    public var description: String {
        if sUnits < 9 {
            return "S\(sUnits)"
        } else {
            return "S9+\(overS9)"
        }
    }
}
```

**Icom Implementation:**
```swift
// In IcomCIVProtocol.swift
public func getSignalStrength() async throws -> SignalStrength {
    let frame = CIVFrame(
        to: civAddress,
        command: [0x15, 0x02]  // Read S-meter
    )

    try await sendFrame(frame)
    let response = try await receiveFrame()

    guard response.command == [0x15, 0x02],
          response.data.count == 2 else {
        throw RigError.invalidResponse
    }

    // Icom returns 0-255 (0x0000 to 0x0255 BCD)
    let rawValue = Int(response.data[0]) + (Int(response.data[1]) * 100)

    // Convert to S-units (roughly 0-241 range)
    let sUnits = min(rawValue / 24, 9)
    let overS9 = sUnits >= 9 ? (rawValue - 216) / 4 : 0

    return SignalStrength(sUnits: sUnits, overS9: overS9, raw: rawValue)
}
```

**Testing Strategy:**
```swift
func testSMeterReading() async throws {
    let mockTransport = MockTransport()
    await mockTransport.setResponse(
        for: Data([0xFE, 0xFE, 0xA2, 0xE0, 0x15, 0x02, 0xFD]),
        response: Data([0xFE, 0xFE, 0xE0, 0xA2, 0x15, 0x02, 0x20, 0x01, 0xFD])
    )

    let proto = IcomCIVProtocol(transport: mockTransport, ...)
    let signal = try await proto.getSignalStrength()

    XCTAssertEqual(signal.sUnits, 5)
}
```

---

### 2. State Caching Layer

**Architecture:**
```swift
public actor RadioStateCache {
    private struct CachedValue<T> {
        let value: T
        let timestamp: Date
    }

    private var cache: [String: Any] = [:]
    private let maxAge: TimeInterval = 0.5  // 500ms default

    func get<T>(_ key: String,
                maxAge: TimeInterval? = nil,
                fetch: () async throws -> T) async throws -> T {
        let age = maxAge ?? self.maxAge

        if let cached = cache[key] as? CachedValue<T>,
           Date().timeIntervalSince(cached.timestamp) < age {
            return cached.value
        }

        let value = try await fetch()
        cache[key] = CachedValue(value: value, timestamp: Date())
        return value
    }

    func invalidate(_ key: String? = nil) {
        if let key = key {
            cache.removeValue(forKey: key)
        } else {
            cache.removeAll()
        }
    }
}

// In RigController
private let stateCache = RadioStateCache()

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
```

**Usage:**
```swift
// Fast queries (from cache if recent)
let freq = try await rig.frequency()  // <10ms if cached

// Force fresh read
let actualFreq = try await rig.frequency(cached: false)  // ~50ms

// Invalidate on changes
try await rig.setFrequency(14_230_000)  // Auto-invalidates cache
```

---

### 3. State Observer Pattern

**Protocol:**
```swift
public protocol RigStateObserver: AnyObject {
    func frequencyChanged(rig: RigController, vfo: VFO, frequency: UInt64) async
    func modeChanged(rig: RigController, vfo: VFO, mode: Mode) async
    func pttChanged(rig: RigController, enabled: Bool) async
    func powerChanged(rig: RigController, watts: Int) async
    func signalStrengthChanged(rig: RigController, strength: SignalStrength) async
}

// Optional methods via extension
extension RigStateObserver {
    func frequencyChanged(rig: RigController, vfo: VFO, frequency: UInt64) async {}
    func modeChanged(rig: RigController, vfo: VFO, mode: Mode) async {}
    // ... defaults for all
}
```

**Implementation:**
```swift
public actor RigController {
    private var observers: [WeakBox<RigStateObserver>] = []

    public func addObserver(_ observer: RigStateObserver) {
        observers.append(WeakBox(observer))
        observers.removeAll { $0.value == nil }
    }

    public func setFrequency(_ hz: UInt64, vfo: VFO = .a) async throws {
        guard connected else { throw RigError.notConnected }

        try await proto.setFrequency(hz, vfo: vfo)
        stateCache.invalidate("freq_\(vfo)")

        // Notify observers
        for observer in observers {
            await observer.value?.frequencyChanged(rig: self, vfo: vfo, frequency: hz)
        }
    }
}

// Usage in SwiftUI
class RadioViewModel: ObservableObject, RigStateObserver {
    @Published var frequency: UInt64 = 0

    func frequencyChanged(rig: RigController, vfo: VFO, frequency: UInt64) async {
        await MainActor.run {
            self.frequency = frequency
        }
    }
}
```

---

## Risk Assessment & Mitigation

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Protocol changes by manufacturers | Medium | High | Version detection, graceful degradation |
| macOS API deprecation | Low | Medium | Track beta releases, maintain compatibility layer |
| Swift 6 migration complexity | High | Medium | Start testing now, incremental adoption |
| Performance degradation (caching) | Medium | Medium | Extensive benchmarking, cache tuning |
| State synchronization bugs | Medium | High | Comprehensive testing, state validation |

### Project Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Feature creep | High | Medium | Strict version planning, defer to next version |
| Contributor burnout | Medium | High | Distribute work, good documentation |
| Community fragmentation | Low | Medium | Clear communication, responsive to feedback |
| Competition (Hamlib updates) | Low | Low | Focus on macOS-specific advantages |

---

## Community Growth Strategy

### Adoption (Months 1-6)

**Target Users:**
1. **macOS logging app developers** (primary)
2. **Digital mode operators** (SSTV, FT8)
3. **Contest operators** (multi-rig setups)
4. **Satellite operators** (Doppler correction)

**Marketing:**
- Blog posts: "Building a macOS Ham Radio App in 30 Minutes"
- YouTube tutorials: SwiftUI integration demos
- Reddit r/amateurradio showcase
- QRZ.com forums presence
- Ham radio podcast interviews

**Example Apps to Build:**
1. SimpleBand - One-touch band changing
2. SSTVController - SSTV transmission manager
3. LoggerPro - Real-time logging with rig control
4. SatTracker - Satellite Doppler compensation

### Contribution (Months 3-12)

**Good First Issues:**
- Add radio model (same protocol)
- Update documentation examples
- Add unit tests for edge cases
- Improve error messages

**Mentorship:**
- Monthly contributor calls
- "Adopt a Protocol" program
- Documentation sprints
- Hacktoberfest participation

**Recognition:**
- Contributors hall of fame
- Release notes credits
- Swag for significant contributions

---

## Critical Recommendations

### Do Immediately (Week 1-2)

1. ✅ **Create v1.1.0 milestone** with S-meter as top priority
2. ✅ **Set up automated testing** (GitHub Actions)
3. ✅ **Create contributor guide video** (15 min)
4. ✅ **Open discussions forum** for feature requests
5. ✅ **Start Swift 6 compatibility testing**

### Do Soon (Month 1-3)

1. ✅ **Build example monitoring app** (showcase library)
2. ✅ **Write "Migrating from Hamlib" tutorial**
3. ✅ **Reach out to logging app developers**
4. ✅ **Create radio protocol test suite**
5. ✅ **Performance benchmarking framework**

### Don't Do (Anti-Patterns)

1. ❌ **Don't add features without protocol support across 3+ manufacturers**
2. ❌ **Don't break API in v1.x releases**
3. ❌ **Don't merge without tests**
4. ❌ **Don't optimize prematurely** (benchmark first)
5. ❌ **Don't add dependencies** (keep zero-dependency promise)

---

## Success Metrics

### v1.1.0 Launch (3 months)
- ✅ 50+ GitHub stars
- ✅ 5+ production apps using it
- ✅ 10+ contributors
- ✅ 30+ radio models supported
- ✅ <10ms cached query latency

### v1.2.0 Launch (6 months)
- ✅ 100+ GitHub stars
- ✅ 15+ production apps
- ✅ 25+ contributors
- ✅ Featured on SwiftUI showcase
- ✅ 500+ downloads/month

### v2.0.0 Launch (12 months)
- ✅ 200+ GitHub stars
- ✅ De facto macOS rig control standard
- ✅ 50+ contributors
- ✅ Conference talk at Ham Radio events
- ✅ Integration with major logging apps

---

## Conclusion

SwiftRigControl v1.0.0 is an **excellent foundation** with clean architecture and comprehensive documentation. The path forward is clear:

**Short-term (v1.1):** Add monitoring capabilities and performance optimizations to make it production-ready for logging/monitoring applications.

**Mid-term (v1.2):** Complete the feature set with memory operations and advanced control to support 90% of ham radio workflows.

**Long-term (v2.0):** Expand to network operation and ecosystem integration to become the definitive macOS amateur radio control library.

**Key Success Factor:** Maintain backward compatibility, zero dependencies, and excellent documentation while systematically adding high-value features based on real user needs.

The library is positioned to become the standard for macOS amateur radio applications if development follows this roadmap and community engagement stays strong.

**73 de VA3ZTF!** 📻

---

*Document Version: 1.0*
*Last Updated: November 19, 2025*
*Next Review: December 2025*
