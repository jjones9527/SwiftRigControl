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
public struct CIVFrame {
    /// Frame preamble (always 0xFE 0xFE)
    public static let preamble: [UInt8] = [0xFE, 0xFE]

    /// Frame terminator (always 0xFD)
    public static let terminator: UInt8 = 0xFD

    /// Default controller (PC) address
    public static let controllerAddress: UInt8 = 0xE0

    /// ACK response
    public static let ack: UInt8 = 0xFB

    /// NAK (negative acknowledgment) response
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

        // Extract command and data
        // Command is at least 1 byte, data is everything between command and terminator
        let commandAndData = Array(bytes[4..<(bytes.count - 1)])

        guard !commandAndData.isEmpty else {
            throw RigError.invalidResponse
        }

        // Some commands have sub-commands (second byte)
        // Commands 0x14 (settings), 0x15 (read level), and 0x1C (PTT) use sub-commands
        let firstByte = commandAndData[0]
        let hasSubCommand = (firstByte == 0x14 || firstByte == 0x15 || firstByte == 0x1C) && commandAndData.count > 1

        let command: [UInt8]
        let frameData: [UInt8]

        if hasSubCommand {
            // Multi-byte command (e.g., 0x14 0x0A or 0x15 0x02)
            command = [commandAndData[0], commandAndData[1]]
            frameData = commandAndData.count > 2 ? Array(commandAndData[2...]) : []
        } else {
            // Single-byte command
            command = [commandAndData[0]]
            frameData = commandAndData.count > 1 ? Array(commandAndData[1...]) : []
        }

        return CIVFrame(to: to, from: from, command: command, data: frameData)
    }

    /// Checks if this frame is an acknowledgment (ACK).
    public var isAck: Bool {
        command.count == 1 && command[0] == CIVFrame.ack
    }

    /// Checks if this frame is a negative acknowledgment (NAK).
    public var isNak: Bool {
        command.count == 1 && command[0] == CIVFrame.nak
    }

    /// Checks if this frame is an echo (command from controller to radio).
    /// Echo frames have 'from' address as controller (0xE0) and minimal/no data.
    /// Some radios (IC-7100, IC-705) echo commands back before sending actual response.
    public var isEcho: Bool {
        // Echo is from controller (0xE0) to radio, with same command we sent
        return from == CIVFrame.controllerAddress && to != CIVFrame.controllerAddress
    }
}

// MARK: - CI-V Command Constants

extension CIVFrame {
    /// Common CI-V command codes
    public enum Command {
        /// Read operating frequency (0x03)
        public static let readFrequency: UInt8 = 0x03

        /// Read operating mode (0x04)
        public static let readMode: UInt8 = 0x04

        /// Set operating frequency (0x05)
        public static let setFrequency: UInt8 = 0x05

        /// Set operating mode (0x06)
        public static let setMode: UInt8 = 0x06

        /// Select VFO mode (0x07)
        public static let selectVFO: UInt8 = 0x07

        /// Split operation (0x0F)
        public static let split: UInt8 = 0x0F

        /// Set/get various settings (0x14)
        public static let settings: UInt8 = 0x14

        /// Read levels (S-meter, squelch, etc.) (0x15)
        public static let readLevel: UInt8 = 0x15

        /// PTT control (0x1C)
        public static let ptt: UInt8 = 0x1C
    }

    /// VFO selection sub-commands (used with Command.selectVFO)
    public enum VFOSelect {
        /// Select VFO A (0x00)
        public static let vfoA: UInt8 = 0x00

        /// Select VFO B (0x01)
        public static let vfoB: UInt8 = 0x01

        /// Select main receiver (0xD0)
        public static let main: UInt8 = 0xD0

        /// Select sub receiver (0xD1)
        public static let sub: UInt8 = 0xD1
    }

    /// Mode codes (used with Command.setMode/readMode)
    public enum ModeCode {
        public static let lsb: UInt8 = 0x00
        public static let usb: UInt8 = 0x01
        public static let am: UInt8 = 0x02
        public static let cw: UInt8 = 0x03
        public static let rtty: UInt8 = 0x04
        public static let fm: UInt8 = 0x05
        public static let wfm: UInt8 = 0x06
        public static let cwR: UInt8 = 0x07
        public static let rttyR: UInt8 = 0x08
    }

    /// Level reading sub-commands (used with Command.readLevel)
    public enum LevelRead {
        /// Read S-meter (0x02)
        public static let sMeter: UInt8 = 0x02

        /// Read squelch level (0x01)
        public static let squelch: UInt8 = 0x01

        /// RF power level (used with Command.settings 0x14 for get/set) (0x0A)
        public static let rfPower: UInt8 = 0x0A

        /// Read RF power meter (0x11)
        public static let rfPowerMeter: UInt8 = 0x11
    }
}
