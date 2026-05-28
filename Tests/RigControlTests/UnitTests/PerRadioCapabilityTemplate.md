# Per-radio capability test template

For each new radio added during the v1.2 parity push, add a
test pair to the appropriate vendor's test file (or create one
if it doesn't exist yet). The pattern mirrors the v1.1 work in
`V11RadioDefinitionsTests.swift`.

## Template

```swift
// MARK: - <Vendor> <Model>

@Test func <model>BasicCaps() {
    let caps = RadioCapabilitiesDatabase.<vendorModel>
    // Power
    #expect(caps.maxPower == <N>)
    // Frequency coverage — pick one transmit-band and one
    // out-of-band frequency from the Hamlib rx_range_list.
    #expect(caps.canTransmit(on: 14_230_000))   // 20m
    #expect(!caps.canTransmit(on: <out_of_band>))
    // v1.1 sets
    #expect(caps.supportedFunctions.contains(.compressor))
    #expect(caps.supportedVFOOperations.contains(.exchange))
    // Vendor-specific assertions
    // ...
}

@Test func <model>ConnectsViaMock() async throws {
    let rig = try RigController(
        radio: .<vendorModel>(),
        connection: .mock
    )
    try await rig.connect()
    #expect(await rig.radioName == "<Vendor> <Model>")
}
```

## When to write a full protocol test

The shared per-vendor protocol actor (`IcomCIVProtocol`,
`KenwoodProtocol`, `YaesuCATProtocol`, `ElecraftProtocol`)
already has comprehensive wire-byte tests in
`Tests/RigControlTests/ProtocolTests/<Vendor>ProtocolTests.swift`.
Every radio that uses the standard command set inherits that
coverage for free.

Write a dedicated `<Vendor><Model>ProtocolTests.swift` only when
the radio has quirks not covered by the shared protocol tests.
Examples:

- **IC-7100 / IC-705**: separate file because `requiresModeFilter
  = false` and command echo. Covered by command-set selection
  in the IC fixture.
- **IC-7600 / IC-9700 / IC-9100 / IC-705**: data-mode follow-up
  bytes (`IcomDataModeTests`).
- **IC-9700 / IC-705**: noise blanker BCD encoding
  (`IcomNoiseBlankerTests`).

For most new radios, the basic-caps + connects-via-mock pair is
sufficient — the wire bytes are exercised by the shared
protocol suite.

## Hamlib citation in test comments

Every test that asserts on wire bytes derived from Hamlib should
cite the source as `rigs/<vendor>/<file>.c:<line>` in a comment
above the test. Example:

```swift
/// Hamlib reference: rigs/icom/ic7600.c:153 (ic7600_priv_caps)
/// — civ_addr 0x7A, mainSub VFO model, data_mode_supported = 1.
/// Setting DATA-USB should emit:
///   1. 0x06 [USB=0x01, FIL1=0x01]
///   2. 0x1A 0x06 [data_flag=0x01, FIL1=0x01]
@Test func ic7600DataUSBSendsBaseUSBPlusDataModeSubcommand() async throws {
    // ...
}
```

This makes the test a living trace from Hamlib source to
SwiftRigControl wire bytes — exactly what we'll need when a
future hardware-validation run finds a discrepancy.
