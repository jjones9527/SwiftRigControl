import Foundation

// Per-vendor "what we know works" VFO-operation presets, derived
// from Hamlib's per-radio `vfo_ops` masks. These are the sets
// SwiftRigControl applies to verified radios in the capabilities
// database. Unverified radios default to `[]` — they can opt in
// once someone exercises them against real hardware.

extension Set where Element == VFOOperation {

    /// Standard modern-Icom VFO ops: copy, exchange, memory
    /// write/recall, memory clear, ATU tune. Matches Hamlib
    /// `IC7600_VFO_OPS` / `IC7300_VFO_OPS` / `IC7100_VFO_OPS`.
    public static let icomStandard: Set<VFOOperation> = [
        .copyVFO, .exchange, .vfoToMemory, .memoryToVFO,
        .memoryClear, .tune,
    ]

    /// Modern Icom without an internal ATU (IC-9700, IC-705).
    /// Same as ``icomStandard`` minus `.tune`. Matches Hamlib
    /// `IC9700_VFO_OPS`.
    public static let icomNoATU: Set<VFOOperation> = [
        .copyVFO, .exchange, .vfoToMemory, .memoryToVFO,
        .memoryClear,
    ]

    /// IC-905 / IC-9700-class radios that don't expose `XCHG`.
    /// Matches Hamlib `IC905_VFO_OPS`.
    public static let icom905: Set<VFOOperation> = [
        .copyVFO, .vfoToMemory, .memoryToVFO, .memoryClear, .tune,
    ]

    /// Standard Kenwood HF set: step up/down, band up/down,
    /// memory write/recall, ATU tune. Matches the union of ops
    /// `kenwood_vfo_op` accepts (UP/DN/BU/BD/MC/MR/AC), filtered
    /// to those that map to our `VFOOperation` enum.
    public static let kenwoodStandard: Set<VFOOperation> = [
        .stepUp, .stepDown, .bandUp, .bandDown,
        .memoryClear, .memoryToVFO, .tune,
    ]

    /// Kenwood HF without an internal ATU (TS-570, TS-870 etc).
    /// Same as ``kenwoodStandard`` minus `.tune`.
    public static let kenwoodNoATU: Set<VFOOperation> = [
        .stepUp, .stepDown, .bandUp, .bandDown,
        .memoryClear, .memoryToVFO,
    ]

    /// Standard Yaesu newcat HF set. From `newcat_vfo_op`:
    /// `CPY` ("AB"/"VV"), `XCHG`/`TOGGLE` ("SV"), `FROM_VFO`
    /// ("AM"), `TO_VFO` ("MA"), `UP`/`DOWN`, `BAND_UP`/
    /// `BAND_DOWN`, `TUNE` ("AC002"/"AC003").
    public static let yaesuStandard: Set<VFOOperation> = [
        .copyVFO, .exchange, .toggle,
        .vfoToMemory, .memoryToVFO,
        .stepUp, .stepDown, .bandUp, .bandDown,
        .tune,
    ]

    /// Elecraft K-series. Falls through to `kenwood_vfo_op` in
    /// Hamlib except for `TUNE` (model-specific `SWT` codes).
    /// We model TUNE plus the Kenwood ops K2/K3/K3S/K4 inherit.
    public static let elecraftStandard: Set<VFOOperation> = [
        .stepUp, .stepDown, .bandUp, .bandDown,
        .vfoToMemory, .memoryToVFO, .tune,
    ]
}
