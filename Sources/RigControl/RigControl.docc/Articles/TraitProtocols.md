# Capability traits and vendor dispatch

How SwiftRigControl uses Swift's type system to make per-radio
capabilities checkable, the compiler do the gating, and stringly-
typed casting unnecessary.

## Overview

SwiftRigControl's architecture rests on two complementary Swift
features for per-radio capability:

- **Capability trait protocols** (`Supports*`) — each radio's
  ``CATProtocol`` conformer opts into the features it actually
  supports. The conformance list *is* the contract.
- **Discriminated vendor extensions** —
  ``RigController/vendorExtensions`` returns a typed enum
  carrying the concrete protocol actor for the radio's vendor,
  no `as?` cast required.

If you've used Hamlib's `rig_caps` capability bits to gate
features at runtime, this is the Swift-native equivalent that
moves the gating into the type system.

## Capability trait protocols

Every vendor protocol actor declares its capabilities by
conforming to the matching trait protocol:

```swift
public actor IcomCIVProtocol:
    CATProtocol,
    SupportsPower,
    SupportsSplit,
    SupportsSignalStrength,
    SupportsRIT,
    SupportsXIT,
    // … 20+ more traits …
    SupportsVFOOperations,
    SupportsFunctions,
    SupportsMicGain,
    SupportsCompressorLevel,
    SupportsMonitorGain,
    SupportsVOXGain,
    SupportsVOXDelay,
    SupportsIFShift
{ … }
```

When a caller invokes ``RigController/setMicGain(_:)``, the
controller dispatches via ``RigController`` → `requireTrait` →
`as? any SupportsMicGain`. If the radio's protocol doesn't
conform, the cast fails and `requireTrait` throws
``RigError/unsupportedOperation(_:)``. No silent no-ops; no
stringly-typed checks at the call site.

### When to use a trait

- **The radio fundamentally either supports the feature or
  doesn't**, in a way that doesn't vary per-instance — that's a
  conformance. (Some HF radios don't have an internal ATU; those
  don't conform to a hypothetical `SupportsInternalTuner`.)
- **The radio supports the feature on some instances and not
  others** (e.g. an optional KAT-2 tuner on a Kenwood K2) —
  that's a runtime `RigCapabilities` flag, not a trait. The
  trait is "this protocol can speak the wire command at all";
  the flag is "did the user actually buy the option."

In practice both layers usually have to agree. Calling
``RigController/selectAntenna(_:)`` checks `capabilities.antennaCount > 1`
*and* requires the underlying actor to conform to
``SupportsAntenna``.

## Vendor extensions (discriminated enum dispatch)

When you need vendor-specific behavior beyond the standard
``RigController`` surface, use
``RigController/vendorExtensions``. This returns a typed
``VendorExtensions`` enum that carries the concrete actor for
the radio's vendor:

```swift
switch await rig.vendorExtensions {
case .icom(let icom):
    try await icom.setAttenuatorIC9700(.dB12)
case .elecraft(let k):
    try await k.getTXStatus()
case .yaesu, .kenwood, .thd72, .tentecOrion, .tentecLegacy, .dummy, .unknown:
    break  // not applicable to this radio
}
```

The compiler enforces exhaustiveness — if we add a new vendor
protocol to the enum, every existing call site sees a build
error until they handle the new case (or explicitly opt out via
`default:`). That's the kind of forward-compatibility guard
that's hard to retrofit later.

### vs. the `rawProtocol` escape hatch

``RigController/rawProtocol`` returns the underlying
`any CATProtocol` — the type-erased actor — for cases the typed
vendor-extension enum doesn't cover. Use it for:

- Hardware validators that touch every per-model method.
- Custom simulators or test fixtures.
- Debugging or one-off scripts.

Anything reached through `rawProtocol` is **unversioned** — the
surface may change between SwiftRigControl releases without a
deprecation cycle. Prefer ``RigController/vendorExtensions`` for
production code.

## Adding a new trait

If you're contributing a new feature trait (say,
`SupportsTuningStep`):

1. Add the protocol in `Sources/RigControl/Core/CATProtocolTraits.swift`
   following the `Supports<Feature>` naming convention.
2. Add the protocol requirements (`func setTuningStep(_ ts: Double) async throws`,
   etc.).
3. For each existing vendor actor that supports the feature, add
   the conformance and implement the methods.
4. Add a per-feature accessor on ``RigController`` that calls
   `requireTrait((any SupportsTuningStep).self, named: "Tuning step")`
   and forwards.
5. If the feature has per-instance per-radio variants (some K3s
   have it, some don't), add a flag to
   ``RigCapabilities`` and check it before dispatching.

See `RigController+Functions.swift` and
`RigController+SecondaryLevels.swift` for canonical examples.

## Topics

### Architecture API

- ``RigController/vendorExtensions``
- ``VendorExtensions``
- ``RigController/rawProtocol``
- ``RigCapabilities``

### The full trait inventory

The complete `Supports*` trait list is on the main
<doc:RigControl> landing page.
