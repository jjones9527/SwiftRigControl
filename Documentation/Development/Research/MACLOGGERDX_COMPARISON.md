# SwiftRigControl vs MacLoggerDX - Radio Support Comparison

## Executive Summary

MacLoggerDX is a mature macOS-native ham radio logging application with extensive radio support (~150+ radios). This document compares SwiftRigControl's current radio coverage against MacLoggerDX to identify strategic gaps for Phase 3 development.

**Target Goal:** Match MacLoggerDX's radio support to provide parity for macOS ham radio applications.

---

## Current Status

**Last Updated:** December 19, 2025 - **Phase 3A Complete**

| Manufacturer | SwiftRigControl | MacLoggerDX | Gap |
|--------------|-----------------|-------------|-----|
| **Icom** | 8 transceivers | 40+ models | -32 |
| **Yaesu** | 10 models | 22+ models | -12 |
| **Kenwood** | 12 models | 19 models | -7 |
| **Elecraft** | 6 models | 4 models | ✅ +2 |
| **Ten-Tec** | 0 models | 6 models | -6 |
| **Xiegu** | 0 models | 3 models | -3 |
| **FlexRadio** | 0 models | 2 series | -2 |
| **Others** | 0 models | 20+ models | -20 |

**Recent Additions (Phase 3A):**
- ✅ IC-718 - Budget HF transceiver (extremely popular with new hams)
- ✅ IC-703 - Portable HF/6m QRP transceiver

---

## Detailed Comparison by Manufacturer

### 1. ICOM

#### ✅ Models We Already Support (6)
- **Modern Flagships:**
  - IC-7610 ✅
  - IC-7300 ✅
  - IC-7600 ✅

- **Multi-band/Portable:**
  - IC-7100 ✅
  - IC-705 ✅

- **VHF/UHF:**
  - IC-9700 ✅

#### ❌ High-Priority Missing Models (MacLoggerDX has these)

**Modern Radios (2010+):**
- IC-7400 - HF/6m transceiver (successor to IC-746)
- IC-7410 ✅ (we have this in IcomRadioModel and RadioDefinition)
- IC-7200 ✅ (we have this in IcomRadioModel and RadioDefinition)
- IC-7000 ✅ (we have this in IcomRadioModel and RadioDefinition)
- IC-9100 ✅ (we have this in IcomRadioModel and RadioDefinition)
- IC-905 - VHF/UHF/microwave (NEW 2024)

**Legacy Popular (2000-2009):**
- IC-718 ✅ **ADDED in Phase 3A** - Budget HF transceiver (extremely popular with new hams)
- IC-703 ✅ **ADDED in Phase 3A** - Portable QRP HF
- IC-706MkIIG ✅ (we have this in IcomRadioModel but not in RadioDefinition)
- IC-706MkII ✅ (we have this in IcomRadioModel but not in RadioDefinition)
- IC-706 ✅ (we have this in IcomRadioModel but not in RadioDefinition)
- IC-746Pro ✅ (we have this in IcomRadioModel but not in RadioDefinition)
- IC-746 ✅ (we have this in IcomRadioModel but not in RadioDefinition)
- IC-756ProIII ✅ (we have this in IcomRadioModel but not in RadioDefinition)
- IC-756ProII ✅ (we have this in IcomRadioModel but not in RadioDefinition)
- IC-756Pro ✅ (we have this in IcomRadioModel but not in RadioDefinition)
- IC-756 ✅ (we have this in IcomRadioModel but not in RadioDefinition)

**Vintage Flagships (1990s):**
- IC-735 - Classic HF transceiver
- IC-736 - HF transceiver
- IC-737 - HF transceiver
- IC-751 - HF transceiver
- IC-765 - HF transceiver
- IC-775 - HF transceiver
- IC-781 - Flagship HF transceiver

**VHF/UHF/Satellite:**
- IC-910H ✅ (we have this in IcomRadioModel but not in RadioDefinition)
- IC-970 - VHF/UHF all-mode

**Receivers:**
- IC-R71A - HF receiver (classic)
- IC-R75 ✅ (we have this in IcomRadioModel but not in RadioDefinition)
- IC-R8500 - Wide-band receiver
- IC-R9000 - Professional receiver
- IC-PCR1000 - Computer-controlled receiver
- IC-PCR2500 - Computer-controlled receiver

---

### 2. YAESU

#### ✅ Models We Already Support (10)
- **Modern Flagships:**
  - FTDX-101MP ✅
  - FTDX-101D ✅
  - FTDX-10 ✅

- **All-Mode/Mobile:**
  - FT-991A ✅
  - FT-891 ✅
  - FT-897D ✅
  - FT-857D ✅
  - FT-817 ✅

