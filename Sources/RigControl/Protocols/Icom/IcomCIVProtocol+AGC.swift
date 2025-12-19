import Foundation

/// AGC (Automatic Gain Control) support for Icom radios.
///
/// This extension provides unified AGC control across all Icom radios that support it.
/// Different Icom models have slightly different AGC implementations:
///
/// - **IC-7600, IC-7300, IC-7610, IC-7851**: Fast (1), Medium (2), Slow (3)
/// - **IC-9700, IC-7100, IC-705**: Off (0), Fast (1), Medium (2), Slow (3)
///
/// The implementation automatically maps the generic AGCSpeed enum to radio-specific codes.
extension IcomCIVProtocol {
    // MARK: - Unified AGC Control

    /// Sets the AGC speed for Icom radios.
    ///
    /// Automatically maps AGCSpeed enum to radio-specific codes and handles differences
    /// between radio models (some support OFF, others don't).
    ///
    /// - Parameter speed: The desired AGC speed
    /// - Throws: `RigError.invalidParameter` if speed not supported by this radio
    /// - Throws: `RigError.commandFailed` if radio rejects the command
    public func setAGC(_ speed: AGCSpeed) async throws {
        // Get radio-specific AGC code
        guard let code = agcCode(for: speed) else {
            throw RigError.invalidParameter("\(speed.rawValue) AGC not supported on \(radioModel.rawValue)")
        }

        // Use radio-specific setter
        switch radioModel {
        case .ic9700:
            try await setAGCIC9700(code)
        case .ic7610, .ic7300, .ic7600, .ic7851, .ic7800, .ic7700:
            try await setAGCIC7600(code)
        case .ic7100, .ic705:
            try await setAGCIC7100(code)
        default:
            throw RigError.unsupportedOperation("AGC control not implemented for \(radioModel.rawValue)")
        }
    }

    /// Gets the current AGC speed from Icom radios.
    ///
    /// Automatically reads radio-specific AGC code and maps it to the unified AGCSpeed enum.
    ///
    /// - Returns: Current AGC speed
    /// - Throws: `RigError.commandFailed` if unable to read AGC setting
    public func getAGC() async throws -> AGCSpeed {
        // Read radio-specific AGC code
        let code: UInt8
        switch radioModel {
        case .ic9700:
            code = try await getAGCIC9700()
        case .ic7610, .ic7300, .ic7600, .ic7851, .ic7800, .ic7700:
            code = try await getAGCIC7600()
        case .ic7100, .ic705:
            code = try await getAGCIC7100()
        default:
            throw RigError.unsupportedOperation("AGC control not implemented for \(radioModel.rawValue)")
        }

        // Map code to AGCSpeed
        guard let speed = agcSpeed(from: code) else {
            throw RigError.invalidResponse
        }

        return speed
    }

    // MARK: - AGC Mapping

    /// Maps AGCSpeed enum to radio-specific code.
    ///
    /// Returns nil if the speed is not supported by this radio model.
    private func agcCode(for speed: AGCSpeed) -> UInt8? {
        switch radioModel {
        case .ic7600, .ic7300, .ic7610, .ic7851, .ic7800, .ic7700:
            // These radios don't support AGC OFF
            switch speed {
            case .off: return nil  // Not supported
            case .fast: return 1
            case .medium: return 2
            case .slow: return 3
            case .auto: return nil  // Not supported
            }

        case .ic9700, .ic7100, .ic705:
            // These radios support AGC OFF
            switch speed {
            case .off: return 0
            case .fast: return 1
            case .medium: return 2
            case .slow: return 3
            case .auto: return nil  // Not supported
            }

        default:
            return nil
        }
    }

    /// Maps radio-specific code to AGCSpeed enum.
    private func agcSpeed(from code: UInt8) -> AGCSpeed? {
        switch radioModel {
        case .ic7600, .ic7300, .ic7610, .ic7851, .ic7800, .ic7700:
            // No AGC OFF support
            switch code {
            case 1: return .fast
            case 2: return .medium
            case 3: return .slow
            default: return nil
            }

        case .ic9700, .ic7100, .ic705:
            // Has AGC OFF support
            switch code {
            case 0: return .off
            case 1: return .fast
            case 2: return .medium
            case 3: return .slow
            default: return nil
            }

        default:
            return nil
        }
    }
}
