import Foundation

// MARK: - Per-family level scales
//
// The API takes AF gain, RF gain and squelch as 0-255 on every radio.
// Elecraft radios use other wire ranges, and Hamlib scales to them per
// family (rigs/kenwood/k3.c). The K2 keeps the unscaled 0-255 path its
// hardware validation ran against; Hamlib's k2.c declares no AF/RF level
// for it.

extension ElecraftProtocol {

    /// `AG` wire range: K3/K4 0–250 (`k3.c:2008`), KX2/KX3 0–60
    /// (`kx3_set_level`, `k3.c:2402`).
    var afGainRange: ClosedRange<Int> {
        switch family {
        case .k2: return 0...255
        case .k3: return 0...250
        case .kx: return 0...60
        }
    }

    /// `RG` wire range: K3/K4 0–250 (`k3.c:2012`), KX2/KX3 190–250
    /// (`kx3_set_level`, `k3.c:2397`).
    var rfGainRange: ClosedRange<Int> {
        switch family {
        case .k2: return 0...255
        case .k3: return 0...250
        case .kx: return 190...250
        }
    }

    /// `SQ` wire range: 0–29 on the K3 family and KX2/KX3 (`k3.c:2004`).
    var squelchRange: ClosedRange<Int> {
        switch family {
        case .k2: return 0...255
        case .k3, .kx: return 0...29
        }
    }

    /// Maps a 0–255 API level onto `range`, rounding to the nearest step.
    static func toWire(_ level: Int, _ range: ClosedRange<Int>) -> Int {
        let clamped = min(max(level, 0), 255)
        let span = range.upperBound - range.lowerBound
        return range.lowerBound + (clamped * span + 127) / 255
    }

    /// Maps a wire value in `range` back to the 0–255 API level.
    static func fromWire(_ value: Int, _ range: ClosedRange<Int>) -> Int {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        let clamped = min(max(value, range.lowerBound), range.upperBound) - range.lowerBound
        return (clamped * 255 + span / 2) / span
    }
}
