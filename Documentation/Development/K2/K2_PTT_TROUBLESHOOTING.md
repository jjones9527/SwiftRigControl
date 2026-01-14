# K2 PTT Troubleshooting Guide

**Issue:** TX command sent but radio does not transmit (even in CW mode)
**Status:** 🔍 INVESTIGATING - TX command may not be working

---

## Current Situation

### What We Know:
1. ✅ Manual mic PTT works perfectly (in CW mode, shows power output)
2. ❌ CAT `TX;` command does NOT key the radio
3. ❌ TQ query returns TQ0 (RX) after TX command
4. ✅ Other CAT commands work (frequency, mode, power, etc.)
5. ✅ K2 has KIO2 interface installed
6. ✅ Serial communication is working

### Critical Question:
**When TX command is sent via CAT, does the radio show ANY indication of transmitting?**
- TX LED on display?
- Power meter deflection?
- Display changes?

If NO → TX command not working (hardware/firmware/config issue)
If YES → TQ query not working (but TX is working)

---

## Possible Causes

### 1. TX Command Not Supported on This K2

**Likelihood: MEDIUM**

Some K2s may not support CAT PTT depending on:
- Firmware version (need 2.01+)
- K2 hardware revision
- KIO2 firmware version
- Configuration jumpers/settings

**Check:**
```
1. K2 Display → Hold MENU on power-on → Check firmware version
   Need: 2.01 or higher (2.04 is latest)

2. KIO2 installation:
   - Is KIO2 module physically installed?
   - Are all connections secure?
   - Is KIO2 enabled in menu?
```

### 2. K2 Menu Setting Disables CAT PTT

**Likelihood: HIGH**

The K2 may have menu settings that control PTT behavior:

**Check These Menus:**
```
Menu → CONFIG → T-R:
  - VOX: Should be OFF
  - PTT: Check setting

Menu → CONFIG → INP:
  - PTT SOURCE: May need to be set to allow CAT control
  - Check if there's a "CAT PTT" or similar option

Menu → CONFIG → ACC:
  - Accessory port PTT settings
```

### 3. Hardware PTT Line Issue

**Likelihood: LOW**

The KIO2 interface uses an internal PTT line. If this is disconnected or failed:
- Manual mic PTT would still work (different circuit)
- CAT PTT would not work

**This would require hardware inspection**

### 4. TX Command Requires Additional Setup

**Likelihood: MEDIUM**

Some radios require:
- Specific initialization sequence
- AI (auto-info) mode to be enabled
- Extended command mode (K22)

**Test:**
```bash
K2_SERIAL_PORT="/dev/cu.usbserial-XXXX" swift run K2PTTDebug
```

This will show exact command sequence and responses.

---

## Investigation Steps

### Step 1: Verify K2 Firmware and KIO2

```
1. Power on K2 while holding MENU
2. Note firmware version (should be 2.01+, ideally 2.04)
3. Check manual for KIO2 CAT PTT support in this firmware
```

### Step 2: Check K2 Menus

Navigate through K2 menu system:
```
CONFIG → T-R → Check VOX (should be OFF)
CONFIG → INP → Check PTT settings
CONFIG → PORT → Check serial settings
```

Look for ANY setting related to:
- CAT control
- PTT source
- Computer control
- RS232 PTT

### Step 3: Run Detailed Debug

```bash
K2_SERIAL_PORT="/dev/cu.usbserial-XXXX" swift run K2PTTDebug
```

This will:
- Send TX command
- Wait 200ms
- Query TQ status
- Show raw responses
- Try IF command as alternative
- Hold TX for observation

**Watch the K2 display during this test!**

### Step 4: Manual Test Sequence

Using terminal program (screen, minicom, etc.):
```bash
screen /dev/cu.usbserial-XXXX 4800

Type these commands (watch K2 display):
MD3;     ← Set CW mode
MD       ← Query mode (should return MD3;)
TX;      ← Send TX command (WATCH RADIO!)
         ← (no response expected)
         ← Wait 1 second
TQ;      ← Query TX status
         ← Should return TQ1; if transmitting

Type: RX;  ← Return to receive
```

---

## K2 Documentation Research

### From KIO2 Programmer's Reference:

