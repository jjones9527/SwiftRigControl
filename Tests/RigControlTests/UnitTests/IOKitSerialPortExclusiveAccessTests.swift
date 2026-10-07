import Foundation
import Testing
@testable import RigControl

#if os(macOS)
import Darwin

/// `IOKitSerialPort.open()` claims exclusive access with `TIOCEXCL`, as
/// Hamlib `serial_open` does since upstream `4b39d3cd`. A second open of
/// the same port must fail with a clear "in use" error instead of
/// sharing the CAT line, and must succeed again once the first owner
/// closes.
///
/// Uses an `openpty(3)` pair, like `IOKitSerialPortModemLineTests`.
/// (`TIOCEXCL` does not apply to root; CI runs as a normal user.)
@Suite struct IOKitSerialPortExclusiveAccessTests {

    private static func makePty() throws -> (masterFD: Int32, slavePath: String) {
        var master: Int32 = -1
        var slave: Int32 = -1
        var name = [CChar](repeating: 0, count: 1024)
        guard openpty(&master, &slave, &name, nil, nil) == 0 else {
            throw RigError.serialPortError("openpty failed")
        }
        Darwin.close(slave)
        return (master, String(cString: name))
    }

    private static func port(_ path: String) -> IOKitSerialPort {
        IOKitSerialPort(configuration: SerialConfiguration(path: path, baudRate: 9600))
    }

    @Test func secondOpenOfSamePortFailsWhileFirstIsOpen() async throws {
        let pty = try Self.makePty()
        defer { Darwin.close(pty.masterFD) }

        let first = Self.port(pty.slavePath)
        try await first.open()

        let second = Self.port(pty.slavePath)
        do {
            try await second.open()
            Issue.record("second open should fail while the port is held exclusively")
            await second.close()
        } catch RigError.serialPortError(let message) {
            #expect(message.contains("in use by another application"), "\(message)")
        }

        await first.close()
    }

    @Test func portCanBeReopenedAfterClose() async throws {
        let pty = try Self.makePty()
        defer { Darwin.close(pty.masterFD) }

        let first = Self.port(pty.slavePath)
        try await first.open()
        await first.close()

        let second = Self.port(pty.slavePath)
        try await second.open()
        #expect(await second.isOpen)
        await second.close()
    }
}
#endif
