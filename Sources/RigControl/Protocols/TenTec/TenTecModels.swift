import Foundation

/// Ten-Tec radio models supported by SwiftRigControl.
///
/// Ten-Tec used two distinct CAT protocol families:
/// - **Orion family**: Binary-framed `*`/`?`/`@` protocol (TT-565, TT-599)
/// - **Legacy family**: Simple ASCII `M`/`N`/`W` protocol (Jupiter TT-538, Pegasus TT-550)
public enum TenTecModel: String, CaseIterable, Sendable {
    // MARK: - Orion Family (binary-framed protocol)

    /// Ten-Tec Orion (TT-565) — HF/6m flagship, dual receiver
    case orion = "Orion (TT-565)"

    /// Ten-Tec Orion II (TT-599) — updated flagship with improved DSP
    case orionII = "Orion II (TT-599)"

    /// Ten-Tec Eagle (TT-599) — single-receiver Orion variant
    case eagle = "Eagle (TT-599)"

    // MARK: - Legacy Family (simple ASCII protocol)

    /// Ten-Tec Jupiter (TT-538) — compact HF transceiver
    case jupiter = "Jupiter (TT-538)"

    /// Ten-Tec Pegasus (TT-550) — SDR-based HF transceiver
    case pegasus = "Pegasus (TT-550)"

    /// Which protocol family this model uses
    public var protocolFamily: TenTecProtocolFamily {
        switch self {
        case .orion, .orionII, .eagle:
            return .orion
        case .jupiter, .pegasus:
            return .legacy
        }
    }

    /// Default baud rate for this model
    public var defaultBaudRate: Int {
        switch self {
        case .orion, .orionII, .eagle:
            return 57600
        case .jupiter, .pegasus:
            return 38400
        }
    }

    /// Whether this model has a sub-receiver
    public var hasDualReceiver: Bool {
        switch self {
        case .orion, .orionII:
            return true
        case .eagle, .jupiter, .pegasus:
            return false
        }
    }
}

/// Ten-Tec protocol family selector
public enum TenTecProtocolFamily: Sendable {
    /// Orion-family: binary-framed `*`/`?`/`@` commands (TT-565, TT-599)
    case orion
    /// Legacy ASCII: `M`/`N`/`W` commands (Jupiter, Pegasus)
    case legacy
}
