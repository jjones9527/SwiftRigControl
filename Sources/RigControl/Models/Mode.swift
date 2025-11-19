import Foundation

/// Represents operating modes supported by amateur radio transceivers.
///
/// Different modes are used for different types of communication:
/// - Voice modes: AM, FM, SSB (USB/LSB)
/// - Digital modes: RTTY, PSK, FT8 (typically use USB or DATA-USB)
/// - Morse code: CW
public enum Mode: String, Sendable, Codable, CaseIterable {
    /// Lower Side Band (voice, primarily HF below 10 MHz)
    case lsb = "LSB"

    /// Upper Side Band (voice, primarily HF above 10 MHz)
    case usb = "USB"

    /// Continuous Wave (Morse code)
    case cw = "CW"

    /// CW Reverse (Morse code with reversed sideband)
    case cwR = "CW-R"

    /// Frequency Modulation (voice, VHF/UHF)
    case fm = "FM"

    /// Narrow FM (voice, VHF/UHF, typically for repeaters)
    case fmN = "FM-N"

    /// Wide FM (voice, typically for broadcast reception)
    case wfm = "WFM"

    /// Amplitude Modulation (voice, primarily HF)
    case am = "AM"

    /// Radio Teletype (digital)
    case rtty = "RTTY"

    /// RTTY Reverse
    case rttyR = "RTTY-R"

    /// Digital mode (USB-based, for FT8, PSK31, etc.)
    case dataUSB = "DATA-USB"

    /// Digital mode (LSB-based)
    case dataLSB = "DATA-LSB"

    /// Digital FM
    case dataFM = "DATA-FM"
}
