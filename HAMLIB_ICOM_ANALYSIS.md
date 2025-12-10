# Hamlib Icom Implementation Analysis

**Date**: 2025-12-10
**Purpose**: Guide SwiftRigControl implementation based on Hamlib's proven approach

## Executive Summary

Hamlib supports **80+ Icom radio models** through a modular architecture that uses capability flags and radio-specific parameter structures. Key findings:

1. **All radios use standard CI-V protocol** with minor variations
2. **Mode filter handling** is the primary differentiator (some radios require filter byte, others reject it)
3. **Modern radios (2010+)** mostly follow standard command patterns
4. **Legacy radios (pre-2010)** have more quirks and custom handling

## Key Capability Flags in Hamlib

### 1. `mode_with_filter` (Most Important)
- **Enabled (1)**: Radio requires filter byte in mode commands (IC-7300, IC-9700, IC-7610, IC-7600, IC-9100, IC-7200)
- **Disabled (0)**: Radio rejects filter byte (IC-7100, IC-705)
- **Maps to our**: `requiresModeFilter` capability flag

### 2. `no_xchg` (VFO Exchange)
- **Enabled (1)**: Radio flickers during VFO exchange, use direct VFO set instead (IC-7300, IC-9100)
- **Disabled (0)**: Can use VFO exchange (IC-7100, IC-705, IC-7200)
- **Maps to our**: `requiresVFOSelection` capability flag (indirectly)

### 3. `civ_731_mode`
- **Always 0 for modern radios** - Legacy IC-731 compatibility mode
- **Not relevant** for radios we're implementing

### 4. `data_mode_supported`
- **Most modern radios support this** (PKTLSB, PKTUSB, PKTFM)
- **Not critical** for basic CAT control

## Radio Categorization Based on Hamlib

### **Category 1: Standard Modern Radios** (2010+)
These radios follow standard CI-V protocol with **filter byte required**:

| Radio | CI-V Addr | Max Power | Baud Rate | No XCHG | Notes |
|-------|-----------|-----------|-----------|---------|-------|
| IC-7300 | 0x94 | 100W | 115200 | ✓ | HF/6m entry-level, very popular |
| IC-7610 | 0x98 | 100W | 115200 | ✓ | HF/6m SDR, dual receiver |
| IC-9700 | 0xA2 | 100W | 115200 | ✓ | VHF/UHF/1.2GHz, dual receiver |
| IC-705 | 0xA4 | 10W | 115200 | No | HF/VHF/UHF portable (NO filter!) |
| IC-9100 | 0x7C | 100W | 115200 | ✓ | HF/VHF/UHF, dual receiver |

**Command Set**: `StandardIcomCommandSet` (with filter byte)

### **Category 2: IC-7100 Family** (Different behavior)
These radios **reject filter byte** in mode commands:

| Radio | CI-V Addr | Max Power | Baud Rate | No XCHG | Notes |
|-------|-----------|-----------|-----------|---------|-------|
| IC-7100 | 0x88 | 100W | 19200 | No | HF/VHF/UHF mobile, echoes commands |
| IC-705 | 0xA4 | 10W | 115200 | No | Portable, echoes commands (NO filter!) |

**Command Set**: `IC7100CommandSet` (no filter byte, echoes commands)

### **Category 3: Mid-Range Standard** (2010-2020)
Standard CI-V with **filter byte required**:

| Radio | CI-V Addr | Max Power | Baud Rate | Notes |
|-------|-----------|-----------|-----------|-------|
| IC-7200 | 0x76 | 100W | 19200 | HF/6m mid-range |
| IC-7600 | 0x7A | 100W | 19200 | HF/6m high-end |
| IC-7410 | 0x80 | 100W | 19200 | HF/6m |

**Command Set**: `StandardIcomCommandSet`

### **Category 4: High-End Transceivers** (2000s)
Standard CI-V protocol:

| Radio | CI-V Addr | Max Power | Baud Rate | Notes |
|-------|-----------|-----------|-----------|-------|
| IC-7700 | 0x74 | 200W | 19200 | HF/6m flagship |
| IC-7800 | 0x6A | 200W | 19200 | HF/6m flagship |

**Command Set**: `StandardIcomCommandSet`

### **Category 5: Legacy Radios** (1990s-2000s)
Older CI-V protocol with **some custom handling**:

| Radio | CI-V Addr | Max Power | Baud Rate | Notes |
|-------|-----------|-----------|-----------|-------|
| IC-756 | 0x50 | 100W | 19200 | HF/6m, no PTT via CI-V |
| IC-756PRO | 0x5C | 100W | 19200 | HF/6m, PTT supported |
| IC-756PROII | 0x64 | 100W | 19200 | HF/6m, data mode |
| IC-756PROIII | 0x6E | 100W | 19200 | HF/6m, most advanced |
| IC-746PRO | 0x66 | 100W | 19200 | HF/VHF |
| IC-7000 | 0x70 | 100W | 19200 | HF/VHF/UHF mobile |

**Command Set**: `StandardIcomCommandSet` (may need custom quirks for very old models)

