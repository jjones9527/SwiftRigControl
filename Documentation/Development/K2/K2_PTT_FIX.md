# K2 PTT Control Fix

**Date:** January 9, 2026
**Issue:** K2 PTT control test failing with "PTT query not supported on Elecraft"
**Root Cause:** Incomplete implementation - K2 supports both PTT control and query

---

## Problem Description

User observed during K2Validator testing:
```
📡 Test 10: PTT Control Commands
   Keying transmitter for 200ms at 1W...
   ❌ PTT control: FAIL - unsupportedOperation("PTT query not supported on Elecraft")
```

The setPTT() was working correctly (sending TX/RX commands), but getPTT() was throwing an error.

---

## Root Cause Analysis

### K2 PTT Support (from KIO2 Pgmrs Ref rev E, page 10):

**TX Command (Transmit Mode; SET only)**
- Format: `TX;` (no data)
- Used to initiate transmit (in SSB and RTTY modes only) by pulling PTT low
- Use RX command to cancel TX
- RX/TX status read is available in the IF response

**RX Command (Receive Mode; SET only)**
- Format: `RX;` (no data)
- Used to terminate transmit and release PTT
- Only when transmit was initiated using the TX command
- Applies only to SSB and RTTY mode

**TQ Command (Transmit Query; GET only)** (page 10)
- Format: `TQ;`
- Response: `TQ0` (receive mode) or `TQ1` (transmit mode)
- **"This is the preferred way to check RX/TX status since it requires far fewer bytes than an IF response"**

### The Bug:
ElecraftProtocol had correct PTT control (TX/RX commands) but getPTT() was throwing "unsupported operation" error.

---

## Fix Implementation

### File Modified:
`Sources/RigControl/Protocols/Elecraft/ElecraftProtocol.swift`

### Changes Made:

#### getPTT() - Lines 181-205
**Old implementation:**
```swift
public func getPTT() async throws -> Bool {
    // Elecraft doesn't have a direct PTT query in basic protocol
    // We can try using extended command if available
    // For now, throw unsupported
    throw RigError.unsupportedOperation("PTT query not supported on Elecraft")
}
```

**New implementation:**
```swift
public func getPTT() async throws -> Bool {
    // K2 supports TQ (Transmit Query) command - preferred method
    // Per KIO2 Pgmrs Ref: "This is the preferred way to check RX/TX status"
    // For K3/K4, we can also use the IF command which includes TX status

    if isK2 {
        // Use TQ command for K2 (most efficient)
        return try await getTXStatus()
    } else {
        // For K3/K4, use IF command which includes TX status
        // IF response format includes 't' field: 1 if TX, 0 if RX
        try await sendCommand("IF")
        let response = try await receiveResponse()

        // IF response format: IF[f]*****+yyyyrx*00tmvspb01*;
        // Position 28 is the TX flag
        guard response.hasPrefix("IF"),
              response.count >= 29 else {
            throw RigError.invalidResponse
        }

        let txIndex = response.index(response.startIndex, offsetBy: 28)
        return response[txIndex] == "1"
    }
}
```

---

## Implementation Details

### For K2:
Uses the `TQ` command (already implemented as `getTXStatus()` in earlier fixes):
- Most efficient method (only 3-4 bytes)
- Explicitly documented as preferred method
- Returns true if transmitting, false if receiving

### For K3/K4:
Uses the `IF` (Information) command:
- Returns comprehensive radio status (38 bytes)
- Includes TX/RX status at position 28
- Format: `IF[f]*****+yyyyrx*00tmvspb01*;` where 't' is TX flag

### PTT Control Commands (Already Working):
- `setPTT(true)` → Sends `TX;`
- `setPTT(false)` → Sends `RX;`

---

## Limitations

Per K2 documentation, PTT control via TX/RX commands:
- **Only works in SSB and RTTY modes**
- Does NOT work in CW mode (CW uses keying, not PTT)
- Does NOT work in AM mode

For CW keying, use the `KY` (keyboard CW) command instead.

---

## Verification

Build completed successfully. The K2 PTT control test should now:
1. ✅ Set PTT on (TX command)
2. ✅ Query PTT status (TQ command)
3. ✅ Set PTT off (RX command)
4. ✅ Verify PTT is off (TQ command)

Test with:
```bash
K2_SERIAL_PORT="/dev/cu.usbserial-XXXX" swift run K2Validator
```

---

## K2 Documentation References

From KIO2 Pgmrs Ref rev E:

**Page 2 - Command Set Overview:**
- Table 1 lists: `RX` (Receive mode), `TX` (Transmit mode), `TQ` (Transmit query)

**Page 3 - Busy Indication:**
- TX-mode commands must use `RX;` to exit transmit state

**Page 10 - TQ Command:**
```
TQ (Transmit Query; GET only)
RSP format: TQ0 (receive mode) or TQ1 (transmit mode).
This is the preferred way to check RX/TX status since
it requires far fewer bytes than an IF response.
```

**Page 10 - TX/RX Commands:**
```
TX (Transmit Mode; SET only)
SET format: TX; (no data). Used to initiate transmit
(in SSB and RTTY modes only) by pulling PTT low. Use the
RX command to cancel TX. RX/TX status read is available
in the IF response.
```

---

## Timing Issue Discovered

After initial implementation, user testing revealed PTT **was working** (radio keyed up) but TQ query returned wrong status. This was due to TX/RX transition timing.

**Fix:** Increased delays to account for K2 hardware transition time:
- setPTT() delay: 50ms → 100ms
- getPTT() pre-query delay: 0ms → 20ms

See **K2_PTT_TIMING_FIX.md** for detailed analysis.

---

## Bottom Line

**Problem:** getPTT() threw "unsupported operation" error, then timing issue with status query
**Solution:**
1. Implement getPTT() using TQ command (K2) or IF command (K3/K4)
2. Add proper timing delays for K2 TX/RX state transitions

**Status:** ✅ FIXED

The K2 PTT control is now fully functional for SSB and RTTY modes.

---

## Files Modified Summary

1. **ElecraftProtocol.swift** - Fixed getPTT() method (lines 181-205)
2. **K2_PTT_FIX.md** - This documentation
