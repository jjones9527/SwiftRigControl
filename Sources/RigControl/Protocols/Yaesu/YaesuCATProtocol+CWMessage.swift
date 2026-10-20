import Foundation

extension YaesuCATProtocol {
    /// Sends text through the FTX-1's built-in CW message keyer.
    ///
    /// Hamlib writes arbitrary text into keyer-memory slot 5 with `KM5`,
    /// then starts that slot with `KY05`. A one-character value from 1...5
    /// is treated as a request to play the corresponding existing memory.
    public func sendCW(_ text: String) async throws {
        guard capabilities.supportsSendCW, quirks.usesFTX1ClarifierCommands else {
            throw RigError.unsupportedOperation("CW text send not supported by this radio")
        }

        let message = String(text.uppercased().unicodeScalars
            .filter(\.isASCII)
            .map(Character.init)
            .prefix(50))

        if message.count == 1, let slot = Int(message), (1...5).contains(slot) {
            try await sendCommand("KY0\(slot)")
            return
        }

        guard !message.isEmpty else {
            throw RigError.invalidParameter("CW message must contain ASCII text")
        }

        try await sendCommand("KM5\(message)")
        try await sendCommand("KY05")
    }

    /// Stops FTX-1 CW-message playback (`KY00`).
    public func stopCW() async throws {
        guard capabilities.supportsSendCW, quirks.usesFTX1ClarifierCommands else {
            throw RigError.unsupportedOperation("CW text send not supported by this radio")
        }
        try await sendCommand("KY00")
    }
}
