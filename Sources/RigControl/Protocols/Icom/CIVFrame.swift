import Foundation

/// Represents an Icom CI-V protocol frame.
///
/// CI-V frames have the following structure:
/// ```
/// [FE FE] [to] [from] [command] [data...] [FD]
/// ```
///
/// - Preamble: 0xFE 0xFE
/// - To: Destination address (radio's CI-V address)
/// - From: Source address (typically 0xE0 for PC)
/// - Command: One or more command bytes
/// - Data: Optional command-specific data
/// - Terminator: 0xFD
///
/// All command byte constants, mode codes, and filter codes are defined in
/// `CIVFrameConstants.swift` as extensions on this type.
public struct CIVFrame {
    /// Frame preamble (always 0xFE 0xFE)
    public static let preamble: [UInt8] = [0xFE, 0xFE]

    /// Frame terminator (always 0xFD)
    public static let terminator: UInt8 = 0xFD

    /// Default controller (PC) address
    public static let controllerAddress: UInt8 = 0xE0

    /// ACK response byte (0xFB)
    public static let ack: UInt8 = 0xFB

    /// NAK (negative acknowledgment) response byte (0xFA)
    public static let nak: UInt8 = 0xFA

    /// Destination address
    public let to: UInt8

    /// Source address
    public let from: UInt8

    /// Command bytes
    public let command: [UInt8]

    /// Data bytes
    public let data: [UInt8]

    /// Initializes a new CI-V frame.
    ///
    /// - Parameters:
    ///   - to: Destination address
    ///   - from: Source address (defaults to controller address 0xE0)
    ///   - command: Command bytes
    ///   - data: Optional data bytes
    public init(to: UInt8, from: UInt8 = controllerAddress, command: [UInt8], data: [UInt8] = []) {
        self.to = to
        self.from = from
        self.command = command
        self.data = data
    }

    /// Converts the frame to a byte array ready for transmission.
    ///
    /// - Returns: Complete frame as byte array
    public func bytes() -> [UInt8] {
        var result = CIVFrame.preamble
        result.append(to)
        result.append(from)
        result.append(contentsOf: command)
        result.append(contentsOf: data)
        result.append(CIVFrame.terminator)
        return result
    }

    /// Parses a CI-V frame from received data.
    ///
    /// - Parameter data: Raw frame data including preamble and terminator
    /// - Returns: Parsed frame
    /// - Throws: `RigError.invalidResponse` if frame is malformed
    public static func parse(_ data: Data) throws -> CIVFrame {
        let bytes = [UInt8](data)

        // Minimum frame: FE FE to from command FD = 6 bytes
        guard bytes.count >= 6 else {
            throw RigError.invalidResponse
        }

        // Check preamble
        guard bytes[0] == preamble[0] && bytes[1] == preamble[1] else {
            throw RigError.invalidResponse
        }

        // Check terminator
        guard bytes.last == terminator else {
            throw RigError.invalidResponse
        }

        let to = bytes[2]
        let from = bytes[3]

        // Extract command and data.
        // Command is at least 1 byte; data is everything between command and terminator.
        let commandAndData = Array(bytes[4..<(bytes.count - 1)])

        guard !commandAndData.isEmpty else {
            throw RigError.invalidResponse
        }

        // Some commands carry a sub-command byte as their second byte.
        // Commands 0x14 (settings), 0x15 (read level), and 0x1C (PTT) always use sub-commands.
        let firstByte = commandAndData[0]
        let hasSubCommand = (firstByte == 0x14 || firstByte == 0x15 || firstByte == 0x1C)
                         && commandAndData.count > 1

        let command: [UInt8]
        let frameData: [UInt8]

        if hasSubCommand {
            // Multi-byte command (e.g., 0x14 0x0A for RF power, 0x15 0x02 for S-meter)
            command = [commandAndData[0], commandAndData[1]]
            frameData = commandAndData.count > 2 ? Array(commandAndData[2...]) : []
        } else {
            // Single-byte command
            command = [commandAndData[0]]
            frameData = commandAndData.count > 1 ? Array(commandAndData[1...]) : []
        }

        return CIVFrame(to: to, from: from, command: command, data: frameData)
    }

    /// True when this frame is an ACK (acknowledgment from the radio).
    public var isAck: Bool {
        command.count == 1 && command[0] == CIVFrame.ack
    }

    /// True when this frame is a NAK (negative acknowledgment from the radio).
    public var isNak: Bool {
        command.count == 1 && command[0] == CIVFrame.nak
    }

    /// True when this frame is an echo of a command the controller sent.
    ///
    /// Some radios (IC-7100, IC-705) echo every command back to the bus before
    /// sending their actual response.  Echo frames originate from the controller
    /// address (0xE0) and are directed at the radio's CI-V address.
    public var isEcho: Bool {
        from == CIVFrame.controllerAddress && to != CIVFrame.controllerAddress
    }
}
