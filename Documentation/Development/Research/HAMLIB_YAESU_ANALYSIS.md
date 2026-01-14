# Hamlib Yaesu Radio Analysis

## Executive Summary

Yaesu radios in Hamlib use multiple CAT (Computer Aided Transceiver) protocol variants. Unlike Kenwood's uniform ASCII protocol or Icom's CI-V binary protocol, Yaesu has evolved through several CAT system generations, each with different command structures and capabilities.

**Current Implementation Status:**
- **Implemented**: 6 radios (FTDX-10, FT-991A, FT-710, FT-891, FT-817, FTDX-101D)
- **Hamlib Support**: 60+ Yaesu models across multiple protocol generations
- **Priority for Addition**: FT-dx101MP, FT-dx10, FT-897D, FT-857D, FTM-400DR, FTM-300D

## Yaesu CAT Protocol Evolution

### Protocol Generations

1. **CAT System (Legacy)**
   - Models: FT-817, FT-857D, FT-897D
   - Binary protocol with 5-byte commands
   - Baud: 4800/9600/38400
   - Limited functionality compared to modern

2. **CAT System Extended**
   - Models: FT-450D, FT-950, FT-2000
   - Enhanced binary commands
   - Baud: 4800/38400
   - More comprehensive control

3. **SCU-17/USB CAT (Modern)**
   - Models: FT-991A, FTDX-10, FTDX-101D, FT-710
   - Binary protocol with extended commands
   - Baud: 4800/9600/38400 (most use 38400)
   - Full radio control including scope data

4. **FTM CAT (VHF/UHF)**
   - Models: FTM-400DR, FTM-300D
   - Different command structure for mobiles
   - Baud: 19200/38400
   - APRS and C4FM digital support

## Radio Categories

### 1. Modern HF Flagships (Priority 1)

#### FT-dx101D/MP - 100/200W HF/6m SDR Flagship
- **Power**: 100W (D model), 200W (MP model)
- **Baud**: 38400
- **Bands**: 160m-6m, general coverage RX
- **Modes**: LSB, USB, CW, RTTY, AM, FM, DATA (PSK/FT8)
- **Features**: Dual RX, built-in ATU, spectrum scope, high-resolution display
- **CAT**: SCU-17 protocol (modern extended)
- **Status**: FTDX-101D implemented, need FTDX-101MP

#### FTDX-10 - 100W HF/6m Compact Flagship
- **Power**: 100W
- **Baud**: 38400
- **Bands**: 160m-6m
- **Modes**: LSB, USB, CW, RTTY, AM, FM, DATA
- **Features**: Built-in ATU, spectrum scope, USB audio
- **CAT**: SCU-17 protocol
- **Status**: ✅ Implemented

#### FT-710 AESS - 100W HF/6m Simplified
- **Power**: 100W
- **Baud**: 38400
- **Bands**: 160m-6m
- **Modes**: LSB, USB, CW, RTTY, AM, FM, DATA
- **Features**: Simplified FTDX-10, built-in ATU
- **CAT**: SCU-17 protocol
- **Status**: ✅ Implemented

### 2. HF All-Mode Portables/Field (Priority 2)

#### FT-991A - HF/VHF/UHF All-Mode
- **Power**: 100W HF/6m/2m, 50W 70cm
- **Baud**: 38400
- **Bands**: 160m-70cm, continuous RX
- **Modes**: LSB, USB, CW, RTTY, AM, FM, C4FM, DATA
- **Features**: Built-in ATU, C4FM digital, waterfall, RTTY/PSK decoder
- **CAT**: SCU-17 protocol
- **Status**: ✅ Implemented

#### FT-891 - 100W HF/6m Field Transceiver
- **Power**: 100W
- **Baud**: 38400
- **Bands**: 160m-6m
- **Modes**: LSB, USB, CW, RTTY, AM, FM, DATA
- **Features**: Compact for portable/field ops, built-in ATU
- **CAT**: SCU-17 protocol
- **Status**: ✅ Implemented

#### FT-817ND - 5W QRP HF/VHF/UHF
- **Power**: 5W (all bands)
- **Baud**: 4800/9600/38400
- **Bands**: 160m-70cm
- **Modes**: LSB, USB, CW, AM, FM, DATA
- **Features**: Ultra-compact, battery powered, legendary QRP radio
- **CAT**: Legacy CAT system (5-byte commands)
- **Status**: FT-817 implemented (same protocol as FT-817ND)

### 3. Legacy HF Transceivers (Priority 3)

#### FT-857D - 100W HF/VHF/UHF Mobile
- **Power**: 100W HF/6m/2m, 50W 70cm
- **Baud**: 4800/9600/38400
- **Bands**: 160m-70cm
- **Modes**: LSB, USB, CW, RTTY, AM, FM, DATA
- **Features**: Compact mobile, detachable faceplate, very popular
- **CAT**: Legacy CAT system (compatible with FT-817)
- **Status**: Not implemented

