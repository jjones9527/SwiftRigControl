import Foundation

/// Dual VFO extensions for Icom radios with 4-state VFO model.
///
/// This extension provides VFO A/B selection methods for dual-receiver radios
/// where EACH receiver (Main and Sub) has its own VFO A and VFO B.
///
/// ## Supported Radios
/// - IC-9700 (VHF/UHF/1.2GHz with satellite mode)
/// - IC-9100 (HF/VHF/UHF with satellite mode)
///
/// ## 4-State VFO Model
/// ```
/// Radio
/// ├── Main Receiver (0xD0)
/// │   ├── VFO A (0x00)
/// │   └── VFO B (0x01)
/// └── Sub Receiver (0xD1)
///     ├── VFO A (0x00)
///     └── VFO B (0x01)
/// ```
///
/// ## Usage
/// ```swift
/// // Select Main receiver, VFO A
/// try await proto.selectBand(.main)
/// try await proto.selectVFO(.a)
///
/// // Or use composite method
/// try await proto.selectBandVFO(band: .main, vfo: .a)
/// ```

// MARK: - Dual VFO Protocol Extension

extension IcomCIVProtocol {

    // MARK: - Composite VFO Selection (Band + VFO)

    /// Select both band (Main/Sub) and VFO (A/B) in one operation.
    ///
    /// **Only available for 4-state radios (IC-9700, IC-9100).**
    ///
    /// This is a composite method that selects both the receiver band and the VFO,
    /// providing explicit 4-state selection (Main-A, Main-B, Sub-A, Sub-B).
    ///
    /// - Parameters:
    ///   - band: The receiver band to select (.main or .sub)
    ///   - vfo: The VFO to select (.a or .b)
    /// - Throws: RigError if radio doesn't support 4-state VFO or command fails
    ///
    /// ## Usage
    /// ```swift
    /// try await proto.selectBandVFO(band: .main, vfo: .a)  // Main-A
    /// try await proto.selectBandVFO(band: .main, vfo: .b)  // Main-B
    /// try await proto.selectBandVFO(band: .sub, vfo: .a)   // Sub-A
    /// try await proto.selectBandVFO(band: .sub, vfo: .b)   // Sub-B
    /// ```
    public func selectBandVFO(band: Band, vfo: VFO) async throws {
        let dualVFOModels: [IcomRadioModel] = [.ic9700, .ic9100]
        guard dualVFOModels.contains(radioModel) else {
            throw RigError.unsupportedOperation(
                "4-state VFO selection only available on IC-9700, IC-9100"
            )
        }

        // Select band first
        try await selectBand(band)

        // Then select VFO on that band
        try await selectVFO(vfo)
    }

    /// Equalize VFO A and VFO B on the currently selected receiver.
    ///
    /// **Only available for 4-state radios (IC-9700, IC-9100).**
    ///
    /// Copies the frequency and settings from VFO A to VFO B (or vice versa)
    /// on the currently active receiver (Main or Sub).
    ///
    /// - Throws: RigError if radio doesn't support this operation or command fails
    ///
    /// ## Usage
    /// ```swift
    /// try await proto.selectBand(.main)  // Select Main receiver
    /// try await proto.equalizeVFOs()     // Copy Main-A → Main-B
    ///
    /// try await proto.selectBand(.sub)   // Select Sub receiver
    /// try await proto.equalizeVFOs()     // Copy Sub-A → Sub-B
    /// ```
    ///
    /// ## CI-V Command
    /// `FE FE [addr] E0 07 A0 FD`
    public func equalizeVFOs() async throws {
        let dualVFOModels: [IcomRadioModel] = [.ic9700, .ic9100]
        guard dualVFOModels.contains(radioModel) else {
            throw RigError.unsupportedOperation(
                "VFO equalization per receiver only available on 4-state radios (IC-9700, IC-9100)"
            )
        }

        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.selectVFO],
            data: [CIVFrame.VFOSelect.equalizeBands]  // This is actually 0xA0, works for VFO A/B too
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        guard response.isAck else {
            throw RigError.commandFailed("VFO equalization rejected")
        }
    }
}

// MARK: - Convenience Methods

extension IcomCIVProtocol {
    /// Get human-readable description of current VFO state for 4-state radios.
    ///
    /// This is a helper method for debugging and logging.
    ///
    /// - Parameters:
    ///   - band: Current band (.main or .sub)
    ///   - vfo: Current VFO (.a or .b)
    /// - Returns: Formatted string like "Main-A" or "Sub-B"
    public func vfoStateDescription(band: Band, vfo: VFO) -> String {
        return "\(band.rawValue)-\(vfo.rawValue)"
    }
}
