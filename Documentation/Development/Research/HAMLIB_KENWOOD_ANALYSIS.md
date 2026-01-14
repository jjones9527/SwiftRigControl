# Hamlib Kenwood Implementation Analysis

**Date**: 2025-12-11
**Purpose**: Guide SwiftRigControl implementation based on Hamlib's proven approach

## Executive Summary

Hamlib supports **36+ Kenwood radio models** through a unified CAT protocol architecture. Key findings:

1. **All radios use standardized ASCII CAT protocol** with consistent command structure
2. **Baud rate is the primary differentiator** (4800/9600/19200/57600/115200 bps)
3. **Modern radios (2010+)** use 115200 baud (USB) or 9600 baud (COM)
4. **Legacy radios (pre-2010)** typically use 4800/9600 baud
5. **Protocol is remarkably consistent** across all models with minimal quirks

## Key Protocol Characteristics

### 1. Command Structure
- **ASCII-based**: All commands are two-letter ASCII codes (e.g., FA, FB, IF, MD)
- **Termination**: Commands end with semicolon (;)
- **Format**: `<CMD><PARAMETERS>;` for set, `<CMD>;` for query
- **Response**: Radio echoes command or returns data with semicolon terminator

### 2. Serial Port Configuration
- **Start Bit**: 1
- **Data Bits**: 8
- **Stop Bits**: 1 (2 for 4800 baud only)
- **Parity**: None
- **Flow Control**: RTS/CTS handshake (hardware flow control)

### 3. Common CAT Commands
| Command | Function | Example |
|---------|----------|---------|
| FA | Set/Read VFO A Frequency | `FA00014250000;` (14.250 MHz) |
| FB | Set/Read VFO B Frequency | `FB00007074000;` (7.074 MHz) |
| IF | Read Transceiver Status | `IF;` returns full status |
| MD | Set/Read Mode | `MD2;` (USB) |
| PC | Set/Read Power Level | `PC100;` (100W) |
| PS | Power On/Off | `PS1;` (Power On) |
| AI | Auto Information | `AI2;` (Auto info on) |
| FT | VFO/Memory Select | `FT0;` (VFO mode) |
| FW | Firmware Version | `FW;` |
| MC | Memory Channel | `MC001;` |

### 4. Baud Rate Patterns
- **4800 baud**: Vintage radios (TS-440, TS-940) - requires 2 stop bits
- **9600 baud**: Common default for COM port
- **19200 baud**: Mid-range radios (IC-7100 era, TS-480, TS-2000)
- **57600 baud**: Transition period
- **115200 baud**: Modern radios (TS-890S, TS-990S, TS-590S/SG) via USB

## Radio Categorization Based on Hamlib

### **Category 1: Flagship Modern HF Transceivers** (2010+)

Premium HF/6m radios with advanced DSP, dual receivers, and high-speed USB CAT control:

| Radio | Rig # | Baud (USB) | Baud (COM) | Power | Bands | Version | Notes |
|-------|-------|------------|------------|-------|-------|---------|-------|
| TS-890S | 2041 | 115200 | 9600 | 200W | HF/6m | 20250107.16 | Flagship, dual RX, DSP, ATU |
| TS-990S | 2039 | 115200 | 9600 | 200W | HF/6m | 20250107.7 | Triple RX, dual DSP, ATU |

**Key Features**:
- Triple/Dual superheterodyne receivers
- Built-in antenna tuner (16.7-150 ohms)
- Advanced DSP processing
- High-speed USB interface (115200 baud)
- Frequency stability: ±0.1 ppm
- Full CAT command support

**Frequency Coverage**:
- TX: All amateur bands 1.8-29.7 MHz + 50-54 MHz (6m)
- RX: Continuous 30 kHz-60 MHz

**Modes**: CW (A1A), SSB (J3E), FSK (F1B), PSK (G1B), AM (A3E), FM (F3E)

**Command Set**: `StandardKenwoodCommandSet` with full feature support

---

### **Category 2: Mid-Range Modern HF Transceivers** (2010+)

Popular HF/6m radios with excellent performance and modern features:

| Radio | Rig # | Baud (USB) | Baud (COM) | Power | Bands | Version | Notes |
|-------|-------|------------|------------|-------|-------|---------|-------|
| TS-590S | 2031 | 115200 | 4800 | 100W | HF/6m | 20250107.18 | Popular HF rig |
| TS-590SG | 2037 | 115200 | 9600 | 100W | HF/6m | 20250107.12 | Enhanced RX, ATU |

