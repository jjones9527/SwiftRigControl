import Foundation

/// Types and enums for Icom radio behavior classification.
///
/// These types help categorize Icom radios by their VFO operation models,
/// command requirements, and other behavioral characteristics.

// MARK: - VFO Operation Model

/// Describes how a radio handles VFO operations.
///
/// Different Icom radios have different approaches to VFO (Variable Frequency Oscillator) management:
/// - Some can target specific VFOs directly in each command
/// - Some operate only on the "current" VFO and require switching first
/// - Dual-receiver radios use Main/Sub band architecture instead of VFO A/B
/// - Some radios (receivers) don't support VFO operations at all
public enum VFOOperationModel: Sendable {
    /// Radio can target VFO A or VFO B directly in commands.
    ///
    /// Most modern HF transceivers use this model:
    /// - IC-7300, IC-7610, IC-7700, IC-7800
    /// - Can send "set VFO A to 14.200 MHz" in one operation
    /// - Uses VFO codes: A=0x00, B=0x01
    case targetable

    /// Radio operates only on the "current" VFO.
    ///
    /// Must explicitly switch the active VFO before operations:
    /// - IC-7100, IC-705, IC-7200, IC-7410
    /// - Sequence: "switch to VFO B" then "set frequency to 14.200 MHz"
    /// - Uses VFO codes: A=0x00, B=0x01
    case currentOnly

    /// Radio uses Main/Sub receiver architecture.
    ///
    /// Dual-receiver radios use different VFO codes:
    /// - IC-7600, IC-9700, IC-9100 (dual receiver models)
    /// - Uses VFO codes: Main=0xD0, Sub=0xD1
    /// - Main and Sub can be on different bands simultaneously
    case mainSub

    /// Radio does not support VFO operations.
    ///
    /// Typically used for:
    /// - Single-VFO receivers (IC-R75, IC-R8600)
    /// - Scanners
    /// - VFO selection commands return nil
    case none
}

// Note: CI-V Frame constants (Command, VFOSelect, ModeCode, LevelRead) are defined in CIVFrame.swift

// MARK: - VFO Code Helpers

/// Helper functions for converting VFO enums to CI-V codes
public enum VFOCodeHelper {
    /// Get standard VFO code for targetable or currentOnly radios
    /// - Parameter vfo: The VFO to convert
    /// - Returns: VFO code (0x00 for A/Main, 0x01 for B/Sub)
    public static func standardCode(for vfo: VFO) -> UInt8 {
        switch vfo {
        case .a, .main:
            return CIVFrame.VFOSelect.vfoA
        case .b, .sub:
            return CIVFrame.VFOSelect.vfoB
        }
    }

    /// Get Main/Sub VFO code for dual-receiver radios
    /// - Parameter vfo: The VFO to convert
    /// - Returns: VFO code if valid for Main/Sub, nil if VFO A/B used
    public static func mainSubCode(for vfo: VFO) -> UInt8? {
        switch vfo {
        case .main:
            return CIVFrame.VFOSelect.main
        case .sub:
            return CIVFrame.VFOSelect.sub
        case .a, .b:
            // Main/Sub radios don't support VFO A/B codes
            return nil
        }
    }
}
