# Verification status

Understand which radios SwiftRigControl has actually exercised
against real hardware versus which are paper-only definitions.

## Overview

SwiftRigControl ships **~80 radio definitions** across six
manufacturers, but only a handful have been validated against
the corresponding real transceiver. The library is honest about
this distinction — apps built on top can surface it to users.

## The categories

Every ``RadioDefinition`` carries a
``RadioDefinition/VerificationStatus``:

- **`.hardware`** — exercised against the real radio via the
  matching validator in
  `Tools/SwiftRigControlTools/HardwareValidation/`. Frequency,
  mode, PTT, and at least one read-back operation are confirmed
  working.
- **`.definition`** — protocol, capabilities, and command set
  are implemented (typically cross-referenced against the
  manufacturer manual and Hamlib source), but no real-radio
  verification has been performed. May work; not proven.

Reading the field at runtime:

```swift
let rig = try RigController(
    radio: .icomIC7300(),
    connection: .serial(path: "/dev/cu.IC7300", baudRate: 115200)
)

switch rig.verificationStatus {
case .hardware:
    // Confident this radio works.
case .definition:
    // Inform the operator: "Beta — please report issues."
}
```

The ``RadioDefinition/VerificationStatus/displayName`` property
returns a UI-friendly string ("Hardware verified" or "Definition
only").

## Currently `.hardware` verified

| Radio | Validator |
| --- | --- |
| Icom IC-7100 | `Tools/SwiftRigControlTools/HardwareValidation/IC7100Validator` |
| Icom IC-7600 | `Tools/SwiftRigControlTools/HardwareValidation/IC7600Validator` |
| Icom IC-9700 | `Tools/SwiftRigControlTools/HardwareValidation/IC9700Validator` |
| Elecraft K2  | `Tools/SwiftRigControlTools/HardwareValidation/K2Validator` |

Every other shipped definition is `.definition`.

## Promotion criteria

A definition becomes `.hardware` only when:

1. A validator in `Tools/SwiftRigControlTools/HardwareValidation/`
   exists and exercises at least frequency, mode, PTT, and one
   read-back operation.
2. The validator has been run successfully against the real radio
   by a project maintainer.
3. The validator's results are captured in commit history.

This conservative rule prevents the verification claim from
drifting. Code that *looks like it should work* and code that
*has worked on real hardware* are very different things to a
user trying to debug a flaky setup.

## What `.definition` actually means

Definition-only radios:

- Have a complete ``CATProtocol`` implementation (usually shared
  with a closely related model that *is* verified — e.g., every
  Icom HF radio shares ``IcomCIVProtocol`` with the IC-7600).
- Have a populated ``RigCapabilities`` derived from the
  manufacturer's manual and cross-referenced against Hamlib's
  per-radio C file.
- Have been audited for correctness as far as static analysis
  goes (CI-V addresses, baud rates, supported modes).
- Have *not* been on a bench with a real radio attached.

In practice they often work, but the failure mode of "I bought
this radio and SwiftRigControl says it's supported but nothing
works" damages user trust. Hence the honest label.

## If a definition-only radio works for you

Please open an issue or PR. We need: model, serial port path
used, baud rate, and which operations you confirmed (at minimum:
frequency read/write, mode read/write, PTT toggle). Once a
project maintainer can either reproduce the test or accept your
word, we'll either commit a validator or — for radios we can't
get our hands on — at least update the status from `.definition`
to a new `.communityVerified` category (not yet defined; we'll
add it on first use).

## Related

- ``RadioDefinition``
- ``RadioDefinition/VerificationStatus``
- ``RigController/verificationStatus``
