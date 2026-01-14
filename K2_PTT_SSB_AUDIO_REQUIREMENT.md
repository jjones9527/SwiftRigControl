# K2 PTT SSB Audio Requirement

**Date:** January 9, 2026
**Critical Discovery:** K2 TX command works but may require audio input for full RF output in SSB mode
**Status:** 🔍 INVESTIGATING

---

## The Problem

User reports:
- TX command sent, radio **appears** to begin transmitting
- No RF power output when playing audio tone during transmit
- Manual PTT with microphone works instantly and produces full RF
- TQ query returns TQ0 (RX) even though radio shows some TX indication

---

## Critical Documentation Review

### TX Command (Page 10):
```
TX (Transmit Mode; SET only)
SET format: TX; (no data). Used to initiate transmit
(in SSB and RTTY modes only) by pulling PTT low.
```

### RX Command (Page 9):
```
RX (Receive Mode; SET only)
SET format: RX; (no data). Used to terminate transmit and
release PTT **only when transmit was initiated using the TX command**.
Applies only to SSB and RTTY mode.
```

### Key Insight from Page 3:
```
Busy Indication
Most SET commands cannot be safely handled when the K2 is in a busy state,
including transmit, direct frequency entry prompting, and scanning.
```

---

## Hypothesis: SSB Requires Audio Input

### Theory:
The K2 TX command in SSB mode may:
1. Pull PTT low (hardware)
2. Switch T/R relays
3. **Wait for audio input** before fully transmitting
4. Without audio, remain in "PTT engaged but no RF" state

### Evidence:
1. **Manual PTT works** → Microphone provides audio signal
2. **CAT PTT doesn't produce RF** → No audio source connected
3. **TX indication appears** → PTT hardware engaged
4. **No power output** → RF stage not active (waiting for audio?)

### Similar Behavior in Other Radios:
- Many SSB transceivers won't produce carrier without audio (VOX threshold)
- Some radios have "PTT engaged" vs "actually transmitting" states
- CW mode typically transmits carrier immediately (no audio needed)

---

## Possible Solutions

### Solution 1: Test in CW Mode (Recommended)
CW mode should produce a carrier immediately without audio:

```swift
// Set to CW mode
try await rig.setMode(.cw, vfo: .a)

// Key transmitter
try await rig.setPTT(true)

// Should produce carrier immediately
// Check TQ status
let isTX = try await rig.isPTTEnabled()
```

### Solution 2: Use KY Command for CW Testing
The KY command sends CW via CAT and should definitely trigger full TX:

```swift
// Send CW test tone
try await proto.sendCommand("KY TEST")

// This should show TQ1
let isTX = try await proto.getTXStatus()
```

### Solution 3: Connect Audio Source
For SSB testing, connect:
- Microphone to MIC input
- Audio signal generator to MIC input
- Computer audio interface to ACC connector audio input

### Solution 4: Check VOX Settings
If VOX is enabled, it might interfere with CAT PTT:
- Menu → T-R → Ensure VOX is OFF

---

## Testing Plan

### Test 1: CW Mode PTT
```bash
# Modify K2PTTDebug to use CW mode
1. Set mode to CW: MD3;
2. Send TX command: TX;
3. Query status: TQ;
4. Should return: TQ1;
5. Send RX command: RX;
```

### Test 2: KY Command
```bash
1. Set mode to CW: MD3;
2. Send CW via KY: KY TEST;
3. Radio should transmit CW
4. Query TQ during transmission
```

### Test 3: IF Command TX Status
```bash
1. Send TX command in USB mode
2. Query IF command (includes TX status at position 28)
3. Compare IF TX flag vs TQ response
```

---

## K2 User Manual Investigation Needed

Check K2 User Manual Section 7 (Computer Control) for:
1. Does TX command require audio in SSB?
2. Is there a menu setting for "CAT PTT" behavior?
3. Are there any PTT-related menu options (T-R menu, INP menu)?

