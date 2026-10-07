import Foundation
import Testing
@testable import RigControl

#if os(macOS)
import Darwin

/// `IOKitSerialPort.open()` claims exclusive access with `TIOCEXCL`, as
/// Hamlib `serial_open` does since upstream `4b39d3cd`, and releases it on
/// close.
///
/// These tests use an `openpty(3)` pair, like
/// `IOKitSerialPortModemLineTests`. A pty accepts `TIOCEXCL`, but CI showed
/// that a second non-root open of the pty slave still succeeds, so the
/// "second program gets EBUSY" behaviour can only be checked on a real
/// USB-serial port. Here we check that the kernel accepts the request and
/// that close releases the port.
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

    @Test func openClaimsExclusiveAccess() async throws {
        let pty = try Self.makePty()
        defer { Darwin.close(pty.masterFD) }

        let port = Self.port(pty.slavePath)
        try await port.open()
        #expect(await port.hasExclusiveAccess, "TIOCEXCL was not accepted")

        await port.close()
        #expect(await port.hasExclusiveAccess == false)
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
