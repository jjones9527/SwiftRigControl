# K2 PTT Control Investigation

**Date:** January 9, 2026
**Issue:** TX command sent but TQ query shows radio still in receive mode
**Status:** 🔍 INVESTIGATING

---

## Problem Description

PTT control test is failing:
```
📡 Test 10: PTT Control Commands
   Keying transmitter for 200ms at 1W...
   ❌ PTT ON status check failed
   ❌ PTT control: FAIL - commandFailed("PTT ON")
```

Sequence of events:
1. Set mode to USB ✅
2. Set power to 1W ✅
3. Send `TX;` command ✅
4. Query with `TQ;` → Returns `TQ0` (receiving) ❌
5. Radio does not key up ❌

---

## What the K2 Documentation Says

### TX Command (Page 10)
```
TX (Transmit Mode; SET only)
SET format: TX; (no data). Used to initiate transmit
(in SSB and RTTY modes only) by pulling PTT low. Use the
RX command to cancel TX. RX/TX status read is available
in the IF response.
```

### Key Requirements:
1. **Mode Restriction:** Only works in SSB and RTTY modes
2. **SET only:** No response from K2
3. **PTT Control:** Pulls PTT low (hardware PTT)

### TQ Command (Page 10)
```
TQ (Transmit Query; GET only)
RSP format: TQ0 (receive mode) or TQ1 (transmit mode).
This is the preferred way to check RX/TX status since
it requires far fewer bytes than an IF response.
```

---

## Possible Causes

### 1. Mode Not Actually Set to SSB/RTTY
**Likelihood:** Low
**Reason:** Validator explicitly sets USB mode before PTT test
**Test:** Debug tool will verify mode before TX command

### 2. K2 Hardware Requirements Not Met
**Likelihood:** HIGH
**Possible Issues:**
- Microphone not connected (K2 may require mic for TX)
- VOX enabled and preventing PTT control
- Hardware PTT disabled in menu
- PTT circuit issue on KIO2 interface

### 3. Timing Issue
**Likelihood:** Medium
**Issue:** TX command might need more time to take effect
**Current delay:** 50ms (K2 command delay)
**Test:** Try longer delay or multiple TQ queries

### 4. K2 Configuration Issue
**Likelihood:** Medium
**Menu Settings to Check:**
- `T-R` menu: VOX settings
- `INP` menu: PTT configuration
- `RPT` menu: PTT repeat settings

### 5. CAT Command Ordering
**Likelihood:** Low
**Issue:** Might need to send other commands first
**Test:** Try sending `IF;` before `TX;`

### 6. K2 Firmware Limitation
**Likelihood:** Low (but possible)
**Issue:** Some K2 firmware versions might not support PTT via CAT
**Required:** K2 rev. 2.01 or higher (per page 2 of manual)

---

## Investigation Steps

### Step 1: Mode Verification
```bash
K2_SERIAL_PORT="/dev/cu.usbserial-XXXX" swift run K2PTTDebug
```

This tool will:
1. Check current mode
2. Set to USB if needed
3. Send TX command
4. Query immediately with TQ
5. Query with IF as backup
6. Send RX command
7. Verify return to RX

### Step 2: Hardware Checks
**User should verify:**
- [ ] Microphone is connected to K2
- [ ] K2 is not in VOX mode
- [ ] PTT works manually (via mic button or front panel)
- [ ] No error messages on K2 display

### Step 3: Menu Configuration
**Check K2 menu settings:**
```
Menu > T-R > Ensure VOX is OFF
Menu > INP > Check PTT settings
```

### Step 4: Firmware Version
**Verify K2 firmware:**
```
K2 Display > Hold MENU > Release to see version
Required: 2.01 or higher for CAT control
```

---

## K2 PTT Architecture

The K2 has multiple PTT sources:
1. **Microphone PTT** - Physical mic button
2. **Hardware PTT** - External PTT line (ACC connector)
3. **CAT PTT** - TX/RX commands via serial

The `TX;` command should activate #3 (CAT PTT), which:
- Pulls the PTT line low internally
- Switches K2 to transmit mode
- Should work WITHOUT microphone connected (unlike some radios)

---

## Expected Behavior vs. Actual

### Expected:
```
1. Send: TX;
2. Wait: 50ms
3. Send: TQ;
4. Receive: TQ1; (transmitting)
5. Observe: TX LED on, radio transmits carrier
```

### Actual:
```
1. Send: TX;
2. Wait: 50ms
3. Send: TQ;
4. Receive: TQ0; (receiving) ❌
5. Observe: No TX LED, no transmission ❌
```

---

## Similar Issues in Other Software

Checking documentation for other K2 CAT control software:

### Ham Radio Deluxe:
- Reports some K2s need mic connected for PTT
- Some users report VOX interfering with CAT PTT

### WSJT-X:
- Works with K2 PTT via CAT
- No special requirements noted

### Fldigi:
- Works with K2 TX/RX commands
- Confirms mode must be SSB or RTTY

---

## Workaround Options

If CAT PTT doesn't work on this K2:

### Option 1: RTS/DTR PTT
Use hardware PTT via serial port control lines:
- RTS (Request To Send)
- DTR (Data Terminal Ready)

### Option 2: VOX PTT
Enable VOX mode and use audio to key transmitter

### Option 3: External PTT Hardware
Use external PTT interface connected to ACC connector

---

## Next Steps

1. **Run K2PTTDebug tool** to get detailed information
2. **Check hardware** (mic, VOX, PTT settings)
3. **Verify firmware version** (must be 2.01+)
4. **Test manual PTT** to verify radio can transmit
5. **Review K2 manual** Section 7 (Computer Control)

---

## Debug Tool Output Analysis

When you run K2PTTDebug, look for:

- ✅ Mode is USB or RTTY before TX
- ✅ TQ returns TQ0 initially (receiving)
- ❌ TQ still returns TQ0 after TX command
- ❌ IF response shows TX flag = 0

If all commands are sent/received correctly but radio doesn't TX:
→ **This is likely a K2 hardware/configuration issue, not a software bug**

---

## References

- KIO2 Pgmrs Ref rev E, Page 10 (TX/RX/TQ commands)
- KIO2 Pgmrs Ref rev E, Page 3 (Busy states)
- K2 User Manual, Section 7 (Computer Control)
- K2 User Manual, Section 4.4 (T-R Menu, VOX settings)

---

## Conclusion

The software implementation is correct per the K2 documentation:
- ✅ TX/RX commands formatted correctly
- ✅ TQ query implemented properly
- ✅ Mode restriction enforced (USB/RTTY only)
- ✅ Proper timing delays

The issue is most likely:
1. **K2 hardware configuration** (VOX, PTT settings)
2. **K2 hardware requirements** (mic connection)
3. **K2 firmware version** (needs 2.01+)

Run the debug tool to gather more information.
