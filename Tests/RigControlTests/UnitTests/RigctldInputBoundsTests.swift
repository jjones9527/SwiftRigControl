import Foundation
import Testing
@testable import RigControl

/// rigctld input bounds (v1.2.20).
///
/// Hamlib `c0adbb2` bounded rigctld's command reads and raw-hex parsing
/// (`tests/rigctl_parse.c`). Our parser works on Swift strings and can't
/// overrun a buffer, but `LineBuffer` had no limit: a client that never
/// sent `\n` grew it without bound. These tests pin the line limit and
/// show the parser rejects the inputs Hamlib's fix targets.
@Suite struct RigctldInputBoundsTests {

    private static let limit = LineBuffer.maxLineLength

    // MARK: - LineBuffer

    @Test func lineAtTheLimitIsKept() {
        var buffer = LineBuffer()
        let line = String(repeating: "F", count: Self.limit)
        buffer.append(Data((line + "\n").utf8))
        #expect(buffer.nextLine() == line)
    }

    @Test func overlongLineInOneChunkIsDropped() {
        var buffer = LineBuffer()
        let junk = String(repeating: "x", count: Self.limit + 1)
        buffer.append(Data((junk + "\nf\n").utf8))
        #expect(buffer.nextLine() == "f")
        #expect(buffer.isEmpty)
    }

    @Test func unterminatedFloodStaysBounded() {
        var buffer = LineBuffer()
        let chunk = Data(repeating: UInt8(ascii: "x"), count: 1024)
        for _ in 0..<64 {
            buffer.append(chunk)
            #expect(buffer.nextLine() == nil)
            #expect(buffer.count <= Self.limit + chunk.count)
        }
        // The rest of the dropped line goes too; the next line survives.
        buffer.append(Data("xxxx\nT VFOA 0\n".utf8))
        #expect(buffer.nextLine() == "T VFOA 0")
        #expect(buffer.nextLine() == nil)
    }

    @Test func validLinesBeforeAnOverlongTailStillArrive() {
        var buffer = LineBuffer()
        let tail = Data(repeating: UInt8(ascii: "x"), count: Self.limit + 10)
        buffer.append(Data("T VFOA 1\n".utf8) + tail)
        #expect(buffer.nextLine() == "T VFOA 1")
        #expect(buffer.nextLine() == nil)
        #expect(buffer.isEmpty)
    }

    // MARK: - Parser

    @Test(arguments: [
        "\\",                                   // bare long-command prefix
        "w 0xFE 0xFE 0x94 0xE0 0x03 0xFD",      // send_raw: not implemented
        "\\send_raw icom FE FE 94 E0 03 FD",
        "x41",                                  // Hamlib raw-hex prefix
        "\\0x41",
        "F " + String(repeating: "9", count: 4096),
        "F 1e400",
        "\u{00}F 14074000",
        "Ф 14074000",
    ])
    func malformedInputThrows(input: String) {
        #expect(throws: (any Error).self) {
            try RigctldCommandParser().parse(input)
        }
    }
}
