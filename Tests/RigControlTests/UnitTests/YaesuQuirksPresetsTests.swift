import Testing
@testable import RigControl

/// Catalog-drift tests for every named `YaesuCATProtocol.Quirks`
/// preset shipped with the library.
///
/// Each preset bundles ~8 wire-format flags (`supportsSTSplit`,
/// `usesFT23ForVFOSelection`, `frequencyDigits`,
/// `filterCommandStyle`, `hasTargetableMode`, …). If someone
/// mutates a preset's fields — a routine one-line edit — no
/// existing test would fail, because the behavioral tests all use
/// specific presets and don't cross-check every field.
///
/// This suite locks each preset's field values against the Hamlib
/// citation captured in `YaesuCATProtocol+Quirks.swift`. Every
/// expected value is traceable to a Hamlib source line — see the
/// per-preset docstrings in that file for the citation.
///
/// Adding a new preset requires adding a row to this test. Adding
/// a new field to `Quirks` requires updating every row.
@Suite struct YaesuQuirksPresetsTests {

    // MARK: - Non-newcat / classic

    @Test func classicPresetIsAllDefaults() {
        let q = YaesuCATProtocol.Quirks.classic
        #expect(q.supportsSTSplit == false)
        #expect(q.usesFT23ForVFOSelection == false)
        #expect(q.supportsFTVFOSelection == true)
        #expect(q.frequencyDigits == 9)
        #expect(q.modeCodeTable == nil)
        #expect(q.requiresMemoryModeEscape == false)
        #expect(q.filterCommandStyle == .qualifierOnly)
        #expect(q.hasTargetableMode == false)
    }

    // MARK: - newcat family without ST-split (FT-950/991/DX5000/1200/9000)

    @Test func newcatNoSTPreset() {
        // Per Hamlib newcat.c:8216-8222 the FT-950 / FT-991(A) /
        // FT-DX5000/1200 / FTDX-9000 use `FT2/FT3` for VFO A/B and
        // have no ST split command. SH is the qualifier-only form
        // (Hamlib newcat.c:9218). No RIG_TARGETABLE_MODE on this
        // preset — factories that need it (FTDX-5000, FTDX-9000)
        // override via `.withTargetableMode()`.
        let q = YaesuCATProtocol.Quirks.newcatNoST
        #expect(q.supportsSTSplit == false)
        #expect(q.usesFT23ForVFOSelection == true)
        #expect(q.supportsFTVFOSelection == true)
        #expect(q.frequencyDigits == 9)
        #expect(q.modeCodeTable == nil)
        #expect(q.requiresMemoryModeEscape == false)
        #expect(q.filterCommandStyle == .qualifierOnly)
        #expect(q.hasTargetableMode == false)
    }

    // MARK: - FT-2000 / FTDX-3000 family

    @Test func ft2000FamilyPreset() {
        // Per Hamlib newcat.c:9210, ft2000.c, ft3000.c: SH form is
        // zero-without-qualifier. FT-2000 is targetable (FT-2000
        // factory overrides via `.withTargetableMode()`); FTDX-3000
        // stays non-targetable, matching this preset's default.
        let q = YaesuCATProtocol.Quirks.ft2000Family
        #expect(q.supportsSTSplit == false)
        #expect(q.usesFT23ForVFOSelection == true)
        #expect(q.supportsFTVFOSelection == true)
        #expect(q.frequencyDigits == 9)
        #expect(q.modeCodeTable == nil)
        #expect(q.requiresMemoryModeEscape == false)
        #expect(q.filterCommandStyle == .zeroWithoutQualifier)
        #expect(q.hasTargetableMode == false)
    }

    // MARK: - newcat with ST-DX split (legacy preset)

