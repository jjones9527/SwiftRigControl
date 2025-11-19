import Foundation
import IOKit
import IOKit.serial

#if os(macOS)
import Darwin

/// IOKit-based serial port implementation for macOS.
///
/// This actor provides thread-safe serial port communication using IOKit and termios.
/// It is optimized for CAT control of amateur radio transceivers.
public actor IOKitSerialPort: SerialTransport {
    private let configuration: SerialConfiguration
    private var fileDescriptor: Int32 = -1
    private var originalTermios: termios?

    public nonisolated var isOpen: Bool {
        get async {
            await _isOpen
        }
    }

    private var _isOpen: Bool {
        fileDescriptor >= 0
    }

    /// Initializes a new serial port.
    ///
    /// - Parameter configuration: The serial port configuration
    public init(configuration: SerialConfiguration) {
        self.configuration = configuration
    }

    /// Opens the serial port and configures it for use.
    ///
    /// This method:
    /// 1. Opens the device file
    /// 2. Saves the original termios settings
    /// 3. Configures the port for raw mode
    /// 4. Sets baud rate, data bits, stop bits, and parity
    ///
    /// - Throws: `RigError.serialPortError` if the port cannot be opened or configured
    public func open() async throws {
        guard fileDescriptor < 0 else {
            // Already open
            return
        }

        // Open the serial port
        fileDescriptor = Darwin.open(configuration.path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fileDescriptor >= 0 else {
            throw RigError.serialPortError("Cannot open \(configuration.path): \(String(cString: strerror(errno)))")
        }

        // Save original termios settings
        var termios = Darwin.termios()
        guard tcgetattr(fileDescriptor, &termios) == 0 else {
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
            throw RigError.serialPortError("Cannot get terminal attributes: \(String(cString: strerror(errno)))")
        }
        originalTermios = termios

        // Configure for raw mode
        cfmakeraw(&termios)

        // Set baud rate
        let baudRate = speed_t(configuration.baudRate)
        cfsetispeed(&termios, baudRate)
        cfsetospeed(&termios, baudRate)

        // Set data bits
        termios.c_cflag &= ~tcflag_t(CSIZE)
        switch configuration.dataBits {
        case 5: termios.c_cflag |= tcflag_t(CS5)
        case 6: termios.c_cflag |= tcflag_t(CS6)
        case 7: termios.c_cflag |= tcflag_t(CS7)
        case 8: termios.c_cflag |= tcflag_t(CS8)
        default:
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
            throw RigError.serialPortError("Invalid data bits: \(configuration.dataBits)")
        }

        // Set stop bits
        if configuration.stopBits == 2 {
            termios.c_cflag |= tcflag_t(CSTOPB)
        } else {
            termios.c_cflag &= ~tcflag_t(CSTOPB)
        }

        // Set parity
        switch configuration.parity {
        case .none:
            termios.c_cflag &= ~tcflag_t(PARENB)
        case .even:
            termios.c_cflag |= tcflag_t(PARENB)
            termios.c_cflag &= ~tcflag_t(PARODD)
        case .odd:
            termios.c_cflag |= tcflag_t(PARENB)
            termios.c_cflag |= tcflag_t(PARODD)
        }

        // Enable receiver, ignore modem control lines
        termios.c_cflag |= tcflag_t(CREAD | CLOCAL)

        // Disable hardware flow control
        if !configuration.hardwareFlowControl {
            termios.c_cflag &= ~tcflag_t(CRTSCTS)
        } else {
            termios.c_cflag |= tcflag_t(CRTSCTS)
        }

        // Disable software flow control
        if !configuration.softwareFlowControl {
            termios.c_iflag &= ~tcflag_t(IXON | IXOFF | IXANY)
        }

        // Non-canonical mode, no echo
        termios.c_lflag &= ~tcflag_t(ICANON | ECHO | ECHOE | ISIG)

        // No output processing
        termios.c_oflag &= ~tcflag_t(OPOST)

        // Set read timeout (VTIME is in deciseconds)
        termios.c_cc.16 = 1  // VTIME = 0.1 second
        termios.c_cc.17 = 0  // VMIN = 0 (non-blocking read)

        // Apply settings
        guard tcsetattr(fileDescriptor, TCSANOW, &termios) == 0 else {
            if let original = originalTermios {
                var orig = original
                tcsetattr(fileDescriptor, TCSANOW, &orig)
            }
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
            throw RigError.serialPortError("Cannot set terminal attributes: \(String(cString: strerror(errno)))")
        }

        // Flush any existing data
        try await flush()
    }

    /// Closes the serial port and restores original settings.
    public func close() async {
        guard fileDescriptor >= 0 else {
            return
        }

        // Restore original termios settings
        if var original = originalTermios {
            tcsetattr(fileDescriptor, TCSANOW, &original)
        }

        Darwin.close(fileDescriptor)
        fileDescriptor = -1
        originalTermios = nil
    }

    /// Writes data to the serial port.
    ///
    /// - Parameter data: The data to write
    /// - Throws: `RigError.serialPortError` if write fails
    public func write(_ data: Data) async throws {
        guard fileDescriptor >= 0 else {
            throw RigError.notConnected
        }

        let bytesWritten = data.withUnsafeBytes { buffer in
            Darwin.write(fileDescriptor, buffer.baseAddress, data.count)
        }

        guard bytesWritten == data.count else {
            throw RigError.serialPortError("Write failed: \(String(cString: strerror(errno)))")
        }

        // Ensure data is transmitted
        tcdrain(fileDescriptor)
    }

    /// Reads data from the serial port with a timeout.
    ///
    /// - Parameter timeout: Maximum time to wait in seconds
    /// - Returns: The data read
    /// - Throws: `RigError.timeout` if no data received
    public func read(timeout: TimeInterval) async throws -> Data {
        guard fileDescriptor >= 0 else {
            throw RigError.notConnected
        }

        var buffer = [UInt8](repeating: 0, count: 4096)
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            let bytesRead = Darwin.read(fileDescriptor, &buffer, buffer.count)

            if bytesRead > 0 {
                return Data(buffer[..<bytesRead])
            } else if bytesRead < 0 && errno != EAGAIN && errno != EWOULDBLOCK {
                throw RigError.serialPortError("Read failed: \(String(cString: strerror(errno)))")
            }

            // Brief sleep to avoid busy-waiting
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        throw RigError.timeout
    }

    /// Reads data until a terminator byte is encountered.
    ///
    /// This is particularly useful for protocols like Icom CI-V that use 0xFD as a frame terminator.
    ///
    /// - Parameters:
    ///   - terminator: The byte that marks the end of a frame
    ///   - timeout: Maximum time to wait for complete frame
    /// - Returns: The complete frame including the terminator
    /// - Throws: `RigError.timeout` if frame not received within timeout
    public func readUntil(terminator: UInt8, timeout: TimeInterval) async throws -> Data {
        guard fileDescriptor >= 0 else {
            throw RigError.notConnected
        }

        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 1)
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            let bytesRead = Darwin.read(fileDescriptor, &buffer, 1)

            if bytesRead == 1 {
                result.append(buffer[0])
                if buffer[0] == terminator {
                    return result
                }
            } else if bytesRead < 0 && errno != EAGAIN && errno != EWOULDBLOCK {
                throw RigError.serialPortError("Read failed: \(String(cString: strerror(errno)))")
            }

            // Brief sleep to avoid busy-waiting
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }

        throw RigError.timeout
    }

    /// Flushes input and output buffers.
    public func flush() async throws {
        guard fileDescriptor >= 0 else {
            throw RigError.notConnected
        }

        tcflush(fileDescriptor, TCIOFLUSH)
    }
}

#else
// Non-macOS platforms get a stub implementation
public actor IOKitSerialPort: SerialTransport {
    public var isOpen: Bool { false }

    public init(configuration: SerialConfiguration) {
        fatalError("IOKitSerialPort is only available on macOS")
    }

    public func open() async throws {
        throw RigError.serialPortError("IOKitSerialPort is only available on macOS")
    }

    public func close() async {}
    public func write(_ data: Data) async throws {}
    public func read(timeout: TimeInterval) async throws -> Data { Data() }
    public func readUntil(terminator: UInt8, timeout: TimeInterval) async throws -> Data { Data() }
    public func flush() async throws {}
}
#endif
