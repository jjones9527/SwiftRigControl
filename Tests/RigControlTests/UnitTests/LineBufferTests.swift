import Foundation
import Testing
@testable import RigControl

/// Regression tests for `LineBuffer`, the fragmentation/coalescing
/// buffer that sits between `NWConnection.receive()` and
/// `ClientSession.receiveLine()` starting in v1.2.14
/// (macwinlink-releases#54 second followup).
///
/// The prior implementation had two catastrophic bugs:
///
/// 1. **Coalescing**: when TCP delivered `T VFOA 1\nT VFOA 0\n`
///    (18 bytes) in a single `recv()`, it consumed the first
///    line and threw away the second — subsequent commands from
///    the client saw responses to the wrong requests.
///
/// 2. **Fragmentation**: when TCP delivered `T VFOA` in one
///    chunk and ` 1\n` in the next, the first chunk was dropped
///    entirely (returned "" from `receiveLine`), leaving the
///    second chunk to be parsed alone as ` 1` → parser rejection
///    → `RPRT -1\n` (8 bytes) on the wire, which Direwolf's
///    Hamlib mapped to `-9 Command rejected by the rig`.
///
/// `LineBuffer` fixes both by keeping unconsumed bytes in an
/// internal `Data` buffer across `receive()` calls.
@Suite struct LineBufferTests {

    // MARK: - Coalesced input

    @Test func coalescedTwoLinesEmitInOrder() {
        var buffer = LineBuffer()
        buffer.append(Data("T VFOA 1\nT VFOA 0\n".utf8))

        #expect(buffer.nextLine() == "T VFOA 1")
        #expect(buffer.nextLine() == "T VFOA 0")
        #expect(buffer.nextLine() == nil)
        #expect(buffer.isEmpty)
    }

    @Test func coalescedThreeLinesEmitInOrder() {
        var buffer = LineBuffer()
        buffer.append(Data("T VFOA 1\nF VFOA 14070000\nT VFOA 0\n".utf8))

        #expect(buffer.nextLine() == "T VFOA 1")
        #expect(buffer.nextLine() == "F VFOA 14070000")
        #expect(buffer.nextLine() == "T VFOA 0")
        #expect(buffer.nextLine() == nil)
    }

    @Test func coalescedInputWithTrailingPartialLineHoldsIt() {
        var buffer = LineBuffer()
        // Second command isn't newline-terminated yet.
        buffer.append(Data("T VFOA 1\nT VFOA".utf8))

        #expect(buffer.nextLine() == "T VFOA 1")
        #expect(buffer.nextLine() == nil,
                "Partial second line must NOT be emitted — that would parse `T VFOA` alone and fail. It stays in the buffer waiting for the rest.")
        #expect(!buffer.isEmpty)
        #expect(buffer.count == 6, "`T VFOA` (6 bytes) still buffered.")

        // Next chunk completes it.
        buffer.append(Data(" 0\n".utf8))
        #expect(buffer.nextLine() == "T VFOA 0",
                "Once the completing bytes arrive, the reassembled line must emit intact.")
        #expect(buffer.isEmpty)
    }

    // MARK: - Fragmented input

    @Test func fragmentedLineReassemblesAcrossTwoAppends() {
        var buffer = LineBuffer()
        buffer.append(Data("T VFOA".utf8))
        #expect(buffer.nextLine() == nil,
                "No newline yet — must not emit anything.")

        buffer.append(Data(" 1\n".utf8))
        #expect(buffer.nextLine() == "T VFOA 1")
        #expect(buffer.isEmpty)
    }

    @Test func fragmentedLineReassemblesAcrossManyAppends() {
        var buffer = LineBuffer()
        // Worst-case fragmentation: one byte at a time.
        for byte in "T VFOA 1\n".utf8 {
            buffer.append(Data([byte]))
            if byte != 0x0A {
                #expect(buffer.nextLine() == nil, "No newline yet.")
            }
        }
        #expect(buffer.nextLine() == "T VFOA 1")
        #expect(buffer.isEmpty)
    }

    // MARK: - Edge cases

    @Test func emptyLineFromBareNewlineEmitsEmptyString() {
        var buffer = LineBuffer()
        buffer.append(Data("\n".utf8))
        #expect(buffer.nextLine() == "",
                "A bare `\\n` is a legitimate (if unusual) input; `ClientSession.receiveCommands` skips empty lines. The buffer just reports what it saw.")
        #expect(buffer.isEmpty)
    }

    @Test func emptyChunkIsNoOp() {
        var buffer = LineBuffer()
        buffer.append(Data("T 1".utf8))
        buffer.append(Data())     // empty chunk — no-op
        buffer.append(Data("\n".utf8))
        #expect(buffer.nextLine() == "T 1")
        #expect(buffer.isEmpty)
    }

    @Test func appendAfterConsumingLineKeepsResidue() {
        var buffer = LineBuffer()
        buffer.append(Data("first\nsecond partial".utf8))
        #expect(buffer.nextLine() == "first")
        #expect(buffer.count == 14, "`second partial` (14 bytes) retained.")

        buffer.append(Data(" continued\n".utf8))
        #expect(buffer.nextLine() == "second partial continued")
        #expect(buffer.isEmpty)
    }

    // MARK: - The exact failing sequence from the field report

    @Test func direwolfPTTStormAllReplyableAsExpected() {
        // Direwolf's beta38 Packet-session sequence, the specific
        // rapid-fire pattern that surfaced the bug. If any of these
        // fails to emit a clean line at the right time, Direwolf's
        // next PTT sees a scrambled response.
        var buffer = LineBuffer()

        // Case: three PTT toggles, TCP coalesced all three into
        // one chunk (18 bytes each = 27 bytes total).
        buffer.append(Data("T VFOA 1\nT VFOA 0\nT VFOA 1\n".utf8))
        #expect(buffer.nextLine() == "T VFOA 1")
        #expect(buffer.nextLine() == "T VFOA 0")
        #expect(buffer.nextLine() == "T VFOA 1")
        #expect(buffer.nextLine() == nil)

        // Case: PTT toggle fragmented mid-VFO.
        buffer.append(Data("T VFO".utf8))
        #expect(buffer.nextLine() == nil)
        buffer.append(Data("A 0\n".utf8))
        #expect(buffer.nextLine() == "T VFOA 0")

        // Case: PTT toggle fragmented mid-argument.
        buffer.append(Data("T VFOA ".utf8))
        #expect(buffer.nextLine() == nil)
        buffer.append(Data("1\n".utf8))
        #expect(buffer.nextLine() == "T VFOA 1")
    }
}