    @Test func newcatWithSTDXPreset() {
        // Retained for source compatibility; no current factory
        // uses it. FT-DX10 / FTDX-101(D/MP) each have their own
        // preset now with the correct SH form. Locks the default
        // qualifier-only SH.
        let q = YaesuCATProtocol.Quirks.newcatWithSTDX
        #expect(q.supportsSTSplit == true)
        #expect(q.usesFT23ForVFOSelection == true)
        #expect(q.supportsFTVFOSelection == true)
        #expect(q.frequencyDigits == 9)
        #expect(q.modeCodeTable == nil)
        #expect(q.requiresMemoryModeEscape == false)
        #expect(q.filterCommandStyle == .qualifierOnly)
        #expect(q.hasTargetableMode == false)
    }

    // MARK: - FTDX-10 family

    @Test func ftdx10FamilyPreset() {
        // Per Hamlib ftdx10.c: RIG_TARGETABLE_MODE, ST-DX split,
        // `FT2/FT3` VFO selection, SH00 filter form (newcat.c:9214).
        let q = YaesuCATProtocol.Quirks.ftdx10Family
        #expect(q.supportsSTSplit == true)
        #expect(q.usesFT23ForVFOSelection == true)
        #expect(q.supportsFTVFOSelection == true)
        #expect(q.frequencyDigits == 9)
        #expect(q.modeCodeTable == nil)
        #expect(q.requiresMemoryModeEscape == false)
        #expect(q.filterCommandStyle == .doubleZero)
        #expect(q.hasTargetableMode == true)
    }

    // MARK: - FTDX-101D/MP family

    @Test func ftdx101FamilyPreset() {
        // Per Hamlib ftdx101.c / ftdx101mp.c: RIG_TARGETABLE_MODE,
        // ST-DX split, `FT2/FT3` VFO selection, VFO-plus-narrow SH
        // form (newcat.c:9205-9207). Narrow flag is not always-on —
        // the FT-891 uses always-on but not this family.
        let q = YaesuCATProtocol.Quirks.ftdx101Family
        #expect(q.supportsSTSplit == true)
        #expect(q.usesFT23ForVFOSelection == true)
        #expect(q.supportsFTVFOSelection == true)
        #expect(q.frequencyDigits == 9)
        #expect(q.modeCodeTable == nil)
        #expect(q.requiresMemoryModeEscape == false)
        #expect(q.filterCommandStyle == .vfoAndNarrow(narrowAlwaysOn: false))
        #expect(q.hasTargetableMode == true)
    }

    // MARK: - FT-710

    @Test func ft710Preset() {
        // Per Hamlib ft710.c: RIG_TARGETABLE_MODE, ST-DX split,
        // classic FT0/FT1 VFO selection (not FT2/FT3), SH00
        // filter form.
        let q = YaesuCATProtocol.Quirks.ft710
        #expect(q.supportsSTSplit == true)
        #expect(q.usesFT23ForVFOSelection == false)
        #expect(q.supportsFTVFOSelection == true)
        #expect(q.frequencyDigits == 9)
        #expect(q.modeCodeTable == nil)
        #expect(q.requiresMemoryModeEscape == false)
        #expect(q.filterCommandStyle == .doubleZero)
        #expect(q.hasTargetableMode == true)
    }

    // MARK: - FT-450 / FT-450D

    @Test func ft450Preset() {
        // Per Hamlib newcat.c:8327: FT-450's ST means Step (not
        // Split), so split via ST is disabled. Uses classic FT0/FT1
        // VFO selection. Qualifier-only SH form. Not targetable.
        let q = YaesuCATProtocol.Quirks.ft450
        #expect(q.supportsSTSplit == false)
        #expect(q.usesFT23ForVFOSelection == false)
        #expect(q.supportsFTVFOSelection == true)
        #expect(q.frequencyDigits == 9)
        #expect(q.modeCodeTable == nil)
        #expect(q.requiresMemoryModeEscape == false)
        #expect(q.filterCommandStyle == .qualifierOnly)
        #expect(q.hasTargetableMode == false)
    }

