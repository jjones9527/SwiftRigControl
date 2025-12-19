import Foundation

/// IF Filter control for Icom radios.
///
/// This extension provides unified IF filter control across different Icom radio models.
/// Filter selection works differently depending on the radio's architecture:
///
/// ## Modern Radios (requiresModeFilter = true)
/// - **IC-7600, IC-7300, IC-7610, IC-9700, IC-9100, IC-7200, IC-7410**
/// - Filter is sent with mode command (0x06)
/// - Reading filter requires reading current mode
/// - Each mode has independent filter settings
///
/// ## IC-7100 Family (requiresModeFilter = false)
/// - **IC-7100, IC-705**
/// - Filter is managed separately from mode
/// - Mode command does not include filter byte
///
/// ## Commands
/// - **Set Mode+Filter**: 0x06 [mode] [filter] (modern radios)
/// - **Set Mode Only**: 0x06 [mode] (IC-7100 family)
/// - **Get Mode+Filter**: 0x04 returns [mode] [filter] (modern radios)
/// - **Get Mode Only**: 0x04 returns [mode] (IC-7100 family)
extension IcomCIVProtocol {
    /// Set IF filter selection.
    ///
    /// Sets which preset IF filter to use (FIL1, FIL2, or FIL3).
    /// On modern radios, this requires re-sending the current mode with the new filter byte.
    ///
    /// - Parameter filter: The filter to select
    /// - Throws: `RigError.unsupportedOperation` if radio doesn't support filter control
    /// - Throws: `RigError.commandFailed` if radio rejects the command
    public func setIFFilter(_ filter: IFFilter) async throws {
        guard supportsIFFilterControl else {
            throw RigError.unsupportedOperation("IF filter control not supported on \(radioModel.rawValue)")
        }

        // Get current mode so we can resend it with the new filter
        let currentMode = try await getMode(vfo: .a)

        // Send mode command with new filter
        let modeCode = try modeCode(for: currentMode)
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.setMode],
            data: [modeCode, filter.rawValue]
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("IF filter command rejected")
        }
    }

    /// Get current IF filter selection.
    ///
    /// Reads the current mode to determine which filter is active.
    ///
    /// - Returns: Current IF filter selection
    /// - Throws: `RigError.unsupportedOperation` if radio doesn't support filter control
    /// - Throws: `RigError.invalidResponse` if response is malformed
    public func getIFFilter() async throws -> IFFilter {
        guard supportsIFFilterControl else {
            throw RigError.unsupportedOperation("IF filter control not supported on \(radioModel.rawValue)")
        }

        // Read mode command - modern radios return mode + filter byte
        let frame = CIVFrame(
            to: civAddress,
            command: [CIVFrame.Command.readMode],
            data: []
        )

        try await sendFrame(frame)
        let response = try await receiveFrame()

        // Response format: [FE FE] [controller] [radio] [04] [mode] [filter] [FD]
        // We need at least mode + filter bytes
        guard response.data.count >= 2 else {
            throw RigError.invalidResponse
        }

        let filterByte = response.data[1]

        // Validate filter byte is one of the known values
        guard let filter = IFFilter(rawValue: filterByte) else {
            throw RigError.invalidResponse
        }

        return filter
    }

    // MARK: - Private Helpers

    /// Whether this radio supports IF filter control.
    private var supportsIFFilterControl: Bool {
        // Only radios that require mode filter byte support filter control
        // This is determined by the IcomRadioCommandSet protocol
        switch radioModel {
        case .ic7600, .ic7300, .ic7610, .ic9700, .ic9100, .ic7200, .ic7410,
             .ic7851, .ic7800, .ic7700:
            return true
        case .ic7100, .ic705:
            // These radios don't include filter in mode command
            return false
        default:
            return false
        }
    }

    /// Get mode code for a given Mode.
    private func modeCode(for mode: Mode) throws -> UInt8 {
        switch mode {
        case .lsb: return 0x00
        case .usb: return 0x01
        case .am: return 0x02
        case .cw: return 0x03
        case .rtty: return 0x04
        case .fm: return 0x05
        case .wfm: return 0x06
        case .cwR: return 0x07
        case .rttyR: return 0x08
        case .fmN: return 0x05  // FM Narrow uses same code as FM
        case .dataLSB: return 0x00  // Data modes use voice mode codes
        case .dataUSB: return 0x01
        case .dataFM: return 0x05
        }
    }
}
