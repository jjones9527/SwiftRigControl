import Foundation

/// Dual receiver radio extensions for Icom radios with Main/Sub architecture.
///
/// This extension provides Main/Sub band selection methods for dual-receiver radios.
/// Available for both 2-state (IC-7600) and 4-state (IC-9700) models.

// MARK: - Band Enum

/// Band selection for dual-receiver radios
public enum Band: String, Sendable {
    case main = "Main"
    case sub = "Sub"
}

// MARK: - Dual Receiver Protocol Extension

extension IcomCIVProtocol {

    // MARK: - Band Selection (Main/Sub)

    /// Select Main or Sub receiver band.
    ///
    /// Available for all dual-receiver radios (IC-7600, IC-9700, IC-9100).
    ///
    /// - Parameter band: The band to select (.main or .sub)
    /// - Throws: RigError if command fails
    ///
    /// ## Usage
    /// ```swift
    /// try await proto.selectBand(.main)  // Select Main receiver
    /// try await proto.selectBand(.sub)   // Select Sub receiver
    /// ```
    ///
    /// ## CI-V Command
    /// - Main: `FE FE [addr] E0 07 D0 FD`
    /// - Sub:  `FE FE [addr] E0 07 D1 FD`
    public func selectBand(_ band: Band) async throws {
        // Only available for Main/Sub radios (IC-7600, IC-9700, IC-9100)
        let dualReceiverModels: [IcomRadioModel] = [.ic7600, .ic9700, .ic9100]
        guard dualReceiverModels.contains(radioModel) else {
            throw RigError.unsupportedOperation("Band selection only available for dual-receiver radios")
        }

        let code: UInt8 = (band == .main) ? CIVFrame.VFOSelect.main : CIVFrame.VFOSelect.sub
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.selectVFO],
            data: [code]
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.isAck else {
            throw RigError.commandFailed("Band selection rejected")
        }
    }

    /// Exchange Main and Sub receiver bands.
    ///
    /// Swaps the frequencies and settings between Main and Sub receivers.
    /// Available for all dual-receiver radios.
    ///
    /// - Throws: RigError if command fails
    ///
    /// ## Usage
    /// ```swift
    /// // Main: 14.200 MHz, Sub: 7.100 MHz
    /// try await proto.exchangeBands()
    /// // Main: 7.100 MHz, Sub: 14.200 MHz
    /// ```
    ///
    /// ## CI-V Command
    /// `FE FE [addr] E0 07 B0 FD`
    public func exchangeBands() async throws {
        let dualReceiverModels: [IcomRadioModel] = [.ic7600, .ic9700, .ic9100]
        guard dualReceiverModels.contains(radioModel) else {
            throw RigError.unsupportedOperation("Band exchange only available for dual-receiver radios")
        }

        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.selectVFO],
            data: [CIVFrame.VFOSelect.exchangeBands]
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.isAck else {
            throw RigError.commandFailed("Band exchange rejected")
        }
    }

    /// Enable or disable dualwatch mode.
    ///
    /// When enabled, radio monitors both Main and Sub receivers simultaneously.
    ///
    /// - Parameter enabled: true to enable dualwatch, false to disable
    /// - Throws: RigError if command fails
    ///
    /// ## Usage
    /// ```swift
    /// try await proto.setDualwatch(true)   // Enable simultaneous RX
    /// try await proto.setDualwatch(false)  // Disable dualwatch
    /// ```
    ///
    /// ## CI-V Command
    /// - ON:  `FE FE [addr] E0 07 C3 FD`
    /// - OFF: `FE FE [addr] E0 07 C2 FD`
    public func setDualwatch(_ enabled: Bool) async throws {
        let dualReceiverModels: [IcomRadioModel] = [.ic7600, .ic9700, .ic9100]
        guard dualReceiverModels.contains(radioModel) else {
            throw RigError.unsupportedOperation("Dualwatch only available for dual-receiver radios")
        }

        let code: UInt8 = enabled ? CIVFrame.VFOSelect.dualwatchOn : CIVFrame.VFOSelect.dualwatchOff
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.selectVFO],
            data: [code]
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.isAck else {
            throw RigError.commandFailed("Dualwatch command rejected")
        }
    }
}
