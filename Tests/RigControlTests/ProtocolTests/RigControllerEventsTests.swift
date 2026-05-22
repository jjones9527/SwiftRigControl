import Foundation
import Testing
@testable import RigControl

/// Tests for the Phase 2.1 push-style event stream
/// (`RigController.events`).
///
/// Each test drives a dummy radio so it can assert on event flow
/// without hardware, byte-level mocking, or timing dependencies.
@Suite struct RigControllerEventsTests {

    /// Subscribe in a child task, perform `body`, then return the
    /// events received in `maxWait` seconds (default 0.5s — plenty
    /// for in-process async fan-out, fast enough that a regression
    /// surfaces quickly).
    ///
    /// `expectedCount`: stop early once this many events arrive.
    /// `body` runs *after* the subscription is established to avoid
    /// the test racing against the broadcaster's setup.
    private func collectEvents(
        from rig: RigController,
        expectedCount: Int,
        maxWait: TimeInterval = 0.5,
        body: @Sendable @escaping () async throws -> Void
    ) async throws -> [RigStateEvent] {
        let stream = rig.events
        let collector = Task<[RigStateEvent], Never> {
            var collected: [RigStateEvent] = []
            for await event in stream {
                collected.append(event)
                if collected.count >= expectedCount { break }
            }
            return collected
        }
        // Give the registration task a tick to run before body fires.
        try await Task.sleep(nanoseconds: 10_000_000)  // 10 ms

        try await body()

        let timeout = Task {
            try await Task.sleep(nanoseconds: UInt64(maxWait * 1_000_000_000))
            collector.cancel()
        }
        defer { timeout.cancel() }
        return await collector.value
    }

    // MARK: - Connection lifecycle events

