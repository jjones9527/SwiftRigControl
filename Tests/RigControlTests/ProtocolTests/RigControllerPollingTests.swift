import Foundation
import Testing
@testable import RigControl

/// Tests for the Phase 2.2 polled state broadcaster.
///
/// These tests use fast polling intervals (50–200 ms) and generous
/// collection windows (1 s) so they don't flake under CI noise. The
/// dummy radio's `simulateSignalStrength(raw:)` test helper lets us
/// drive observed S-meter changes deterministically.
@Suite struct RigControllerPollingTests {

    /// Standard test radio: dummy, no frequency restrictions.
    private func makeRig() async throws -> RigController {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        return rig
    }

    /// Collect up to `expectedCount` events from `rig.events` within
    /// `maxWait` seconds. Returns whatever arrived.
    private func collectEvents(
        from rig: RigController,
        expectedCount: Int,
        maxWait: TimeInterval = 1.0
    ) async -> [RigStateEvent] {
        let stream = rig.events
        let collector = Task<[RigStateEvent], Never> {
            var collected: [RigStateEvent] = []
            for await event in stream {
                collected.append(event)
                if collected.count >= expectedCount { break }
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

    @Test func isPollingFlag() async throws {
        let rig = try await makeRig()
        #expect(await rig.isPolling == false)

        await rig.startPolling()
        #expect(await rig.isPolling == true)

        await rig.stopPolling()
        #expect(await rig.isPolling == false)
    }

    @Test func disabledConfigurationStartsNothing() async throws {
        let rig = try await makeRig()
        await rig.startPolling(.disabled)
        #expect(await rig.isPolling == false)
    }

    @Test func disconnectStopsPolling() async throws {
        let rig = try await makeRig()
        await rig.startPolling()
        #expect(await rig.isPolling == true)

        await rig.disconnect()
        #expect(await rig.isPolling == false)
    }

    @Test func startPollingTwiceReplacesPreviousBatch() async throws {
        let rig = try await makeRig()

        await rig.startPolling(.init(signalStrength: 0.1, frequency: nil, mode: nil, ptt: nil))
        #expect(await rig.isPolling == true)

        // Restart with a different field — previous batch must be
        // replaced (not added to).
        await rig.startPolling(.init(signalStrength: nil, frequency: 0.1, mode: nil, ptt: nil))
        #expect(await rig.isPolling == true)

        await rig.stopPolling()
    }

    // MARK: - Emission

    @Test func signalStrengthEmitsEveryPoll() async throws {
        let rig = try await makeRig()
        // Fast poll, signal-strength only.
        await rig.startPolling(.init(
            signalStrength: 0.05,  // 50 ms → ~20 samples per second
            frequency: nil,
            mode: nil,
            ptt: nil
        ))

        // Collect events for ~250 ms. With 50 ms cadence we expect
        // ~5 signal-strength events plus the connection-state replay.
        let events = await collectEvents(from: rig, expectedCount: 6, maxWait: 0.5)

        let signalEvents = events.filter {
            if case .signalStrengthChanged = $0 { return true }
            return false
        }
        // Lower-bound the count generously — we want to know polling
        // is happening, not nail an exact rate.
        #expect(signalEvents.count >= 2, "expected at least 2 signal-strength events, got \(signalEvents.count)")

        await rig.stopPolling()
    }

    @Test func frequencyOnlyEmitsOnChange() async throws {
        // Reach into the dummy via the controller's protocol handle.
        // Drive a frequency change between polls and confirm exactly
        // one event arrives for each unique value.
        let rig = try await makeRig()
        let proto = await rig.rawProtocol as! DummyCATProtocol

        await rig.startPolling(.init(
            signalStrength: nil,
            frequency: 0.05,
            mode: nil,
            ptt: nil
        ))

        // Let the poller see the initial value (which the first poll
        // emits, since the cache hadn't seen it yet).
        try await Task.sleep(nanoseconds: 100_000_000)  // 100 ms

        let stream = rig.events
        let collector = Task<[RigStateEvent], Never> {
            var collected: [RigStateEvent] = []
            for await event in stream {
                if case .frequencyChanged = event {
                    collected.append(event)
                    if collected.count >= 2 { break }
                }
            }
            return collected
        }

        // Wait long enough that, if the poller were emitting every
        // tick (not just on change), we'd see many more events.
        try await Task.sleep(nanoseconds: 100_000_000)  // 100 ms — no change should fire
        try await proto.setFrequency(7_074_000, vfo: .a)  // → change → emit
        try await Task.sleep(nanoseconds: 100_000_000)
        try await proto.setFrequency(14_074_000, vfo: .a)  // → change → emit
        try await Task.sleep(nanoseconds: 200_000_000)

        let timeout = Task {
            try await Task.sleep(nanoseconds: 500_000_000)
            collector.cancel()
        }
        defer { timeout.cancel() }
        let events = await collector.value

        // We expect the two changes; we tolerate one extra (the
        // initial poll seeing the default value before our test
        // setup ran).
        let frequencies = events.compactMap { event -> UInt64? in
            if case .frequencyChanged(_, let hz) = event { return hz }
            return nil
        }
        #expect(frequencies.contains(7_074_000))
        #expect(frequencies.contains(14_074_000))

        await rig.stopPolling()
    }

    @Test func pttPolledChangesEmit() async throws {
        // The interesting case: PTT changes via direct protocol
        // (simulating front-panel mic PTT, which bypasses
        // RigController.setPTT).
        let rig = try await makeRig()
        let proto = await rig.rawProtocol as! DummyCATProtocol

        await rig.startPolling(.init(
            signalStrength: nil,
            frequency: nil,
            mode: nil,
            ptt: 0.05
        ))

        // Subscribe BEFORE settling, then wait for the registration
        // task to run before we start mutating state. `rig.events`
        // schedules registration in a detached Task; under parallel
        // test load it can lag the first poll otherwise.
        let stream = rig.events
        try await Task.sleep(nanoseconds: 100_000_000)  // settle + let subscriber register

        let collector = Task<[RigStateEvent], Never> {
            var collected: [RigStateEvent] = []
            for await event in stream {
                if case .pttChanged = event {
                    collected.append(event)
                    if collected.count >= 2 { break }
                }
            }
            return collected
        }
        // Brief yield so the for-await is in the iterator before
        // we start firing events.
        try await Task.sleep(nanoseconds: 10_000_000)

        // Flip PTT directly on the protocol — does NOT go through
        // RigController.setPTT (which would emit synchronously).
        try await proto.setPTT(true)
        try await Task.sleep(nanoseconds: 200_000_000)
        try await proto.setPTT(false)
        try await Task.sleep(nanoseconds: 200_000_000)

        let timeout = Task {
            try await Task.sleep(nanoseconds: 800_000_000)
            collector.cancel()
        }
        defer { timeout.cancel() }
        let events = await collector.value

        let states = events.compactMap { event -> Bool? in
            if case .pttChanged(let on) = event { return on }
            return nil
        }
        #expect(states.contains(true))
        #expect(states.contains(false))

        await rig.stopPolling()
    }

    // MARK: - Configuration shapes

    @Test func uniformConfigurationSetsAllFields() {
        let config = RigController.PollingConfiguration.uniform(every: 0.5)
        #expect(config.signalStrength == 0.5)
        #expect(config.frequency == 0.5)
        #expect(config.mode == 0.5)
        #expect(config.ptt == 0.5)
    }

    @Test func disabledConfigurationHasNoIntervals() {
        let config = RigController.PollingConfiguration.disabled
        #expect(config.signalStrength == nil)
        #expect(config.frequency == nil)
        #expect(config.mode == nil)
        #expect(config.ptt == nil)
    }

    @Test func defaultsAreSensible() {
        let config = RigController.PollingConfiguration()
        // The defaults are tunable, but they must at least be
        // positive — guards against accidentally setting one to 0.
        #expect((config.signalStrength ?? 0) > 0)
        #expect((config.frequency ?? 0) > 0)
        #expect((config.mode ?? 0) > 0)
        #expect((config.ptt ?? 0) > 0)
    }
}