**Key Features (TS-590SG)**:
- Enhanced 3rd-order dynamic range over TS-590S
- Built-in automatic antenna tuner (160M-6M including 5MHz)
- On-screen CW decoder with 13-segment display
- Extended digital IF filter selections
- TX/RX Equalizer DSP settable per mode
- 32-bit floating point DSP

**Frequency Coverage**:
- TX: 1.8-29.7 MHz + 50-54 MHz
- RX: 500 kHz-60 MHz (continuous VFO)

**Modes**: SSB, CW, FSK, AM, FM

**Command Set**: `StandardKenwoodCommandSet`

**Note**: TS-590S requires 2 stop bits for 4800 baud COM port

---

### **Category 3: Compact HF Transceivers** (2000s-2010s)

Mobile/compact HF transceivers with remote head capability:

| Radio | Rig # | Baud | Power | Bands | Version | Notes |
|-------|-------|------|-------|-------|---------|-------|
| TS-480 | 2028 | 9600 | 100/200W | HF/6m | 20250107.3 | HX: 200W, SAT: 100W+ATU |

**Models**:
- **TS-480SAT**: 100W, built-in ATU (16.7-150 ohms, 1.9-50 MHz)
- **TS-480HX**: 200W HF (100W 6m), no ATU

**Key Features**:
- Detachable control head for remote operation
- DSP IF filtering and noise reduction
- Compact main unit: 7.1 x 2.4 x 10.2 inches (3.7 kg)
- Power consumption: 20.5A at 13.8V DC (TX at full power)

**Frequency Coverage**:
- TX: 1.8-29.7 MHz + 50-54 MHz
- RX: 500 kHz-60 MHz

**Receiver Performance**:
- Sensitivity: <0.2µV (SSB/CW, mid-HF)
- Image/IF rejection: >70 dB

**Modes**: SSB, CW, FSK, AM, FM

**Command Set**: `StandardKenwoodCommandSet`

---

### **Category 4: Multi-Band Transceivers** (HF/VHF/UHF)

All-mode transceivers covering HF through UHF bands:

| Radio | Rig # | Baud | Power | Bands | Version | Notes |
|-------|-------|------|-------|-------|---------|-------|
| TS-2000 | 2014 | 9600 | 100W | HF/6m/2m/440 | 20250107.2 | All-band, satellite mode |

**Frequency Coverage**:
- TX: 1.8-29.7 MHz, 50-54 MHz, 144-148 MHz, 430-450 MHz
- RX Main: 30 kHz-60 MHz, 142-152 MHz, 420-450 MHz
- RX Sub: 118-174 MHz, 220-512 MHz
- Optional: 1240-1300 MHz with UT-20 module

**Power Output**:
- HF/6m/2m: 100W
- 440 MHz: 50W

**Key Features**:
- Dual independent receivers (main + sub)
- Full-duplex satellite operation
- Built-in TNC for packet radio
- All-mode: CW, SSB, FSK, AM, FM

**Command Set**: `StandardKenwoodCommandSet`

---

### **Category 5: VHF/UHF Transceivers** (Satellite/Base)

Multi-band VHF/UHF base stations, popular for satellite operations:

| Radio | Rig # | Baud | Power | Bands | Version | Notes |
|-------|-------|------|-------|-------|---------|-------|
| TS-790 | 2007 | 4800 | 45W | 2m/70cm/23cm | 20250107.0 | Satellite, full-duplex |

**Frequency Coverage**:
- 2 meters (144-148 MHz)
- 70 cm (430-450 MHz)
- 23 cm (1240-1300 MHz) - with optional UT-10 module

**Power Output**:
- 2m: 45W FM / 35W SSB
- 70cm: 40W FM / 30W SSB

**Key Features**:
- Full-duplex cross-band operation
- Dual-channel watch
- 59 multi-function memory channels
- Satellite Doppler compensation
- All-mode: CW, SSB, FM

**Command Set**: `StandardKenwoodCommandSet`

**Note**: Ideal for serious satellite operators, introduced 1989

---

### **Category 6: Dual-Band VHF/UHF Mobiles** (FM)

Popular VHF/UHF FM mobile transceivers:

