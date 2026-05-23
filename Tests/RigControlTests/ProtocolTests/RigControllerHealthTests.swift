import Foundation
import Testing
@testable import RigControl

/// Tests for the Phase 2.3 connection-health monitor.
///
/// The dummy radio's `simulateFailure(_:)` test helper lets us
/// flip the radio into "always-throw" mode and back, which is how
/// these tests deterministically exercise the heartbeat-detection
/// and auto-reconnect paths without any real I/O or timing
/// dependencies beyond the test's own configured intervals.
@Suite struct RigControllerHealthTests {

    /// Standard test radio: dummy, all defaults.
    private func makeRig() async throws -> RigController {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        return rig
    }

    /// Collect events from `rig.events`, stopping when `predicate`
    /// returns true OR `maxWait` elapses. Returns whatever arrived.
    private func collectEvents(
        from rig: RigController,
        until predicate: @Sendable @escaping ([RigStateEvent]) -> Bool,
        maxWait: TimeInterval
    ) async -> [RigStateEvent] {
        let stream = rig.events
        let collector = Task<[RigStateEvent], Never> {
            var collected: [RigStateEvent] = []
            for await event in stream {
                collected.append(event)
                if predicate(collected) { break }
            }
            return collected
        }
        let timeout = Task {
            try await Task.sleep(nanoseconds: UInt64(maxWait * 1_000_000_000))
            collector.cancel()
        }
        defer { timeout.cancel() }
        return await collector.value
    }

    // MARK: - Lifecycle

    @Test func isMonitoringHealthFlag() async throws {
        let rig = try await makeRig()
        #expect(await rig.isMonitoringHealth == false)

        await rig.startHealthMonitor()
        #expect(await rig.isMonitoringHealth == true)

        await rig.stopHealthMonitor()
        #expect(await rig.isMonitoringHealth == false)
    }

    @Test func disconnectStopsHealthMonitor() async throws {
        let rig = try await makeRig()
        await rig.startHealthMonitor()
        await rig.disconnect()
        #expect(await rig.isMonitoringHealth == false)
    }

    @Test func startHealthMonitorTwiceReplacesPreviousMonitor() async throws {
        let rig = try await makeRig()
        await rig.startHealthMonitor(.init(heartbeatInterval: 0.05))
        await rig.startHealthMonitor(.init(heartbeatInterval: 0.1))
        // Just confirming no leak / no double-tasks; the actor's
        // dictionary holds one entry either way.
        #expect(await rig.isMonitoringHealth == true)
        await rig.stopHealthMonitor()
    }

    // MARK: - Degradation

    @Test func consecutiveFailuresTransitionToDegraded() async throws {
        let rig = try await makeRig()
        let proto = await rig.rawProtocol as! DummyCATProtocol

        // 50 ms heartbeat, degrade after 2 consecutive failures.
        // Window: ~250 ms is comfortably enough for 2 probes +
        // transition event.
        await rig.startHealthMonitor(.init(
            heartbeatInterval: 0.05,
            degradeAfter: 2,
            retryPolicy: nil
        ))

        // Flip the dummy into "always fail" mode.
        await proto.simulateFailure(.timeout)

        let events = await collectEvents(
            from: rig,
            until: { events in
                events.contains { event in
                    if case .connectionStateChanged(.degraded) = event { return true }
                    return false
                }
            },
            maxWait: 1.0
        )

        let degradedEvents = events.filter {
            if case .connectionStateChanged(.degraded) = $0 { return true }
            return false
        }
        #expect(!degradedEvents.isEmpty, "expected a .degraded transition")

        await rig.stopHealthMonitor()
    }