#### FT-897D - 100W HF/VHF/UHF Base/Mobile
- **Power**: 100W HF/6m/2m, 50W 70cm
- **Baud**: 4800/9600/38400
- **Bands**: 160m-70cm
- **Modes**: LSB, USB, CW, RTTY, AM, FM, DATA
- **Features**: Base/mobile hybrid, built-in ATU, battery operation
- **CAT**: Legacy CAT system (compatible with FT-817)
- **Status**: Not implemented

#### FT-450D - 100W HF/6m
- **Power**: 100W
- **Baud**: 4800/38400
- **Bands**: 160m-6m
- **Modes**: LSB, USB, CW, RTTY, AM, FM, DATA
- **Features**: Budget-friendly HF, built-in ATU, DNR/DNF
- **CAT**: Extended CAT system
- **Status**: Not implemented

#### FT-950 - 100W HF/6m
- **Power**: 100W
- **Baud**: 4800/38400
- **Bands**: 160m-6m
- **Modes**: LSB, USB, CW, RTTY, AM, FM, DATA
- **Features**: Mid-range HF, dual RX, roofing filters
- **CAT**: Extended CAT system
- **Status**: Not implemented

#### FT-2000(D) - 100W/200W HF/6m Flagship
- **Power**: 100W (FT-2000), 200W (FT-2000D)
- **Baud**: 4800/38400
- **Bands**: 160m-6m
- **Modes**: LSB, USB, CW, RTTY, AM, FM, DATA
- **Features**: High-end HF, dual RX, roofing filters, contest-grade
- **CAT**: Extended CAT system
- **Status**: Not implemented

### 4. VHF/UHF Mobiles (Priority 2)

#### FTM-400XDR - 50W VHF/UHF C4FM Digital
- **Power**: 50W
- **Baud**: 19200/38400
- **Bands**: 2m/70cm
- **Modes**: FM, FM-N, C4FM (System Fusion)
- **Features**: Color touchscreen, APRS, dual RX, GPS, Bluetooth
- **CAT**: FTM CAT protocol
- **Status**: Not implemented

#### FTM-300D - 50W VHF/UHF C4FM Digital
- **Power**: 50W
- **Baud**: 19200/38400
- **Bands**: 2m/70cm
- **Modes**: FM, FM-N, C4FM
- **Features**: Compact, APRS, dual RX, GPS, Bluetooth, simplified FTM-400
- **CAT**: FTM CAT protocol
- **Status**: Not implemented

#### FTM-100DR - 50W VHF/UHF C4FM Digital
- **Power**: 50W
- **Baud**: 19200/38400
- **Bands**: 2m/70cm
- **Modes**: FM, FM-N, C4FM
- **Features**: Dual RX, APRS, GPS optional
- **CAT**: FTM CAT protocol
- **Status**: Not implemented

### 5. Classic HF Transceivers (Historical Interest)

#### FT-1000MP Mark-V Field - 200W HF/6m Flagship (2001)
- **Power**: 200W
- **Baud**: 4800
- **Bands**: 160m-6m
- **Modes**: LSB, USB, CW, RTTY, AM, FM
- **Features**: Contest-grade, dual RX, legendary status among contesters
- **CAT**: Early extended CAT
- **Status**: Not implemented

#### FT-920 - 100W HF/6m (1996-2003)
- **Power**: 100W
- **Baud**: 4800
- **Bands**: 160m-6m
- **Modes**: LSB, USB, CW, RTTY, AM, FM
- **Features**: Mid-range HF, general coverage RX
- **CAT**: Early CAT system
- **Status**: Not implemented

## CAT Protocol Characteristics

### Command Structure

**Legacy CAT (FT-817/857D/897D):**
```
5-byte command structure:
[P1] [P2] [P3] [P4] [CMD]

Example - Set frequency 14.250 MHz:
0x01 0x42 0x50 0x00 0x01
```

**Modern CAT (FT-991A/FTDX-10/FTDX-101D):**
```
Variable length with extended commands:
[Prefix] [P1] [P2] [P3] [P4] [CMD]

Example - Read frequency:
0x00 0x00 0x00 0x00 0x03
```

### Serial Configuration

- **Baud Rates**: 4800, 9600, 19200, 38400 (most modern use 38400)
- **Data Format**: 8N2 (8 data bits, no parity, 2 stop bits) for legacy
- **Data Format**: 8N1 for modern radios
- **Flow Control**: None or RTS/CTS

### Key Commands (Modern CAT)

- **0x01**: Set frequency
- **0x03**: Read frequency
- **0x07**: Set mode
- **0x0C**: PTT control
- **0x14**: Get transmit status
- **0x1C**: PTT status
- **0xBB**: Read S-meter
- **0xF7**: Read transmit power
- **Scope commands**: Various extended commands for spectrum data

## Implementation Patterns

### Yaesu CAT Protocol Characteristics

