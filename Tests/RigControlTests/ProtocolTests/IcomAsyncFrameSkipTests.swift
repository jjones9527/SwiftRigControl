import Foundation
import Testing
@testable import RigControl

/// Regression tests for macwinlink-releases#66 v1.2.16 fix.
///
/// **The bug.** IC-7100 (and other Icoms in transceive mode) send
/// unsolicited "async" frames on the same CI-V port used for CAT
/// command replies — frequency change, mode change, spectrum-scope
/// data. When one of those frames arrived between our `sendFrame`
/// and the ACK read, `IcomCIVProtocol.receiveFrame` returned it to
/// the caller. `setPTT` then saw `isAck == false` and threw
/// `RigError.commandFailed`, which v1.2.15 wire-encoded as
/// `RPRT -9\n` — Direwolf logged `rig_set_ptt returning(-9) Command
/// rejected by the rig` on every PTT toggle even though the radio
/// keyed correctly and Winlink Packet sessions completed cleanly.
///
/// **The fix.** `IcomCIVProtocol.receiveFrame` now skips echo and
/// unsolicited async frames (up to `asyncFrameSkipBudget`) before
/// returning the actual reply.  Matches Hamlib's approach at
/// `rigs/icom/frame.c:216-236` (`icom_is_async_frame` → `goto
/// again1`).
@Suite struct IcomAsyncFrameSkipTests {

    // MARK: - Frame builders

    private static func pttEcho(civAddr: UInt8, enabled: Bool) -> Data {
        // Controller → radio: FE FE <addr> E0 1C 00 <state> FD
        Data([0xFE, 0xFE, civAddr, 0xE0, 0x1C, 0x00, enabled ? 0x01 : 0x00, 0xFD])
    }

    private static func ack(civAddr: UInt8) -> Data {
        // Radio → controller: FE FE E0 <addr> FB FD
        Data([0xFE, 0xFE, 0xE0, civAddr, 0xFB, 0xFD])
    }

    /// Transceive broadcast: radio announces a frequency change to
    /// BCASTID (0x00). Hamlib async frame from `icom.c:9297-9310`.
    private static func transceiveFrequencyBroadcast(civAddr: UInt8) -> Data {
        // FE FE 00 <from> 00 <5-byte BCD freq> FD
        Data([0xFE, 0xFE, 0x00, civAddr, 0x00,
              0x00, 0x00, 0x30, 0x14, 0x00,  // 14.300 MHz
              0xFD])
    }

    private static func transceiveModeBroadcast(civAddr: UInt8) -> Data {
        // FE FE 00 <from> 01 <mode byte> FD (Hamlib C_SND_MODE async path)
        Data([0xFE, 0xFE, 0x00, civAddr, 0x01, 0x00, 0xFD])
    }

    private static func spectrumScopeBroadcast(civAddr: UInt8) -> Data {
        // FE FE E0 <from> 27 00 <scope data> FD
        // Hamlib check: to == CTRLID && cmd == 0x27 && sub == 0x00.
        Data([0xFE, 0xFE, 0xE0, civAddr, 0x27, 0x00, 0x11, 0x22, 0x33, 0xFD])
    }

    /// Build an IC-7100 `IcomCIVProtocol` wired to a mock transport
    /// delivering a scripted sequence of frames (echo, async
    /// broadcasts, ACK, in the desired order).
    private static func makeIC7100Protocol(delivering frames: [Data]) async throws -> (IcomCIVProtocol, MockTransport) {
        let mock = MockTransport()
        await mock.setChunkedResponse(frames)
        let proto = IcomCIVProtocol(
            transport: mock,
            civAddress: 0x88,
            radioModel: .ic7100,
            commandSet: IC7100CommandSet.ic7100,
            capabilities: RadioCapabilitiesDatabase.Icom.ic7100
        )
        try await proto.connect()
        return (proto, mock)
    }

    // MARK: - The exact macwinlink-releases#66 scenario

    /// Radio echoes the command, an operator-driven transceive
    /// frequency broadcast arrives on the bus, then the ACK.
    /// Pre-v1.2.16: `receiveFrame` returned the broadcast, setPTT
    /// threw `.commandFailed`, Direwolf logged `RPRT -9`.
    /// Post-fix: broadcast is skipped, ACK reaches the caller,
    /// setPTT succeeds without throwing.
    @Test func setPTTSucceedsWhenTransceiveFrequencyBroadcastArrivesBeforeACK() async throws {
        let (proto, _) = try await Self.makeIC7100Protocol(delivering: [
            Self.pttEcho(civAddr: 0x88, enabled: true),
            Self.transceiveFrequencyBroadcast(civAddr: 0x88),
            Self.ack(civAddr: 0x88),
        ])
        try await proto.setPTT(true)
    }

    /// Same shape but with a mode-broadcast async frame instead.
    @Test func setPTTSucceedsWhenTransceiveModeBroadcastArrivesBeforeACK() async throws {
        let (proto, _) = try await Self.makeIC7100Protocol(delivering: [
            Self.pttEcho(civAddr: 0x88, enabled: true),
            Self.transceiveModeBroadcast(civAddr: 0x88),
            Self.ack(civAddr: 0x88),
        ])
        try await proto.setPTT(true)
    }

    /// Spectrum-scope data — Hamlib treats these the same as
    /// broadcast async frames.
    @Test func setPTTSucceedsWhenSpectrumScopeBroadcastArrivesBeforeACK() async throws {
        let (proto, _) = try await Self.makeIC7100Protocol(delivering: [
            Self.pttEcho(civAddr: 0x88, enabled: true),
            Self.spectrumScopeBroadcast(civAddr: 0x88),
            Self.ack(civAddr: 0x88),
        ])
        try await proto.setPTT(true)
    }

