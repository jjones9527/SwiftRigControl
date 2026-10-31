import Foundation

extension YaesuCATProtocol {
    /// Sends text through the radio's CW message keyer.
    ///
    /// Newcat radios (Hamlib `newcat_send_morse`, `newcat.c:7304-7387`)
    /// load the text into keyer memory 1 with `KM1` and play it with
    /// `KY6`. A single digit 1-5 plays that stored message instead: `KY6`
    /// to `KYA`, or `KY1` to `KY5` on the FT-710; the FT-450 has 1-3.
    /// Text is upper-cased ASCII, up to 50 characters.
    ///
    /// The FTX-1 uses keyer memory 5: `KM5` then `KY05` (Hamlib
    /// `ftx1_cw.c`).
    ///
    /// Through v1.3.1 only the FTX-1 could send CW, and the check was the
    /// FTX-1 clarifier quirk, which the FT-710 also sets.
    public func sendCW(_ text: String) async throws {
        guard capabilities.supportsSendCW else {
            throw RigError.unsupportedOperation("CW text send not supported by this radio")
        }

        let message = String(text.uppercased().unicodeScalars
            .filter(\.isASCII)
            .map(Character.init)
            .prefix(50))
        guard !message.isEmpty else {
            throw RigError.invalidParameter("CW message must contain ASCII text")
        }
        let slot = message.count == 1 ? Int(message) : nil

        switch quirks.cwMessageStyle {
        case .ftx1:
            if let slot, (1...5).contains(slot) {
                try await sendCommand("KY0\(slot)")
                return
            }
            try await sendCommand("KM5\(message)")
            try await sendCommand("KY05")

        case .newcat(let count, let playsSlotsDirectly):
            if let slot {
                guard (1...count).contains(slot) else {
                    throw RigError.invalidParameter("Stored CW messages are 1-\(count)")
                }
                let code = playsSlotsDirectly ? slot : slot + 5
                try await sendSetCommand("KY" + String(code, radix: 16).uppercased())
                return
            }
            try await sendSetCommand("KM1\(message)")
            try await sendSetCommand("KY6")
        }
    }

    /// Stops FTX-1 CW-message playback (`KY00`). Hamlib has no stop for
    /// the other newcat radios, so they throw.
    public func stopCW() async throws {
        guard capabilities.supportsSendCW, quirks.cwMessageStyle == .ftx1 else {
            throw RigError.unsupportedOperation("Stopping CW playback is not supported by this radio")
        }
        try await sendCommand("KY00")
    }
}
