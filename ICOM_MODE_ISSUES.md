# Icom Radio Mode Setting Issues

**Last Updated:** 2025-12-12

## Overview

Three Icom radios are experiencing mode setting failures in hardware testing:
- IC-7600 (Main/Sub VFO model, echoes commands, requires mode filter)
- IC-9700 (Main/Sub VFO model, does NOT echo, requires mode filter)
- IC-7100 (Current-Only VFO model, does NOT echo, does NOT require filter)

All three radios can:
- ✅ Read frequency correctly
- ✅ Set frequency correctly
- ✅ Read mode correctly

But all three fail to:
- ❌ Set mode (command rejected with NAK response)

## IC-7600 Test Results

**Radio Configuration:**
- VFO Model: `.mainSub`
- CI-V Address: `0x7A`
- Echo Commands: `true`
- Requires Mode Filter: `true`
- Connection: `/dev/cu.usbserial-2120` @ 19200 baud

**Test Output (2025-12-12):**

```
Current State: 24.919 MHz, USB mode

Test 1: Set frequency to 14.200 MHz
✓ Frequency set successfully

Test 2: Set mode to USB (already in USB!)
Command: [0x06, 0x01, 0x00]  (setMode, USB code, filter 0x00)
❌ ERROR: commandFailed("Radio rejected mode usb")
Radio still reports: USB

Test 3: Set frequency to 3.750 MHz
✓ Frequency set successfully

Test 4: Set mode to LSB
Command: [0x06, 0x00, 0x00]  (setMode, LSB code, filter 0x00)
❌ ERROR: commandFailed("Radio rejected mode lsb")
Radio still reports: USB (no change)

Test 5: Read mode 3 times
✓ Read 1: usb
✓ Read 2: usb
✓ Read 3: usb
```

**Key Observations:**
1. Radio rejects setMode even when setting to current mode
2. Radio does not change mode - stays in USB regardless of command
3. Mode reading works perfectly every time
4. Frequency setting works perfectly

## IC-9700 Test Results

**Radio Configuration:**
- VFO Model: `.mainSub`
- CI-V Address: `0xA2`
- Echo Commands: `false`
- Requires Mode Filter: `true`
- Test Band: 23cm (1270 MHz)

**User Report:**
- Mode test fails when setting USB on 1270 MHz
- User tested multiple times, manually switched mode out of USB
- Mode did not change back to USB to pass the test
- Issue confirmed NOT related to mode/frequency compatibility

## IC-7100 Test Results

**Radio Configuration:**
- VFO Model: `.currentOnly`
- CI-V Address: `0x88`
- Echo Commands: `true` (USB connection)
- Requires Mode Filter: `false`  (NAKs if filter byte sent)
- Test Frequency: 7.074 MHz (40m)

**Test Output:**
```
Step 5: Set mode to USB on 7.074 MHz
❌ Command FAILED: commandFailed("Radio rejected mode usb")

Step 6: Set mode to LSB
❌ Command FAILED: commandFailed("Radio rejected mode lsb")

Step 7: Set mode to FM
✓ Command succeeded!  (But...)
Software says mode is now: lsb  (NOT fm!)
```

**Key Observations:**
1. USB and LSB modes rejected
2. FM mode command "succeeds" but doesn't actually change mode
3. VFO selection was fixed (requiresVFOSelection now true)
4. Power setting also fails
5. PTT read fails

## Common Pattern Analysis

### Similarities Across All Three Radios:
1. All can read frequency ✅
2. All can set frequency ✅
3. All can read mode ✅
4. All FAIL to set mode ❌
5. Frequency setting uses same protocol layer

### Differences:

| Radio   | Echo | Filter | VFO Model  | Mode Failures          |
|---------|------|--------|------------|------------------------|
| IC-7600 | ✅   | ✅     | MainSub    | All modes (USB, LSB)   |
| IC-9700 | ❌   | ✅     | MainSub    | USB (at least)         |
| IC-7100 | ✅   | ❌     | CurrentOnly| USB, LSB, FM (weird)   |

## Technical Analysis

### setMode Command Format

From `IcomRadioCommandSet.swift`:

