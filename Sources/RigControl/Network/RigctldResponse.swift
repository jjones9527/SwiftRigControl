import Foundation

/// Formats responses for rigctld protocol.
///
/// Supports both Default and Extended response protocols:
/// - **Default Protocol**: Minimal responses with just the data
/// - **Extended Protocol**: Verbose responses with command echo and return codes
///
/// ## Examples
///
/// ### Default Protocol
/// ```
/// Client: f\n
/// Server: 14230000\n
/// ```
///
/// ### Extended Protocol
/// ```
/// Client: \get_freq\n
/// Server: get_freq: 14230000\n
/// Server: RPRT 0\n
/// ```
public struct RigctldResponse {
    /// Response data
    public let data: [String]

    /// Command that was executed (for extended protocol)
    public let command: RigctldCommand?

    /// Return code (for extended protocol)
    public let returnCode: RigctldProtocol.ReturnCode

    /// Response separator character
    private static let separator = "\n"

    /// Create a successful response
    ///
    /// - Parameters:
    ///   - data: Response data lines
    ///   - command: Command that was executed (optional, for extended protocol)
    public init(data: [String], command: RigctldCommand? = nil) {
        self.data = data
        self.command = command
        self.returnCode = .ok
    }

    /// Create a successful response with single value
    ///
    /// - Parameters:
    ///   - value: Response value
    ///   - command: Command that was executed (optional, for extended protocol)
    public init(value: String, command: RigctldCommand? = nil) {
        self.data = [value]
        self.command = command
        self.returnCode = .ok
    }

    /// Create an error response
    ///
    /// - Parameters:
    ///   - returnCode: Error code
    ///   - command: Command that was executed (optional, for extended protocol)
    public init(error returnCode: RigctldProtocol.ReturnCode, command: RigctldCommand? = nil) {
        self.data = []
        self.command = command
        self.returnCode = returnCode
    }

    /// Format response for default protocol
    ///
    /// Returns minimal response with just the data, one value per line.
    ///
    /// - Returns: Formatted response string
    public func formatDefault() -> String {
        if returnCode != .ok {
            // For errors in default protocol, return empty or error code
            return returnCode.description + Self.separator
        }

        return data.joined(separator: Self.separator) + Self.separator
    }

    /// Format response for extended protocol
    ///
    /// Returns verbose response with command echo, data, and return code.
    ///
    /// - Returns: Formatted response string
    public func formatExtended() -> String {
        var lines: [String] = []

        // Echo command with data if present
        if let command = command {
            if data.isEmpty {
                lines.append("\(command.longName):")
            } else {
                lines.append("\(command.longName): \(data.joined(separator: " "))")
            }
        } else if !data.isEmpty {
            // No command echo, just data
            lines.append(contentsOf: data)
        }

        // Append return code
        lines.append(returnCode.description)

        return lines.joined(separator: Self.separator) + Self.separator
    }

    /// Format response based on protocol mode
    ///
    /// - Parameter mode: Response protocol mode
    /// - Returns: Formatted response string
    public func format(mode: RigctldProtocol.ResponseMode) -> String {
        switch mode {
        case .default:
            return formatDefault()
        case .extended:
            return formatExtended()
        }
    }
}

/// Helper for creating common responses
public extension RigctldResponse {
    /// Create frequency response
    static func frequency(_ hz: UInt64, command: RigctldCommand? = nil) -> RigctldResponse {
        RigctldResponse(value: String(hz), command: command)
    }

    /// Create mode response
    static func mode(_ mode: String, passband: Int, command: RigctldCommand? = nil) -> RigctldResponse {
        RigctldResponse(data: [mode, String(passband)], command: command)
    }

    /// Create VFO response
    static func vfo(_ vfo: String, command: RigctldCommand? = nil) -> RigctldResponse {
        RigctldResponse(value: vfo, command: command)
    }

    /// Create PTT response
    static func ptt(_ enabled: Bool, command: RigctldCommand? = nil) -> RigctldResponse {
        RigctldResponse(value: enabled ? "1" : "0", command: command)
    }

    /// Create split VFO response
    static func splitVFO(enabled: Bool, txVFO: String, command: RigctldCommand? = nil) -> RigctldResponse {
        RigctldResponse(data: [enabled ? "1" : "0", txVFO], command: command)
    }

    /// Create power response
    static func power(_ watts: Int, command: RigctldCommand? = nil) -> RigctldResponse {
        RigctldResponse(value: String(watts), command: command)
    }

    /// Create OK response (for set commands)
    static func ok(command: RigctldCommand? = nil) -> RigctldResponse {
        RigctldResponse(data: [], command: command)
    }

    /// Create error response
    static func error(_ code: RigctldProtocol.ReturnCode, command: RigctldCommand? = nil) -> RigctldResponse {
        RigctldResponse(error: code, command: command)
    }
}
