import Foundation

/// Errors that can occur during rig control operations.
public enum RigError: Error, LocalizedError, Sendable {
    /// Radio is not connected. Call connect() first.
    case notConnected

    /// The specified radio model is not supported.
    case unsupportedRadio(String)

    /// A command sent to the radio failed.
    case commandFailed(String)

    /// Operation timed out waiting for radio response.
    case timeout

    /// Received invalid or unexpected response from radio.
    case invalidResponse

    /// Serial port operation failed.
    case serialPortError(String)

    /// Radio is busy or cannot accept the command.
    case busy

    /// The requested feature is not supported by this radio.
    case unsupportedOperation(String)

    /// Invalid parameter provided.
    case invalidParameter(String)

    /// Frequency is outside the radio's capabilities.
    case frequencyOutOfRange(UInt64, model: String)

    /// Transmit is not allowed on this frequency.
    case transmitNotAllowed(UInt64, reason: String)

    /// Operating mode is not supported at this frequency.
    case modeNotSupported(Mode, frequency: UInt64)

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Radio is not connected. Call connect() first."
        case .unsupportedRadio(let model):
            return "Radio model '\(model)' is not supported."
        case .commandFailed(let reason):
            return "Command failed: \(reason)"
        case .timeout:
            return "Operation timed out. Check cable connection and radio power."
        case .invalidResponse:
            return "Received invalid response from radio."
        case .serialPortError(let message):
            return "Serial port error: \(message)"
        case .busy:
            return "Radio is busy and cannot accept the command."
        case .unsupportedOperation(let operation):
            return "Operation '\(operation)' is not supported by this radio."
        case .invalidParameter(let message):
            return "Invalid parameter: \(message)"
        case .frequencyOutOfRange(let freq, let model):
            let mhz = Double(freq) / 1_000_000.0
            return String(format: "Frequency %.3f MHz is outside %@ capabilities", mhz, model)
        case .transmitNotAllowed(let freq, let reason):
            let mhz = Double(freq) / 1_000_000.0
            return String(format: "Transmit not allowed on %.3f MHz: %@", mhz, reason)
        case .modeNotSupported(let mode, let freq):
            let mhz = Double(freq) / 1_000_000.0
            return String(format: "Mode %@ not supported at %.3f MHz", mode.rawValue, mhz)
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .frequencyOutOfRange:
            return "Check the radio's manual for valid frequency ranges"
        case .transmitNotAllowed:
            return "This frequency is receive-only or outside amateur bands"
        case .modeNotSupported:
            return "Use a different mode for this frequency"
        default:
            return nil
        }
    }
}
