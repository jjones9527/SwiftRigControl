import Foundation
import Testing
@testable import RigControl

/// Verifies that ``TenTecLegacyProtocol/tuningFactors`` reproduces
/// Hamlib's `tentec_tuning_factor_calc` (rigs/tentec/tentec.c:181)
/// bit-for-bit for representative frequency/mode combinations.
///
/// Pre-fix code sent a 6-byte zero-padded decimal string instead
/// of the three 16-bit binary tuning factors — Jupiter and Pegasus
/// firmware silently ignored it and never tuned.
///
/// Expected values were computed by hand from the Hamlib formulas:
/// ```
/// fcor       = (mode == CW) ? 0 : (width / 2) + 200
/// mcor       = ±1 for LSB/USB/CW, 0 for AM/FM
/// cwbfo      = (mode == CW) ? priv->cwbfo : 0
/// adjtfreq   = freq - 1250 + mcor * (fcor + pbt)
/// CTF        = (adjtfreq / 2500) + 18000
/// FTF        = floor((adjtfreq mod 2500) * 5.46)
/// BTF        = floor((fcor + pbt + cwbfo + 8000) * 2.73)
/// ```
@Suite struct TenTecTuningFactorTests {

    @Test func usbAt14MHzMatchesHamlibFormula() {
        let (ctf, ftf, btf) = TenTecLegacyProtocol.tuningFactors(
            freqHz: 14_200_000,
            mode: .usb,
            widthHz: 2400,
            pbtHz: 0,
            cwBFOHz: 1000
        )
        #expect(ctf == 23680)
        #expect(ftf == 819)
        #expect(btf == 25662)
    }

    @Test func lsbAt7MHzMatchesHamlibFormula() {
        let (ctf, ftf, btf) = TenTecLegacyProtocol.tuningFactors(
            freqHz: 7_100_000,
            mode: .lsb,
            widthHz: 2400,
            pbtHz: 0,
            cwBFOHz: 1000
        )
        #expect(ctf == 20838)
        #expect(ftf == 12831)
        #expect(btf == 25662)
    }

    @Test func cwAt7MHzUsesBFOAndZeroFilter() {
        let (ctf, ftf, btf) = TenTecLegacyProtocol.tuningFactors(
            freqHz: 7_050_000,
            mode: .cw,
            widthHz: 2400,
            pbtHz: 0,
            cwBFOHz: 1000
        )
        #expect(ctf == 20819)
        #expect(ftf == 6825)
        #expect(btf == 24570)
    }

    @Test func amAt5MHzUsesZeroMcor() {
        let (ctf, ftf, btf) = TenTecLegacyProtocol.tuningFactors(
            freqHz: 5_000_000,
            mode: .am,
            widthHz: 6000,
            pbtHz: 0,
            cwBFOHz: 1000
        )
        #expect(ctf == 19999)
        #expect(ftf == 6825)
        #expect(btf == 30576)
    }

    @Test func tuningFactorsFitIn16Bits() {
        // Sanity: the `N` command sends each factor as two bytes big-
        // endian, so the values must fit in UInt16. Verify at both
        // ends of the HF spectrum with the widest AM filter.
        for freq in [1_800_000, 30_000_000] as [Int] {
            for mode in [Mode.am, .usb, .lsb, .cw] {
                let (ctf, ftf, btf) = TenTecLegacyProtocol.tuningFactors(
                    freqHz: freq,
                    mode: mode,
                    widthHz: 6000,
                    pbtHz: 0,
                    cwBFOHz: 1000
                )
                #expect(ctf >= 0 && ctf <= 0xFFFF, "CTF out of range at \(freq)/\(mode): \(ctf)")
                #expect(ftf >= 0 && ftf <= 0xFFFF, "FTF out of range at \(freq)/\(mode): \(ftf)")
                #expect(btf >= 0 && btf <= 0xFFFF, "BTF out of range at \(freq)/\(mode): \(btf)")
            }
        }
    }
}
