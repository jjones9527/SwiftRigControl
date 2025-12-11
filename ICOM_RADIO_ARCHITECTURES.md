# Icom Radio Architectures and Test Requirements

## Executive Summary

SwiftRigControl supports 22 Icom radios with 4 distinct VFO operation models and varying frequency capabilities. The IcomInteractiveTest must account for these variations to ensure accurate hardware testing.

## VFO Operation Models

### 1. Targetable (.targetable)
**Can directly target VFO A or VFO B with commands**

**Radios:**
- IC-7300 (HF/6m, 100W)
- IC-7700 (HF/6m, 200W)
- IC-7800 (HF/6m, 200W)
- IC-756PRO (HF/6m, 100W)
- IC-756PROII (HF/6m, 100W)
- IC-756PROIII (HF/6m, 100W)
- IC-746PRO (HF/VHF 2m, 100W)
- ID-5100 (VHF/UHF, 50W D-STAR)
- ID-4100 (VHF/UHF, 65W D-STAR)
- IC-R8600 (Receiver)
- IC-R9500 (Receiver)

**Test Requirements:**
- Use VFO .a and .b directly
- VFO select command (0x07) targets specific VFO
- Display prompts use "VFO A" and "VFO B"

### 2. Main/Sub (.mainSub)
**Dual receiver architecture using Main and Sub bands**

**Radios:**
- IC-7610 (HF/6m, 100W, dual RX)
- IC-7600 (HF/6m, 100W, dual RX)
- IC-9700 (VHF/UHF/1.2GHz, 100W, 2m/70cm/23cm only)
- IC-9100 (HF/VHF/UHF, 100W, dual RX)

**Test Requirements:**
- Use VFO .main and .sub (NOT .a/.b)
- VFO codes: Main=0xD0, Sub=0xD1
- Display prompts use "Main" and "Sub"
- IC-9700 is VHF/UHF only (no HF frequencies!)

### 3. Current Only (.currentOnly)
**Operates on currently selected VFO, must switch before operations**

**Radios:**
- IC-7100 (HF/VHF/UHF, 100W, echoes commands, no filter byte)
- IC-705 (HF/VHF/UHF, 10W portable, echoes commands, no filter byte)
- IC-7200 (HF/6m, 100W)
- IC-7410 (HF/6m, 100W)
- IC-7000 (HF/VHF/UHF, 100W mobile)

**Test Requirements:**
- Must switch to VFO before operations (0x07 0x00 or 0x07 0x01)
- Operations always affect "current" VFO
- Display prompts use "VFO A" and "VFO B" after switching

### 4. None (.none)
**No VFO operations (single VFO or receiver)**

**Radios:**
- IC-R75 (HF receiver, single VFO)

**Test Requirements:**
- Skip VFO tests entirely
- No VFO switching or targeting
- Frequency/mode operations work on single VFO

## Frequency Capabilities by Radio Type

### HF Only (30 kHz - 60 MHz)
**160m, 80m, 40m, 30m, 20m, 17m, 15m, 12m, 10m, 6m**
- IC-7300, IC-7610, IC-7600, IC-7200, IC-7410
- IC-7700, IC-7800
- IC-756PRO, IC-756PROII, IC-756PROIII
- IC-R75 (receiver)

**Test Frequencies:**
- 160m: 1.900 MHz (LSB)
- 40m: 7.100 MHz (LSB)
- 20m: 14.200 MHz (USB)

### HF + VHF (30 kHz - 60 MHz + 144-148 MHz)
**All HF bands + 2m**
- IC-746PRO (HF/6m + 2m)

**Test Frequencies:**
- HF: Same as above
- 2m: 145.000 MHz (FM)

### HF + VHF + UHF (30 kHz - 470 MHz)
**All HF bands + 2m + 70cm**
- IC-7100 (HF through 70cm, current VFO only, no filter byte)
- IC-705 (HF through 70cm, portable, current VFO only, no filter byte)
- IC-9100 (HF through 70cm, Main/Sub dual RX)
- IC-7000 (HF through 70cm, mobile)

**Test Frequencies:**
- HF: 14.200 MHz (USB)
- 2m: 145.000 MHz (FM)
- 70cm: 435.000 MHz (FM)

### VHF/UHF Only (144-148 MHz, 430-450 MHz)
**2m and 70cm only**
- ID-5100 (2m/70cm D-STAR mobile, 50W)
- ID-4100 (2m/70cm D-STAR mobile, 65W)

