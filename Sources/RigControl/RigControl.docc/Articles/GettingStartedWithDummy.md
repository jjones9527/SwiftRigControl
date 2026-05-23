# Getting started without hardware

Build, preview, and demo SwiftRigControl-backed apps with no
radio attached.

## Overview

SwiftRigControl ships an in-memory **dummy radio** — the Swift
analogue of [Hamlib](https://hamlib.github.io/)'s Model 1
("Dummy") rig. It implements the full ``CATProtocol`` API but
holds state in memory instead of talking to a serial port, so
you can write your app's UI, view models, and integration tests
without owning (or being plugged into) a real transceiver.

This article walks through the pattern.

## When to use the dummy

| Use case | Use the dummy? |
| --- | --- |
| SwiftUI `#Preview` blocks | Yes |
| Demo apps shipped to App Store reviewers | Yes |
| Tutorials, screencasts, README snippets | Yes |
| Integration tests of app-side code | Yes |
| Testing your own protocol implementation | No — use ``MockSerialTransport`` |
| Reproducing radio quirks (NAKs, weird timing) | No — use ``MockSerialTransport`` |

The dummy is a "compliant" radio: it accepts any frequency, mode,
and control value within its capabilities, and never throws
mid-session. Real radios reject more than that — if you need to
test those failure paths, drive the real ``CATProtocol``
implementation against a scripted ``MockSerialTransport`` instead.

## The shortest possible example

```swift
import RigControl

let rig = try RigController(
    radio: .dummy(),
    connection: .mock
)

try await rig.connect()
try await rig.setFrequency(14_230_000, vfo: .a)
try await rig.setMode(.usb, vfo: .a)

let f = try await rig.frequency()   // 14_230_000
let m = try await rig.mode()        // .usb
```

No serial port. No hardware. No XPC helper. The dummy participates
in the standard ``RigController`` lifecycle exactly like a real
radio.

## Custom capabilities

The default ``RadioDefinition/dummy(name:capabilities:)`` ships a
generic full-featured HF rig. Override capabilities to simulate
something more specific — a VHF/UHF FM mobile, a QRP HF rig, a
receive-only radio:

```swift
let vhfFM = RigCapabilities(
    hasSplit: false,
    maxPower: 50,
    supportedModes: [.fm, .fmN],
    frequencyRange: FrequencyRange(min: 144_000_000, max: 148_000_000),
    hasATU: false,
    requiresVFOSelection: false,
    supportsRIT: false,
    supportsXIT: false,
    supportsCTCSS: true,
    supportsDuplex: true
)
let rig = try RigController(
    radio: .dummy(name: "2m FM Mobile", capabilities: vhfFM),
    connection: .mock
)
```

Capability flags are enforced. Setting an out-of-range frequency
or unsupported mode throws ``RigError`` — exactly as the real
radio would. This means your app's error-handling code gets
exercised under the dummy too.

## The recommended SwiftUI pattern

Don't make views talk to ``RigController`` directly. Instead,
build a `@MainActor` `@Observable` view model that subscribes
to ``RigController/events`` and republishes the relevant state:

```swift
import RigControl
import SwiftUI

@Observable @MainActor
final class RadioViewModel {
    var frequency: UInt64 = 0
    var mode: Mode = .usb
    var transmitting: Bool = false
    var connectionState: ConnectionState = .disconnected

    private let rig: RigController
    private var eventTask: Task<Void, Never>?

    init(rig: RigController) {
        self.rig = rig
        self.eventTask = Task { [weak self] in
            for await event in rig.events {
                guard let self else { return }
                switch event {
                case .frequencyChanged(_, let hz):
                    self.frequency = hz
                case .modeChanged(_, let mode):
                    self.mode = mode
                case .pttChanged(let on):
                    self.transmitting = on
                case .connectionStateChanged(let state):
                    self.connectionState = state
                default:
                    break
                }
            }
        }
    }

    deinit { eventTask?.cancel() }

    func setFrequency(_ hz: UInt64) async {
        try? await rig.setFrequency(hz, vfo: .a)
    }
}
```

Now wire the dummy into a preview:

```swift
extension RadioViewModel {
    static var preview: RadioViewModel {
        let rig = try! RigController(radio: .dummy(), connection: .mock)
        Task { try? await rig.connect() }
        return RadioViewModel(rig: rig)
    }
}

#Preview {
    RadioControlView(viewModel: .preview)
}
```

The preview works in Xcode with no hardware, no entitlements, no
permissions. Switching to a real radio means swapping the
``RadioDefinition`` and ``ConnectionType``; the view model and
view don't change.

For the full event-stream story, see <doc:ReactiveState>.

## Related

- ``RadioDefinition/dummy(name:capabilities:)``
- ``DummyCATProtocol``
- ``ConnectionType``
- <doc:ReactiveState>
