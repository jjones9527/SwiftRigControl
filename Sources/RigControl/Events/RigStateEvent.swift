import Foundation

/// A radio state change observed by a `RigController`.
///
/// `RigStateEvent` is the single payload type delivered through
/// ``RigController/events``, the library's push-style state stream.
/// SwiftUI apps consume it like any `AsyncSequence`:
///
/// ```swift
/// for await event in rig.events {
///     switch event {
///     case .frequencyChanged(let vfo, let hz):
///         viewModel.frequency[vfo] = hz
///     case .modeChanged(let vfo, let mode):
///         viewModel.mode[vfo] = mode
///     case .pttChanged(let on):
///         viewModel.transmitting = on
///     default:
///         break
///     }
/// }
/// ```
///
/// ## Emission policy
///
/// Events fire after a successful `set*` call on `RigController`,
/// after the radio acknowledges the write. The library does NOT
/// deduplicate — setting the frequency to the value it already
/// holds still produces a `.frequencyChanged` event. App code can
/// dedupe trivially if needed; the library does not, so behavior
/// matches Hamlib's transceive model (the radio doesn't know
/// whether the value already matched).
///
/// In Phase 2.2 / 2.3, the same enum carries polling-driven and
/// connection-health events. Apps reading the stream don't have to
/// distinguish where an event came from.
public enum RigStateEvent: Sendable, Equatable {
    /// The frequency of a VFO changed.
    case frequencyChanged(vfo: VFO, hz: UInt64)

    /// The mode of a VFO changed.
    case modeChanged(vfo: VFO, mode: Mode)

    /// PTT was toggled on or off.
    case pttChanged(enabled: Bool)

    /// The active VFO was changed.
    case vfoSelected(VFO)

    /// Transmit power level changed.
    case powerChanged(Int)

    /// Split operation was toggled.
    case splitChanged(enabled: Bool)

    /// RIT state changed.
    case ritChanged(RITXITState)

    /// XIT state changed.
    case xitChanged(RITXITState)

    /// Signal strength was sampled.
    ///
    /// Emitted by the polling broadcaster (Phase 2.2), not by
    /// `setSignalStrength` — there is no such setter.
    case signalStrengthChanged(SignalStrength)

    /// AGC speed changed.
    case agcChanged(AGCSpeed)

    /// Noise blanker configuration changed.
    case noiseBlankerChanged(NoiseBlanker)

    /// Noise reduction configuration changed.
    case noiseReductionChanged(NoiseReduction)

    /// IF filter selection changed.
    case ifFilterChanged(IFFilter)

    /// A level control (AF gain, RF gain, squelch, preamp,
    /// attenuator) changed.
    case levelChanged(kind: LevelKind, value: Int)

    /// Radio power state (standby / on) changed.
    case powerStateChanged(on: Bool)

    /// The radio's connection lifecycle transitioned. See
    /// ``ConnectionState`` for the meaning of each case.
    case connectionStateChanged(ConnectionState)

    /// Identifier for `RigStateEvent.levelChanged` so consumers can
    /// route a single event variant by which control changed,
    /// rather than carrying a dedicated case per level.
    public enum LevelKind: String, Sendable, Equatable {
        case afGain
        case rfGain
        case squelch
        case preamp
        case attenuator
    }
}

/// Lifecycle state of a `RigController`'s underlying transport.
///
/// Emitted as ``RigStateEvent/connectionStateChanged(_:)``. The
/// `.degraded` and `.reconnecting` cases are populated by the
/// connection-health monitor (Phase 2.3); without that monitor
/// running, the only observable transitions are
/// `.disconnected ↔ .connecting ↔ .connected`.
public enum ConnectionState: Sendable, Equatable {
    /// No active connection. The initial state.
    case disconnected

    /// `connect()` is in progress.
    case connecting

    /// `connect()` succeeded and the radio is responsive.
    case connected

    /// Connection appears alive but recent operations have failed
    /// or timed out. Carries a short reason string for logging.
    /// Set by the connection-health monitor.
    case degraded(reason: String)

    /// The auto-reconnect logic is trying to restore a lost
    /// connection. `attempt` is 1-based.
    case reconnecting(attempt: Int)
}
