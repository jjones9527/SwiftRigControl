import Foundation

/// The `KY` CW-text loop shared by the Kenwood and Elecraft protocols.
///
/// Hamlib `kenwood_send_morse` (`kenwood.c`): text goes out 24 characters
/// at a time. Before each chunk, `KY;` is polled until the radio answers
/// `KY0` (buffer space) or `KY2` (buffer space, not sending); `KY1` means
/// busy, so wait 50 ms and ask again. Any other reply is an error.
protocol KYMorseSending: Actor {
    func sendCommand(_ command: String) async throws
    func receiveResponse() async throws -> String
    func sendSetCommand(_ command: String) async throws
}

extension KYMorseSending {
    /// Sends `text` as `KY` chunks built by `format`.
    ///
    /// - Parameters:
    ///   - text: The message; upper-cased, ASCII only.
    ///   - format: Builds the command for one chunk of up to 24 characters.
    func sendKYMorse(_ text: String, format: (String) -> String) async throws {
        let message = String(text.uppercased().unicodeScalars.filter(\.isASCII).map(Character.init))
        guard !message.isEmpty else {
            throw RigError.invalidParameter("CW message must contain ASCII text")
        }
        var rest = Substring(message)
        while !rest.isEmpty {
            try await waitForKYBuffer()
            let chunk = rest.prefix(24)
            rest = rest.dropFirst(chunk.count)
            try await sendSetCommand(format(String(chunk)))
        }
    }

    /// Polls `KY;` until the keyer buffer has room (about 10 s at most).
    private func waitForKYBuffer() async throws {
        for _ in 0..<200 {
            try await sendCommand("KY")
            let reply = try await receiveResponse()
            if reply.hasPrefix("KY0") || reply.hasPrefix("KY2") { return }
            guard reply.hasPrefix("KY1") else { throw RigError.invalidResponse }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw RigError.timeout
    }
}

/// Pads a `KY` chunk to Hamlib's 24 characters.
func kyPadded(_ chunk: String, rightAligned: Bool) -> String {
    let pad = String(repeating: " ", count: max(0, 24 - chunk.count))
    return rightAligned ? pad + chunk : chunk + pad
}
