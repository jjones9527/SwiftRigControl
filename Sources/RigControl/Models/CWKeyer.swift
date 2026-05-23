import Foundation

/// CW (Morse code) break-in mode.
///
/// Break-in (also called QSK on some radios) controls how the
/// transceiver switches between TX and RX while sending CW. Most
/// modern radios support three discrete modes:
///
/// - ``off`` — semi-break-in disabled. The operator must use PTT
///   or VOX to switch into transmit.
/// - ``semi`` — TX is engaged when the key first closes; the radio
///   stays in TX for a configurable delay after the last element,
///   then drops back to RX.
/// - ``full`` — TX is engaged element-by-element. The radio drops
///   back to RX between dots and dashes, so the operator can hear
///   the other station even mid-transmission (true QSK).
///
/// ## Hamlib parity
///
/// Hamlib models these as two function bits — `RIG_FUNC_SBKIN`
/// (semi) and `RIG_FUNC_FBKIN` (full) — with the absence of both
/// meaning "off." On Icom CI-V, the underlying command is a single
/// sub-command (0x16 0x47) that takes a discrete byte: 0x00 / 0x01 /
/// 0x02. SwiftRigControl exposes the discrete states directly since
/// that matches the operator's mental model and the radio's wire
/// protocol better than a pair of toggles.
public enum BreakInMode: String, Sendable, Equatable, CaseIterable {
    /// Break-in disabled. Use PTT or VOX to TX.
    case off
    /// Semi-break-in. TX engages on first element, drops after delay.
    case semi
    /// Full break-in (QSK). TX drops between every element.
    case full
}

/// CW keyer speed in words per minute (WPM).
///
/// Most Icom radios support 6–48 WPM in discrete steps; the wire
/// protocol uses a 0–255 byte that's mapped through a lookup table
/// to the actual WPM value (see Hamlib's `cw_lookup[43][2]` in
/// `rigs/icom/icom.c`). SwiftRigControl exposes the WPM value
/// directly and handles the lookup internally.
///
/// Values outside `6...48` are clamped on send.
public struct CWSpeed: Sendable, Equatable, ExpressibleByIntegerLiteral {
    /// Words per minute. Always within `6...48` after construction
    /// (out-of-range inputs are clamped).
    public let wpm: Int

    /// Builds a CW speed value, clamping `wpm` into `6...48`.
    public init(wpm: Int) {
        self.wpm = max(6, min(wpm, 48))
    }

    /// Convenience: `let speed: CWSpeed = 28`.
    public init(integerLiteral value: Int) {
        self.init(wpm: value)
    }
}

/// CW sidetone pitch in Hz.
///
/// Most Icom radios support 300–900 Hz in 5 Hz increments; the wire
/// protocol uses a 0–255 byte calculated as
/// `(Hz − 300) × 255 / 600`, then BCD-encoded.
///
/// Values outside `300...900` are clamped on send.
public struct CWPitch: Sendable, Equatable, ExpressibleByIntegerLiteral {
    /// Frequency in Hz. Always within `300...900` after construction
    /// (out-of-range inputs are clamped).
    public let hz: Int

    /// Builds a CW pitch value, clamping `hz` into `300...900`.
    public init(hz: Int) {
        self.hz = max(300, min(hz, 900))
    }

    /// Convenience: `let pitch: CWPitch = 600`.
    public init(integerLiteral value: Int) {
        self.init(hz: value)
    }
}