### **Category 6: Mobile/Portable VHF/UHF**

| Radio | CI-V Addr | Max Power | Baud Rate | Notes |
|-------|-----------|-----------|-----------|-------|
| ID-5100 | 0x86 | 50W | 19200 | VHF/UHF mobile, D-STAR |
| ID-4100 | 0x76 | 65W | 19200 | VHF/UHF mobile, D-STAR |

**Command Set**: `StandardIcomCommandSet`

### **Category 7: Receivers**

| Radio | CI-V Addr | Baud Rate | Notes |
|-------|-----------|-----------|-------|
| IC-R8600 | 0x96 | 115200 | Wideband receiver |
| IC-R9500 | 0x7A | 19200 | Communications receiver |
| IC-R75 | 0x5A | 19200 | HF receiver |

**Command Set**: `StandardIcomCommandSet` (no PTT, no power control)

## Key Patterns Identified

### 1. **Mode Filter Byte**
- **Modern HF radios with DSP filters** (IC-7300, IC-7610, IC-9700, IC-9100): **REQUIRE** filter byte
- **IC-7100 family**: **REJECT** filter byte (NAK response)
- **IC-705**: **Despite being modern, follows IC-7100 pattern** (NO filter byte)

### 2. **Command Echo**
- **IC-7100, IC-705**: Echo commands back before sending response
- **All other radios**: No echo

### 3. **VFO Selection**
- **Radios with no_xchg=1** (IC-7300, IC-9100, IC-9700): **Require explicit VFO selection**
- **IC-7100, IC-705, IC-7200**: **Don't require VFO selection**

### 4. **Baud Rate Progression**
- **Legacy radios (pre-2010)**: 19200 baud
- **Modern radios (2010+)**: 115200 baud
- **Exception**: IC-7100 (2013) still uses 19200 baud

## Mapping to SwiftRigControl CommandSets

### IC7100CommandSet
**Use for**: IC-7100, IC-705
- No filter byte in mode commands
- Echoes commands
- No VFO selection required

### IC9700CommandSet
**Use for**: IC-9700 only (has unique dual-band characteristics)
- Filter byte required
- No echo
- VFO selection required

### StandardIcomCommandSet
**Use for**: IC-7300, IC-7610, IC-7600, IC-9100, IC-7200, IC-7410, IC-7700, IC-7800, IC-756 series, IC-746PRO, IC-7000, ID-5100, ID-4100, IC-R8600, IC-R75, IC-R9500

**Configuration patterns**:
```swift
// Modern HF/6m with DSP filters
StandardIcomCommandSet(civAddress: 0x94, echoesCommands: false, requiresVFOSelection: true)

// Older HF radios
StandardIcomCommandSet(civAddress: 0x76, echoesCommands: false, requiresVFOSelection: false)

// Receivers (no PTT/power)
StandardIcomCommandSet(civAddress: 0x96, echoesCommands: false, requiresVFOSelection: true)
```

## Recommended Implementation Priority

### Phase 1: Already Complete ✅
- IC-7100, IC-9700, IC-705, IC-7300, IC-7610, IC-7600

### Phase 2: High Priority (Popular Current Models)
1. **IC-9100** (0x7C) - HF/VHF/UHF, very popular, standard commands
2. **IC-7200** (0x76) - HF/6m mid-range, standard commands
3. **IC-7410** (0x80) - HF/6m, standard commands

### Phase 3: High-End Models
4. **IC-7700** (0x74) - HF/6m flagship, 200W
5. **IC-7800** (0x6A) - HF/6m flagship, 200W

### Phase 4: Legacy Popular
6. **IC-7000** (0x70) - HF/VHF/UHF mobile, widely used
7. **IC-756PROIII** (0x6E) - HF/6m, still in use
8. **IC-746PRO** (0x66) - HF/VHF

### Phase 5: D-STAR Mobiles
9. **ID-5100** (0x86) - VHF/UHF mobile with D-STAR
10. **ID-4100** (0x76) - VHF/UHF mobile with D-STAR

### Phase 6: Receivers
11. **IC-R8600** (0x96) - Wideband receiver
12. **IC-R75** (0x5A) - HF receiver

## Summary

- **~90% of radios can use StandardIcomCommandSet** with different configurations
- **IC-7100/IC-705 need IC7100CommandSet** (no filter, echo)
- **IC-9700 has IC9700CommandSet** (but could also use Standard with custom VFO handling)
- **Key differentiators**: mode_with_filter, no_xchg, command echo
- **All Icom radios use percentage (0-100%) for power display**

## Next Steps for SwiftRigControl

1. Add Tier 2 radios (IC-9100, IC-7200) using StandardIcomCommandSet
2. Add Tier 3 radios (IC-7700, IC-7800) using StandardIcomCommandSet
3. Add Tier 4 legacy radios (IC-7000, IC-756PROIII, IC-746PRO)
4. Add D-STAR mobiles and receivers
5. Consider adding IC-7410 (similar to IC-7200)
6. Test with hardware where available