- **HF:**
  - FT-710 ✅
  - FT-450D ✅

#### ❌ High-Priority Missing Models

**Modern (2015+):**
- FT-818 - Portable QRP (2023, successor to FT-817)

**Popular Legacy (2000-2014):**
- FT-950 - HF/6m transceiver
- FT-900 - HF/6m transceiver
- FT-920 - HF/6m transceiver
- FT-847 - All-band transceiver
- FT-840 - HF transceiver
- FT-100 - Compact all-band

**Flagship Series:**
- FTDX-9000 - Ultimate flagship
- FTDX-5000 - Flagship HF/6m
- FTDX-3000 - HF/6m transceiver
- FTDX-1200 - HF/6m transceiver
- FT-2000 - HF/6m transceiver

**Vintage:**
- FT-1000MP - Classic flagship
- FT-1000D - Flagship HF
- FT-990 - HF/6m transceiver
- FT-890 - HF transceiver
- FT-757GXII - Vintage HF

**New Model:**
- FTX-1 - Latest portable (2024)

**Receiver:**
- VR-5000 - Wide-band receiver

---

### 3. KENWOOD

#### ✅ Models We Already Support (12)
- **Modern Flagships:**
  - TS-990S ✅
  - TS-890S ✅

- **HF:**
  - TS-590SG ✅
  - TS-590S ✅
  - TS-480SAT ✅
  - TS-480HX ✅
  - TS-870S ✅
  - TS-2000 ✅

- **VHF/UHF Handhelds:**
  - TH-D74 ✅
  - TH-D72A ✅
  - TM-D710 ✅
  - TM-V71 ✅

#### ❌ High-Priority Missing Models

**Legacy HF (Popular):**
- TS-570 - HF/6m transceiver
- TS-450 - HF transceiver
- TS-850 - HF transceiver
- TS-950S/TS-950SDX - Flagship HF
- TS-690 - 6m all-mode
- TS-790 - VHF/UHF all-mode

**Budget/Entry:**
- TS-50 - Compact HF
- TS-60 - 6m transceiver
- TS-440S - HF transceiver

**Vintage:**
- TS-670 - HF/6m
- TS-940S - HF transceiver

**Receiver:**
- R-5000 - HF receiver

---

### 4. ELECRAFT

#### ✅ Models We Already Support (6) - COMPLETE+
- K4 ✅
- K3S ✅
- K3 ✅ (we have this but MacLoggerDX lists K3S)
- KX3 ✅
- KX2 ✅
- K2 (MacLoggerDX has K2/K2-100, we should add)

#### ❌ Missing Models
- K2/K2-100 (with KIO2) - Classic QRP transceiver

**Status:** Nearly complete, just need K2

---

### 5. TEN-TEC (Not Currently Supported)

MacLoggerDX supports 6 Ten-Tec models:

**Transceivers:**
- Jupiter - HF transceiver
- Argonaut V - QRP transceiver
- Argonaut VI - QRP transceiver
- Orion - Flagship HF transceiver
- Eagle - Flagship HF transceiver
- Omni VI - HF transceiver
- Omni VII - HF transceiver

**Receivers:**
- RX-320 - PC-controlled HF receiver
- RX-350 - DSP HF receiver
- Pegasus - Software-defined transceiver

**Priority:** MEDIUM (Ten-Tec has ceased operations, but radios still in use)

---

### 6. XIEGU (Not Currently Supported)

MacLoggerDX supports 3 Xiegu models:

- **G90** - Budget HF transceiver (extremely popular with new hams)
- **X6100** - Portable SDR transceiver (very popular)
- **X6200** - Enhanced portable SDR (newest model)

**Priority:** HIGH - Growing market segment, popular with new/budget-conscious hams

---

### 7. FLEXRADIO (Not Currently Supported)

MacLoggerDX supports:

- **Flex 6000 series** (6300, 6400, 6500, 6600, 6700)
- **Flex 8000 series** (8600)

**Priority:** MEDIUM - High-end SDR market, network-based protocol

---

### 8. OTHER MANUFACTURERS (Not Currently Supported)

MacLoggerDX also supports:

**JRC (Japanese Radio Company):**
- JST-245
- NRD-525, NRD-535, NRD-545 (receivers)

**Drake:**
- R8B (receiver)

**AOR (receivers):**
- AR8200, AR8600, AR5000, AR3000A, AR7030

**Other SDR:**
- SunSDR2 series (Pro, DX, QRP, MB1, Colibri)
- Apache Labs ANAN
- ELAD FDM-DUO

**Vintage:**
- Racal 6790/GM
- Alinco DX-77
- Rockwell-Collins HF-2050
- Collins/AOR DDS-2A
- DZKit Sienna

**Priority:** LOW - Niche equipment, specialized use cases

