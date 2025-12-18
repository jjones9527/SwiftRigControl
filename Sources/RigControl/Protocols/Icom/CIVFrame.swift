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
    /// IC-7600 CI-V command codes (complete implementation per manual)
    public enum Command {
        // MARK: - Basic Operations
        /// Read band edge frequencies (0x02)
        public static let readBandEdge: UInt8 = 0x02

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

        // MARK: - Memory Operations
        /// Select memory mode (0x08)
        public static let selectMemory: UInt8 = 0x08

        /// Memory write (0x09)
        public static let memoryWrite: UInt8 = 0x09

        /// Memory to VFO (0x0A)
        public static let memoryToVFO: UInt8 = 0x0A

        /// Memory clear (0x0B)
        public static let memoryClear: UInt8 = 0x0B

        // MARK: - Scan Operations
        /// Scan control (0x0E)
        public static let scan: UInt8 = 0x0E

        // MARK: - Control Operations
        /// Split operation (0x0F)
        public static let split: UInt8 = 0x0F

        /// Set tuning step (0x10)
        public static let tuningStep: UInt8 = 0x10

        /// Attenuator (0x11)
        public static let attenuator: UInt8 = 0x11

        /// Antenna selection (0x12)
        public static let antenna: UInt8 = 0x12

        /// Announce (voice) (0x13)
        public static let announce: UInt8 = 0x13

        /// Set/get various settings (0x14)
        public static let settings: UInt8 = 0x14

        /// Read levels (S-meter, squelch, etc.) (0x15)
        public static let readLevel: UInt8 = 0x15

        /// Function settings (0x16)
        public static let function: UInt8 = 0x16

        // MARK: - Advanced Operations
        /// Read transceiver ID (0x19)
        public static let readID: UInt8 = 0x19

        /// Advanced settings (0x1A)
        public static let advancedSettings: UInt8 = 0x1A

        /// Tone control (0x1B)
        public static let tone: UInt8 = 0x1B

        /// PTT control (0x1C)
        public static let ptt: UInt8 = 0x1C

        /// TX frequency band (0x1E)
        public static let txBand: UInt8 = 0x1E
    }

    /// VFO selection sub-commands (used with Command.selectVFO 0x07)
    public enum VFOSelect {
        /// Select VFO A (0x00)
        public static let vfoA: UInt8 = 0x00

        /// Select VFO B (0x01)
        public static let vfoB: UInt8 = 0x01

        /// Exchange main/sub bands (0xB0)
        public static let exchangeBands: UInt8 = 0xB0

        /// Equalize main/sub bands (0xB1)
        public static let equalizeBands: UInt8 = 0xB1

        /// Turn dualwatch OFF (0xC0)
        public static let dualwatchOff: UInt8 = 0xC0

        /// Turn dualwatch ON (0xC1)
        public static let dualwatchOn: UInt8 = 0xC1

        /// Select main receiver (0xD0)
        public static let main: UInt8 = 0xD0

        /// Select sub receiver (0xD1)
        public static let sub: UInt8 = 0xD1
    }

    /// Mode codes (used with Command.setMode/readMode 0x06/0x04)
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
        public static let psk: UInt8 = 0x12
        public static let pskR: UInt8 = 0x13
    }

    /// Filter codes (used with setMode 0x06)
    public enum FilterCode {
        public static let fil1: UInt8 = 0x01
        public static let fil2: UInt8 = 0x02
        public static let fil3: UInt8 = 0x03
    }

    /// Scan sub-commands (used with Command.scan 0x0E)
    public enum ScanCode {
        /// Stop scan (0x00)
        public static let stop: UInt8 = 0x00

        /// Programmed/memory scan start (0x01)
        public static let programmedMemory: UInt8 = 0x01

        /// Programmed scan start (0x02)
        public static let programmed: UInt8 = 0x02

        /// Delta-F scan start (0x03)
        public static let deltaF: UInt8 = 0x03

        /// Fine programmed scan start (0x12)
        public static let fineProgrammed: UInt8 = 0x12

        /// Fine delta-F scan start (0x13)
        public static let fineDeltaF: UInt8 = 0x13

        /// Memory scan start (0x22)
        public static let memory: UInt8 = 0x22

        /// Select memory scan start (0x23)
        public static let selectMemory: UInt8 = 0x23

        /// Scan resume OFF (0xD0)
        public static let resumeOff: UInt8 = 0xD0

        /// Scan resume ON (0xD3)
        public static let resumeOn: UInt8 = 0xD3
    }

    /// Tuning step sub-commands (used with Command.tuningStep 0x10)
    public enum TuningStep {
        public static let step10Hz: UInt8 = 0x00
        public static let step100Hz: UInt8 = 0x01
        public static let step1kHz: UInt8 = 0x02
        public static let step2_5kHz: UInt8 = 0x03
        public static let step5kHz: UInt8 = 0x04
        public static let step9kHz: UInt8 = 0x05
        public static let step10kHz: UInt8 = 0x06
        public static let step12_5kHz: UInt8 = 0x07
        public static let step25kHz: UInt8 = 0x08
    }

    /// Attenuator settings (used with Command.attenuator 0x11)
    public enum AttenuatorCode {
        public static let off: UInt8 = 0x00
        public static let dB6: UInt8 = 0x06
        public static let dB12: UInt8 = 0x12
        public static let dB18: UInt8 = 0x18
    }

    /// Announce sub-commands (used with Command.announce 0x13)
    public enum AnnounceCode {
        public static let all: UInt8 = 0x00
        public static let frequencyAndSMeter: UInt8 = 0x01
        public static let mode: UInt8 = 0x02
    }

    /// Settings sub-commands (used with Command.settings 0x14)
    public enum SettingsCode {
        /// AF level (0x01)
        public static let afLevel: UInt8 = 0x01

        /// RF level (0x02)
        public static let rfLevel: UInt8 = 0x02

        /// Squelch level (0x03)
        public static let squelchLevel: UInt8 = 0x03

        /// NR level (0x06)
        public static let nrLevel: UInt8 = 0x06

        /// Inner TWIN PBT (0x07)
        public static let innerPBT: UInt8 = 0x07

        /// Outer TWIN PBT (0x08)
        public static let outerPBT: UInt8 = 0x08

        /// CW pitch (0x09)
        public static let cwPitch: UInt8 = 0x09

        /// RF power (0x0A)
        public static let rfPower: UInt8 = 0x0A

        /// MIC gain (0x0B)
        public static let micGain: UInt8 = 0x0B

        /// Key speed (0x0C)
        public static let keySpeed: UInt8 = 0x0C

        /// Notch position (0x0D)
        public static let notchPosition: UInt8 = 0x0D

        /// Compression level (0x0E)
        public static let compLevel: UInt8 = 0x0E

        /// Break-in delay (0x0F)
        public static let breakInDelay: UInt8 = 0x0F

        /// Balance position (0x10)
        public static let balance: UInt8 = 0x10

        /// NB level (0x12)
        public static let nbLevel: UInt8 = 0x12

        /// Drive gain (0x14)
        public static let driveGain: UInt8 = 0x14

        /// Monitor gain (0x15)
        public static let monitorGain: UInt8 = 0x15

        /// VOX gain (0x16)
        public static let voxGain: UInt8 = 0x16

        /// Anti-VOX gain (0x17)
        public static let antiVoxGain: UInt8 = 0x17

        /// Bright level (0x19)
        public static let brightLevel: UInt8 = 0x19
    }

    /// Level reading sub-commands (used with Command.readLevel 0x15)
    public enum LevelRead {
        /// Squelch condition (0x01)
        public static let squelch: UInt8 = 0x01

        /// S-meter (0x02)
        public static let sMeter: UInt8 = 0x02

        /// RF power meter (0x11)
        public static let rfPowerMeter: UInt8 = 0x11

        /// SWR meter (0x12)
        public static let swrMeter: UInt8 = 0x12

        /// ALC meter (0x13)
        public static let alcMeter: UInt8 = 0x13

        /// COMP meter (0x14)
        public static let compMeter: UInt8 = 0x14

        /// VD meter (voltage) (0x15)
        public static let vdMeter: UInt8 = 0x15

        /// ID meter (current) (0x16)
        public static let idMeter: UInt8 = 0x16
    }

    /// Function settings sub-commands (used with Command.function 0x16)
    public enum FunctionCode {
        /// Preamp (0x02)
        public static let preamp: UInt8 = 0x02

        /// AGC (0x12)
        public static let agc: UInt8 = 0x12

        /// Noise blanker (0x22)
        public static let noiseBlanker: UInt8 = 0x22

        /// Audio peak filter (0x32)
        public static let audioPeakFilter: UInt8 = 0x32

        /// Noise reduction (0x40)
        public static let noiseReduction: UInt8 = 0x40

        /// Auto notch (0x41)
        public static let autoNotch: UInt8 = 0x41

        /// Repeater tone (0x42)
        public static let repeaterTone: UInt8 = 0x42

        /// Tone squelch (0x43)
        public static let toneSquelch: UInt8 = 0x43

        /// Speech compressor (0x44)
        public static let speechCompressor: UInt8 = 0x44

        /// Monitor (0x45)
        public static let monitor: UInt8 = 0x45

        /// VOX (0x46)
        public static let vox: UInt8 = 0x46

        /// Break-in (0x47)
        public static let breakIn: UInt8 = 0x47

        /// Manual notch (0x48)
        public static let manualNotch: UInt8 = 0x48

        /// Twin peak filter (0x4F)
        public static let twinPeakFilter: UInt8 = 0x4F

        /// Dial lock (0x50)
        public static let dialLock: UInt8 = 0x50
    }

    /// Preamp settings (used with FunctionCode.preamp)
    public enum PreampCode {
        public static let off: UInt8 = 0x00
        public static let preamp1: UInt8 = 0x01
        public static let preamp2: UInt8 = 0x02
    }

    /// AGC settings (used with FunctionCode.agc)
    public enum AGCCode {
        public static let fast: UInt8 = 0x01
        public static let mid: UInt8 = 0x02
        public static let slow: UInt8 = 0x03
    }

    /// Advanced settings sub-commands (used with Command.advancedSettings 0x1A)
    public enum AdvancedCode {
        /// Memory contents (0x00)
        public static let memoryContents: UInt8 = 0x00

        /// Band stacking register (0x01)
        public static let bandStacking: UInt8 = 0x01

        /// Memory keyer contents (0x02)
        public static let memoryKeyer: UInt8 = 0x02

        /// Filter width (0x03)
        public static let filterWidth: UInt8 = 0x03

        /// AGC time constant (0x04)
        public static let agcTimeConstant: UInt8 = 0x04

        /// Various settings (0x05)
        public static let variousSettings: UInt8 = 0x05
    }

    /// Tone sub-commands (used with Command.tone 0x1B)
    public enum ToneCode {
        /// Repeater tone frequency (0x00)
        public static let repeaterTone: UInt8 = 0x00

        /// Tone squelch frequency (0x01)
        public static let toneSquelch: UInt8 = 0x01
    }
}
