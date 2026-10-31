import Foundation

// MARK: - CW text (Hamlib kenwood_send_morse, k3_stop_morse, k4_stop_morse)
//
// KY + text in 24-character chunks after polling KY; (KYMorseSending).
// K3 / K3S / KX2 / KX3: "KY %s", stop "KY \u{04};". K4: Hamlib's default
// "KY %-24s", stop "KY @;". K2: "KY %-24s", no stop command.

extension ElecraftProtocol: KYMorseSending, SupportsSendCW {

    public func sendCW(_ text: String) async throws {
        try requireSendCW()
        let form = cwMessageForm
        try await sendKYMorse(text) { chunk in
            form == .k3 ? "KY " + chunk : "KY " + kyPadded(chunk, rightAligned: false)
        }
    }

    public func stopCW() async throws {
        try requireSendCW()
        switch cwMessageForm {
        case .k3: try await sendSetCommand("KY \u{04}")
        case .k4: try await sendSetCommand("KY @")
        case .k2: throw RigError.unsupportedOperation("The K2 has no CAT command to stop CW")
        }
    }

    private func requireSendCW() throws {
        guard capabilities.supportsSendCW else {
            throw RigError.unsupportedOperation("CW text send not supported by this radio")
        }
    }
}