    @Test func recoveryFromDegradedEmitsConnected() async throws {
        let rig = try await makeRig()
        let proto = await rig.rawProtocol as! DummyCATProtocol

        await rig.startHealthMonitor(.init(
            heartbeatInterval: 0.05,
            degradeAfter: 2,
            retryPolicy: nil
        ))

        // Fail until degraded, then recover.
        await proto.simulateFailure(.timeout)

        // Wait for degraded.
        let phase1 = await collectEvents(
            from: rig,
            until: { events in
                events.contains { event in
                    if case .connectionStateChanged(.degraded) = event { return true }
                    return false
                }
            },
            maxWait: 1.0
        )
        #expect(phase1.contains { event in
            if case .connectionStateChanged(.degraded) = event { return true }
            return false
        })

        // Clear the failure — next heartbeat probe should succeed
        // and emit a .connected transition.
        await proto.simulateFailure(nil)

        let phase2 = await collectEvents(
            from: rig,
            until: { events in
                events.contains { event in
                    if case .connectionStateChanged(.connected) = event { return true }
                    return false
                }
            },
            maxWait: 1.0
        )
        #expect(phase2.contains { event in
            if case .connectionStateChanged(.connected) = event { return true }
            return false
        }, "expected a .connected transition after recovery")

        await rig.stopHealthMonitor()
    }

    // MARK: - Retry policy math

    @Test func retryPolicyDelayMath() {
        let policy = RigController.RetryPolicy(
            initialDelay: 1.0,
            maxDelay: 30.0,
            multiplier: 2.0
        )
        #expect(policy.delay(forAttempt: 1) == 1.0)
        #expect(policy.delay(forAttempt: 2) == 2.0)
        #expect(policy.delay(forAttempt: 3) == 4.0)
        #expect(policy.delay(forAttempt: 4) == 8.0)
        #expect(policy.delay(forAttempt: 5) == 16.0)
        #expect(policy.delay(forAttempt: 6) == 30.0)  // capped
        #expect(policy.delay(forAttempt: 7) == 30.0)  // capped
    }

    @Test func retryPolicyDefaults() {
        let policy = RigController.RetryPolicy()
        #expect(policy.maxAttempts == nil)
        #expect(policy.initialDelay == 1.0)
        #expect(policy.maxDelay == 30.0)
        #expect(policy.multiplier == 2.0)
    }

    // MARK: - Auto-reconnect

    @Test func autoReconnectAttemptsAndRecovers() async throws {
        let rig = try await makeRig()
        let proto = await rig.rawProtocol as! DummyCATProtocol

        // Aggressive timing for the test: 50 ms heartbeat, degrade
        // after 1 failure, 50 ms reconnect delays.
        let policy = RigController.RetryPolicy(
            maxAttempts: 5,
            initialDelay: 0.05,
            maxDelay: 0.05,
            multiplier: 1.0
        )
        await rig.startHealthMonitor(.init(
            heartbeatInterval: 0.05,
            degradeAfter: 1,
            retryPolicy: policy
        ))

        // Fail. Monitor should: probe fails → .degraded →
        // .reconnecting(1) → re-attempts connect → still failing →
        // .reconnecting(2) → ...
        await proto.simulateFailure(.timeout)

        // Wait for at least one .reconnecting event.
        let phase1 = await collectEvents(
            from: rig,
            until: { events in
                events.contains { event in
                    if case .connectionStateChanged(.reconnecting) = event { return true }
                    return false
                }
            },
            maxWait: 1.0
        )
        #expect(phase1.contains { event in
            if case .connectionStateChanged(.reconnecting) = event { return true }
            return false
        }, "expected at least one .reconnecting transition")

        // Now clear the failure — the next reconnect attempt
        // should succeed and emit .connected.
        await proto.simulateFailure(nil)

        let phase2 = await collectEvents(
            from: rig,
            until: { events in
                events.contains { event in
                    if case .connectionStateChanged(.connected) = event { return true }
                    return false
                }
            },
            maxWait: 1.0
        )
        #expect(phase2.contains { event in
            if case .connectionStateChanged(.connected) = event { return true }
            return false
        }, "expected reconnect to succeed")

        await rig.stopHealthMonitor()
        await rig.disconnect()
    }

    @Test func autoReconnectGivesUpAfterMaxAttempts() async throws {
        let rig = try await makeRig()
        let proto = await rig.rawProtocol as! DummyCATProtocol

        // 2 attempts then give up. With 50 ms delays, we expect
        // .degraded → .reconnecting(1) → .reconnecting(2) → .disconnected
        // within ~500 ms.
        let policy = RigController.RetryPolicy(
            maxAttempts: 2,
            initialDelay: 0.05,
            maxDelay: 0.05,
            multiplier: 1.0
        )
        await rig.startHealthMonitor(.init(
            heartbeatInterval: 0.05,
            degradeAfter: 1,
            retryPolicy: policy
        ))

        await proto.simulateFailure(.timeout)

        let events = await collectEvents(
            from: rig,
            until: { events in
                events.contains { event in
                    // Look for the final .disconnected after
                    // .reconnecting attempts are exhausted.
                    if case .connectionStateChanged(.disconnected) = event { return true }
                    return false
                }
            },
            maxWait: 2.0
        )

        // We should have seen .degraded, at least one .reconnecting,
        // and the final .disconnected.
        let states: [ConnectionState] = events.compactMap { event in
            if case .connectionStateChanged(let state) = event { return state }
            return nil
        }
        let names = states.map { String(describing: $0) }
        #expect(names.contains { $0.hasPrefix("degraded") }, "expected .degraded; got \(names)")
        #expect(names.contains { $0.hasPrefix("reconnecting") }, "expected .reconnecting; got \(names)")
        #expect(states.contains(.disconnected), "expected final .disconnected; got \(names)")
    }

    // MARK: - Configuration shapes

    @Test func healthMonitorConfigurationDefaults() {
        let config = RigController.HealthMonitorConfiguration()
        #expect(config.heartbeatInterval == 5.0)
        #expect(config.degradeAfter == 3)
        #expect(config.retryPolicy == nil)  // No auto-reconnect by default.
    }
}
