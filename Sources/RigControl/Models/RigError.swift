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
        }
    }
}
