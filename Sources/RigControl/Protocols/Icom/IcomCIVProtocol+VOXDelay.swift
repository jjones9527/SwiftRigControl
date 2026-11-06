import Foundation

// VOX delay. Icom keeps it in a settings-menu item, `1A 05 <p1> <p2>`
// followed by one BCD byte in tenths of a second (0-20, 0.0-2.0 s;
// Hamlib `level_gran_icom.h:33`), and the item number differs per model
// (each backend's `extcmds` RIG_LEVEL_VOXDELAY entry). The IC-7200 uses
// `1A 03 55` (`ic7200.c:306-327`).
//
// Through v1.3.1 setVOXDelay sent `14 16`, which is VOX *gain*, so it
// changed the VOX gain on every Icom and never the delay.

extension IcomCIVProtocol {

    /// Sets VOX delay.
    ///
    /// The 0-100 API level maps to the radio's 0.0-2.0 s in 0.1 s steps.
    ///
    /// - Parameter level: VOX delay, 0-100
    /// - Throws: `RigError.unsupportedOperation` if this model's menu item
    ///   isn't known, `RigError.commandFailed` if the radio rejects it
    public func setVOXDelay(_ level: Int) async throws {
        let prefix = try voxDelayPrefix()
        let tenths = (min(max(level, 0), 100) * 20 + 50) / 100
        let frame = CIVFrame(to: civAddress, command: [0x1A], data: prefix + [UInt8((tenths / 10) << 4 | tenths % 10)])
        try await sendFrame(frame)
        let response = try await receiveFrame()
        guard response.isAck else {
            throw RigError.commandFailed("Radio rejected VOX delay command")
        }
    }

    /// Reads VOX delay.
    ///
    /// - Returns: VOX delay, 0-100 (the radio's 0.0-2.0 s scaled up)
    /// - Throws: `RigError.unsupportedOperation` if this model's menu item
    ///   isn't known, `RigError.invalidResponse` if the reply is malformed
    public func getVOXDelay() async throws -> Int {
        let prefix = try voxDelayPrefix()
        try await sendFrame(CIVFrame(to: civAddress, command: [0x1A], data: prefix))
        let response = try await receiveFrame()
        guard response.command == [0x1A],
              response.data.count == prefix.count + 1,
              Array(response.data.prefix(prefix.count)) == prefix,
              let last = response.data.last else {
            throw RigError.invalidResponse
        }
        let tenths = Int(last >> 4) * 10 + Int(last & 0x0F)
        return min(tenths * 5, 100)
    }

    /// The bytes after `1A` that address VOX delay on this model.
    private func voxDelayPrefix() throws -> [UInt8] {
        if radioModel == .ic7200 {
            return [0x03, 0x55]
        }
        guard let item = Self.voxDelayMenuItem(for: radioModel) else {
            throw RigError.unsupportedOperation("VOX delay not implemented for \(radioModel.rawValue)")
        }
        return [0x05] + item
    }

    /// `1A 05` item number for VOX delay, from each Hamlib backend's
    /// `extcmds` (Hamlib `9199f8a`).
    static func voxDelayMenuItem(for model: IcomRadioModel) -> [UInt8]? {
        switch model {
        case .ic7300, .ic7300mk2: return model.menuSettingParameter(.voxDelay)  // ic7300.c:331, 348
        case .ic9700:      return [0x03, 0x30]  // ic7300.c:367
        case .ic705:       return [0x03, 0x59]  // ic7300.c:384
        case .ic905:       return [0x03, 0x39]  // ic7300.c:401
        case .ic7100:      return [0x01, 0x65]  // ic7100.c:117
        case .ic7000:      return [0x01, 0x17]  // ic7000.c:155
        case .ic7410:      return [0x00, 0x89]  // ic7410.c:94
        case .ic7600:      return [0x01, 0x67]  // ic7600.c:135
        case .ic7610:      return [0x02, 0x92]  // ic7610.c:136
        case .ic7700:      return [0x01, 0x82]  // ic7700.c:108
        case .ic7760:      return [0x03, 0x65]  // ic7760.c:108 (upstream 720268f; was 01 82)
        case .ic7800:      return [0x01, 0x83]  // ic7800.c:121
        case .ic7850, .ic7851: return [0x03, 0x09]  // ic785x.c:126
        case .ic9100:      return [0x01, 0x27]  // ic9100.c:91
        case .ic756proII, .ic756proIII: return [0x00, 0x60]  // ic756.c:65 (ic756pro2/pro3 priv caps)
        default:           return nil
        }
    }
}