    @Test func subscribingReplaysCurrentConnectionState() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        // Subscribe BEFORE connect — should immediately see the
        // .disconnected replay.
        let events = try await collectEvents(from: rig, expectedCount: 1) {
            // No-op — the replay alone fulfills expectedCount=1.
        }
        #expect(events.first == .connectionStateChanged(.disconnected))
    }

    @Test func connectEmitsConnectingThenConnected() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        // Expected sequence: replay(.disconnected), .connecting, .connected
        let events = try await collectEvents(from: rig, expectedCount: 3) {
            try await rig.connect()
        }
        #expect(events == [
            .connectionStateChanged(.disconnected),
            .connectionStateChanged(.connecting),
            .connectionStateChanged(.connected),
        ])
    }

    @Test func disconnectEmitsDisconnected() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        // Subscribe AFTER connect — replay shows current state.
        // Expected: replay(.connected), then .disconnected on disconnect.
        let events = try await collectEvents(from: rig, expectedCount: 2) {
            await rig.disconnect()
        }
        #expect(events == [
            .connectionStateChanged(.connected),
            .connectionStateChanged(.disconnected),
        ])
    }

    // MARK: - State-change events

    @Test func setFrequencyEmitsFrequencyChanged() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        let events = try await collectEvents(from: rig, expectedCount: 2) {
            try await rig.setFrequency(14_230_000, vfo: .a)
        }
        // First event is the connection-state replay.
        #expect(events.contains(.frequencyChanged(vfo: .a, hz: 14_230_000)))
    }

    @Test func setModeEmitsModeChanged() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        let events = try await collectEvents(from: rig, expectedCount: 2) {
            try await rig.setMode(.cw, vfo: .a)
        }
        #expect(events.contains(.modeChanged(vfo: .a, mode: .cw)))
    }

    @Test func setPTTEmitsPTTChanged() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        let events = try await collectEvents(from: rig, expectedCount: 3) {
            try await rig.setPTT(true)
            try await rig.setPTT(false)
        }
        #expect(events.contains(.pttChanged(enabled: true)))
        #expect(events.contains(.pttChanged(enabled: false)))
    }

    @Test func levelSetterEmitsLevelChanged() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        let events = try await collectEvents(from: rig, expectedCount: 2) {
            try await rig.setAFGain(200)
        }
        #expect(events.contains(.levelChanged(kind: .afGain, value: 200)))
    }

    @Test func eventsAreEmittedInOrder() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        let events = try await collectEvents(from: rig, expectedCount: 4) {
            try await rig.setFrequency(14_230_000, vfo: .a)
            try await rig.setMode(.usb, vfo: .a)
            try await rig.setPTT(true)
        }
        // Drop the connection-state replay, look at the rest.
        let stateEvents = events.dropFirst()
        #expect(Array(stateEvents) == [
            .frequencyChanged(vfo: .a, hz: 14_230_000),
            .modeChanged(vfo: .a, mode: .usb),
            .pttChanged(enabled: true),
        ])
    }

    // MARK: - Multi-subscriber fan-out

    @Test func twoSubscribersBothReceiveEvents() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()

        let stream1 = rig.events
        let stream2 = rig.events

        let collector1 = Task<[RigStateEvent], Never> {
            var collected: [RigStateEvent] = []
            for await event in stream1 {
                collected.append(event)
                if collected.count >= 2 { break }
            }
            return collected
        }
        let collector2 = Task<[RigStateEvent], Never> {
            var collected: [RigStateEvent] = []
            for await event in stream2 {
                collected.append(event)
                if collected.count >= 2 { break }
            }
            return collected
        }

        try await Task.sleep(nanoseconds: 20_000_000)  // 20 ms for both registrations
        try await rig.setFrequency(14_230_000, vfo: .a)

        let timeout = Task {
            try await Task.sleep(nanoseconds: 500_000_000)
            collector1.cancel()
            collector2.cancel()
        }
        defer { timeout.cancel() }

        let events1 = await collector1.value
        let events2 = await collector2.value

        // Each subscriber should see the connection replay + the
        // frequency change.
        #expect(events1.contains(.frequencyChanged(vfo: .a, hz: 14_230_000)))
        #expect(events2.contains(.frequencyChanged(vfo: .a, hz: 14_230_000)))
    }

    @Test func cancelledSubscriberDoesNotLeak() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()

        // Subscribe, then immediately drop the stream.
        do {
            _ = rig.events
            // Stream goes out of scope here; onTermination fires
            // asynchronously.
        }

        // Give the deregistration task time to run.
        try await Task.sleep(nanoseconds: 50_000_000)  // 50 ms

        // Subscribe a new consumer and verify events still flow —
        // i.e., the controller didn't lock up trying to emit to a
        // dead subscriber. The check is implicit: this completes.
        let events = try await collectEvents(from: rig, expectedCount: 2) {
            try await rig.setMode(.cw, vfo: .a)
        }
        #expect(events.contains(.modeChanged(vfo: .a, mode: .cw)))
    }

    // MARK: - Emission policy

    @Test func emittingDoesNotDedupe() async throws {
        let rig = try RigController(radio: .dummy(), connection: .mock)
        try await rig.connect()
        // Set same frequency twice — should produce two events.
        let events = try await collectEvents(from: rig, expectedCount: 3) {
            try await rig.setFrequency(14_230_000, vfo: .a)
            try await rig.setFrequency(14_230_000, vfo: .a)
        }
        let freqEvents = events.filter {
            if case .frequencyChanged = $0 { return true }
            return false
        }
        #expect(freqEvents.count == 2)
    }

    @Test func failedSetDoesNotEmit() async throws {
        // VHF-only dummy rejects HF set; the rejected setter must
        // NOT emit (the change didn't actually happen).
        let vhf = RigCapabilities(
            supportedModes: [.fm, .usb],
            frequencyRange: FrequencyRange(min: 144_000_000, max: 148_000_000)
        )
        let rig = try RigController(
            radio: .dummy(name: "VHF", capabilities: vhf),
            connection: .mock
        )
        try await rig.connect()

        let stream = rig.events
        let collector = Task<[RigStateEvent], Never> {
            var collected: [RigStateEvent] = []
            for await event in stream {
                collected.append(event)
                if collected.count >= 2 { break }
            }
            return collected
        }
        try await Task.sleep(nanoseconds: 10_000_000)

        // This must throw and not emit.
        await #expect(throws: RigError.self) {
            try await rig.setFrequency(14_230_000, vfo: .a)
        }
        // Successful set, to give the collector something to find
        // (we want expectedCount=2 to finish: replay + this event).
        try await rig.setFrequency(146_520_000, vfo: .a)

        let timeout = Task {
            try await Task.sleep(nanoseconds: 500_000_000)
            collector.cancel()
        }
        defer { timeout.cancel() }
        let events = await collector.value

        // The 14.230 MHz set should not appear.
        let freqEvents = events.compactMap { event -> UInt64? in
            if case let .frequencyChanged(_, hz) = event { return hz }
            return nil
        }
        #expect(!freqEvents.contains(14_230_000))
        #expect(freqEvents.contains(146_520_000))
    }
}
