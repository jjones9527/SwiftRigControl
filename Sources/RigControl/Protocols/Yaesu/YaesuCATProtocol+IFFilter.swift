import Foundation

// MARK: - IF filter (newcat `SH`)
//
// Moved out of YaesuCATProtocol+LevelControls.swift to keep that file
// under the 500-line cap. No behavior change.

extension YaesuCATProtocol {

    // MARK: - IF Filter

    /// Sets the IF filter (DSP passband width).
    ///
    /// The exact `SH` wire format is dispatched via
    /// ``YaesuCATProtocol/Quirks/filterCommandStyle`` per Hamlib
    /// `rigs/yaesu/newcat.c:9202-9220`. Four variants exist:
    ///
    /// | Style | Wire format | Radios |
    /// | --- | --- | --- |
    /// | `.qualifierOnly` | `SH%c%02d;` | FT-950, FT-991(A), FTDX-5000/1200/9000, FT-450(D) |
    /// | `.zeroWithoutQualifier` | `SH0%02d;` | FT-2000, FTDX-3000 |
    /// | `.doubleZero` | `SH00%02d;` | FTDX-10, FT-710, FTX-1 |
    /// | `.vfoAndNarrow` | `SH%c%d%02d;` | FTDX-101D/MP (real flag), FT-891 (flag always `1`) |
    ///
    /// Prior to the v1.2.2 quirks refactor every radio emitted
    /// `SH0%02d;` — correct for the FT-2000 family but rejected by
    /// FTDX-10/101/710/FTX-1/891.
    ///
    /// This implementation always addresses VFO `0` (main) — the
    /// Swift `IFFilter` API has no sub-VFO parameter.
    ///
    /// Filter slot mapping (high-cut code, per Hamlib bandwidth
    /// tables in `rigs/yaesu/newcat.c` — SSB defaults):
    /// - `.filter1` → 7 (wide, ~3000 Hz)
    /// - `.filter2` → 5 (medium, ~2400 Hz)
    /// - `.filter3` → 2 (narrow, ~1500 Hz)
    ///
    /// - Parameter filter: The desired IF filter slot
    /// - Throws: `RigError` if the command fails
    public func setIFFilter(_ filter: IFFilter) async throws {
        let highCut: Int
        switch filter {
        case .filter1: highCut = 7   // wide
        case .filter2: highCut = 5   // medium
        case .filter3: highCut = 2   // narrow
        }
        let command: String
        switch quirks.filterCommandStyle {
        case .qualifierOnly:
            command = String(format: "SH0%02d", highCut)
        case .zeroWithoutQualifier:
            command = String(format: "SH0%02d", highCut)
        case .doubleZero:
            command = String(format: "SH00%02d", highCut)
        case .vfoAndNarrow:
            // Both FTDX-101 (real on/off flag) and FT-891 (always
            // on) code paths send `1` here — the Swift IFFilter API
            // has no "bandwidth off" state to communicate.
            command = String(format: "SH01%02d", highCut)
        }
        try await sendSetCommand(command)
    }

    /// Gets the current IF filter by reading the DSP high-cut setting.
    ///
    /// Per Hamlib `newcat.c:9477-9486` the get form is `SH0;` for
    /// `.zeroWithoutQualifier` and `.doubleZero` radios (FT-2000,
    /// FTDX-3000, FTDX-10, FT-710) and `SH%c;` for everything else.
    /// The FTX-1 falls into the `SH%c;` bucket on the get side even
    /// though it uses `SH00%02d;` on the set side — matches Hamlib.
    ///
    /// Response is `SH<qualifier><2-digit high-cut>;` for
    /// non-narrow-flag radios or `SH<qualifier><flag><2-digit>;` for
    /// FTDX-101 / FT-891. This implementation reads the last two
    /// digits before the terminator so both response widths decode.
    ///
    /// - Returns: The closest matching filter slot
    /// - Throws: `RigError` if the command fails
    public func getIFFilter() async throws -> IFFilter {
        let query: String
        switch quirks.filterCommandStyle {
        case .zeroWithoutQualifier, .doubleZero:
            query = "SH0"
        case .qualifierOnly, .vfoAndNarrow:
            query = "SH0"
        }
        try await sendCommand(query)
        let response = try await receiveResponse()
        guard response.hasPrefix("SH"), response.count >= 5 else {
            throw RigError.invalidResponse
        }
        // The last two ASCII digits before the semicolon (or end of
        // response) encode the high-cut. This handles both the 6-char
        // (`SHXnn`) and 7-char (`SHXYnn`) response widths.
        let trimmed = response.hasSuffix(";")
            ? String(response.dropLast())
            : response
        let tail = trimmed.suffix(2)
        guard let code = Int(tail) else { throw RigError.invalidResponse }
        switch code {
        case 0...3: return .filter3   // narrow
        case 4...6: return .filter2   // medium
        default:    return .filter1   // wide
        }
    }
}