| Radio | Rig # | Baud | Power | Bands | Version | Notes |
|-------|-------|------|-------|-------|---------|-------|
| TM-D710(G) | 2034 | 9600 | 50W | 2m/440 | 20250107.6 | APRS, GPS, dual RX |
| TM-V71(A) | 2035 | 9600 | 50W | 2m/440 | 20250107.1 | Dual RX, EchoLink |
| TM-D700 | 2026 | 9600 | 50W | 2m/440 | 20231001.1 | APRS, TNC |
| TM-V7 | 2027 | 9600 | 50W/35W | 2m/440 | 20231001.0 | Dual RX |

**TM-D710(G) Features**:
- Built-in GPS and APRS
- 1000 memory channels
- EchoLink compatible
- Full duplex capability
- Detachable/invertible control head
- V/V, U/U, or V/U dual receive

**TM-V71(A) Features**:
- True dual receive (V/V, U/U, or V/U)
- 1000 memory channels
- EchoLink Sysop mode
- External TNC support (6-pin Mini-DIN)
- APRS with external TNC
- Backlight: amber or green selectable
- 5/10/50W power levels

**CAT Control Notes**:
- TM-D700 uses different VFO commands than TH-D7 family
- TM-D710 commands incompatible with TM-D700
- Each model requires specific command implementation

**Command Set**: `StandardKenwoodCommandSet` with model-specific VFO handling

---

### **Category 7: Handheld Transceivers** (VHF/UHF)

Feature-rich dual/tri-band handhelds with APRS and digital modes:

| Radio | Rig # | Baud | Power | Bands | Version | Notes |
|-------|-------|------|-------|-------|---------|-------|
| TH-D74 | 2042 | 9600 | 5W | 2m/1.25m/70cm | 20250107.3 | D-STAR, APRS, GPS, BT |
| TH-D72A | 2033 | 9600 | 5W | 2m/70cm | 20231001.1 | APRS, GPS, full duplex |
| TH-D7A | 2017 | 9600 | 5W | 2m/70cm | 20231001.1 | APRS, TNC |
| TH-F6A | 2019 | 9600 | 5W | 2m/70cm | 20231001.0 | Wideband RX |
| TH-F7E | 2020 | 9600 | 5W | 2m/70cm | 20231001.0 | Wide coverage |
| TH-G71 | 2023 | 9600 | 5W | 2m/70cm | 20231001.0 | Dual band |

**TH-D74 Features** (Most Advanced):
- 144/220/430 MHz tri-band
- D-STAR digital voice & data
- APRS (simultaneous with D-STAR)
- Built-in GPS
- Bluetooth connectivity
- MicroSD/SDHC card slot
- Micro-USB port
- Waterproof: IP54/55
- Color TFT display (transflective)
- Wide-band multi-mode receiver
- IF filters and DSP equalizer
- Dual independent receivers (V/V, U/U operation)

**TH-D72A Features**:
- APRS with built-in GPS
- Full duplex operation
- Traditional packet (Winlink support)
- Built-in TNC (APRS, KISS, packet)

**TH-D74 vs TH-D72**:
- TH-D74 adds D-STAR (missing from D72)
- TH-D74 lacks full duplex (present in D72)
- TH-D74 has color display, larger buttons, improved ergonomics
- TH-D74 TNC: APRS and KISS only (D72 supports full packet)

**Command Set**: `StandardKenwoodCommandSet` (TH-D7 family has unique VFO handling)

---

### **Category 8: Classic HF Transceivers** (1990s-2000s)

Popular legacy HF transceivers still in use:

| Radio | Rig # | Baud | Power | Bands | Version | Notes |
|-------|-------|------|-------|-------|---------|-------|
| TS-870S | 2010 | 9600 | 100W | HF | 20250107.1 | DSP at IF stage |
| TS-850 | 2009 | 9600 | 100W | HF | 20250107.0 | Competition class |
| TS-950S | 2012 | 4800 | 100W | HF | 20250107.1 | High-end |
| TS-950SDX | 2013 | 4800 | 100W | HF | 20250107.1 | Built-in DSP |

**TS-870S Features**:
- Digital Signal Processing at IF stage
- 160-10m + WARC bands
- General coverage RX: 100 kHz-30 MHz
- 100W SSB/CW/FM/FSK, 25W AM
- High-speed computer control interface

