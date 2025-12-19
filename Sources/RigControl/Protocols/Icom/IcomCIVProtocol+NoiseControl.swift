import Foundation

/// Noise Blanker and Noise Reduction control for Icom radios.
///
/// This extension provides a unified interface for controlling noise blanker and noise reduction
/// across different Icom radio models. Different radios have different capabilities:
///
/// ## Noise Blanker (NB)
/// - **IC-7600, IC-7300, IC-7610, IC-7851, IC-7800, IC-7700**: On/Off only
/// - **IC-9700, IC-7100, IC-705**: On/Off with level control (0-255)
///
/// ## Noise Reduction (NR)
/// - **IC-7600, IC-7300, IC-7610, IC-7851, IC-7800, IC-7700**: On/Off with level control (0-255)
/// - **IC-9700, IC-7100, IC-705**: On/Off with level control (0-255)
///
/// ## Commands
/// - **NB On/Off**: 0x16 0x22 [0x00=OFF, 0x01=ON]
/// - **NB Level**: 0x14 0x12 [level BCD] (IC-7100, IC-705)
/// - **NR On/Off**: 0x16 0x40 [0x00=OFF, 0x01=ON]
/// - **NR Level**: 0x14 0x06 [level BCD]
extension IcomCIVProtocol {
    // MARK: - Noise Blanker

    /// Set noise blanker configuration.
    ///
    /// Controls the impulse noise blanker which removes power line noise, ignition noise, and static crashes.
    ///
    /// - Parameter config: Desired noise blanker configuration
    /// - Throws: `RigError.invalidParameter` if level not supported on this radio
    /// - Throws: `RigError.commandFailed` if radio rejects the command
    public func setNoiseBlanker(_ config: NoiseBlanker) async throws {
        switch config {
        case .off:
            // Turn off NB using common command
            try await setNoiseBlanker(false)

        case .enabled(let level):
            // First enable NB
            try await setNoiseBlanker(true)

            // Then set level if provided and supported
            if let level = level {
                guard supportsNBLevel else {
                    throw RigError.invalidParameter("NB level control not supported on \(radioModel.rawValue)")
                }

                guard level >= 0 && level <= 255 else {
                    throw RigError.invalidParameter("NB level must be 0-255, got \(level)")
                }

                try await setNBLevel(UInt8(level))
            }
        }
    }

    /// Get current noise blanker configuration.
    ///
    /// - Returns: Current noise blanker configuration
    /// - Throws: `RigError.invalidResponse` if response is malformed
    public func getNoiseBlanker() async throws -> NoiseBlanker {
        // Use the existing Boolean method from CommonCommands
        let enabled = try await getNoiseBlankerState()

        guard enabled else {
            return .off
        }

        // If enabled and radio supports level control, read the level
        if supportsNBLevel {
            let level = try await getNBLevel()
            return .enabled(level: Int(level))
        } else {
            return .enabled(level: nil)
        }
    }

    // MARK: - Noise Reduction

    /// Set noise reduction configuration.
    ///
    /// Controls the DSP noise reduction filter which reduces continuous background noise.
    ///
    /// - Parameter config: Desired noise reduction configuration
    /// - Throws: `RigError.invalidParameter` if level out of range
    /// - Throws: `RigError.commandFailed` if radio rejects the command
    public func setNoiseReduction(_ config: NoiseReduction) async throws {
        switch config {
        case .off:
            // Turn off NR using common command
            try await setNoiseReduction(false)

        case .enabled(let level):
            // Validate level range
            guard level >= 0 && level <= 255 else {
                throw RigError.invalidParameter("NR level must be 0-255, got \(level)")
            }

            // First enable NR
            try await setNoiseReduction(true)

            // Then set the level
            try await setNRLevel(UInt8(level))
        }
    }

    /// Get current noise reduction configuration.
    ///
    /// - Returns: Current noise reduction configuration
    /// - Throws: `RigError.invalidResponse` if response is malformed
    public func getNoiseReduction() async throws -> NoiseReduction {
        // Use the existing Boolean method from CommonCommands
        let enabled = try await getNoiseReductionState()

        guard enabled else {
            return .off
        }

        // If enabled, read the level
        let level = try await getNRLevel()
        return .enabled(level: Int(level))
    }

    // MARK: - Private Helpers

    /// Whether this radio supports NB level control.
    private var supportsNBLevel: Bool {
        switch radioModel {
        case .ic9700, .ic7100, .ic705:
            return true
        case .ic7600, .ic7300, .ic7610, .ic7851, .ic7800, .ic7700:
            return false
        default:
            return false
        }
    }

    /// Set NB level (for radios that support it).
    private func setNBLevel(_ level: UInt8) async throws {
        switch radioModel {
        case .ic9700, .ic705:
            // These radios use the same NB level command as IC-7100
            // Command: 0x14 0x12 [level BCD]
            let bcdLevel = [UInt8(level % 10) | (UInt8(level / 10) << 4), UInt8(level / 100)]
            let frame = CIVFrame(
                to: civAddress,
                command: [0x14, 0x12],
                data: bcdLevel
            )
            try await sendFrame(frame)
            let response = try await receiveFrame()
            guard response.isAck else {
                throw RigError.commandFailed("NB level command rejected")
            }

        case .ic7100:
            // Use existing IC-7100 specific method
            try await setNBLevelIC7100(level)

        default:
            throw RigError.unsupportedOperation("NB level control not supported on \(radioModel.rawValue)")
        }
    }

    /// Get NB level (for radios that support it).
    private func getNBLevel() async throws -> UInt8 {
        switch radioModel {
        case .ic9700, .ic705:
            // Command: 0x14 0x12 (read)
            let frame = CIVFrame(
                to: civAddress,
                command: [0x14, 0x12],
                data: []
            )
            try await sendFrame(frame)
            let response = try await receiveFrame()
            guard response.command.count >= 2, response.data.count == 2 else {
                throw RigError.invalidResponse
            }
            let lo = response.data[0] & 0x0F
            let hi = (response.data[0] >> 4) * 10
            let hundreds = response.data[1] * 100
            return lo + hi + hundreds

        case .ic7100:
            // Use existing IC-7100 specific method
            return try await getNBLevelIC7100()

        default:
            throw RigError.unsupportedOperation("NB level control not supported on \(radioModel.rawValue)")
        }
    }
}
