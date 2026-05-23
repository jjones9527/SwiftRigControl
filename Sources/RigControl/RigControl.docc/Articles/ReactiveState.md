# Reactive state and the events stream

Drive SwiftUI from `RigController.events` — push, poll, and
connection-health updates all flow through one `AsyncStream`.

## Overview

``RigController/events`` is an `AsyncStream<RigStateEvent>` that
fires whenever the radio's state changes. SwiftUI apps consume
it like any other async sequence; there is no polling loop in
your code.

Three independent sources feed the stream:

1. **Setter emissions.** Every successful `set*` call on
   ``RigController`` emits a corresponding ``RigStateEvent``
   after the radio acknowledges the change.
2. **Polled state** (opt-in via ``RigController/startPolling(_:)``).
   Sampled fields the radio doesn't push — S-meter, front-panel
   knob, mic PTT — emit on configurable cadences.
3. **Connection health** (opt-in via
   ``RigController/startHealthMonitor(_:)``). Heartbeat-driven
   transitions through ``ConnectionState`` cases, including
   optional auto-reconnect.

Consumers don't have to distinguish source. A `.frequencyChanged`
event looks identical whether it came from `setFrequency` you
just called, the poller catching a front-panel knob turn, or
the radio echoing back a value over CI-V transceive.

## The basic shape

```swift
Task {
    for await event in rig.events {
        switch event {
        case .frequencyChanged(let vfo, let hz):
            print("VFO \(vfo) → \(hz) Hz")
        case .pttChanged(let on):
            print("PTT \(on ? "ON" : "OFF")")
        case .connectionStateChanged(let state):
            print("Connection: \(state)")
        default:
            break
        }
    }
}
```

Each call to `rig.events` returns a **fresh stream**. Two
SwiftUI views observing the same controller don't starve each
other — the controller fans every emission out to every active
subscriber.

## Emission policy

| Source | When it emits |
| --- | --- |
| Setters (`setFrequency`, `setMode`, `setPTT`, etc.) | After the radio ACKs. Failed writes do *not* emit. |
| `connect()` / `disconnect()` | On every state transition (.connecting, .connected, .disconnected). |
| Polled signal strength | Every poll (continuous monitoring data). |
| Polled frequency / mode / PTT | Only when the value differs from the previous sample. |
| Health monitor | On every ``ConnectionState`` transition. |

The library does *not* deduplicate setter emissions. Setting the
frequency to the value it already holds still produces a
`.frequencyChanged` event. This matches Hamlib's transceive
model — the radio doesn't know whether the value already
matched, and app-side dedupe is trivial if you need it.

## Buffering and subscriber lifecycle

Each per-subscriber stream uses a `.bufferingNewest(64)` policy.
Slow consumers see the most recent events and drop older ones,
so a hung UI cannot grow the controller's memory without bound.
64 is enough headroom for normal UI pacing while still being a
hard cap.

Subscribers auto-deregister on cancellation via the stream's
`onTermination` handler — when a SwiftUI view disappears and
its `Task` is cancelled, its continuation is removed from the
broadcast list. Inactive subscribers cost nothing.

When a new subscriber arrives mid-session, the controller
immediately yields a replay of the current ``ConnectionState``,
so a view that subscribes after `connect()` still sees the right
initial state. Other state (frequency, mode, etc.) is not
replayed — query it directly on the controller if you need an
initial value.

## Adding polling

Some state never reaches the app through a setter — the operator
turns the VFO knob, presses the front-panel mic PTT, signal
strength fluctuates with band conditions. The opt-in poller
samples these on a configurable cadence and emits to the same
stream:

```swift
await rig.startPolling()  // sensible defaults for UI rendering

// Per-field tuning:
await rig.startPolling(.init(
    signalStrength: 0.1,  // 100 ms = 10 Hz S-meter
    frequency: 0.5,
    mode: 2.0,
    ptt: 0.1
))

await rig.stopPolling()
```

Defaults: 200 ms S-meter, 1 s frequency, 2 s mode, 100 ms PTT.
``RigController/disconnect()`` stops polling automatically.

For full configuration options see
``RigController/PollingConfiguration``.

## Adding connection-health monitoring

Long-running sessions outlive cables and USB drivers.
``RigController/startHealthMonitor(_:)`` runs a periodic
heartbeat probe and emits ``ConnectionState`` transitions when
things go wrong — optionally with automatic reconnect:

```swift
// Heartbeat only — surfaces .degraded on the stream when the
// radio stops responding, .connected when it answers again.
await rig.startHealthMonitor()

// Or with auto-reconnect, exponential backoff, retries forever:
await rig.startHealthMonitor(.init(
    heartbeatInterval: 5,
    degradeAfter: 3,
    retryPolicy: RigController.RetryPolicy()
))
```

The state machine:

```
.connected
  ── (N heartbeat failures) ──→ .degraded(reason:)
                                  │
                                  ├── (heartbeat recovers) ──→ .connected
                                  │
                                  └── (retryPolicy set) ──→
                                      .reconnecting(attempt: 1)
                                      .reconnecting(attempt: 2)
                                      ...
                                      ├── success ──→ .connected
                                      └── maxAttempts ──→ .disconnected
```

UI can render a "Reconnecting…" banner by matching
``ConnectionState/reconnecting(attempt:)`` cases. See
``RigController/HealthMonitorConfiguration`` and
``RigController/RetryPolicy`` for tuning.

## A complete SwiftUI view model

```swift
import RigControl
import SwiftUI

@Observable @MainActor
final class RadioViewModel {
    var frequency: UInt64 = 0
    var mode: Mode = .usb
    var transmitting: Bool = false
    var signal: SignalStrength?
    var connectionState: ConnectionState = .disconnected

    private let rig: RigController
    private var eventTask: Task<Void, Never>?

    init(rig: RigController) {
        self.rig = rig
        self.eventTask = Task { [weak self] in
            for await event in rig.events {
                guard let self else { return }
                switch event {
                case .frequencyChanged(_, let hz):       self.frequency = hz
                case .modeChanged(_, let mode):          self.mode = mode
                case .pttChanged(let on):                self.transmitting = on
                case .signalStrengthChanged(let s):      self.signal = s
                case .connectionStateChanged(let state): self.connectionState = state
                default:                                 break
                }
            }
        }
        Task { [rig] in
            try? await rig.connect()
            await rig.startPolling()
            await rig.startHealthMonitor(.init(
                retryPolicy: RigController.RetryPolicy()
            ))
        }
    }

    deinit { eventTask?.cancel() }

    func setFrequency(_ hz: UInt64) async { try? await rig.setFrequency(hz, vfo: .a) }
    func setMode(_ m: Mode) async         { try? await rig.setMode(m, vfo: .a) }
    func toggle()             async       { try? await rig.setPTT(!transmitting) }
}
```

Zero polling loops in user code. Zero callback chains. Zero
connection-health timer management. SwiftUI just observes.

## Hamlib comparison

Hamlib offers per-event C callbacks
(`rig_set_freq_callback`, etc.) tied to radios that support
transceive mode. SwiftRigControl unifies push, poll, and
connection-health into a single discriminated event stream that
works for every radio — including the dummy — and integrates
naturally with Swift 6 / SwiftUI.

## Related

- ``RigStateEvent``
- ``ConnectionState``
- ``RigController/events``
- ``RigController/PollingConfiguration``
- ``RigController/HealthMonitorConfiguration``
- ``RigController/RetryPolicy``
- <doc:GettingStartedWithDummy>