1. **Binary Protocol**: All Yaesu radios use binary commands (vs Kenwood's ASCII)
2. **BCD Encoding**: Frequencies encoded in BCD format
3. **Command Acknowledgment**: Most commands return data or status
4. **No Echo**: Radios don't echo commands (unlike some Icom models)

### Radio Groupings by Protocol

**Group 1: Modern SCU-17 (Same Protocol)**
- FTDX-101D/MP, FTDX-10, FT-710, FT-991A, FT-891
- Can share command set implementation
- Differences: frequency ranges, power levels, features

**Group 2: Legacy CAT (Compatible)**
- FT-817/ND, FT-857D, FT-897D
- Share 5-byte command structure
- Very similar implementation

**Group 3: Extended CAT**
- FT-450D, FT-950, FT-2000
- Enhanced over legacy but not modern SCU-17
- Bridge between old and new

**Group 4: FTM Mobile**
- FTM-400XDR, FTM-300D, FTM-100DR
- Different command structure
- May need separate protocol implementation

## Recommended Implementation Priority

### Phase 1: Complete Modern HF (High Priority)
1. **FTDX-101MP** (200W version of FTDX-101D) - Same protocol, just power difference
2. **FT-450D** (Popular budget HF) - Extended CAT
3. **FT-950** (Mid-range HF with dual RX) - Extended CAT

### Phase 2: Legacy All-Mode (High Usage)
4. **FT-857D** (Very popular mobile) - Legacy CAT
5. **FT-897D** (Popular base/mobile) - Legacy CAT

### Phase 3: VHF/UHF Digital (Modern Users)
6. **FTM-400XDR** (Premium C4FM mobile) - FTM CAT
7. **FTM-300D** (Compact C4FM mobile) - FTM CAT

### Phase 4: Contest/Classic HF (Lower Priority)
8. **FT-2000D** (200W flagship) - Extended CAT
9. **FT-1000MP Mark-V** (Classic contest radio) - Early CAT

## Protocol Implementation Strategy

### Current Architecture
The existing `YaesuCATProtocol` actor already handles modern SCU-17 protocol radios well. The implementation is clean and doesn't require refactoring like Icom did.

### Recommended Approach

**For Modern Radios (SCU-17 Protocol):**
- Use existing `YaesuCATProtocol`
- Only need to add RadioCapabilities and RadioDefinitions
- Protocol differences are minimal (mainly frequency ranges and power)

**For Legacy Radios (5-byte CAT):**
- May need `YaesuLegacyCATProtocol` for FT-817/857D/897D family
- Or extend existing protocol with command set abstraction
- Consider creating `YaesuCommandSet` protocol similar to Icom's approach

**For FTM Mobiles:**
- Likely needs separate `YaesuFTMProtocol` implementation
- Command structure differs significantly from HF radios

## Key Differences: Yaesu vs Icom vs Kenwood

| Aspect | Yaesu | Icom | Kenwood |
|--------|-------|------|---------|
| **Protocol Type** | Binary (multiple variants) | Binary (CI-V) | ASCII |
| **Consistency** | 3-4 protocol generations | Mostly uniform | Very uniform |
| **Baud Rates** | 4800/9600/38400 | 4800/9600/19200/115200 | 4800/9600/115200 |
| **Command Echo** | No | Some models | No |
| **Frequency Encoding** | BCD | BCD | ASCII decimal |
| **Complexity** | Medium-High | Medium | Low |

## Technical References

- **Hamlib Source**: `yaesu/` directory contains separate files per model family
- **CAT Documentation**: Available in radio manuals (CAT operation sections)
- **Command Sets**:
  - `newcat.c` - Modern SCU-17 radios
  - `ft817.c` - Legacy 5-byte CAT
  - `ft450.c` - Extended CAT
  - `ftm.c` - FTM mobile CAT

## Summary Statistics

- **Total Yaesu Models in Hamlib**: ~60 radios
- **Currently Implemented**: 6 radios (10%)
- **High Priority to Add**: 9 radios
- **Protocol Families**: 4 major variants
- **Most Common Baud**: 38400 (modern), 4800/9600 (legacy)
- **Typical Power**: 5W (QRP), 50W (mobile), 100-200W (base)

## Implementation Notes

1. **Modern radios share protocol**: FTDX-101MP can reuse FTDX-101D implementation
2. **Legacy radios compatible**: FT-857D/897D can share FT-817 command structure
3. **VHF/UHF radios different**: FTM series needs dedicated protocol
4. **BCD encoding consistent**: All Yaesu radios use same BCD format for frequencies
5. **No filter byte issues**: Unlike Icom, mode commands are simpler

## Next Steps

1. Add FTDX-101MP (simple - same as FTDX-101D but 200W)
2. Add FT-857D and FT-897D (may need legacy CAT protocol)
3. Add FT-450D and FT-950 (extended CAT)
4. Add FTM-400XDR and FTM-300D (new FTM protocol)
5. Consider creating protocol abstraction if legacy/FTM support needed