    /// Stack of async frames — realistic bus with operator VFO knob
    /// + mode change + scope tick all in flight before the ACK.
    @Test func setPTTSucceedsAgainstStackOfAsyncFrames() async throws {
        let (proto, _) = try await Self.makeIC7100Protocol(delivering: [
            Self.pttEcho(civAddr: 0x88, enabled: true),
            Self.transceiveFrequencyBroadcast(civAddr: 0x88),
            Self.transceiveModeBroadcast(civAddr: 0x88),
            Self.spectrumScopeBroadcast(civAddr: 0x88),
            Self.transceiveFrequencyBroadcast(civAddr: 0x88),
            Self.ack(civAddr: 0x88),
        ])
        try await proto.setPTT(true)
    }

    /// PTT off — the field report showed both keying and un-keying
    /// failed identically pre-fix.
    @Test func setPTTOffSucceedsWhenAsyncFrameArrivesBeforeACK() async throws {
        let (proto, _) = try await Self.makeIC7100Protocol(delivering: [
            Self.pttEcho(civAddr: 0x88, enabled: false),
            Self.transceiveFrequencyBroadcast(civAddr: 0x88),
            Self.ack(civAddr: 0x88),
        ])
        try await proto.setPTT(false)
    }

    // MARK: - Baseline: happy path still works

    @Test func setPTTStillWorksWithoutAnyAsyncFrames() async throws {
        let (proto, _) = try await Self.makeIC7100Protocol(delivering: [
            Self.pttEcho(civAddr: 0x88, enabled: true),
            Self.ack(civAddr: 0x88),
        ])
        try await proto.setPTT(true)
    }
}

/// Locks IC-7100's opt-in flush behavior so a future edit can't
/// silently disable the pre-transaction flush that Hamlib documents
/// at `rigs/icom/frame.c:158-165` as required for the IC-7100.
@Suite struct IC7100PreTransactionFlushTests {

    @Test func ic7100CommandSetOptsIntoPreTransactionFlush() {
        #expect(IC7100CommandSet.ic7100.requiresPreTransactionFlush == true)
    }

    @Test func ic705ShareTheSameCommandSetOptsIntoFlush() {
        // IC-705 uses IC7100CommandSet.ic705 (same struct, different
        // CI-V address). Same combined-USB-port architecture as the
        // IC-7100; the flush applies for the same reason.
        #expect(IC7100CommandSet.ic705.requiresPreTransactionFlush == true)
    }

    @Test func standardIcomCommandSetDoesNotFlushByDefault() {
        // Hamlib only flushes on the IC-7100 model check — no other
        // Icom needs it (their async transceive support is
        // meant to keep working through the CAT port). Locking
        // `false` guards against someone accidentally enabling
        // flush globally and breaking async transceive for the
        // whole family.
        #expect(StandardIcomCommandSet.ic7300.requiresPreTransactionFlush == false)
        #expect(StandardIcomCommandSet.ic7610.requiresPreTransactionFlush == false)
        #expect(StandardIcomCommandSet.ic7600.requiresPreTransactionFlush == false)
    }

    @Test func ic9700DoesNotFlushByDefault() {
        #expect(IC9700CommandSet().requiresPreTransactionFlush == false)
    }

    /// Locks the invariant that setPTT on an IC-7100 flushes the
    /// input buffer before writing. Any future refactor that
    /// bypasses the flush (or moves it to a spot that isn't
    /// executed before every set-then-ACK transaction) fails here.
    @Test func setPTTOnIC7100FlushesBeforeWrite() async throws {
        let mock = MockTransport()
        // Script the response: echo + ACK (simplest happy path).
        await mock.setChunkedResponse([
            Data([0xFE, 0xFE, 0x88, 0xE0, 0x1C, 0x00, 0x01, 0xFD]),
            Data([0xFE, 0xFE, 0xE0, 0x88, 0xFB, 0xFD]),
        ])
        let proto = IcomCIVProtocol(
            transport: mock,
            civAddress: 0x88,
            radioModel: .ic7100,
            commandSet: IC7100CommandSet.ic7100,
            capabilities: RadioCapabilitiesDatabase.Icom.ic7100
        )
        try await proto.connect()

        // Reset ops so we only inspect the setPTT transaction.
        // (connect() may write commands like getVFO / getMode; we
        // don't care about their flush ordering here.)
        let opsBefore = await mock.recordedOperations
        try await proto.setPTT(true)
        let opsAfter = await mock.recordedOperations
        let opsDelta = Array(opsAfter.dropFirst(opsBefore.count))

        // First op in the delta must be a flush; second must be
        // the PTT write. Any interleaving that puts write before
        // flush loses the whole point of the IC-7100 fix.
        #expect(opsDelta.count >= 2,
                "Expected at least [flush, write] in the setPTT transaction; got \(opsDelta).")
        #expect(opsDelta[0] == .flush,
                "First op in setPTT transaction must be `.flush`; got \(opsDelta[0]).")
        if case .write(let payload) = opsDelta[1] {
            #expect(payload == Data([0xFE, 0xFE, 0x88, 0xE0, 0x1C, 0x00, 0x01, 0xFD]))
        } else {
            Issue.record("Second op must be `.write(pttFrame)`; got \(opsDelta[1]).")
        }
    }
}
