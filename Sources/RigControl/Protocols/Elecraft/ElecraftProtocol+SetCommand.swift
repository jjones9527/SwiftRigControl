import Foundation

// MARK: - Set-command verification
//
// Elecraft radios answer set commands with nothing. Hamlib drives them
// through `kenwood_transaction`, which follows each set with `ID;` and
// reads that reply; a `?;`, `N;`, `E;` or `O;` ahead of it is the
// radio rejecting the set (`kenwood.c:400-443`, `655-700`). `RX`, `RU`,
// `RD`, `PS` and `K22` skip the check (`kenwood.c:402-422`).
//
// Before v1.2.19 the K3 / K3S / K4 / KX2 / KX3 path read one reply after
// each set and, for frequency, mode, power, VFO and RIT, required it to
// echo the command ("K3/K4 and newer radios echo SET commands"). They
// don't, so each of those sets should have timed out and thrown even
// though the radio applied it.
//
// The K2 path is unchanged: it writes and waits `k2CommandDelay`, the
// behaviour the K2 hardware validation ran against. Hamlib verifies K2
// sets with `ID;` too; moving the K2 over waits for a hardware re-check
// (ROADMAP 5.8.1).

extension ElecraftProtocol {

    /// Commands Hamlib writes without the `ID;` check.
    static let unverifiedSetPrefixes = ["RX", "RU", "RD", "PS", "K22"]

    /// Replies read while waiting for the `ID` reply: one error reply
    /// plus a few unsolicited frames.
    static let verifyReplySkipBudget = 4

    /// Sends a set command and confirms the radio accepted it.
    ///
    /// - Parameter command: The set command, without the `;` terminator.
    /// - Throws: `RigError.commandFailed` for `?;`,
    ///   `RigError.unsupportedOperation` for `N;`,
    ///   `RigError.serialPortError` for `E;`, `RigError.invalidResponse`
    ///   for `O;` or when no `ID` reply arrives, and `RigError.timeout` if
    ///   the radio doesn't answer at all.
    func sendSetCommand(_ command: String) async throws {
        try await sendCommand(command)

        if isK2 {
            try await Task.sleep(nanoseconds: k2CommandDelay)
            return
        }
        if Self.unverifiedSetPrefixes.contains(where: { command.hasPrefix($0) }) {
            return
        }

        try await sendCommand("ID")
        for _ in 0..<Self.verifyReplySkipBudget {
            let reply = try await receiveResponse()
            if reply.hasPrefix("ID") {
                return
            }

            let failure: RigError
            switch reply {
            case "?":
                failure = .commandFailed("Radio rejected \(command);")
            case "N":
                failure = .unsupportedOperation("Radio does not support \(command);")
            case "E":
                failure = .serialPortError("Radio reported a communication error for \(command);")
            case "O":
                failure = .invalidResponse
            default:
                // Unsolicited auto-information (kenwood.c:686-696); keep reading.
                continue
            }

            // The radio still answers the ID; that followed the rejected
            // command. Consume it so the next transaction starts clean.
            _ = try? await receiveResponse()
            throw failure
        }
        throw RigError.invalidResponse
    }
}
