# K2 PTT 5-Second Observation Test

**Purpose:** Definitively determine if CAT TX command keys the radio
**Method:** Hold TX for 5 seconds while playing audio to observe power output

---

## What This Test Does

### Test 2: TX Command with TQ Query
1. Sets K2 to USB mode
2. Sends `TX;` command
3. Waits 200ms for processing
4. Queries status with `TQ;`
5. **Holds TX for 5 seconds** with countdown
6. You play audio/whistle into microphone during this time
7. Sends `RX;` to return to receive

### Test 4: TX Command with IF Query
1. Sends `TX;` command again
2. Queries status with `IF;` (alternative to TQ)
3. If IF reports TX, holds for 5 seconds
4. You play audio during this time
5. Returns to RX

---

## How to Run the Test

```bash
K2_SERIAL_PORT="/dev/cu.usbserial-XXXX" swift run K2PTTDebug
```

### During the Test:

**When you see this:**
```
╔═══════════════════════════════════════════════════════════╗
║  HOLDING TX FOR 5 SECONDS - PLAY AUDIO INTO MICROPHONE  ║
╚═══════════════════════════════════════════════════════════╝

→ Watch K2 display for TX indicator
→ Watch power meter for deflection
→ Play audio/whistle into microphone NOW!
→ If power meter shows output, CAT PTT IS WORKING
```

**DO THIS:**
1. **Watch the K2 display** - Does TX indicator appear?
2. **Watch the power meter** - Does it deflect?
3. **Play audio immediately** - Whistle, talk, hum into the mic
4. **Watch for power output** - Does meter show RF power?
5. **Note the countdown** - You have full 5 seconds to observe

---

## What to Look For

### K2 Display:
- TX indicator on screen
- Meter switches from S-meter to power/ALC
- Display changes to TX mode

### Power Meter (on K2):
- Needle/bar deflects when you make sound
- Shows RF power output
- Should correlate with audio level

### External Watt Meter (if connected):
- Should show power when audio is present
- Confirms RF is actually being produced

---

## Interpreting Results

### Scenario A: Power Output Observed
```
TX command sent → K2 shows TX → Audio produces power
Result: ✅ CAT PTT IS WORKING!
Problem: TQ/IF query not reporting status correctly
Solution: Can work around this or fix query logic
```

### Scenario B: TX Indicator But No Power
```
TX command sent → K2 shows TX → No power with audio
Result: ⚠️ Partial TX state only
Problem: Radio in TX but not producing RF
Cause: Could be SSB audio routing issue
```

### Scenario C: No TX Indication at All
```
TX command sent → K2 stays in RX → No TX indicator
Result: ❌ CAT PTT NOT WORKING
Problem: TX command not being processed
Causes: Menu setting, firmware, hardware, KIO2 config
```

---

## Expected Output

```
K2 PTT Control Debug
======================================================================

Port: /dev/cu.usbserial-XXXX

✅ Connected to K2

Checking current mode...
  Current mode: MD2

Test 1: Check initial TX/RX status
  Response: TQ0
  Status: RECEIVING

Test 2: Send TX command - 5 SECOND TEST
  Sending: TX;
  → K2 doesn't echo TX command (normal)
  → Waiting 200ms for K2 to process...

  Querying status: TQ;
  Response: 'TQ0;'
  TQ Status: RECEIVING (TQ0) ❌

  ╔═══════════════════════════════════════════════════════════╗
  ║  HOLDING TX FOR 5 SECONDS - PLAY AUDIO INTO MICROPHONE  ║
  ╚═══════════════════════════════════════════════════════════╝

  → Watch K2 display for TX indicator
  → Watch power meter for deflection
  → Play audio/whistle into microphone NOW!
  → If power meter shows output, CAT PTT IS WORKING

  1 second elapsed...
  2 seconds elapsed...
  3 seconds elapsed...
  4 seconds elapsed...
  5 seconds elapsed...

  → 5 seconds complete
  → Did you see power output? (This is the key question!)

Test 3: Send RX command
  [...]

Test 4: Alternative TX check using IF command
  [...]
```

---

## What to Report Back

Please tell me:

1. **TQ Query Result:**
   - Did TQ return TQ0 (RX) or TQ1 (TX)?

2. **K2 Display During Test:**
   - Did TX indicator appear on K2?
   - Did display change to TX mode?

3. **Power Meter Observation:**
   - Did power meter deflect when you made sound?
   - Approximately how much power (if any)?

4. **Audio Test:**
   - Did you play audio during the 5-second window?
   - Whistling, talking, humming into mic?

5. **Overall Behavior:**
   - Did radio key up (even without RF)?
   - Did radio produce RF with audio?
   - Or did nothing happen at all?

---

## Next Steps Based on Results

### If CAT PTT Works (Scenario A):
- TX command is functional ✅
- TQ query needs fixing (or use IF instead)
- Update getPTT() to use IF command for K2
- PTT control feature complete

### If Partial TX State (Scenario B):
- Investigate audio routing
- Check K2 audio settings
- May need different mode or configuration

### If CAT PTT Doesn't Work (Scenario C):
- Check K2 menu settings (T-R, INP)
- Verify firmware version (need 2.01+)
- Check KIO2 installation
- May not be supported on this K2
- Would need hardware PTT alternative

---

## Files Updated

1. **K2PTTDebug/main.swift** - Now holds TX for 5 seconds with clear prompts
2. **K2Validator/main.swift** - Already updated for 5-second test
3. **K2_PTT_5_SECOND_TEST.md** - This guide

---

## Ready to Test!

Run the command and follow the on-screen prompts:

```bash
K2_SERIAL_PORT="/dev/cu.usbserial-XXXX" swift run K2PTTDebug
```

The test will clearly indicate when to play audio (5-second window with countdown).
Watch the K2 carefully during this time - this will tell us definitively if CAT PTT works!
