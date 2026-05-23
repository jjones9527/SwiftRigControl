import Foundation

extension RigController {

    /// A push-style stream of radio state changes.
    ///
    /// Each call returns a *fresh* `AsyncStream` whose continuation
    /// is registered with the controller. The controller fans every
    /// emission out to every active subscriber, so two SwiftUI views
    /// can both `for await event in rig.events` without one starving
    /// the other.
    ///
    /// ## Cancellation
    ///
    /// When the consuming task is cancelled (e.g. the SwiftUI view
    /// disappears), the stream's `onTermination` handler fires and
    /// the continuation is removed from the broadcast list. Inactive
    /// subscribers cost nothing.
    ///
    /// ## Buffering
    ///
    /// Each per-subscriber stream uses a `.bufferingNewest(64)`
    /// policy. Slow consumers see the most recent events and drop
    /// older ones, so a hung UI cannot grow the controller's
    /// memory without bound. 64 is enough headroom for normal UI
    /// pacing while still being a hard cap; if you need every
    /// intermediate value (logging, recording), poll in a tight
    /// `Task` instead.
    ///
    /// ## Registration is asynchronous
    ///
    /// Accessing `events` is `nonisolated` so it can be called from
    /// any context, but the underlying subscriber registration runs
    /// in a detached `Task` to hop onto the actor. In practice this
    /// means a few hundred microseconds of lag before the new
    /// subscriber is wired up. Code that subscribes and then
    /// immediately triggers an emission may miss the first event.
    /// The recommended pattern is to subscribe in `init` (or `task`
    /// modifier in SwiftUI) and let the runtime settle naturally.
    ///
    /// ## Example
    ///
    /// ```swift
    /// Task {
    ///     for await event in rig.events {
    ///         switch event {
    ///         case .frequencyChanged(let vfo, let hz):
    ///             print("VFO \(vfo) → \(hz) Hz")
    ///         default:
    ///             break
    ///         }
    ///     }
    /// }
    /// ```
    public nonisolated var events: AsyncStream<RigStateEvent> {
        AsyncStream(bufferingPolicy: .bufferingNewest(64)) { continuation in
            let id = UUID()
            Task {
                await self.registerEventContinuation(continuation, id: id)
            }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.removeEventContinuation(id: id)
                }
            }
        }
    }

    /// Internal: register a subscriber's continuation. Called once
    /// per `events` access from a detached `Task` to bridge the
    /// `nonisolated` accessor onto the actor.
    internal func registerEventContinuation(
        _ continuation: AsyncStream<RigStateEvent>.Continuation,
        id: UUID
    ) {
        eventSubscribers[id] = continuation
        // Replay the current connection state to the new subscriber
        // so a view that subscribes after `connect()` still sees
        // the right initial state. This matters for SwiftUI views
        // that subscribe lazily on appear.
        continuation.yield(.connectionStateChanged(connectionState))
    }

    /// Internal: drop a subscriber's continuation on cancellation.
    internal func removeEventContinuation(id: UUID) {
        eventSubscribers.removeValue(forKey: id)
    }

    /// Internal: fan an event out to every active subscriber.
    /// Called from every `set*` path after the underlying protocol
    /// acknowledges the change.
    internal func emit(_ event: RigStateEvent) {
        for continuation in eventSubscribers.values {
            continuation.yield(event)
        }
    }

    /// Internal: update connection state and emit the corresponding
    /// event. Use this anywhere the lifecycle transitions —
    /// `connect()`, `disconnect()`, the future health monitor, and
    /// the future auto-reconnect path.
    internal func transition(to newState: ConnectionState) {
        guard newState != connectionState else { return }
        connectionState = newState
        emit(.connectionStateChanged(newState))
    }
}
