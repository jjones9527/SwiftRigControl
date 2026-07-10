import Foundation

/// Protocol for serial port communication with radio transceivers.
///
/// This protocol abstracts the underlying serial port implementation,
/// allowing for different backends (IOKit, mock for testing, etc.)
public protocol SerialTransport: Actor {
    /// Opens the serial port connection.
    ///
    /// - Throws: `RigError.serialPortError` if port cannot be opened
    func open() async throws

    /// Closes the serial port connection.
    func close() async

    /// Writes data to the serial port.
    ///
    /// - Parameter data: The data to write
    /// - Throws: `RigError.serialPortError` if write fails
    func write(_ data: Data) async throws

    /// Reads data from the serial port.
    ///
    /// - Parameter timeout: Maximum time to wait for data in seconds
    /// - Returns: The data read from the port
    /// - Throws: `RigError.timeout` if no data received within timeout
    func read(timeout: TimeInterval) async throws -> Data

    /// Reads data until a specific terminator byte is found.
    ///
    /// - Parameters:
    ///   - terminator: The byte that marks the end of a frame
    ///   - timeout: Maximum time to wait for complete frame
    /// - Returns: The complete frame including the terminator
    /// - Throws: `RigError.timeout` if frame not received within timeout
    func readUntil(terminator: UInt8, timeout: TimeInterval) async throws -> Data

    /// Checks if the port is currently open.
    var isOpen: Bool { get async }

    /// Flushes any pending data in input and output buffers.
    func flush() async throws

    /// Drives the DTR (Data Terminal Ready) modem control line.
    ///
    /// `open()` on a serial transport de-asserts DTR by default so that
    /// radios which use DTR as a hardware PTT signal (some Yaesu HF
    /// models with Menu 048 set to DTR, TS-590 with DTR-as-PTT, etc.)
    /// do not key on connect. Call this method with `true` only if a
    /// specific device requires DTR asserted for RX or for legacy
    /// PTT-via-DTR keying.
    ///
    /// Transports that have no modem control lines (e.g. TCP) implement
    /// this as a no-op.
    ///
    /// - Parameter enabled: `true` to assert DTR, `false` to de-assert.
    /// - Throws: `RigError.serialPortError` if the port is not open or
    ///   the underlying ioctl fails.
    func setDTR(_ enabled: Bool) async throws

    /// Drives the RTS (Request To Send) modem control line.
    ///
    /// `open()` on a serial transport de-asserts RTS by default so that
    /// radios which use RTS as a hardware PTT signal (Yaesu FT-DX10,
    /// FT-DX101, FT-991A, FT-450D, and many earlier HF models) do not
    /// key on connect. Call this method with `true` only if a specific
    /// device legitimately requires RTS asserted.
    ///
    /// Transports that have no modem control lines (e.g. TCP) implement
    /// this as a no-op.
    ///
    /// - Parameter enabled: `true` to assert RTS, `false` to de-assert.
    /// - Throws: `RigError.serialPortError` if the port is not open or
    ///   the underlying ioctl fails.
    func setRTS(_ enabled: Bool) async throws
}

/// Configuration for serial port connections.
public struct SerialConfiguration: Sendable {
    /// Path to the serial device (e.g., "/dev/cu.usbserial-A1B2C3")
    public let path: String

    /// Baud rate (bits per second)
    public let baudRate: Int

    /// Data bits (typically 8)
    public let dataBits: Int

    /// Stop bits (typically 1)
    public let stopBits: Int

    /// Parity (none, even, odd)
    public let parity: Parity

    /// Hardware flow control (RTS/CTS)
    public let hardwareFlowControl: Bool

    /// Software flow control (XON/XOFF)
    public let softwareFlowControl: Bool

    /// Serial-port parity setting. Almost every amateur-radio
    /// CAT interface uses `.none`; check the manufacturer's
    /// programmer reference if you're unsure.
    public enum Parity: String, Sendable {
        /// No parity bit. Default for all SwiftRigControl-supported radios.
        case none
        /// Even parity.
        case even
        /// Odd parity.
        case odd
    }

    /// Builds a new serial-port configuration.
    ///
    /// - Parameters:
    ///   - path: Device path (e.g. `"/dev/cu.usbserial-A1B2C3"`).
    ///   - baudRate: Bits per second. Each `RadioDefinition` ships
    ///     a `defaultBaudRate` you can use here when unsure.
    ///   - dataBits: Bits per character. 8 for every supported radio.
    ///   - stopBits: Stop bits. 1 for every supported radio.
    ///   - parity: Parity setting. `.none` for every supported radio.
    ///   - hardwareFlowControl: Enable RTS/CTS hardware flow control.
    ///   - softwareFlowControl: Enable XON/XOFF software flow control.
    public init(
        path: String,
        baudRate: Int = 9600,
        dataBits: Int = 8,
        stopBits: Int = 1,
        parity: Parity = .none,
        hardwareFlowControl: Bool = false,
        softwareFlowControl: Bool = false
    ) {
        self.path = path
        self.baudRate = baudRate
        self.dataBits = dataBits
        self.stopBits = stopBits
        self.parity = parity
        self.hardwareFlowControl = hardwareFlowControl
        self.softwareFlowControl = softwareFlowControl
    }
}
