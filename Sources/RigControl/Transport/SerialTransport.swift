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

    public enum Parity: String, Sendable {
        case none
        case even
        case odd
    }

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
