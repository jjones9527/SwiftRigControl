import Foundation

/// CI-V command set for the Icom IC-F8101 commercial HF transceiver.
///
/// The IC-F8101 doesn't take the amateur `0x05` / `0x06` / `0x1C` commands
/// for frequency, mode and PTT. Hamlib `rigs/icom/icf8101.c` drives it with
/// `0x1A` sub-commands instead:
///
/// | Operation       | Wire                          | Hamlib                 |
/// |-----------------|-------------------------------|------------------------|
/// | Set frequency   | `1A 35` + 5-byte BCD          | `icf8101_set_freq`, `:40-63` |
/// | Read frequency  | `03` (standard)               | `icom_get_freq`        |
/// | Set mode        | `1A 36 [00, mode]`            | `icf8101_set_mode`, `:65-107` |
/// | Read mode       | `1A 34` → `[34, 00, mode]`    | `icf8101_get_mode`, `:109-158` |
/// | PTT             | `1A 37 [00, 00/01]`           | `icf8101_set_ptt`, `:327-372` |
///
/// Mode bytes: LSB `00`, USB `01`, AM `02`, CW `03`, RTTY `04`, and the
/// first DATA profile LSB-D1 `18` / USB-D1 `19` (D2 `20`/`21`, D3
/// `22`/`23` read back as DATA too). Before v1.2.19 the IC-F8101 used the
/// standard command set, so frequency, mode and PTT all sent commands the
/// radio doesn't implement.
///
/// Definition-only: no IC-F8101 has been tested.
public struct ICF8101CommandSet: IcomRadioCommandSet {
    public let civAddress: UInt8
    public let vfoModel: VFOOperationModel = .targetable
    public let requiresModeFilter = false
    public let echoesCommands = false
    public let powerUnits: PowerUnits = .percentage
    /// DATA modes are mode codes on this radio, not the `0x1A 0x06` flag.
    public let supportsDataMode = false

    /// `0x1A` sub-commands (Hamlib `icf8101.c`, `icom_defs.h:441`).
    enum SubCommand {
        static let readMode: UInt8 = 0x34
        static let setFrequency: UInt8 = 0x35
        static let setMode: UInt8 = 0x36
        static let ptt: UInt8 = 0x37
    }

    /// DATA mode bytes, D1 / D2 / D3 profiles (`icf8101.c:86-97`).
    static let dataLSBCodes: Set<UInt8> = [0x18, 0x20, 0x22]
    static let dataUSBCodes: Set<UInt8> = [0x19, 0x21, 0x23]

    /// Creates an IC-F8101 command set.
    /// - Parameter civAddress: CI-V address (default `0x8A`, Hamlib `icf8101_priv_caps`).
    public init(civAddress: UInt8 = 0x8A) {
        self.civAddress = civAddress
    }

    /// `1A 35` + 5-byte BCD frequency (`icf8101_set_freq`).
    public func setFrequencyCommand(frequency: UInt64) -> (command: [UInt8], data: [UInt8]) {
        ([CIVFrame.Command.advancedSettings, SubCommand.setFrequency],
         BCDEncoding.encodeFrequency(frequency))
    }

    /// `1A 36 [00, mode]` for LSB / USB / AM / CW / RTTY (`icf8101_set_mode`).
    public func setModeCommand(mode: UInt8) -> (command: [UInt8], data: [UInt8]) {
        // LSB/USB/AM/CW/RTTY share the generic Icom mode bytes 00-04.
        ([CIVFrame.Command.advancedSettings, SubCommand.setMode], [0x00, mode])
    }

    /// `1A 36 [00, 18]` (LSB-D1) or `[00, 19]` (USB-D1) for DATA-LSB / DATA-USB.
    public func setDataModeCommand(mode: UInt8) -> (command: [UInt8], data: [UInt8]) {
        // LSB-D1 / USB-D1. `mode` is the base LSB (00) or USB (01) byte.
        let code: UInt8 = mode == CIVFrame.ModeCode.lsb ? 0x18 : 0x19
        return ([CIVFrame.Command.advancedSettings, SubCommand.setMode], [0x00, code])
    }

    /// `1A 34` (`icf8101_get_mode`).
    public func readModeCommand() -> [UInt8] {
        [CIVFrame.Command.advancedSettings, SubCommand.readMode]
    }

    /// The base mode byte from a `1A 34` reply; DATA profiles map to LSB / USB.
    public func parseModeResponse(_ response: CIVFrame) throws -> UInt8 {
        let code = try Self.modeByte(response)
        if Self.dataLSBCodes.contains(code) { return CIVFrame.ModeCode.lsb }
        if Self.dataUSBCodes.contains(code) { return CIVFrame.ModeCode.usb }
        return code
    }

    /// Whether a `1A 34` reply reports a DATA profile (`18`-`23`).
    /// - Parameter response: The `1A 34` reply.
    /// - Returns: `true` for a DATA profile, `nil` if the reply isn't a `1A 34` reply.
    public func parseDataModeFlag(_ response: CIVFrame) -> Bool? {
        guard let code = try? Self.modeByte(response) else { return nil }
        return Self.dataLSBCodes.contains(code) || Self.dataUSBCodes.contains(code)
    }

    /// `1A 37 [00, 01]` (on) or `[00, 00]` (off) (`icf8101_set_ptt`).
    public func setPTTCommand(enabled: Bool) -> (command: [UInt8], data: [UInt8]) {
        ([CIVFrame.Command.advancedSettings, SubCommand.ptt], [0x00, enabled ? 0x01 : 0x00])
    }

    /// `1A 37` (`icf8101_get_ptt`).
    public func readPTTCommand() -> [UInt8] {
        [CIVFrame.Command.advancedSettings, SubCommand.ptt]
    }

    /// `true` unless the `1A 37` reply's state byte is `00`.
    public func parsePTTResponse(_ response: CIVFrame) throws -> Bool {
        // `CIVFrame.parse` leaves the sub-command in the data:
        // [37, 00, state], state 0 = RX, 1 = mic PTT, 2 = data PTT
        // (icf8101_get_ptt, icf8101.c:378-412).
        guard response.command == [CIVFrame.Command.advancedSettings],
              response.data.count == 3,
              response.data[0] == SubCommand.ptt else {
            throw RigError.invalidResponse
        }
        return response.data[2] != 0x00
    }

    /// The mode byte from a `1A 34` reply: `[34, 00, mode]`.
    private static func modeByte(_ response: CIVFrame) throws -> UInt8 {
        guard response.command == [CIVFrame.Command.advancedSettings],
              response.data.count >= 3,
              response.data[0] == SubCommand.readMode else {
            throw RigError.invalidResponse
        }
        return response.data[2]
    }
}
