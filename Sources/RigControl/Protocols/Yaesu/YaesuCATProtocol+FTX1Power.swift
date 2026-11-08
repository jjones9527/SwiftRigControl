import Foundation

// FTX-1 RF power. The FTX-1's `PC` carries a head digit before the
// watts: `PC1nnn;` on the field head (0.5-10 W) and `PC2nnn;` with the
// Optima / SPA-1 amplifier (5-100 W). Hamlib `ftx1_set_power` /
// `ftx1_get_power` (`ftx1/ftx1_audio.c:310-455`). Through v1.3.1 we sent
// the plain newcat `PCnnn;` and read the head digit as part of the watts
// (`PC1005` read as 100 W).
//
// rigctld fractions use the detected head's maximum (10 W or 100 W).
// Battery versus 12 V cannot be determined from PC alone; we retain the
// non-invasive 12 V assumption instead of probing by changing power.

extension YaesuCATProtocol {

    /// Which FTX-1 head a `PC` reply came from.
    enum FTX1PowerHead: Equatable {
        /// Field head, `PC1`: 0.5-10 W (6 W on battery).
        case field
        /// Optima / SPA-1 amplifier, `PC2`: 5-100 W.
        case spa1
    }

    /// Sets FTX-1 power in watts, in the form the attached head takes.
    ///
    /// Reads `PC;` first to find the head, as Hamlib does when it hasn't
    /// detected it at open (`ftx1_audio.c:327-349`). Hamlib's open also
    /// probes battery against 12 V by setting 8 W; we don't change the
    /// radio's power on connect, so a field head on battery rejects
    /// anything above 6 W.
    ///
    /// - Parameter watts: Output power. Clamped to 5-100 W on the SPA-1
    ///   and 0.5-10 W on the field head, where 0 sends Hamlib's 0.5 W
    ///   minimum (`PC10.5;`).
    func setFTX1Power(_ watts: Int) async throws {
        try await sendCommand("PC")
        let head = try Self.parseFTX1Power(try await receiveResponse()).head
        try await sendSetCommand(Self.ftx1PowerCommand(watts: watts, head: head))
    }

    /// Internal rigctld path; nil means this radio uses the catalog scale.
    func setDynamicPowerFraction(_ fraction: Double) async throws -> Int? {
        guard quirks.usesFTX1PowerCommands else { return nil }
        guard fraction.isFinite, (0...1).contains(fraction) else {
            throw RigError.invalidParameter("Power fraction must be between 0 and 1")
        }
        try await sendCommand("PC")
        let head = try Self.parseFTX1PowerReading(try await receiveResponse()).head
        let watts = head == .field ? max(0.5, fraction * 10) : max(5, fraction * 100)
        let command: String
        if head == .field {
            // Hamlib ftx1_audio.c:386-395 preserves tenths on the field head.
            let rounded = (watts * 10).rounded() / 10
            command = rounded == rounded.rounded()
                ? Self.ftx1PowerCommand(watts: Int(rounded), head: head)
                : String(format: "PC1%.1f", locale: Locale(identifier: "en_US_POSIX"), rounded)
        } else {
            command = Self.ftx1PowerCommand(watts: Int(watts), head: head)
        }
        try await sendSetCommand(command)
        return head == .field ? Int(watts.rounded()) : Int(watts)
    }

    /// Reads the head and fractional watts together to avoid stale scaling.
    func dynamicPowerFraction() async throws -> Double? {
        guard quirks.usesFTX1PowerCommands else { return nil }
        try await sendCommand("PC")
        let reading = try Self.parseFTX1PowerReading(try await receiveResponse())
        return reading.watts / (reading.head == .field ? 10 : 100)
    }

    /// The `PC` set command for `watts` on `head` (`ftx1_audio.c:352-395`).
    static func ftx1PowerCommand(watts: Int, head: FTX1PowerHead) -> String {
        switch head {
        case .spa1:
            return String(format: "PC2%03d", min(max(watts, 5), 100))
        case .field:
            return watts < 1 ? "PC10.5" : String(format: "PC1%03d", min(watts, 10))
        }
    }

    /// Parses an FTX-1 `PC` reply (without the `;`): `PC1005`, `PC10.5`
    /// or `PC2050`.
    ///
    /// - Returns: The head, and the power rounded to whole watts
    /// - Throws: `RigError.invalidResponse` if the reply isn't one of
    ///   those forms
    static func parseFTX1Power(_ response: String) throws -> (head: FTX1PowerHead, watts: Int) {
        let reading = try parseFTX1PowerReading(response)
        return (reading.head, Int(reading.watts.rounded()))
    }

    private static func parseFTX1PowerReading(_ response: String) throws -> (head: FTX1PowerHead, watts: Double) {
        guard response.hasPrefix("PC"), response.count >= 4 else {
            throw RigError.invalidResponse
        }
        let body = response.dropFirst(2)
        let head: FTX1PowerHead
        switch body.first {
        case "1": head = .field
        case "2": head = .spa1
        default: throw RigError.invalidResponse
        }
        let value = body.dropFirst()
        // Field heads also report fractional watts (ftx1_audio.c:410-415).
        // Reject exponent notation, signs and oversized values before any
        // conversion to the public API's integer watts.
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        let whole = value.count == 3 && value.allSatisfy { $0.isASCII && $0.isNumber }
        let decimal = head == .field && parts.count == 2
            && (1...2).contains(parts[0].count) && parts[1].count == 1
            && parts.allSatisfy { $0.allSatisfy { $0.isASCII && $0.isNumber } }
        guard whole || decimal,
              let watts = Double(value),
              (head == .field ? 0.5...10.0 : 5.0...100.0).contains(watts) else {
            throw RigError.invalidResponse
        }
        return (head, watts)
    }
}
