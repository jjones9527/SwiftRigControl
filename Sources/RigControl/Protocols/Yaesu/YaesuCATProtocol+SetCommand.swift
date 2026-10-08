import Foundation

// MARK: - Set-command verification
//
// Yaesu newcat radios don't answer set commands. A rejected command
// answers `?;` (or `N;`, `E;`, `O;`) and an accepted one answers
// nothing, so Hamlib follows most sets with a cheap query (`ID;`, or
// `AI;` on the FTDX-9000) and reads until that query's reply arrives
// (`newcat_set_cmd`, `newcat.c:10911-11095`):
//
// - `FA`, `FB`, `TX`, `MD` and `ST` are written with no read at all
//   (`newcat.c:10966-10973`: frequency and PTT are checked elsewhere,
//   `MD` is too slow on Win4Yaesu, `ST` caused problems on the
//   FTDX101D).
// - `AC` (tuner) is sent once and drained through the query reply,
//   never resent (`newcat_set_ac_cmd`, `newcat.c:10802-10899`,
//   upstream `635d11fe`).
// - Everything else is verified; `?;` means busy, so the command is
//   resent (`newcat.c:11034-11075`).
//
// Before v1.2.19 almost every set read one reply, expecting an echo
// ("Yaesu radios echo the command back"). Real radios don't echo, so
// each set should have waited out the 1 s timeout and thrown even
// though the radio applied it — and a rejected `?;` was taken as success.

extension YaesuCATProtocol {

    /// Set commands Hamlib writes without reading anything back.
    static let unverifiedSetPrefixes: Set<String> = ["FA", "FB", "TX", "MD", "ST"]

    /// Replies read while waiting for the verification reply. Covers
    /// one error reply plus a few unsolicited frames.
    static let verifyReplyFrameBudget = 4

    /// Attempts for a verified set command. Hamlib resends while the
    /// radio answers `?;` ("busy, retry"), up to the port's retry count.
    static let setCommandAttempts = 2

    /// Sends a set command the way Hamlib's `newcat_set_cmd` does.
    ///
    /// - Parameter command: The command without its `;` terminator.
    /// - Throws: `RigError.commandFailed` if the radio keeps answering
    ///   `?;`, `RigError.unsupportedOperation` on `N;`,
    ///   `RigError.serialPortError` on `E;`, `RigError.invalidResponse`
    ///   on `O;` or when the verification reply never arrives, and
    ///   `RigError.timeout` if the radio doesn't answer the query.
    func sendSetCommand(_ command: String) async throws {
        let prefix = String(command.prefix(2))
        if Self.unverifiedSetPrefixes.contains(prefix) {
            try await sendCommand(command)
            return
        }
        if prefix == "AC" {
            try await sendTunerCommand(command)
            return
        }

        var lastError = RigError.invalidResponse
        for _ in 0..<Self.setCommandAttempts {
            // Discard anything unsolicited, as Hamlib does before each try.
            try await transport.flush()
            try await sendCommand(command)
            try await sendCommand(quirks.verifyCommand)

            switch try await readVerification(after: command) {
            case .accepted:
                return
            case .retry(let error):
                lastError = error
            case .failed(let error):
                throw error
            }
        }
        throw lastError
    }

    private enum Verification {
        case accepted
        case retry(RigError)
        case failed(RigError)
    }

    /// Reads replies until the verification query's reply arrives.
    private func readVerification(after command: String) async throws -> Verification {
        for _ in 0..<Self.verifyReplyFrameBudget {
            let reply: String
            do {
                reply = try await receiveResponse()
            } catch RigError.timeout {
                return .retry(.timeout)
            }

            if reply.hasPrefix(quirks.verifyCommand) {
                return .accepted
            }
            guard let error = Self.errorReply(reply, command: command) else {
                // An unsolicited frame (auto-information left on);
                // keep reading for the query reply.
                continue
            }
            // The query's own reply is still queued behind the error;
            // read it so the next transaction starts clean.
            _ = try? await receiveResponse()
            if case .unsupportedOperation(_) = error {
                return .failed(error)   // "N": the radio can't do it
            }
            return .retry(error)
        }
        return .retry(.invalidResponse)
    }

    /// Sends an `AC` (antenna tuner) command once and drains its
    /// replies through the verification query, as Hamlib
    /// `newcat_set_ac_cmd` does. Not resent: an `AC002;` that was
    /// accepted starts a tune cycle.
    private func sendTunerCommand(_ command: String) async throws {
        try await transport.flush()
        try await sendCommand(command)
        try await sendCommand(quirks.verifyCommand)

        var result: RigError?
        for _ in 0..<Self.verifyReplyFrameBudget {
            let reply = try await receiveResponse()
            if reply.hasPrefix(quirks.verifyCommand) {
                if let result { throw result }
                return
            }
            // Hamlib counts any other reply as a protocol error, but
            // keeps reading so the query reply is consumed.
            result = Self.errorReply(reply, command: command) ?? .invalidResponse
        }
        throw RigError.invalidResponse
    }

    /// Maps a two-character error reply (`?;`, `N;`, `E;`, `O;`, read
    /// without the terminator) to a `RigError`, or `nil` for anything
    /// else (`newcat.c:10868-10889`, `11008-11075`).
    private static func errorReply(_ reply: String, command: String) -> RigError? {
        switch reply {
        case "?":
            return .commandFailed("Radio rejected \(command);")
        case "N":
            return .unsupportedOperation("Radio does not accept \(command);")
        case "E":
            return .serialPortError("Radio reported a communication error for \(command);")
        case "O":
            return .invalidResponse
        default:
            return nil
        }
    }
}
