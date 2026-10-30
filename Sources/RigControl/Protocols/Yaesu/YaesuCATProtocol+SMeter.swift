import Foundation

// MARK: - S-meter
//
// Newcat reads the S-meter with `SM0;` (reply `SM0nnn;`, 0-255) and
// Hamlib converts the reading with the model's `.str_cal` table
// (`newcat_get_level` RIG_LEVEL_STRENGTH, `newcat.c:5304-5316`,
// `5818-5845`). Through v1.3.1 this sent `RM5;`, which on the FT-991A and
// FTDX-101 selects the power-output meter, so the "S-meter" read power
// out instead of signal strength.

extension YaesuCATProtocol {

    /// Hamlib `yaesu_default_str_cal` (`newcat.c:353-368`): used for the
    /// FTDX-10, FTDX-1200, FTDX-3000 and FTDX-5000, which have no table
    /// of their own.
    public static let defaultSMeterCalibration = CalibrationTable([
        (0, -54), (26, -42), (51, -30), (81, -18), (105, -9), (130, 0),
        (157, 12), (186, 25), (203, 35), (237, 50), (255, 60),
    ])

    /// The 16-point table Hamlib uses for the FT-710, FT-891, FT-991/991A,
    /// FT-950, FT-2000, FTDX-9000 and FTX-1 (`FT710_STR_CAL`, `ft710.h:106`).
    public static let newcatSMeterCalibration = CalibrationTable([
        (0, -54), (12, -48), (27, -42), (40, -36), (55, -30), (65, -24),
        (80, -18), (95, -12), (112, -6), (130, 0), (150, 10), (172, 20),
        (190, 30), (220, 40), (240, 50), (255, 60),
    ])

    /// Hamlib `FT450_STR_CAL` (`ft450.h`).
    public static let ft450SMeterCalibration = CalibrationTable([(10, -60), (125, 0), (240, 60)])

    /// Hamlib `FTDX101D_STR_CAL` (`ftdx101.h`), FTDX-101D and MP.
    public static let ftdx101SMeterCalibration = CalibrationTable([
        (0, -60), (17, -54), (25, -48), (34, -42), (51, -36), (68, -30),
        (85, -24), (102, -18), (119, -12), (136, -6), (160, 0), (255, 60),
    ])

    /// Reads the main receiver's S-meter.
    ///
    /// Command: `SM0;` — Response: `SM0nnn;`. The reading is calibrated
    /// with ``YaesuCATProtocol/Quirks/sMeterCalibration``, so
    /// ``SignalStrength/calibratedDBRelativeToS9`` matches Hamlib's
    /// `RIG_LEVEL_STRENGTH` for the same model.
    ///
    /// - Returns: The signal strength
    /// - Throws: `RigError` if the command fails
    public func getSignalStrength() async throws -> SignalStrength {
        try await sendCommand("SM0")
        let response = try await receiveResponse()
        guard response.hasPrefix("SM"), response.count >= 4,
              let raw = Int(response.dropFirst(3)) else {
            throw RigError.invalidResponse
        }
        let dB = quirks.sMeterCalibration.value(forRaw: raw)
        return SignalStrength(dBRelativeToS9: dB, raw: raw)
    }
}
