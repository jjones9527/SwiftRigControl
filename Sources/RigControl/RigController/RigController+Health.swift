import Foundation

// MARK: - Connection health monitor (Phase 2.3)

extension RigController {

    /// Configuration for the connection-health monitor.
    ///
    /// The monitor periodically probes the radio (a cheap
    /// `getFrequency` read) and tracks consecutive failures. After
    /// ``degradeAfter`` consecutive failures the connection is
    /// marked `.degraded(reason:)`. A subsequent successful probe
    /// transitions back to `.connected`.
    ///
    /// If ``retryPolicy`` is non-nil, the monitor also drives
    /// automatic reconnection — on persistent failure it tears down
    /// the protocol's transport and calls `connect()` again with
    /// the configured backoff. State transitions through
    /// `.reconnecting(attempt:)` and either lands on `.connected`
    /// (on success) or `.disconnected` (after `maxAttempts`).
    ///
    /// Defaults are tuned for "long-running rig session" use cases:
    /// a 5-second heartbeat is plenty for catching a yanked USB
    /// cable without flooding the radio with traffic, and three
    /// failures filter out one-off timeouts that real radios
    /// sometimes emit under load.
    public struct HealthMonitorConfiguration: Sendable {
        public var heartbeatInterval: TimeInterval
        public var degradeAfter: Int
        public var retryPolicy: RetryPolicy?

        public init(
            heartbeatInterval: TimeInterval = 5.0,
            degradeAfter: Int = 3,
            retryPolicy: RetryPolicy? = nil
        ) {
            self.heartbeatInterval = heartbeatInterval
            self.degradeAfter = degradeAfter
            self.retryPolicy = retryPolicy
        }
    }

    /// Exponential-backoff retry policy for the connection-health
    /// monitor's auto-reconnect path.
    ///
    /// Delay between attempt N and attempt N+1 is
    /// `min(initialDelay * multiplier^N, maxDelay)`. With the
    /// defaults — 1 s initial, 30 s cap, 2× growth — the sequence
    /// is 1, 2, 4, 8, 16, 30, 30, … seconds.
    public struct RetryPolicy: Sendable {
        /// Maximum reconnect attempts before giving up. `nil` means
        /// retry forever.
        public var maxAttempts: Int?

        /// Delay before the first reconnect attempt.
        public var initialDelay: TimeInterval

        /// Upper bound on inter-attempt delay.
        public var maxDelay: TimeInterval

        /// Backoff multiplier (≥ 1.0).
        public var multiplier: Double

        public init(
            maxAttempts: Int? = nil,
            initialDelay: TimeInterval = 1.0,
            maxDelay: TimeInterval = 30.0,
            multiplier: Double = 2.0
        ) {
            self.maxAttempts = maxAttempts
            self.initialDelay = initialDelay
            self.maxDelay = maxDelay
            self.multiplier = multiplier
        }

        /// Delay before the N-th attempt (1-based).
        internal func delay(forAttempt attempt: Int) -> TimeInterval {
            let exponent = max(0, attempt - 1)
            let raw = initialDelay * pow(multiplier, Double(exponent))
            return min(raw, maxDelay)
        }
    }

    /// Starts (or restarts) the connection-health monitor.
    ///
    /// Calling this while the monitor is already running stops the
    /// previous instance first. The monitor stops automatically on
    /// `disconnect()` — there's nothing to probe on a closed
    /// transport.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Heartbeat only — no auto-reconnect.
    /// await rig.startHealthMonitor()
    ///
    /// // Heartbeat with auto-reconnect forever.
    /// await rig.startHealthMonitor(.init(
    ///     heartbeatInterval: 5,
    ///     degradeAfter: 3,
    ///     retryPolicy: RigController.RetryPolicy()
    /// ))
    /// ```
    public func startHealthMonitor(_ config: HealthMonitorConfiguration = .init()) {
        stopHealthMonitorInternal()
        healthMonitorTask = Task { [config] in
            await self.runHealthMonitor(config: config)
        }
    }

    /// Stops the connection-health monitor. Idempotent.
    public func stopHealthMonitor() {
        stopHealthMonitorInternal()
    }

    /// True when the health monitor is currently active.
    public var isMonitoringHealth: Bool {
        healthMonitorTask != nil
    }

    // MARK: - Internal plumbing

    internal func stopHealthMonitorInternal() {
        healthMonitorTask?.cancel()
        healthMonitorTask = nil
    }

    /// The monitor's main loop. Lives on the actor.
    private func runHealthMonitor(config: HealthMonitorConfiguration) async {
        var consecutiveFailures = 0
        let nanos = UInt64(config.heartbeatInterval * 1_000_000_000)

        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: nanos)
            } catch {
                return  // Cancelled.
            }

            // If we're already disconnected (e.g. the user called
            // disconnect()), exit cleanly — no point heartbeating a
            // closed transport.
            guard connected else { return }

            do {
                _ = try await proto.getFrequency(vfo: .a)
                if consecutiveFailures > 0 {
                    // Recovered from degraded state.
                    consecutiveFailures = 0
                    transition(to: .connected)
                }
            } catch {
                consecutiveFailures += 1
                if consecutiveFailures >= config.degradeAfter,
                   case .connected = connectionState {
                    transition(to: .degraded(reason: "heartbeat: \(error)"))
                }

                // Auto-reconnect path. Tear down and re-establish.
                if let policy = config.retryPolicy,
                   case .degraded = connectionState {
                    await attemptReconnect(policy: policy)
                    // On success the monitor loops; on terminal
                    // failure attemptReconnect transitions to
                    // .disconnected and we exit on the next guard.
                    consecutiveFailures = 0
                }
            }
        }
    }

    /// Reconnect loop driven by the supplied retry policy. Returns
    /// when reconnection succeeds, or when the policy's
    /// `maxAttempts` is exhausted. Updates `connectionState` as it
    /// goes — every transition emits the corresponding event.
    private func attemptReconnect(policy: RetryPolicy) async {
        var attempt = 1
        while !Task.isCancelled {
            if let max = policy.maxAttempts, attempt > max {
                // Give up. Close out and report disconnected.
                await proto.disconnect()
                connected = false
                transition(to: .disconnected)
                return
            }

            transition(to: .reconnecting(attempt: attempt))

            let delay = policy.delay(forAttempt: attempt)
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                return  // Cancelled.
            }

            // Tear down the previous transport state first — some
            // failures leave the port half-open. Ignore errors here;
            // we're about to try a fresh connect anyway.
            await proto.disconnect()

            do {
                try await proto.connect()
                transition(to: .connected)
                return  // Reconnect succeeded — back to the heartbeat loop.
            } catch {
                attempt += 1
                // Loop continues; next iteration sleeps the backoff.
            }
        }
    }
}