**Test Frequencies:**
- 2m: 145.000 MHz (FM/DV)
- 70cm: 435.000 MHz (FM/DV)

### VHF/UHF/1.2GHz Only (144-1300 MHz)
**2m, 70cm, 23cm (NO HF!)**
- IC-9700 (2m/70cm/23cm, Main/Sub, NO HF transmit capability)

**Test Frequencies:**
- 2m: 145.000 MHz (USB/FM)
- 70cm: 435.000 MHz (USB/FM)
- 23cm: 1.270 GHz (USB/FM)

**CRITICAL:** IC-9700 does NOT transmit on HF or 6m!

### Wideband Receivers
- IC-R8600 (25 kHz - 3 GHz wideband)
- IC-R9500 (5 kHz - 3.3 GHz professional)

**Test Frequencies:** Use standard amateur band frequencies for simplicity

## Mode Capabilities by Band

### HF Modes
- **160m, 80m, 40m:** LSB, CW, RTTY, DATA-LSB
- **30m:** CW, USB (no voice), DATA-USB
- **20m, 17m, 15m, 12m:** USB, CW, RTTY, DATA-USB
- **10m:** USB, CW, RTTY, AM, FM, DATA-USB

### VHF/UHF Modes
- **2m, 70cm:** USB (SSB), CW, FM, FM-N, DATA-USB
- **D-STAR radios:** Add DV mode

### IC-9700 Specific
- 2m/70cm/23cm: USB, CW, FM, FM-N, DATA-USB, DATA-FM
- No AM on VHF/UHF bands

## Command Set Variations

### Standard (requiresModeFilter = true, echoesCommands = false)
**Most radios use this**
- Mode command: [0x06, mode, filter_byte]
- No command echo
- Examples: IC-7300, IC-7610, IC-7600, IC-9700, IC-9100, IC-7700, IC-7800, etc.

### IC-7100 Family (requiresModeFilter = false, echoesCommands = true)
**IC-7100 and IC-705 ONLY**
- Mode command: [0x06, mode] (NO filter byte - radio NAKs if sent!)
- Commands are echoed before response
- Current VFO only operation

### IC-9700 Special
**VHF/UHF/1.2GHz only, Main/Sub architecture**
- Uses Main/Sub VFO codes (0xD0/0xD1)
- No HF transmit capability
- Requires mode filter byte

## Power Control

### All Icom Radios
- Power display: Percentage (0-100%)
- Power command: [0x14, 0x0A, BCD_percentage]
- **NOT watts** - always percentage regardless of max power

**Source:** Hamlib GitHub issue #533, verified across all Icom radios

## Split Operation

### Radios with Split Support
All transceivers support split operation (hasVFOB = true or hasDualReceiver = true)

### Receivers (No Split)
- IC-R75, IC-R8600, IC-R9500 (receivers don't transmit)

## Test Strategy Requirements

### 1. Frequency Test
- Select appropriate test frequencies based on radio's frequency ranges
- IC-9700: ONLY 2m/70cm/23cm frequencies
- HF radios: Use 160m, 40m, 20m
- VHF/UHF radios: Use 2m and/or 70cm

### 2. Mode Test
- Select modes appropriate for the test frequency
- HF low bands (160m-40m): LSB
- HF high bands (20m-10m): USB
- VHF/UHF: USB or FM
- D-STAR radios: Can test DV mode

### 3. VFO Test
- Targetable (.targetable): Use .a and .b directly
- Main/Sub (.mainSub): Use .main and .sub
- Current Only (.currentOnly): Switch VFO, then operate
- None (.none): Skip VFO test

### 4. Split Test
- Skip for receivers (IC-R75, IC-R8600, IC-R9500)
- Use appropriate VFO codes based on radio architecture
- Ensure split frequencies are in valid ranges for radio

### 5. Power Test
- All radios use percentage (0-100%)
- Skip for receivers
- Test: Set 50%, verify on radio display

### 6. PTT Test
- Skip for receivers
- Test: Enable PTT, check TX LED, disable PTT

## Test Implementation Checklist

- [ ] Detect VFO architecture from command set (not just by name)
- [ ] Select test frequencies appropriate for radio's bands
- [ ] Use correct VFO codes (.a/.b vs .main/.sub vs switch)
- [ ] Select modes appropriate for test frequencies
- [ ] Skip tests not applicable to radio (PTT/power for receivers)
- [ ] Handle IC-7100/IC-705 special cases (no filter byte, echo)
- [ ] Validate frequency ranges against radio capabilities
- [ ] Test only bands radio can actually transmit on
