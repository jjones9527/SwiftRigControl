import Foundation

// MARK: - On/off reply parsing
//
// `FT`, `TQ`, `RT` and `XT` answer with the command letters and one
// digit: `FT1;`, `TQ0;`. Before v1.2.20 we checked only the prefix and
// treated any third character other than `1` as off, so a garbled or
// truncated reply (`FT;`, `TQ1x;`, a K4 extended reply) read as a
// valid "off". Hamlib rejects these since `ffe227a3` / `900c4d3`
// (`parse_binary_response`, `elecraft.c:594-608`): exactly the two
// command letters, then `0` or `1`, then nothing.

extension ElecraftProtocol {

    /// Parses a two-letter on/off reply such as `FT1` or `TQ0`.
    ///
    /// - Parameters:
    ///   - response: The reply with its `;` removed.
    ///   - command: The two-letter command that was sent.
    /// - Returns: `true` for `1`, `false` for `0`.
    /// - Throws: `RigError.invalidResponse` for anything else.
    static func parseOnOffReply(_ response: String, command: String) throws -> Bool {
        switch response {
        case command + "1": return true
        case command + "0": return false
        default: throw RigError.invalidResponse
        }
    }
}
