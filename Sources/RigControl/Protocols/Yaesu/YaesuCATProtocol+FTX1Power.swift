import Foundation

// FTX-1 RF power. The FTX-1's `PC` carries a head digit before the
// watts: `PC1nnn;` on the field head (0.5-10 W) and `PC2nnn;` with the
// Optima / SPA-1 amplifier (5-100 W). Hamlib `ftx1_set_power` /
// `ftx1_get_power` (`ftx1/ftx1_audio.c:310-455`). Through v1.3.1 we sent
// the plain newcat `PCnnn;` and read the head digit as part of the watts
// (`PC1005` read as 100 W).
//
// Known divergence: rigctld `L RFPOWER` scales by the catalog's 100 W, so
// on a field head `0.5` asks for 50 W (clamped to 10 W) where Hamlib sends
// 5 W (fraction of the head's own maximum).

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
        guard let watts = Double(body.dropFirst()), watts.isFinite, watts >= 0 else {
            throw RigError.invalidResponse
        }
        return (head, Int(watts.rounded()))
    }
}
