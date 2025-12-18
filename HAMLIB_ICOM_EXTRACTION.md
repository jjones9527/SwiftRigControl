# Hamlib Icom Radio CI-V Implementation Details

Extracted from Hamlib GitHub repository (https://github.com/Hamlib/Hamlib)
Date: 2025-12-17

## Overview of CI-V Protocol Patterns

### VFO Models
Icom radios follow three main VFO architectures:
1. **VFO A/B Only**: Simple dual VFO (e.g., IC-706, IC-746, IC-756)
2. **Main/Sub Only**: Dual receiver with main and sub (e.g., IC-7600, IC-7800)
3. **Main/Sub + A/B**: Satellite-capable with dual receivers, each having A/B VFOs (e.g., IC-9100, IC-910)

### VFO Targeting
- Command 0x25: Targeted frequency read/write
- Command 0x26: Targeted mode operations
- **Limitation**: 0x25/0x26 can manipulate either A/B or Main/Sub, but not both levels simultaneously
- Radios with Main/Sub+A/B require VFO swapping to access Sub receiver's A/B VFOs

### Mode Commands and Filter Bytes
- **Legacy radios**: Command 0x04 for mode, no filter byte or simple filter
- **Modern radios**: Command 0x26 for mode with 3-byte response (mode, data mode flag, filter)
- **Filter handling**:
  - No filter byte: Older models without DSP
  - Filter indices: 1=wide, 2=normal, 3=narrow (most models)
  - FM special encoding: Bandwidth encoded in filter byte on newer models

### Echo Behavior
- **USB CI-V**: Auto-detected during initialization; may or may not echo
- **Serial**: Typically no echo
- Detection method: Send command, if single-byte echo received, USB echo is enabled

---

## Radio Family: IC-706 Series (All-Mode HF/VHF Mobile)

### IC-706
**Model**: RIG_MODEL_IC706
**CI-V Address**: 0x48
**Baud Rate**: 300-19200 (default 19200)
**Echo**: USB CI-V may not echo
**VFO Model**: VFO A/B + Memory
**Mode Filter**: No filter byte in mode commands
**Max Power**: 100W (HF/6m: CW/SSB/RTTY/FM), 40W (AM)
**Frequency**: HF + 6m + 2m (RX: 30kHz-200MHz)
**Quirks**:
- Basic CI-V implementation
- No transceive for memory mode
- Wide FM receive only (no WFM transmit)

### IC-706MKII
**Model**: RIG_MODEL_IC706MKII
**CI-V Address**: 0x4E
**Baud Rate**: 300-19200 (default 19200)
**Echo**: USB CI-V may not echo
**VFO Model**: VFO A/B + Memory
**Mode Filter**: No filter byte in mode commands
**Max Power**: 100W (HF/6m: CW/SSB/RTTY/FM), 40W (AM)
**Frequency**: HF + 6m + 2m (RX: 30kHz-200MHz)
**Quirks**:
- Enhanced version of IC-706
- Same CI-V protocol as original
- 99 memory channels plus edge/call memory

### IC-706MKIIG
**Model**: RIG_MODEL_IC706MKIIG
**CI-V Address**: 0x58
**Baud Rate**: 300-19200 (default 19200)
**Echo**: USB CI-V may not echo
**VFO Model**: VFO A/B + Memory
**Mode Filter**: No filter byte in mode commands
**Max Power**: 100W (HF/6m), 50W (2m), 20W (70cm)
**Frequency**: HF + 6m + 2m + 70cm (RX: 30kHz-200MHz, 400-470MHz)
**Quirks**:
- "IC-706MKII plus UHF, DSP, and 50W VHF"
- Includes DCD (carrier detect) support
- Full multi-band mobile transceiver

---

## Radio Family: IC-746 Series (HF + 6m Base Station)

### IC-746
**Model**: RIG_MODEL_IC746
**CI-V Address**: 0x56
**Baud Rate**: 300-19200 (default 19200)
**Echo**: Standard serial echo behavior
**VFO Model**: VFO A/B + Memory
**Mode Filter**: No filter byte
**Max Power**: 100W (CW/SSB/RTTY/FM), 40W (AM)
**Frequency**: HF + 6m + 2m receive (RX: 30kHz-60MHz, 108-174MHz)
**Quirks**:
- No DCD support
- No parameter get support
- Limited set parameters (announcement only)

### IC-746PRO
**Model**: RIG_MODEL_IC746PRO
**CI-V Address**: 0x66
**Baud Rate**: 300-19200 (default 19200)
**Echo**: Standard serial echo behavior
**VFO Model**: VFO A/B + Memory
**Mode Filter**: No filter byte (older implementation)
**Max Power**: 100W (CW/SSB/RTTY/FM), 40W (AM)
**Frequency**: HF + 6m + 2m receive (RX: 30kHz-60MHz, 108-174MHz)
**Quirks**:
- DCD type: RIG (receiver detection supported)
- Extended parameter control (backlight, beep, announcements)
- 3 band-stacking registers per ham band (rotates on band change)
- 9-character channel descriptions

---

## Radio Family: IC-756 Series (HF + 6m Base Station)

### IC-756
**Model**: RIG_MODEL_IC756
**CI-V Address**: 0x50
**Baud Rate**: 19200 max
**Echo**: Standard serial echo behavior
**VFO Model**: Main/Sub + Memory
**Mode Filter**: Custom r2i_mode function for older filter width handling (normal/narrow only)
**Max Power**: 100W (CW/SSB/RTTY/FM), 40W (AM)
**Frequency**: HF + 6m (RX: 30kHz-60MHz)
**Quirks**:
- get_vfo commented out across all variants
- Simplified filter: normal/narrow only (no wide)
- Custom mode handling for legacy filter system

### IC-756PRO
**Model**: RIG_MODEL_IC756PRO
**CI-V Address**: 0x5C
**Baud Rate**: 19200 max
**Echo**: Standard serial echo behavior
**VFO Model**: Main/Sub + Memory
**Mode Filter**: Standard filter byte support
**Max Power**: 100W (CW/SSB/RTTY/FM), 40W (AM)
**Frequency**: HF + 6m (RX: 30kHz-60MHz)
**Quirks**:
- RIG_LEVEL_VOXGAIN and RIG_LEVEL_ANTIVOX incorrectly handled (per comments)
- Supports noise blanking, compressor, VOX

### IC-756PROII
**Model**: RIG_MODEL_IC756PROII
**CI-V Address**: 0x64
**Baud Rate**: 19200 max
**Echo**: Standard serial echo behavior
**VFO Model**: Main/Sub + Memory
**Mode Filter**: Standard filter byte support
**Max Power**: 100W (CW/SSB/RTTY/FM), 40W (AM)
**Frequency**: HF + 6m (RX: 30kHz-60MHz)
**Quirks**:
- Custom extended parameters for SSB bass tone
- Memory names supported
- RTTY filter widths configurable

### IC-756PROIII
**Model**: RIG_MODEL_IC756PROIII
**CI-V Address**: 0x6E
**Baud Rate**: 19200 max
**Echo**: Standard serial echo behavior
**VFO Model**: Main/Sub + Memory
**Mode Filter**: Standard filter byte support
**Max Power**: 100W (CW/SSB/RTTY/FM), 40W (AM)
**Frequency**: HF + 6m (RX: 30kHz-60MHz)
**Quirks**:
- Memory split support not available
- Enhanced DSP features
- Custom parameter extensions

---

## Radio Family: IC-7000 (All-Mode HF/VHF/UHF Mobile)

### IC-7000
**Model**: RIG_MODEL_IC7000
**CI-V Address**: 0x70
**Baud Rate**: 19200 max
**Echo**: Standard USB echo detection
**VFO Model**: VFO A/B + Memory
**Mode Filter**: Custom ic7000_r2i_mode function with special bandwidth coding
**Max Power**: 100W (HF/6m), 50W (2m), 35W (70cm); AM: 40W/20W/14W
**Frequency**: HF + 6m + 2m + 70cm (RX: 30kHz-200MHz, 400-470MHz)
**Quirks**:
- Custom passband calculations for filter width
- AGC: Fast, Medium, Slow
- Dual antenna: Ant1 (HF-6m), Ant2 (2m-70cm)
- 99 memory channels plus edge and call memory
- Calibration tables for S-meter, SWR, ALC, RF power, compression

---

## Radio Family: IC-7200 (HF + 6m Base/Mobile)

### IC-7200
**Model**: RIG_MODEL_IC7200
**CI-V Address**: 0x76
**Baud Rate**: 19200 max
**Echo**: Standard USB echo detection
**VFO Model**: VFO A/B + Memory
**Mode Filter**: Standard filter byte support
**Max Power**: 100W (HF/6m: SSB/CW), 40W (AM)
**Frequency**: HF + 6m (RX: 30kHz-60MHz)
**Quirks**:
- TODO: Complete command set (esp. 0x1A commands) per source comments
- Custom level handlers for VOX delay (0x55 command)
- Tuning steps: 1Hz (CW/SSB/RTTY), 10Hz (AM), 100Hz-10kHz (others)
- AGC: OFF, FAST, SLOW
- Calibration data for S-meter, SWR, ALC, RF power

---

## Radio Family: IC-7410 (HF + 6m Base Station)

### IC-7410
**Model**: RIG_MODEL_IC7410
**CI-V Address**: 0x80
**Baud Rate**: 19200 max
**Echo**: Standard USB echo detection
**VFO Model**: VFO A/B + Memory
**Mode Filter**: Standard filter byte support
**Max Power**: 100W (CW/SSB/RTTY/FM), 27W (AM)
**Frequency**: HF + 6m (including USA 5MHz allocations)
**Quirks**:
- Status: BETA (not stable)
- Preamp and attenuator values marked "TBC" (to be confirmed)
- FM filter at 8kHz marked "TBC"
- USA 5MHz range requires verification
- get_vfo function commented out/disabled

---

## Radio Family: IC-7600 (HF + 6m SDR Base Station)

### IC-7600
**Model**: RIG_MODEL_IC7600
**CI-V Address**: 0x7A
**Baud Rate**: 19200 max
**Echo**: Standard USB echo detection
**VFO Model**: Main/Sub + Memory (targetable)
**Mode Filter**: mode_with_filter = 1 (filter byte required)
**Max Power**: 100W (HF/6m: CW/SSB/RTTY/FM), 30W (AM)
**Frequency**: HF + 6m (RX: 30kHz-60MHz)
**Quirks**:
- RIG_TARGETABLE_FREQ | RIG_TARGETABLE_MODE
- Custom extended commands for beep, backlight, time
- AGC: Fast, Medium, Slow
- Dual antenna support
- Calibration tables for SWR, ALC, RF power, compression

---

## Radio Family: IC-7700 (High-End HF + 6m Base Station)

### IC-7700
**Model**: RIG_MODEL_IC7700
**CI-V Address**: 0x74
**Baud Rate**: 19200 max
**Echo**: Standard USB echo detection
**VFO Model**: VFO A/B + Memory (targetable)
**Mode Filter**: Standard filter byte support
**Max Power**: 200W (HF/6m: CW/SSB/RTTY/FM), 50W (AM)
**Frequency**: HF + 6m (RX: 30kHz-60MHz)
**Quirks**:
- RIG_TARGETABLE_FREQ | RIG_TARGETABLE_MODE
- VFOB mode changes require VFO swapping
- 4 antenna inputs supported
- Custom clock setting/getting (date/time with UTC offset)
- Special init sets x25/x26 and x1c/x03 command failure flags
- Calibration: S-meter, SWR, ALC, RF power, compression, voltage, ID meter

---

## Radio Family: IC-7800 (Flagship HF + 6m Base Station)

### IC-7800
**Model**: RIG_MODEL_IC7800
**CI-V Address**: 0x6A
**Baud Rate**: 19200 max
**Echo**: Standard USB echo detection
**VFO Model**: Main/Sub + Memory
**Mode Filter**: Standard filter byte support
**Max Power**: 200W (SSB/CW), 50W (AM)
**Frequency**: HF + 6m (RX: 30kHz-60MHz)
**Quirks**:
- Attenuator uses 0x11 command with index values (not actual dB)
- 1Hz tuning steps across all receive modes
- Specialized meter calibration: SWR, ALC, RF power, compression, voltage, current
- Custom clock/time functions with UTC offset
- Antenna selection: indexed values (1-4)
- Dual-watch capability
- RIT/XIT functions

---

## Radio Family: IC-785x Series (Flagship HF + 6m with Spectrum)

### IC-7850 / IC-7851
**Model**: RIG_MODEL_IC7851
**CI-V Address**: 0x8E
**Baud Rate**: 19200 max
**Echo**: Standard USB echo detection
**VFO Model**: Main/Sub + Memory (targetable)
**Mode Filter**: Standard filter byte support
**Max Power**: 200W (primary modes), 50W (AM)
**Frequency**: HF + 6m (RX: 30kHz-60MHz)
**Quirks**:
- RIG_TARGETABLE_FREQ | RIG_TARGETABLE_MODE | RIG_TARGETABLE_SPECTRUM
- Spectrum scope with dual displays (Main/Sub)
- 4 antenna selections
- Preamp: 12dB and 20dB options
- Attenuator: multiple steps up to 21dB
- Clock functions via IC-7300 implementation
- Extended command parameters for beep, backlight, time, keyer type
- Status: Stable

---

## Radio Family: IC-9100 (Multi-Band with Satellite)

### IC-9100
**Model**: RIG_MODEL_IC9100
**CI-V Address**: 0x7C
**Baud Rate**: 19200 max
**Echo**: Standard USB echo detection
**VFO Model**: Main/Sub + A/B (complex: MAIN_A, MAIN_B, SUB_A, SUB_B)
**Mode Filter**: Standard filter byte support
**Max Power**: 100W (HF/6m/2m), 75W (70cm), 10W (23cm optional)
**Frequency**: HF + 6m + 2m + 70cm + 23cm (RX: 30kHz-1.32GHz)
**Quirks**:
- "no XCHG to avoid display flicker" per source comments
- Borrowed VFO function from IC-9700 for compatibility
- Dual receiver architecture with satellite mode
- AM transmit: 25W on HF bands only
- DSP functions: noise blanker, noise reduction, auto notch

---

## Radio Family: IC-910H (VHF/UHF with Satellite)

### IC-910H
**Model**: RIG_MODEL_IC910
**CI-V Address**: 0x60
**Baud Rate**: 19200 max
**Echo**: Standard USB echo detection
**VFO Model**: Main/Sub + A/B (satellite configuration)
**Mode Filter**: Custom simplified narrow/normal bandwidth (not standard constants)
**Max Power**: 100W (2m), 75W (70cm), No TX (23cm receive only)
**Frequency**: 2m + 70cm + 23cm (RX: 144-148MHz, 430-450MHz, 1240-1300MHz)
**Quirks**:
- Conditional compilation flag for "weird firmware" where Set FM mode conflicts with RTTY
- Simplified bandwidth handling: narrow/normal only
- Dual receiver with satellite mode
- DSP: noise blanker, noise reduction, auto notch
- Developer note: Report firmware issues to Hamlib project

---

## Radio Family: IC-2730 (Dual-Band Mobile)

### IC-2730
**Model**: RIG_MODEL_IC2730
**CI-V Address**: 0x90
**Baud Rate**: 19200 max
**Echo**: Standard USB echo detection
**VFO Model**: Main/Sub (dual VFO, no exchange operations)
**Mode Filter**: No filter byte (FM only)
**Max Power**: 25W (Region 1) or 50W (Region 2)
**Frequency**: 2m + 70cm (RX: VHF/UHF amateur bands)
**Quirks**:
- "No memory support through CI-V, but there is a clone mode apart"
- Tuning step cannot be changed via software (8.33kHz depends on band/mode)
- Signal strength calibration: UNKNOWN_IC_STR_CAL
- No RIT/XIT/IF shift
- Mobile transceiver with dual-band coverage
- RIG_OP_NONE (no VFO exchange operations)

---

## Radio Family: ID-4100 (Dual-Band D-STAR Mobile)

### ID-4100
**Model**: RIG_MODEL_ID4100
**CI-V Address**: 0x9A
**Baud Rate**: 19200 max
**Echo**: Standard USB echo detection
**VFO Model**: Main/Sub (dual VFO, no operations)
**Mode Filter**: No filter byte (FM/D-STAR)
**Max Power**: 25W (Region 1) or 50W (Region 2)
**Frequency**: 2m + 70cm (RX: 144-146MHz/430-440MHz R1, 144-148MHz/430-450MHz R2)
**Quirks**:
- "Use the port labeled 'SP2' for rig control" (not Data port)
- No memory support via CI-V
- Cannot query power status (set_powerstat disabled)
- No tuning step adjustment
- Pending features: DV mode, GPS support, dual watch
- D-STAR digital voice support

---

## Radio Family: ID-5100 (Dual-Band D-STAR Mobile)

### ID-5100
**Model**: RIG_MODEL_ID5100
**CI-V Address**: 0x8C
**Baud Rate**: 19200 max
**Echo**: Standard USB echo detection
**VFO Model**: VFO A/B + Main/Sub (complex dual-watch architecture)
**Mode Filter**: No filter byte (FM/AM/D-STAR)
**Max Power**: 25W (Region 1) or 50W (Region 2) on both 2m and 70cm
**Frequency**: 2m + 70cm (RX: 118-174MHz, 375-550MHz; TX: 144-146/430-440MHz R1)
**Quirks**:
- "Use the port labeled 'SP2' for rig control" (not Data port)
- Automatic mode switching between VFO pairs and main/sub
- Dual-watch mode requires specific VFO management
- Memory support unavailable via CI-V
- Cannot retrieve power status
- Modes: AM, AMN (narrow), FM, FMN (narrow), D-STAR
- Bandwidth: 12/6kHz (AM), 10/5kHz (FM), 6kHz (D-STAR)

---

## Radio Family: IC-R75 (HF Receiver)

### IC-R75
**Model**: RIG_MODEL_ICR75
**CI-V Address**: 0x5A
**Baud Rate**: 19200 max
**Echo**: Standard serial echo behavior
**VFO Model**: VFO + Memory (receiver only)
**Mode Filter**: Standard filter byte support (8 modes)
**Max Power**: N/A (receiver only)
**Frequency**: HF (RX: 30kHz-60MHz)
**Quirks**:
- RIG_TYPE_RECEIVER (no transmit capability)
- TODO: "set_parm, set_trn, IF filter setting, etc." incomplete
- Channel read/write "still a WIP" (work in progress)
- get_channel returns error when read_only=false
- Developer note: "contact hamlib mailing list to implement this"
- Modes: AM, CW, CWR, SSB, FM, RTTY, RTTYR, AMS
- Filter range: 1.9kHz to 15kHz depending on mode

---

## Radio Family: IC-R8600 (Wideband Receiver)

### IC-R8600
**Model**: RIG_MODEL_ICR8600
**CI-V Address**: 0x96
**Baud Rate**: 115200 max (much faster than typical Icom!)
**Echo**: USB CI-V may not echo
**VFO Model**: VFO + Memory (receiver only)
**Mode Filter**: Standard filter byte support
**Max Power**: N/A (receiver only)
**Frequency**: Wideband (RX: 10kHz-3GHz VHF/UHF, 10kHz-30MHz HF)
**Quirks**:
- RIG_TYPE_RECEIVER (no transmit)
- USB CI-V echo warning in comments
- Spectrum scope with 475-line display capability
- 100 memory banks with 100 channels each (10,000 total memories!)
- Multiple AGC levels: Fast, Medium, Slow
- Async data for spectrum functionality
- Extensive mode support: LSB, USB, AM, CW, RTTY, FM, WFM, SAM, P25, D-STAR, DMR, NXDN, DCR

---

## Radio Family: IC-R9500 (Professional Wideband Receiver)

### IC-R9500
**Model**: RIG_MODEL_ICR9500
**CI-V Address**: 0x72
**Baud Rate**: 1200 max (very slow!)
**Echo**: Standard serial echo behavior
**VFO Model**: VFO A + Memory (receiver only)
**Mode Filter**: Standard filter byte support
**Max Power**: N/A (receiver only)
**Frequency**: Professional wideband (RX: 5kHz-3.335GHz)
**Quirks**:
- RIG_TYPE_RECEIVER (no transmit)
- S-meter calibration copied from IC-9700: "Hope it's correct" per comments
- 1000 standard memory slots plus Auto, Skip, Scan edge banks
- Tuning steps: 1Hz to 1MHz resolution
- Modes: AM, AMS, SSB, FM, RTTY, RTTYR, CW, CWR, WFM
- RIG_PTT_NONE (no PTT)

---

## Implementation Patterns for Swift CommandSet Structs

### Grouping by VFO Architecture

**Group 1: Simple VFO A/B** (IC-706 series, IC-746 series, IC-7000, IC-7200, IC-7410)
- Use direct VFO A/B targeting
- No Main/Sub concept
- Memory mode separate

**Group 2: Main/Sub** (IC-756 series, IC-7600, IC-7800)
- Main/Sub receiver architecture
- May support targetable freq/mode (command 0x25/0x26)
- Memory mode separate

**Group 3: Dual Receiver Mobile** (IC-2730, ID-4100, ID-5100)
- Main/Sub for dual receivers
- Limited CI-V operations
- Memory via clone mode or not supported

**Group 4: Satellite Capable** (IC-9100, IC-910H)
- Main/Sub + A/B per receiver
- Complex VFO management
- Requires VFO swapping for Sub receiver A/B access

**Group 5: Receivers** (IC-R75, IC-R8600, IC-R9500)
- No transmit capability
- VFO + Memory
- Simplified protocol

### Mode Command Implementation

**Legacy Mode (Command 0x04)**:
- IC-706 series
- IC-746 (original)
- IC-756 (original)
- No data mode flag
- Simple or no filter byte

**Modern Mode (Command 0x26)**:
- IC-7000 and newer
- 3-byte response: mode, data mode flag, filter
- Filter indices: 1=wide, 2=normal, 3=narrow
- FM special encoding on newer models

**Custom Mode Functions**:
- IC-7000: Custom ic7000_r2i_mode for bandwidth calculations
- IC-756: Custom r2i_mode for legacy filter (normal/narrow only)
- IC-910H: Simplified narrow/normal (not standard constants)

### Echo Detection Strategy

All modern radios should implement USB echo detection:
1. Assume echo is off initially
2. Send first command
3. If single-byte echo received instead of proper response, USB echo is enabled
4. Track echo state in connection properties
5. Strip echo byte from responses when enabled

### Filter Byte Requirements

**No Filter Byte**:
- IC-706 series
- IC-746
- IC-2730, ID-4100, ID-5100 (FM/D-STAR only)

**Simple Filter**:
- IC-756 (custom: normal/narrow)
- IC-910H (custom: narrow/normal)

**Standard Filter**:
- IC-7000 and all modern HF transceivers
- mode_with_filter = 1 flag
- Filter indices typically 1/2/3

**Advanced Filter**:
- IC-7600 and newer: Dynamic filter selection
- IC-785x series: Extended filter options with DSP

### Power Output Patterns

**Standard HF**: 100W (SSB/CW/RTTY/FM), 40W (AM)
**High Power HF**: 200W (SSB/CW/RTTY/FM), 50W (AM) - IC-7700, IC-7800, IC-785x
**Mobile HF/VHF/UHF**: 100W HF, 50W 2m, 20-35W 70cm - IC-706MKIIG, IC-7000
**VHF/UHF Only**: 25W or 50W depending on region - IC-2730, ID-4100, ID-5100
**Satellite**: 100W 2m, 75W 70cm, 10W 23cm - IC-9100
**VHF Satellite**: 100W 2m, 75W 70cm - IC-910H

### Baud Rate Patterns

**Standard**: 19200 max (most radios)
**Legacy**: 1200 max (IC-R9500)
**High Speed**: 115200 max (IC-R8600)

All support lower rates: 300, 1200, 4800, 9600 baud typically available.

### Common Quirks to Handle

1. **USB Echo**: All modern radios require echo detection
2. **VFO Swapping**: Satellite radios (IC-9100, IC-910H) require swapping for Sub receiver A/B access
3. **Band Stacking**: IC-746PRO, IC-756 series rotate band stack on band change
4. **Memory via Clone**: IC-2730, ID-4100 cannot access memory via CI-V
5. **Attenuator Encoding**: IC-7800 uses indexed values (not dB)
6. **Filter Conflicts**: IC-910H has FM mode value conflicts on some firmware
7. **Incomplete Commands**: IC-7200, IC-7410 marked as incomplete/BETA
8. **VOX/Anti-VOX**: IC-756PRO has known incorrect handling
9. **Special Ports**: ID-4100, ID-5100 require SP2 port (not Data port)
10. **Calibration**: Many radios include meter calibration tables for S-meter, SWR, ALC, RF power

---

## Missing Radios

**IC-2820H**: Not implemented in Hamlib. No dedicated source file found in rigs/icom directory.

---

## Swift Implementation Recommendations

### Base Protocol Class
```swift
class IcomCIVProtocol {
    var civAddress: UInt8
    var baudRate: Int
    var echoEnabled: Bool = false
    var vfoArchitecture: VFOArchitecture
    var modeCommandType: ModeCommandType
    var requiresFilterByte: Bool

    enum VFOArchitecture {
        case simpleAB          // IC-706, IC-746, IC-7000, IC-7200
        case mainSub           // IC-756, IC-7600, IC-7800
        case dualReceiverMobile // IC-2730, ID-4100, ID-5100
        case satelliteCapable  // IC-9100, IC-910H (Main/Sub + A/B)
        case receiverOnly      // IC-R75, IC-R8600, IC-R9500
    }

    enum ModeCommandType {
        case legacy0x04        // Old radios
        case modern0x26        // Modern with data mode + filter
        case custom(String)    // Custom function name
    }
}
```

### Radio-Specific CommandSets
Create protocol-based CommandSets that inherit from base and specialize:
- IC706CommandSet (shared by IC-706, MKII, MKIIG)
- IC746CommandSet (IC-746 basic, IC-746PRO extended)
- IC756CommandSet (IC-756, PRO, PROII, PROIII variants)
- IC7000CommandSet
- IC7200CommandSet
- IC7600CommandSet
- IC7700CommandSet
- IC7800CommandSet
- IC785xCommandSet (IC-7850/7851)
- IC9100CommandSet
- IC910HCommandSet
- IC2730CommandSet
- ID4100CommandSet
- ID5100CommandSet
- ICR75CommandSet
- ICR8600CommandSet
- ICR9500CommandSet

### Common Features by Era

**Generation 1 (1990s-early 2000s)**: IC-706, IC-746, IC-756, IC-910H
- Legacy CI-V protocol
- Simple filter handling
- No data mode flag
- 19200 baud max
- Basic transceive

**Generation 2 (mid 2000s)**: IC-7000, IC-7200, IC-7410
- Modern CI-V protocol
- Enhanced filter support
- Data mode support emerging
- 19200 baud max
- USB echo detection

**Generation 3 (late 2000s-2010s)**: IC-7600, IC-7700, IC-7800, IC-9100
- Full modern CI-V
- Targetable VFO operations
- Complete filter byte support
- Advanced features (spectrum, dual watch, DSP)
- 19200 baud max

**Generation 4 (2010s+)**: IC-785x, ID-5100
- Latest CI-V enhancements
- Spectrum scope integration
- Touch screen support
- D-STAR digital modes
- Enhanced memory systems

---

## Command Summary Table

| Radio | CI-V Addr | Baud Max | VFO Type | Mode Cmd | Filter | Echo | Max Power |
|-------|-----------|----------|----------|----------|--------|------|-----------|
| IC-706 | 0x48 | 19200 | A/B | 0x04 | No | USB? | 100W |
| IC-706MKII | 0x4E | 19200 | A/B | 0x04 | No | USB? | 100W |
| IC-706MKIIG | 0x58 | 19200 | A/B | 0x04 | No | USB? | 100W HF/50W VHF/20W UHF |
| IC-746 | 0x56 | 19200 | A/B | 0x04 | No | Std | 100W |
| IC-746PRO | 0x66 | 19200 | A/B | 0x04 | No | Std | 100W |
| IC-756 | 0x50 | 19200 | M/S | Custom | Custom | Std | 100W |
| IC-756PRO | 0x5C | 19200 | M/S | Std | Std | Std | 100W |
| IC-756PROII | 0x64 | 19200 | M/S | Std | Std | Std | 100W |
| IC-756PROIII | 0x6E | 19200 | M/S | Std | Std | Std | 100W |
| IC-7000 | 0x70 | 19200 | A/B | Custom | Custom | USB | 100W HF/50W VHF/35W UHF |
| IC-7200 | 0x76 | 19200 | A/B | Std | Std | USB | 100W |
| IC-7410 | 0x80 | 19200 | A/B | Std | Std | USB | 100W |
| IC-7600 | 0x7A | 19200 | M/S | 0x26 | Yes | USB | 100W |
| IC-7700 | 0x74 | 19200 | A/B | 0x26 | Std | USB | 200W |
| IC-7800 | 0x6A | 19200 | M/S | 0x26 | Std | USB | 200W |
| IC-7850/51 | 0x8E | 19200 | M/S | 0x26 | Std | USB | 200W |
| IC-9100 | 0x7C | 19200 | Sat | 0x26 | Std | USB | 100W HF+VHF/75W UHF |
| IC-910H | 0x60 | 19200 | Sat | Custom | Custom | USB | 100W VHF/75W UHF |
| IC-2730 | 0x90 | 19200 | M/S | N/A | No | USB | 25W/50W |
| ID-4100 | 0x9A | 19200 | M/S | N/A | No | USB | 25W/50W |
| ID-5100 | 0x8C | 19200 | Complex | N/A | No | USB | 25W/50W |
| IC-R75 | 0x5A | 19200 | VFO | Std | Std | Std | RX Only |
| IC-R8600 | 0x96 | 115200 | VFO | Std | Std | USB? | RX Only |
| IC-R9500 | 0x72 | 1200 | VFO | Std | Std | Std | RX Only |

Legend:
- VFO Type: A/B = VFO A/B, M/S = Main/Sub, Sat = Satellite (M/S+A/B), Complex = Multiple modes
- Mode Cmd: 0x04 = Legacy, 0x26 = Modern, Custom = Special implementation, N/A = Limited (FM/D-STAR only)
- Filter: No = No filter byte, Std = Standard filter indices, Custom = Special handling, Yes = mode_with_filter=1
- Echo: Std = Standard serial, USB = USB echo detection required, USB? = May or may not echo

---

## End of Extraction