**TS-850S Features**:
- Competition-class transceiver
- Optional DSP-100 (TX and RX DSP)
- Dynamic range: 108 dB (100 kHz-30 MHz)
- 1 Hz step dual VFOs
- CW full/semi break-in
- Dual noise blanker
- 100 memory channels

**TS-950S/SDX Features**:
- Built-in DSP (SDX model)
- MOS FET final section
- Exceptional signal purity
- First-class audio quality
- Advanced engineering

**Command Set**: `StandardKenwoodCommandSet`

---

### **Category 9: Mid-Range HF Transceivers** (1990s-2000s)

Affordable HF transceivers with solid performance:

| Radio | Rig # | Baud | Power | Bands | Version | Notes |
|-------|-------|------|-------|-------|---------|-------|
| TS-690S | 2005 | 9600 | 100/50W | HF/6m | 20250107.1 | Same as TS-450S+6m |
| TS-680S | 2024 | 9600 | 100W | HF/6m | 20250107.1 | HF/6m all-mode |
| TS-570D | 2004 | 9600 | 100W | HF | 20250107.1 | DSP, HF only |
| TS-570S | 2016 | 9600 | 100W | HF/6m | 20250107.3 | DSP, HF+6m |
| TS-450S | 2003 | 4800 | 100W | HF | 20250107.0 | Classic HF |

**TS-690S Features**:
- Triple conversion receiver
- 160-10m + WARC + 6m
- RX: 500 kHz-30 MHz, 50-54 MHz
- 100W HF (40W AM), 50W 6m (20W AM)
- Optional CAT interface (IC-10/IF-10 series)
- Essentially TS-450S with 6m added

