import Foundation

// MARK: - CW text (Hamlib kenwood_send_morse / kenwood_stop_morse)
//
// KY + text in 24-character chunks, after polling KY; for buffer space
// (KYMorseSending). The chunk form is KenwoodLevelProfile.cwMessageForm:
// "KY %-24s" by default, "KY %24s" on the TS-590S, "KY2%s" on the
// TS-890S. Stop is KY0 (kenwood.c:5717).

extension KenwoodProtocol: KYMorseSending, SupportsSendCW {

    public func sendCW(_ text: String) async throws {
        try requireSendCW()
        let form = levelProfile.cwMessageForm
        try await sendKYMorse(text) { chunk in
            switch form {
            case .leftPadded:  return "KY " + kyPadded(chunk, rightAligned: false)
            case .rightPadded: return "KY " + kyPadded(chunk, rightAligned: true)
            case .variable:    return "KY2" + chunk
            }
        }
    }

    public func stopCW() async throws {
        try requireSendCW()
        try await sendSetCommand("KY0")
    }

    private func requireSendCW() throws {
        guard capabilities.supportsSendCW else {
            throw RigError.unsupportedOperation("CW text send not supported by this radio")
        }
    }
}
