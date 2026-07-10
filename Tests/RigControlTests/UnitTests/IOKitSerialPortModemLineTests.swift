import Foundation
import Testing
@testable import RigControl

#if os(macOS)
import Darwin

/// Regression tests for issue #11: `IOKitSerialPort.open()` must not
/// leave DTR or RTS asserted, or Yaesu radios that use those pins as a
/// hardware PTT signal (FT-DX10, FT-DX101, FT-991A, FT-450D, ...) key
/// the moment the port opens and stay keyed until the USB cable is
/// pulled.
///
/// The core regression test opens an `openpty(3)` pair, has
/// `IOKitSerialPort` open the slave side, and reads the modem-line
/// state from the master side via `TIOCMGET`. That path exercises the
/// exact `TIOCMBIC` sequence a real USB-serial driver sees.
///
/// The `setDTR(true)` / `setRTS(true)` re-assertion path is not
/// exercised here — the macOS pty slave rejects `TIOCMBIS` with
/// ENOTTY. Those code paths are covered by the `MockSerialTransport`
/// contract tests and by the per-radio hardware validators.
@Suite struct IOKitSerialPortModemLineTests {

    /// Path to the slave side of a freshly-allocated pty pair, plus
    /// the master file descriptor we keep so we can query modem-line
    /// state from the peer side.
    private struct PtyPair {
        let masterFD: Int32
        let slavePath: String

        func close() {
            Darwin.close(masterFD)
        }

        func modemFlags() -> Int32 {
            var flags: Int32 = 0
            _ = ioctl(masterFD, TIOCMGET, &flags)
            return flags
        }
    }

    private static func makePty() throws -> PtyPair {
        var master: Int32 = -1
        var slave: Int32 = -1
        var name = [CChar](repeating: 0, count: 1024)
        guard openpty(&master, &slave, &name, nil, nil) == 0 else {
            throw RigError.serialPortError("openpty failed")
        }
        // We only need the slave path — close the fd; IOKitSerialPort
        // will open its own.
        Darwin.close(slave)
        let path = String(cString: name)
        return PtyPair(masterFD: master, slavePath: path)
    }

    @Test func openDeAssertsDTRAndRTS() async throws {
        let pty = try Self.makePty()
        defer { pty.close() }

        let port = IOKitSerialPort(
            configuration: SerialConfiguration(
                path: pty.slavePath,
                baudRate: 9600,
                hardwareFlowControl: false
            )
        )
        try await port.open()
        defer { Task { await port.close() } }

        let flags = pty.modemFlags()
        #expect(flags & TIOCM_DTR == 0, "DTR must be low after open() — Yaesu PTT safety")
        #expect(flags & TIOCM_RTS == 0, "RTS must be low after open() — Yaesu PTT safety")
    }

    @Test func setDTRBeforeOpenThrows() async throws {
        let port = IOKitSerialPort(
            configuration: SerialConfiguration(path: "/dev/null")
        )
        await #expect(throws: RigError.self) {
            try await port.setDTR(true)
        }
    }
}
#endif