**TS-570D/S Features**:
- Digital Signal Processing
- Dual Beat Cancel
- Noise Reduction (9 steps)
- SSB/AM/FM slope control (441 combinations)
- CW/FSK variable band tuning
- Auto zero-beat for CW (world's first CW AUTO TUNE)
- Built-in antenna tuner and keyer
- 5-100W adjustable power
- TS-570D: HF only (160-10m)
- TS-570S: HF+6m (160-6m)
- G-Series: Added 3 DSP CW filters

**Command Set**: `StandardKenwoodCommandSet`

**CAT Notes**: TS-450S may require optional CAT chipset

---

### **Category 10: Vintage HF Transceivers** (1980s-1990s)

Legacy radios requiring optional CAT interfaces:

| Radio | Rig # | Baud | Power | Bands | Version | CAT Module | Notes |
|-------|-------|------|-------|-------|---------|------------|-------|
| TS-440S | 2002 | 4800 | 100W | HF | 20231002.3 | IC-10 | TTL levels, 1200 optional |
| TS-940S | 2011 | 4800 | 100W | HF | 20250107.0 | IF-10B | 6-pin DIN CAT |
| TS-930 | 2022 | 4800 | 100W | HF | 20250107.1 | IF-10C | Beta status |
| TS-140S | 2025 | 9600 | 100W | HF | 20250107.1 | IF-10C | Compact HF |
| TS-50S | 2001 | 9600 | 100W | HF | 20250107.1 | Unknown | Compact mobile |
| TS-711 | 2006 | 4800 | 25W | 2m | 20250107.0 | Optional | Beta - 2m all-mode |
| TS-811 | 2008 | 4800 | 25W | 70cm | 20250107.0 | Optional | Beta - 70cm all-mode |

**TS-440S CAT Details**:
- TTL levels (NOT RS-232) - requires level converter
- Default: 4800 baud, 2 stop bits
- Optional: 1200 baud (jumper W50)
- Serial format: 1 start, 8 data, 2 stop, no parity
- Interface: 6-pin DIN ACC 1 connector
- Requires IC-10 upgrade kit for CAT
- Signals must be inverted for PC interface

**TS-940S CAT Details**:
- Requires optional IF-10B interface
- 6-pin DIN CAT port
- Similar protocol to TS-440S

**CAT Module Reference**:
- **IC-10**: Early CAT interface chipset
- **IF-10A/B/C**: CAT interface modules (varying models)
- **IF-232C**: RS-232 interface (for R-5000 receiver)

**Command Set**: `StandardKenwoodCommandSet`

**Note**: Level conversion required for vintage radios with TTL interfaces

---

### **Category 11: Receivers**

General coverage communications receivers:

| Radio | Rig # | Baud | Coverage | Version | Notes |
|-------|-------|------|----------|---------|-------|
| R-5000 | 2015 | 9600 | HF | 20231002.1 | 150 kHz-30 MHz |

**R-5000 Features**:
- Double-conversion (triple in FM mode)
- RX: 150 kHz-30 MHz
- Optional VC-20: 108-174 MHz VHF
- First IF: 58.1725 MHz
- Second IF: 8.83 MHz
- Third IF (FM): 455 kHz
- Modes: AM, LSB, USB, CW, FM, RTTY
- Dynamic range: 102 dB (@14 MHz, 500 Hz BW, 50 kHz spacing)
- VFO accuracy: ±10 PPM
- Digital readout: 10 Hz resolution
- 100 memory channels (frequency, mode, antenna)
- Optional IF-232C interface for CAT control
- Dual noise blankers
- Notch and IF shift controls
- Auto/manual filter select
- Selectable AGC

**Command Set**: `StandardKenwoodCommandSet` (no TX commands)

---

### **Category 12: Specialized Transceivers**

Unique or specialized radios:

| Radio | Rig # | Baud | Power | Bands | Version | Notes |
|-------|-------|------|-------|-------|---------|-------|
| TRC-80 | 2030 | 9600 | 10W | HF | 20250107.0 | Transceiver module |

**Command Set**: `StandardKenwoodCommandSet`

---

## Key Patterns Identified

### 1. Baud Rate Evolution
- **Vintage (1980s-early 1990s)**: 4800 baud with 2 stop bits
- **Mid-era (1990s-2000s)**: 9600 baud standard
- **Modern USB (2010+)**: 115200 baud
- **Modern COM**: 9600 baud remains common

### 2. Serial Configuration
- **4800 baud only**: 2 stop bits required
- **All other rates**: 1 stop bit
- **Always**: 8 data bits, no parity, RTS/CTS flow control

### 3. Interface Requirements
- **Vintage radios**: Often require optional CAT modules (IC-10, IF-10 series)
- **TS-440/940 era**: TTL levels, need RS-232 conversion
- **Modern radios**: USB native support at 115200 baud

### 4. Protocol Consistency
- **Remarkably uniform**: Same command structure across all models
- **ASCII-based**: Two-letter commands with semicolon termination
- **Standard commands**: FA, FB, IF, MD, PC, PS, AI, FT work across models
- **Model variations**: Primarily in VFO handling (TM-D700 vs TH-D7 family)

### 5. Power Output Representation
- **Absolute values**: Commands use actual wattage (e.g., PC100 = 100W)
- **Range varies by model**: 5W handhelds to 200W base stations
- **Unlike Icom**: Kenwood doesn't use percentage-based power

### 6. CAT Command Differences
Unlike Icom's filter byte variations, Kenwood's main differences are:
- **VFO commands**: TM-D700 uses different VFO switching than TH-D7 family
- **Baud rate**: Primary configuration difference
- **Optional modules**: Vintage radios need hardware add-ons

---

## Mapping to SwiftRigControl CommandSets

### StandardKenwoodCommandSet
**Use for**: All Kenwood radios with consistent configuration by baud rate

**Configuration patterns**:
```swift
// Modern flagship HF (USB connection)
StandardKenwoodCommandSet(baudRate: 115200, stopBits: 1, powerRange: 5...200)

// Modern flagship HF (COM port)
StandardKenwoodCommandSet(baudRate: 9600, stopBits: 1, powerRange: 5...200)

// Mid-range HF (TS-480, TS-2000)
StandardKenwoodCommandSet(baudRate: 9600, stopBits: 1, powerRange: 5...100)

// VHF/UHF mobiles (TM-series)
StandardKenwoodCommandSet(baudRate: 9600, stopBits: 1, powerRange: 5...50)

// Handhelds (TH-series)
StandardKenwoodCommandSet(baudRate: 9600, stopBits: 1, powerRange: 1...5)

// Vintage HF with 4800 baud
StandardKenwoodCommandSet(baudRate: 4800, stopBits: 2, powerRange: 5...100)

// Receivers (no TX)
StandardKenwoodCommandSet(baudRate: 9600, stopBits: 1, txCapable: false)
```

### Custom VFO Handling Required For:
- **TM-D700**: Uses `BC 0,0` / `BC 1,1` instead of standard VFO commands
- **TM-D710**: Different commands than TM-D700 (incompatible)
- **TH-D7 family**: Different VFO handling than mobile radios

Consider creating:
- `TMD700CommandSet` (if VFO handling differs significantly)
- `TMD710CommandSet` (if incompatible with standard)
- `THD7CommandSet` (for handheld VFO quirks)

---

## Recommended Implementation Priority

### Phase 1: Modern Flagship HF (High Demand)
1. **TS-890S** (Rig 2041) - Latest flagship, 200W, dual RX, 115200 baud
2. **TS-990S** (Rig 2039) - Triple RX, dual DSP, 115200 baud
3. **TS-590SG** (Rig 2037) - Very popular, enhanced RX, ATU, 115200 baud
4. **TS-590S** (Rig 2031) - Popular HF rig, 115200 baud

### Phase 2: Multi-Band & Compact HF
5. **TS-2000** (Rig 2014) - HF/VHF/UHF all-mode, satellite capable
6. **TS-480** (Rig 2028) - Compact HF/6m, detachable head, popular mobile

### Phase 3: VHF/UHF Mobile Transceivers
7. **TM-D710(G)** (Rig 2034) - APRS, GPS, dual RX, very popular
8. **TM-V71(A)** (Rig 2035) - Dual RX, EchoLink, popular mobile
9. **TS-790** (Rig 2007) - VHF/UHF all-mode, satellite operations

### Phase 4: Handhelds
10. **TH-D74** (Rig 2042) - D-STAR, APRS, tri-band, most advanced
11. **TH-D72A** (Rig 2033) - APRS, GPS, full duplex, popular
12. **TH-D7A** (Rig 2017) - Classic APRS handheld

### Phase 5: Legacy Popular HF
13. **TS-870S** (Rig 2010) - DSP at IF, still in use
14. **TS-850** (Rig 2009) - Competition class, popular vintage
15. **TS-570S** (Rig 2016) - DSP, HF/6m, affordable
16. **TS-570D** (Rig 2004) - DSP, HF only

### Phase 6: Vintage & Specialized
17. **TS-690S** (Rig 2005) - HF/6m, TS-450S equivalent
18. **TS-440S** (Rig 2002) - Classic, requires IC-10
19. **TS-940S** (Rig 2011) - Classic, requires IF-10B
20. **R-5000** (Rig 2015) - HF receiver, still popular

### Phase 7: Additional Mobiles & Legacy
21. **TM-D700** (Rig 2026) - APRS mobile, still in use
22. **TM-V7** (Rig 2027) - Dual-band mobile
23. **TS-950S/SDX** (Rig 2012/2013) - High-end vintage
24. **TS-680S** (Rig 2024) - HF/6m
25. **TS-140S** (Rig 2025) - Compact HF

---

## Hamlib Status Definitions

From Hamlib supported radios list:
- **Stable**: Feature complete, well-tested, minimal future changes
- **Beta**: Usable, seeking more testing and feedback
- **Alpha**: Work in progress, actively developed
- **Untested**: Written from documentation, no actual radio testing

Most Kenwood radios are **Stable** status in Hamlib, indicating mature implementations.

---

## Summary

- **~95% of radios use StandardKenwoodCommandSet** with baud rate as primary differentiator
- **Protocol is extremely consistent** compared to other manufacturers
- **Key configuration**: Baud rate + stop bits + power range
- **VFO handling quirks**: Limited to TM-D700, TM-D710, TH-D7 family
- **Baud rate critical**: Must match radio's configured setting
- **USB vs COM**: Different default baud rates (115200 vs 9600)
- **Legacy radios**: May require optional CAT interface hardware
- **All Kenwood radios use absolute power values** (not percentages)

---

## Technical References

### Official Documentation
- **TS-890S PC Command Reference**: Available from Kenwood
- **TS-990S PC Command Reference**: Available from Kenwood
- **TS-590S/SG PC Command Reference**: Available from Kenwood
- **TS-480 PC Command Reference**: Available from Kenwood

### CAT Protocol Resources
- **Hamlib GitHub**: https://github.com/Hamlib/Hamlib
- **Kenwood CAT Reference**: https://github.com/n4af/TR4W/wiki/Kenwood-CAT-Reference
- **Ham Radio Deluxe CAT Guide**: Support documentation for CAT commands

### Baud Rate Reference
Standard Kenwood baud rates in priority order:
1. **115200 baud** (modern USB)
2. **57600 baud** (transition)
3. **38400 baud** (uncommon)
4. **19200 baud** (mid-range)
5. **9600 baud** (common default)
6. **4800 baud** (vintage, 2 stop bits)

**Note**: 4800 baud cannot be used with USB-B connector

---

## Next Steps for SwiftRigControl

1. **Implement StandardKenwoodCommandSet** with configurable baud rate
2. **Add Tier 1 radios** (TS-890S, TS-990S, TS-590S/SG)
3. **Add Tier 2 radios** (TS-2000, TS-480)
4. **Test baud rate configuration** (115200 USB vs 9600 COM)
5. **Add VHF/UHF mobiles** (TM-D710, TM-V71)
6. **Add handhelds** (TH-D74, TH-D72A)
7. **Implement custom VFO handling** for TM-D700/D710/TH-D7 if needed
8. **Add legacy HF** (TS-870S, TS-850, TS-570S/D)
9. **Add receiver support** (R-5000)
10. **Test with hardware** where available

---

## Appendix A: Complete Hamlib Kenwood Rig List

| Model | Rig # | Version | Status |
|-------|-------|---------|--------|
| TS-50S | 2001 | 20250107.1 | Stable |
| TS-440S | 2002 | 20231002.3 | Stable |
| TS-450S | 2003 | 20250107.0 | Stable |
| TS-570D | 2004 | 20250107.1 | Stable |
| TS-690S | 2005 | 20250107.1 | Stable |
| TS-711 | 2006 | 20250107.0 | Beta |
| TS-790 | 2007 | 20250107.0 | Stable |
| TS-811 | 2008 | 20250107.0 | Beta |
| TS-850 | 2009 | 20250107.0 | Stable |
| TS-870S | 2010 | 20250107.1 | Stable |
| TS-940S | 2011 | 20250107.0 | Stable |
| TS-950S | 2012 | 20250107.1 | Stable |
| TS-950SDX | 2013 | 20250107.1 | Stable |
| TS-2000 | 2014 | 20250107.2 | Stable |
| R-5000 | 2015 | 20231002.1 | Stable |
| TS-570S | 2016 | 20250107.3 | Stable |
| TH-D7A | 2017 | 20231001.1 | Stable |
| TH-F6A | 2019 | 20231001.0 | Stable |
| TH-F7E | 2020 | 20231001.0 | Stable |
| TS-930 | 2022 | 20250107.1 | Beta |
| TH-G71 | 2023 | 20231001.0 | Stable |
| TS-680S | 2024 | 20250107.1 | Stable |
| TS-140S | 2025 | 20250107.1 | Stable |
| TM-D700 | 2026 | 20231001.1 | Stable |
| TM-V7 | 2027 | 20231001.0 | Stable |
| TS-480 | 2028 | 20250107.3 | Stable |
| TRC-80 | 2030 | 20250107.0 | Stable |
| TS-590S | 2031 | 20250107.18 | Stable |
| TH-D72A | 2033 | 20231001.1 | Stable |
| TM-D710(G) | 2034 | 20250107.6 | Stable |
| TM-V71(A) | 2035 | 20250107.1 | Stable |
| TS-590SG | 2037 | 20250107.12 | Stable |
| TS-990S | 2039 | 20250107.7 | Stable |
| TS-890S | 2041 | 20250107.16 | Stable |
| TH-D74 | 2042 | 20250107.3 | Stable |

**Total**: 36 models (34 Stable, 2 Beta)

---

## Appendix B: Kenwood vs Icom Protocol Comparison

| Aspect | Kenwood | Icom |
|--------|---------|------|
| Protocol Type | ASCII text | Binary (CI-V) |
| Command Format | Two letters + params | Hex bytes |
| Terminator | Semicolon (;) | 0xFD |
| Consistency | Very high | Moderate (filter byte issues) |
| Echo | None (standard) | Some models echo |
| Baud Rate | Varies widely (4800-115200) | Mostly 19200/115200 |
| Power Format | Absolute watts | Percentage (0-100%) |
| Main Quirks | Baud rate, VFO handling | Filter byte, echo, VFO exchange |
| Ease of Implementation | Easier (text-based) | Harder (binary parsing) |

**Conclusion**: Kenwood's ASCII protocol is more straightforward to implement than Icom's binary CI-V protocol, with fewer model-specific quirks.
