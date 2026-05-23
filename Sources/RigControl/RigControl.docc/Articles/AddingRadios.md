# Adding a new radio

A condensed guide to adding a new radio definition to
SwiftRigControl. See the much longer `Documentation/ADDING_RADIOS.md`
in the repo for full step-by-step instructions.

## Decision tree

Before you write any code, decide which path applies:

1. **Same vendor protocol as an existing radio?** Most common
   case. You only need a new ``RadioDefinition`` entry — the
   protocol code is reused as-is. Adding e.g. a new Yaesu rig
   that speaks standard CAT means a five-line addition.
2. **Same vendor, different protocol quirks?** Add a new
   per-radio command set (Icom CI-V case — see
   `Sources/RigControl/Protocols/Icom/CommandSets/`).
3. **New vendor protocol entirely?** Implement a new
   ``CATProtocol`` conformer. Ten-Tec was the most recent
   example — see `Sources/RigControl/Protocols/TenTec/`.

## The standard recipe (case 1)

Pick a `Sources/RigControl/Models/RadioCapabilitiesDatabase+*.swift`
file matching the manufacturer, add a static
``RigCapabilities`` constant for the new radio, then add a
factory method (e.g., `.icomIC7910()`) in the corresponding
`Sources/RigControl/Protocols/<Vendor>/<Vendor>Models*.swift`
file.

A complete example, paraphrased from how IC-7600 is defined:

```swift
// In RadioCapabilitiesDatabase+IcomFlagships.swift
static let icomIC9999 = RigCapabilities(
    hasSplit: true,
    powerControl: true,
    maxPower: 200,
    supportedModes: [.lsb, .usb, .cw, .cwR, .am, .fm, .rtty, .rttyR,
                      .dataLSB, .dataUSB],
    frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
    requiresVFOSelection: true,
    requiresModeFilter: true,
    region: .region2,
    supportsRIT: true,
    supportsXIT: true
)

// In IcomModels+HF.swift (or wherever the model logically fits)
public static func icomIC9999(civAddress: UInt8? = nil) -> RadioDefinition {
    RadioDefinition(
        manufacturer: .icom,
        model: "IC-9999",
        defaultBaudRate: 115200,
        capabilities: RadioCapabilitiesDatabase.icomIC9999,
        civAddress: civAddress ?? 0xB0,
        // verificationStatus defaults to .definition — leave that
        // unless you're going to validate against real hardware
        // in this same commit.
        protocolFactory: { transport in
            IcomCIVProtocol(
                transport: transport,
                civAddress: civAddress,
                radioModel: .ic9999,  // add the enum case
                commandSet: StandardIcomCommandSet(civAddress: 0xB0),
                capabilities: RadioCapabilitiesDatabase.icomIC9999
            )
        }
    )
}
```

## The Hamlib cross-check

Before shipping, grep `~/Developer/hamlib/rigs/icom/` (or
`yaesu/`, `kenwood/`, etc.) for the radio's model name. If
Hamlib has it:

- Compare capability flags. Hamlib's `rig_caps` struct lists
  modes, levels, and quirks — your ``RigCapabilities`` should
  agree where the concepts map.
- Compare command-set deviations. If Hamlib's per-radio C file
  overrides standard CI-V/CAT behavior, document why and
  consider whether SwiftRigControl needs a custom command set.
- Note divergences in a code comment, with the Hamlib file and
  line as evidence.

The `CLAUDE.md` rule: *"matches `ic7600.c:842`" beats "Hamlib does
it this way"* — be specific about the source you cross-checked.

## Verification

Set ``RadioDefinition/VerificationStatus`` to `.hardware` **only**
after you've run a real validator against the real radio. See
<doc:VerificationStatus> for the exact criteria.

## Tests

Every new radio needs at minimum:

- One entry in the appropriate
  `Tests/RigControlTests/UnitTests/RadioCapabilitiesTests.swift`
  case (verifies the static `RigCapabilities` is sane).
- If you implemented a new command set: a protocol test in
  `Tests/RigControlTests/ProtocolTests/` against
  ``MockSerialTransport`` verifying the byte format on the wire.

If you're promoting to `.hardware`-verified: add an entry in
`Tools/SwiftRigControlTools/HardwareValidation/` matching the
existing validators.

## Related

- ``RadioDefinition``
- ``RigCapabilities``
- <doc:VerificationStatus>
- See `Documentation/ADDING_RADIOS.md` in the repo for the full
  walkthrough.