---

## PHASE 3 STRATEGIC PRIORITIES

Based on MacLoggerDX comparison, here are recommended priorities:

### **Priority 3.1: Complete Existing Icom Support (HIGHEST)**
**Effort:** 1-2 weeks
**Impact:** HIGH

We already have IcomRadioModel enums for these but no RadioDefinition entries:
1. IC-706/706MKII/706MKIIG (very popular mobile)
2. IC-746/746Pro (popular HF)
3. IC-756 series (4 models: IC-756, Pro, ProII, ProIII)
4. IC-910H (VHF/UHF satellite)
5. IC-R75 (receiver)

**Action:** Create RadioDefinition entries for models that already have IcomRadioModel support

---

### **Priority 3.2: High-Demand Missing Icom Models**
**Effort:** 3-4 weeks total
**Impact:** HIGH

1. **IC-718** - Budget HF (extremely popular, similar to IC-7100)
2. **IC-7000** - All-band mobile (very popular, similar to IC-7100)
3. **IC-7200** - Budget HF (similar to IC-7100)
4. **IC-703** - Portable QRP (similar to IC-705)
5. **IC-9100** - VHF/UHF (similar to IC-9700)
6. **IC-905** - VHF/UHF microwave (NEW 2024, similar to IC-9700)

---

### **Priority 3.3: Xiegu Support (HIGH)**
**Effort:** 3-4 weeks (new manufacturer)
**Impact:** HIGH - Growing market

1. **G90** - Popular budget HF
2. **X6100** - Popular portable SDR
3. **X6200** - Latest portable SDR

---

### **Priority 3.4: Popular Yaesu Missing Models**
**Effort:** 2-3 weeks
**Impact:** MEDIUM-HIGH

1. **FT-818** - New portable (2023)
2. **FT-2000** - Popular HF
3. **FT-950** - Popular HF
4. **FTDX-3000** - Popular flagship
5. **FTDX-5000** - Flagship

---

### **Priority 3.5: Ten-Tec Support**
**Effort:** 4-5 weeks (new manufacturer)
**Impact:** MEDIUM

1. **Orion/Eagle** - Flagship models
2. **Jupiter** - Popular model
3. **Argonaut V/VI** - QRP models
4. **Omni VI/VII** - Classic models

---

### **Priority 3.6: FlexRadio Support**
**Effort:** 4-6 weeks (complex network protocol)
**Impact:** MEDIUM

1. **Flex 6000 series** - Network-based SDR

---

## RECOMMENDED IMPLEMENTATION ORDER

### Phase 3A: Quick Wins (2-3 weeks)
1. ✅ Complete existing Icom models (IC-706, IC-746, IC-756 series) - just add RadioDefinition entries
2. Add IC-718, IC-7000, IC-7200 (use existing IC-7100/7600 protocols)

### Phase 3B: Xiegu Support (3-4 weeks)
1. Implement Xiegu protocol (new manufacturer)
2. Add G90, X6100, X6200

### Phase 3C: Expand Yaesu (2-3 weeks)
1. Add FT-818, FT-2000, FT-950 (use existing Yaesu CAT protocol)
2. Add FTDX-3000, FTDX-5000 (flagship series)

### Phase 3D: Ten-Tec Support (4-5 weeks)
1. Implement Ten-Tec protocol (new manufacturer)
2. Add popular models (Orion, Eagle, Jupiter, Argonaut series)

### Phase 3E: Advanced SDR (4-6 weeks)
1. FlexRadio network protocol
2. Flex 6000/8000 series support

---

## IMPACT ANALYSIS

### With Phase 3A-C Complete:
- **Icom:** 18 models (vs MacLoggerDX's 40) - 45% coverage
- **Yaesu:** 15 models (vs MacLoggerDX's 22) - 68% coverage
- **Kenwood:** 12 models (vs MacLoggerDX's 19) - 63% coverage
- **Elecraft:** 6 models (vs MacLoggerDX's 4) - 150% coverage ✅
- **Xiegu:** 3 models (vs MacLoggerDX's 3) - 100% coverage ✅

**Total:** ~54 models (vs MacLoggerDX's ~150) - **36% coverage**
**Modern radios (2010+):** ~90% coverage ✅

### With All Phases Complete:
**Total:** ~70+ models - **50% coverage of MacLoggerDX**
Focus on modern, popular radios with strategic vintage support

---

## CONCLUSION

**Recommendation:** Focus on Phase 3A-C to achieve strong coverage of modern popular radios while maintaining code quality. Phase 3D-E can be deferred based on user demand.

**Strategic Advantage:** SwiftRigControl will have better modern radio support than MacLoggerDX (newer models, better DSP controls) while covering the most popular legacy models.
