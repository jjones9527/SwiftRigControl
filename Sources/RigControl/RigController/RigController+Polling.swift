import Foundation

// MARK: - Polled state broadcaster

extension RigController {

    /// Configuration for the periodic poller (Phase 2.2).
    ///
    /// Each field is an interval in seconds, or `nil` to disable
    /// polling for that field. Sensible defaults are tuned for a
    /// typical SwiftUI radio-control UI:
    ///
    /// | Field           | Default | Rationale |
    /// | --------------- | ------- | --------- |
    /// | signalStrength  | 200 ms  | S-meter renders smoothly at 5 Hz |
    /// | frequency       | 1 s     | Catches front-panel knob turns without flooding |
    /// | mode            | 2 s     | Modes change rarely; this catches the click |
    /// | ptt             | 100 ms  | Catches front-panel mic PTT promptly |
    ///
    /// Apps that only care about one or two fields can leave the rest
    /// as `nil`. Apps that want a "single rate for everything" can
    /// use ``PollingConfiguration/uniform(every:)``.
    ///
    /// ## Emission policy
    ///
    /// - **`signalStrength`** emits every poll — it's monitoring data,
    ///   and every sample is meaningful (S-meter movement).
    /// - **`frequency`**, **`mode`**, **`ptt`** emit only when the
    ///   value actually changes. The poller compares against the
    ///   previous reading and stays quiet otherwise.
    public struct PollingConfiguration: Sendable {
        /// Poll the S-meter at this interval (seconds). `nil` disables.
        /// `signalStrength` is the one field that emits on every poll —
        /// other fields emit only when the value changes.
        public var signalStrength: TimeInterval?

        /// Poll frequency on every active VFO at this interval
        /// (seconds). `nil` disables. Emits only on change.
        public var frequency: TimeInterval?

        /// Poll mode on every active VFO at this interval (seconds).
        /// `nil` disables. Emits only on change.
        public var mode: TimeInterval?

        /// Poll PTT at this interval (seconds). `nil` disables.
        /// Catches front-panel mic PTT that bypasses
        /// ``RigController/setPTT(_:)``. Emits only on change.
        public var ptt: TimeInterval?

        /// Creates a polling configuration with per-field intervals.
        /// All parameters default to sensible "UI control panel"
        /// values; pass `nil` for any field you don't want to poll.
        public init(
            signalStrength: TimeInterval? = 0.2,
            frequency: TimeInterval? = 1.0,
            mode: TimeInterval? = 2.0,
            ptt: TimeInterval? = 0.1
        ) {
            self.signalStrength = signalStrength
            self.frequency = frequency
            self.mode = mode
            self.ptt = ptt
        }

        /// All fields polled at the same interval. Convenience for
        /// "I want a single rate for everything."
        public static func uniform(every interval: TimeInterval) -> PollingConfiguration {
            PollingConfiguration(
                signalStrength: interval,
                frequency: interval,
                mode: interval,
                ptt: interval
            )
        }

        /// All polling disabled. Use to ``RigController/stopPolling()``
        /// in a single call.
        public static let disabled = PollingConfiguration(
            signalStrength: nil,
            frequency: nil,
            mode: nil,
            ptt: nil
        )
    }

    /// Starts (or restarts) the per-field polling tasks.
    ///
    /// Polling read-only state that the radio does not push gives
    /// SwiftUI apps reactive updates for front-panel changes,
    /// S-meter movement, and similar. Each enabled field gets its
    /// own `Task` that loops with the configured interval; results
    /// fan out through the same ``events`` stream as setter-driven
    /// changes, so consumer code doesn't have to distinguish source.
    ///
    /// Calling this while polling is already active stops the
    /// previous batch first. `disconnect()` stops polling
    /// automatically — there's no point polling a closed transport.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Default cadence (good for most UIs)
    /// await rig.startPolling()
    ///
    /// // Only watch the S-meter, faster
    /// await rig.startPolling(.init(signalStrength: 0.1,
    ///                              frequency: nil,
    ///                              mode: nil,
    ///                              ptt: nil))
    /// ```
    public func startPolling(_ config: PollingConfiguration = .init()) {
        stopPollingInternal()

        if let interval = config.signalStrength {
            pollingTasks["signalStrength"] = makePollTask(
                interval: interval,
                tick: { try await self.pollSignalStrength() }
            )
        }
        if let interval = config.frequency {
            pollingTasks["frequency"] = makePollTask(
                interval: interval,
                tick: { try await self.pollFrequency() }
            )
        }
        if let interval = config.mode {
            pollingTasks["mode"] = makePollTask(
                interval: interval,
                tick: { try await self.pollMode() }
            )
        }
        if let interval = config.ptt {
            pollingTasks["ptt"] = makePollTask(
                interval: interval,
                tick: { try await self.pollPTT() }
            )
        }
    }