    // MARK: - FT-891

    @Test func ft891Preset() {
        // Per Hamlib newcat.c:516 the FT-891 has no `FT` command
        // (both split and TX VFO selection unsupported). SH uses
        // the VFO-plus-narrow form with the narrow flag ALWAYS `1`
        // per Hamlib newcat.c:9207.
        let q = YaesuCATProtocol.Quirks.ft891
        #expect(q.supportsSTSplit == false)
        #expect(q.usesFT23ForVFOSelection == false)
        #expect(q.supportsFTVFOSelection == false)
        #expect(q.frequencyDigits == 9)
        #expect(q.modeCodeTable == nil)
        #expect(q.requiresMemoryModeEscape == false)
        #expect(q.filterCommandStyle == .vfoAndNarrow(narrowAlwaysOn: true))
        #expect(q.hasTargetableMode == false)
    }

    // MARK: - FTX-1 (2025 flagship portable)

    @Test func ftx1Preset() {
        // Per Hamlib ftx1/ftx1.c: RIG_TARGETABLE_ALL (includes
        // RIG_TARGETABLE_MODE), ST-DX split, `FT2/FT3` VFO,
        // memory-mode escape, custom mode-code table, SH00 filter
        // form.
        let q = YaesuCATProtocol.Quirks.ftx1
        #expect(q.supportsSTSplit == true)
        #expect(q.usesFT23ForVFOSelection == true)
        #expect(q.supportsFTVFOSelection == true)
        #expect(q.frequencyDigits == 9)
        #expect(q.modeCodeTable != nil, "FTX-1 must ship a custom mode table")
        #expect(q.requiresMemoryModeEscape == true)
        #expect(q.filterCommandStyle == .doubleZero)
        #expect(q.hasTargetableMode == true)

        // Sample the mode table for the CW / CW-R distinction —
        // the whole point of the custom table. FTX-1 diverges from
        // shared newcat on codes 3 (CW-USB not CW) and 7 (CW-LSB
        // not CW-R). See `rigs/yaesu/ftx1/ftx1_mode.c` header.
        let table = q.modeCodeTable ?? [:]
        #expect(table[.cw] == "3", "FTX-1 .cw must map to code 3 (CW-USB)")
        #expect(table[.cwR] == "7", "FTX-1 .cwR must map to code 7 (CW-LSB)")
        #expect(table[.lsb] == "1")
        #expect(table[.usb] == "2")
        #expect(table[.fm] == "4")
        #expect(table[.am] == "5")
    }

    // MARK: - withTargetableMode helper

    @Test func withTargetableModePreservesEverythingElse() {
        // Copy-with-override helper used by factory sites for
        // radios where a shared preset needs per-radio targetable-
        // mode gating. Must preserve every other field.
        let base = YaesuCATProtocol.Quirks.newcatNoST
        let overridden = base.withTargetableMode()

        #expect(overridden.hasTargetableMode == true)
        #expect(base.hasTargetableMode == false)   // base untouched

        #expect(overridden.supportsSTSplit == base.supportsSTSplit)
        #expect(overridden.usesFT23ForVFOSelection == base.usesFT23ForVFOSelection)
        #expect(overridden.supportsFTVFOSelection == base.supportsFTVFOSelection)
        #expect(overridden.frequencyDigits == base.frequencyDigits)
        #expect(overridden.requiresMemoryModeEscape == base.requiresMemoryModeEscape)
        #expect(overridden.filterCommandStyle == base.filterCommandStyle)
    }

    @Test func withTargetableModeCanExplicitlyDisable() {
        // Sanity: `.withTargetableMode(false)` is the inverse case.
        let base = YaesuCATProtocol.Quirks.ftdx10Family   // has targetable=true
        let disabled = base.withTargetableMode(false)
        #expect(disabled.hasTargetableMode == false)
        #expect(base.hasTargetableMode == true)
    }
}
