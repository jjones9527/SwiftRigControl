import Foundation

/// `1A 05` menu settings whose parameter numbers differ between models.
///
/// Icom renumbers its `1A 05` menu items from model to model, even between
/// the IC-7300 and the IC-7300MK2, which otherwise share a CAT command set
/// (jjones9527/SwiftRigControl#19). Any feature that sends a `1A 05`
/// setting must look its number up here per model rather than reuse
/// another radio's number.
///
/// No feature sends these yet; the table records Hamlib's numbers so the
/// first one starts from verified data.
enum IcomMenuSetting: CaseIterable, Sendable {
    /// Confirmation beep on/off (`RIG_PARM_BEEP`).
    case beep
    /// Display backlight level (`RIG_PARM_BACKLIGHT`).
    case backlight
    /// Screen saver timeout (`RIG_PARM_SCREENSAVER`).
    case screenSaver
    /// AF/IF output select (`RIG_PARM_AFIF`).
    case afIFOutput
    /// VOX delay (`RIG_LEVEL_VOXDELAY`).
    case voxDelay
    /// CI-V transceive on/off (`RIG_FUNC_TRANSCEIVE`).
    case transceive
    /// Spectrum scope averaging (`RIG_LEVEL_SPECTRUM_AVG`).
    case spectrumAverage
    /// USB AF output level (`RIG_LEVEL_USB_AF`).
    case usbAFLevel
    /// CW keyer type (`RIG_PARM_KEYERTYPE`).
    case keyerType
    /// Clock date (`icom_clock_cmds.date_cmds`).
    case clockDate
    /// Clock time (`icom_clock_cmds.time_cmds`, also `RIG_PARM_TIME`).
    case clockTime
    /// Clock UTC offset (`icom_clock_cmds.offset_cmds`).
    case clockUTCOffset
}

extension IcomRadioModel {
    /// The two parameter bytes that follow `1A 05` for a menu setting on
    /// this model, or `nil` if the number hasn't been recorded.
    ///
    /// Numbers come from Hamlib `rigs/icom/ic7300.c`: `ic7300_extcmds` /
    /// `ic7300mk2_extcmds` (`ic7300.c:323-354`) and `ic7300_clock_cmds` /
    /// `ic7300mk2_clock_cmds` (`ic7300.c:424-430`).
    ///
    /// The IC-7300's DATA modulation source (`00 67`) is deliberately not
    /// listed: on the MK2 `00 67` is the calibration marker, Hamlib has no
    /// entry for either, and the MK2 number has to come from its CI-V
    /// manual (attached to jjones9527/SwiftRigControl#19).
    func menuSettingParameter(_ setting: IcomMenuSetting) -> [UInt8]? {
        switch self {
        case .ic7300:
            switch setting {
            case .beep:            return [0x00, 0x23]
            case .backlight:       return [0x00, 0x81]
            case .screenSaver:     return [0x00, 0x89]
            case .afIFOutput:      return [0x00, 0x59]
            case .voxDelay:        return [0x01, 0x91]
            case .transceive:      return [0x00, 0x71]
            case .spectrumAverage: return [0x01, 0x02]
            case .usbAFLevel:      return [0x00, 0x60]
            case .keyerType:       return [0x01, 0x64]
            case .clockDate:       return [0x00, 0x94]
            case .clockTime:       return [0x00, 0x95]
            case .clockUTCOffset:  return [0x00, 0x96]
            }
        case .ic7300mk2:
            switch setting {
            case .beep:            return [0x00, 0x24]
            case .backlight:       return [0x01, 0x15]
            case .screenSaver:     return [0x01, 0x23]
            case .afIFOutput:      return [0x00, 0x74]
            case .voxDelay:        return [0x02, 0x67]
            case .transceive:      return [0x00, 0x89]
            case .spectrumAverage: return [0x01, 0x42]
            case .usbAFLevel:      return [0x00, 0x70]
            case .keyerType:       return [0x02, 0x24]
            case .clockDate:       return [0x01, 0x32]
            case .clockTime:       return [0x01, 0x33]
            case .clockUTCOffset:  return [0x01, 0x36]
            }
        default:
            return nil
        }
    }
}