    /// Stops all polling tasks. Idempotent — calling when nothing is
    /// polling is a no-op.
    public func stopPolling() {
        stopPollingInternal()
    }

    /// True when at least one polling task is active. Useful for
    /// "Live updates" toggles in UI.
    public var isPolling: Bool {
        !pollingTasks.isEmpty
    }

    // MARK: - Internal plumbing

    /// Constructs a poll task that wakes on `interval`, calls
    /// `tick`, and silently retries on error. The task exits on
    /// cancellation. Errors are swallowed deliberately — a single
    /// failed poll cycle (timeout, malformed response) should not
    /// kill the poller. Phase 2.3 layers a connection-health
    /// monitor on top that escalates persistent failure into a
    /// `.degraded` connection-state transition.
    internal func makePollTask(
        interval: TimeInterval,
        tick: @Sendable @escaping () async throws -> Void
    ) -> Task<Void, Never> {
        Task {
            let nanos = UInt64(interval * 1_000_000_000)
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: nanos)
                } catch {
                    return  // Cancellation surfaces as a sleep error.
                }
                do {
                    try await tick()
                } catch {
                    // Swallow — see comment above.
                }
            }
        }
    }

    /// Cancels and clears every polling task. Safe to call from
    /// either polling control or `disconnect()`.
    internal func stopPollingInternal() {
        for task in pollingTasks.values {
            task.cancel()
        }
        pollingTasks.removeAll()
    }

    // MARK: - Per-field poll implementations

    /// Sample the S-meter and always emit. Continuous monitoring
    /// data — every sample is meaningful.
    private func pollSignalStrength() async throws {
        let signal = try await proto.getSignalStrength()
        await stateCache.store(signal, forKey: "signal_strength")
        emit(.signalStrengthChanged(signal))
    }

    /// Sample frequency for every VFO supported by the radio.
    /// Emit only when the value differs from the previous sample.
    private func pollFrequency() async throws {
        let vfos: [VFO] = radio.capabilities.hasDualReceiver ? [.main, .sub] : [.a]
        for vfo in vfos {
            let hz = try await proto.getFrequency(vfo: vfo)
            let key = "freq_\(vfo)"
            let previous: UInt64? = await stateCache.getIfValid(key, maxAge: .greatestFiniteMagnitude)
            if previous != hz {
                await stateCache.store(hz, forKey: key)
                emit(.frequencyChanged(vfo: vfo, hz: hz))
            }
        }
    }

    /// Sample mode for every VFO supported by the radio. Emit
    /// only on change.
    private func pollMode() async throws {
        let vfos: [VFO] = radio.capabilities.hasDualReceiver ? [.main, .sub] : [.a]
        for vfo in vfos {
            let mode = try await proto.getMode(vfo: vfo)
            let key = "mode_\(vfo)"
            let previous: Mode? = await stateCache.getIfValid(key, maxAge: .greatestFiniteMagnitude)
            if previous != mode {
                await stateCache.store(mode, forKey: key)
                emit(.modeChanged(vfo: vfo, mode: mode))
            }
        }
    }

    /// Sample PTT and emit only on change. The interesting case is
    /// the operator pressing the front-panel mic PTT — that doesn't
    /// trigger any setter and is otherwise invisible to the app.
    private func pollPTT() async throws {
        let enabled = try await proto.getPTT()
        let previous: Bool? = await stateCache.getIfValid("ptt", maxAge: .greatestFiniteMagnitude)
        if previous != enabled {
            await stateCache.store(enabled, forKey: "ptt")
            emit(.pttChanged(enabled: enabled))
        }
    }
}