**Page 2, footnote:**
> K2 revision 2.01 or higher firmware and the KIO2 Aux I/O option
> are required for computer control of the K2.

**Page 3, Busy Indication:**
> The only SET commands that are allowed unconditionally during busy
> states are: AI, K2, KS, KY, PC, RX, and SW.

**Note:** TX is NOT listed as "allowed unconditionally" - but it's also not listed as disallowed. This is ambiguous.

**Page 10, TX Command:**
> TX (Transmit Mode; SET only)
> SET format: TX; (no data). Used to initiate transmit (in SSB and
> RTTY modes only) by pulling PTT low.

**Critical Note:** Says "SSB and RTTY modes only" - but does it work in CW?

### Possible Documentation Issue:

The manual says TX works in "SSB and RTTY modes only" but we're testing in CW mode.
However:
- Manual mic PTT works in CW
- Logic suggests CAT PTT should also work in CW
- But documentation is unclear

**Try testing in USB mode (not CW) with audio connected?**

---

## Alternative PTT Methods

If CAT PTT doesn't work on this K2, alternatives:

### 1. RTS/DTR Hardware PTT

Use serial port hardware lines:
```swift
// Use RTS or DTR pin on serial port
// Requires hardware modification or special cable
```

### 2. VOX PTT

Enable VOX on K2:
```
Menu → T-R → VOX: ON
Set threshold appropriately
Send audio tone to trigger VOX
```

### 3. External PTT Interface

Hardware interface connected to K2 ACC port controlled by computer.

---

## Comparison with Other Software

### Test with Other K2 CAT Software:

1. **Ham Radio Deluxe** - Does CAT PTT work?
2. **WSJT-X** - Does CAT PTT work?
3. **Fldigi** - Does CAT PTT work?

If other software CAN use CAT PTT on this K2:
→ Our implementation has a bug

If other software CANNOT use CAT PTT:
→ This K2 doesn't support CAT PTT (hardware/firmware limitation)

---

## Next Steps

### Immediate Actions:

1. **Run K2PTTDebug** and observe radio carefully
2. **Check K2 firmware version**
3. **Review all K2 menu settings** (T-R, INP, PORT, ACC)
4. **Test with terminal program** (manual command entry)
5. **Check K2 manual** for CAT PTT support in your firmware version

### If TX Command Never Keys Radio:

This suggests TX command is not working on this K2. Possible reasons:
- Firmware doesn't support it
- Menu setting disables it
- Hardware issue
- KIO2 not properly installed

### If TX Command Keys Radio but TQ Returns TQ0:

This suggests TX works but TQ doesn't report status correctly. We could:
- Use IF command instead (includes TX status)
- Accept that TX works but status query doesn't
- Work around by assuming TX succeeded

---

## K2 Manual Section to Review

**K2 Owner's Manual - Section 7: Computer Control**

Look for:
- PTT control via CAT commands
- Menu settings for CAT PTT
- Firmware requirements
- Any notes about TX/RX commands

---

## Bottom Line

The TX command is either:
1. **Not supported** on this K2 (firmware/hardware)
2. **Disabled** by menu setting
3. **Requires special mode** (AI mode, K2 extended mode, etc.)
4. **Works but TQ doesn't** report status correctly

We need to determine which case applies to proceed with the fix.

---

## Test Commands for Manual Verification

```
Connect to K2 at 4800 baud, 8N1:

1. Test basic CAT:
   ID;      → Should return ID017;
   FA;      → Should return frequency

2. Test mode setting:
   MD3;     → Set CW mode
   MD;      → Query mode → Should return MD3;

3. Test TX command:
   TX;      → Key transmitter (no echo)
             → WATCH RADIO DISPLAY/METER!
   TQ;      → Query status → TQ1; or TQ0; ?

4. Test RX command:
   RX;      → Return to RX (no echo)
   TQ;      → Query status → Should return TQ0;

5. Test IF command (alternative TX query):
   TX;      → Key transmitter
   IF;      → Get info → Position 28 should be '1' if TX
```

If radio doesn't key on TX; command → Hardware/firmware issue
If radio keys but TQ returns TQ0 → TQ query issue, use IF instead