---

## Comparison: Manual PTT vs CAT PTT

### Manual PTT (Mic Button):
```
1. Physical PTT switch closes
2. Hardware PTT line goes low
3. K2 switches to TX immediately
4. Audio from microphone → RF output
5. TX indicator instant
6. TQ query would return TQ1
```

### CAT PTT (TX Command):
```
1. TX; command received
2. Hardware PTT line goes low (internal)
3. K2 switches to TX state
4. ??? Audio requirement ???
5. TX indicator may appear
6. TQ query returns TQ0 (???)
```

---

## The TQ Query Mystery

**Most Puzzling Issue:** TQ returns TQ0 even though radio shows TX indication

Possibilities:
1. **K2 is not actually in TX** → PTT engaged but not transmitting
2. **TQ timing issue** → Query happens too soon (already addressed)
3. **TQ requires full TX** → Returns 0 if waiting for audio in SSB
4. **Busy state** → K2 returns TQ0 during state transition
5. **Firmware quirk** → TQ may not reflect CAT PTT accurately

---

## Recommended Next Steps

### 1. Test in CW Mode (High Priority)
This will definitively answer whether TX/RX commands work or if there's an audio requirement.

### 2. Check IF Command (Medium Priority)
The IF response includes TX status. Compare IF's TX flag vs TQ response.

### 3. Review K2 Menus (Medium Priority)
Check:
- Menu → T-R (VOX settings)
- Menu → INP (PTT configuration)
- Menu → ACC (accessory PTT settings)

### 4. Test with Different Modes (Low Priority)
- Try RTTY mode (also uses TX/RX commands)
- Compare behavior across all SSB/RTTY/CW modes

---

## Code Changes to Test CW Mode

Update K2Validator PTT test to use CW:

```swift
// Test 10: PTT Control Commands
print("📡 Test 10: PTT Control Commands (CW Mode)")
do {
    try await rig.setPower(1)  // 1W QRP
    try await rig.setFrequency(14_100_000, vfo: .a)  // CW portion of 20m
    try await rig.setMode(.cw, vfo: .a)  // ← Use CW instead of USB

    print("   Keying transmitter for 200ms at 1W...")
    try await rig.setPTT(true)

    // CW should produce carrier immediately
    try await Task.sleep(nanoseconds: 50_000_000)  // 50ms

    let pttOn = try await rig.isPTTEnabled()
    guard pttOn else {
        print("   ❌ PTT ON status check failed")
        testsFailed += 1
        throw RigError.commandFailed("PTT ON")
    }
    print("   ✓ PTT ON confirmed")

    try await Task.sleep(nanoseconds: 200_000_000)  // 200ms

    try await rig.setPTT(false)
    let pttOff = try await rig.isPTTEnabled()
    guard !pttOff else {
        print("   ❌ PTT OFF status check failed")
        testsFailed += 1
        throw RigError.commandFailed("PTT OFF")
    }
    print("   ✓ PTT OFF confirmed")

    testsPassed += 1
    print("   ✅ PTT control: PASS\n")
} catch {
    print("   ❌ PTT control: FAIL - \(error)\n")
    testsFailed += 1
}
```

---

## Expected Results

### If CW Mode Works:
- TX command → Immediate carrier
- TQ returns TQ1
- RF power meter shows output
- → **SSB requires audio input hypothesis confirmed**

### If CW Mode Fails Too:
- TX command not working at all
- Hardware/firmware issue
- Menu configuration problem
- → **Deeper investigation needed**

---

## Bottom Line

The K2's TX command may require **audio input** in SSB mode to produce RF output. The radio enters a "PTT engaged" state but waits for audio before fully transmitting.

**Test in CW mode to confirm** - CW should produce a carrier immediately without audio.

If CW works but SSB doesn't → This is normal behavior, not a bug.
If neither works → Check K2 menu settings and hardware configuration.
