import Foundation

/// Represents a Variable Frequency Oscillator (VFO) on a radio transceiver.
///
/// Most amateur radio transceivers have two VFOs (A and B) that allow monitoring
/// or transmitting on different frequencies. Some radios also support Main/Sub
/// receiver configurations.
public enum VFO: String, Sendable, Codable {
    /// VFO A (primary)
    case a = "A"

    /// VFO B (secondary)
    case b = "B"

    /// Main receiver (for dual-receiver radios)
    case main = "Main"

    /// Sub receiver (for dual-receiver radios)
    case sub = "Sub"
}