```swift
public func setModeCommand(mode: UInt8) -> (command: [UInt8], data: [UInt8]) {
    if requiresModeFilter {
        // IC-7600, IC-9700: mode + filter byte
        return ([CIVFrame.Command.setMode], [mode, 0x00])  // ← 0x00 hardcoded!
    } else {
        // IC-7100: mode only (NAKs if filter byte sent)
        return ([CIVFrame.Command.setMode], [mode])
    }
}
```

**Potential Issues:**

1. **Filter Byte Hardcoded to 0x00**
   - May be invalid for certain modes or bands
   - IC-7600/IC-9700 both have `requiresModeFilter: true`
   - Hamlib 4.5 fixed "Icom data mode and filter selection issues"

2. **Echo Handling**
   - IC-7600 and IC-7100 echo commands over USB
   - `echoesCommands: true` configured for both
   - May not be properly consuming echo before reading response

3. **Response Parsing**
   - `response.isAck` check may be incorrect
   - Echo frame might be confused with ACK frame
   - NAK (0xFA) vs ACK (0xFB) detection

### setFrequency vs setMode

**Why does setFrequency work but setMode doesn't?**

Both use same protocol layer (IcomCIVProtocol):
- Send frame via `sendFrame()`
- Receive response via `receiveFrame()`
- Check `response.isAck`

The difference:
- Frequency uses BCD encoding, no additional parameters
- Mode requires filter byte (or not, for IC-7100)

## Investigation Required

### Hardware Debugging Needed:

1. **Protocol Tracing**
   - Capture actual CI-V frames with protocol analyzer
   - Compare with working Hamlib/other software
   - Verify echo handling is correct

2. **Manual Testing**
   - Try different filter values (0x01, 0x02, 0x03, etc.)
   - Test with Hamlib to see working commands
   - Check IC-7600 manual for filter byte values

3. **IC-7100 Specific**
   - Why does FM "succeed" but not change mode?
   - Is response parsing broken for this radio?
   - Test power and PTT commands (also failing)

### Code Changes to Test:

1. **Add Debug Logging**
   ```swift
   // In IcomCIVProtocol.setMode()
   print("DEBUG: Sending frame: \(frame.bytes.map { String(format: "%02X", $0) })")
   let response = try await receiveFrame()
   print("DEBUG: Response frame: \(response.bytes.map { String(format: "%02X", $0) })")
   print("DEBUG: isAck = \(response.isAck)")
   ```

2. **Try Different Filter Values**
   ```swift
   // Test with filter 0x01, 0x02, 0x03 instead of 0x00
   return ([CIVFrame.Command.setMode], [mode, 0x01])
   ```

3. **IC-7100: Remove Echo Handling**
   ```swift
   // Try setting echoesCommands to false
   public static var ic7100: StandardIcomCommandSet {
       StandardIcomCommandSet(civAddress: 0x88, vfoModel: .currentOnly, echoesCommands: false)
   }
   ```

## Hamlib Reference

From Hamlib release notes (v4.5):
- Fixed "Icom data mode and filter selection"
- This suggests filter byte handling was problematic

From Hamlib source (`icom.c`):
- May have specific filter values for different modes/bands
- Should compare against Hamlib's filter selection logic

## Workaround Options

Until hardware debugging is complete:

1. **Document the limitation** in README and API docs
2. **Skip mode tests** for affected radios
3. **Provide manual mode setting** instructions for users
4. **Focus on other functionality** (frequency, VFO, etc.)

## References

- IC-7600 CI-V Manual: Section on mode commands
- IC-9700 CI-V Manual: PDF corrupted (need clean copy)
- IC-7100 CI-V Manual: Section on mode commands
- Hamlib source: `rigs/icom/icom.c`, `rigs/icom/ic7600.c`, etc.
- SwiftRigControl files:
  - `Sources/RigControl/Protocols/Icom/IcomCIVProtocol.swift:129-154`
  - `Sources/RigControl/Protocols/Icom/IcomRadioCommandSet.swift:96-104`
  - `Sources/RigControl/Protocols/Icom/CommandSets/StandardIcomCommandSet.swift`

## Next Steps

1. ✅ Create this investigation document
2. ⏳ Add detailed logging to setMode command
3. ⏳ Test with IC-7600 hardware (connected)
4. ⏳ Try different filter byte values
5. ⏳ Compare with Hamlib's approach
6. ⏳ Get clean IC-9700 CI-V manual
7. ⏳ Protocol trace with hardware analyzer
