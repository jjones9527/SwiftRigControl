# IC-9700 Interactive Hardware Validator

## Purpose

This fully interactive validation tool tests the IC-9700 4-state VFO implementation by **pausing at each step** and waiting for user verification on the radio display.

## Why Not Use `swift test`?

**XCTest Limitation**: The `swift test` command runs tests in XCTest framework, which:
- Captures stdout (output doesn't display in real-time)
- Does **NOT support interactive stdin** (`readLine()` doesn't work)
- Cannot pause for user input

**Solution**: This standalone executable uses `@main` struct and can be run with `swift run`, which:
- Displays output in real-time
- **Supports interactive stdin** (`readLine()` works!)
- Can pause and wait for user verification at each step

## Usage

```bash
IC9700_SERIAL_PORT="/dev/cu.usbserial-XXXX" swift run IC9700InteractiveValidator
```

Replace `/dev/cu.usbserial-XXXX` with your actual IC-9700 serial port.

## What It Tests

The validator runs **4 comprehensive tests**, each with multiple user verification points:

### Test 1: 4-State VFO Configuration Reading
- Reads all 4 VFO states: Main-A, Main-B, Sub-A, Sub-B
- Displays band identification (VHF 2m, UHF 70cm, 1.2GHz 23cm)
- **User verifies** frequencies match radio display

### Test 2: Band Exchange (Main ↔ Sub)
- Reads initial 4-state configuration
- Executes `exchangeBands()` command
- **User verifies** bands swapped on radio
- Reads swapped configuration
- Verifies frequencies match expected swap
- Restores original configuration

### Test 3: Independent Mode Control
- Sets Main receiver to FM
- **User verifies** Main shows FM
- Sets Sub receiver to USB
- **User verifies** Sub shows USB and Main still shows FM
- Confirms independent mode operation

### Test 4: VFO A/B Selection (4-State)
- Selects Main VFO A, **user verifies**
- Selects Main VFO B, **user verifies**
- Selects Sub VFO A, **user verifies**
- Selects Sub VFO B, **user verifies**
- Tests composite `selectBandVFO()` method, **user verifies**

## Important Note About Dualwatch

**IC-9700 does NOT have a "Dualwatch" mode** like the IC-7600. The IC-9700 is a **true dual-receiver radio** where both Main and Sub receivers are always independent and fully active. You can turn the Sub receiver on/off by pressing and holding the SUB AF/RF knob, but there's no separate "dualwatch" feature to enable/disable.

The `setDualwatch()` method in the API is **only available for IC-7600** and will throw an error on IC-9700.

## Interactive Flow

At each step, the validator:

1. **Explains what it will do**
   ```
   📊 Step 1: Setting Main receiver to FM...
   ```

2. **Executes the command**
   ```
   🔄 Executing: setMode(.fm, vfo: .main)...
   ```

3. **Asks user to verify on radio**
   ```
   👀 VERIFY ON RADIO:
     - Main receiver should show: FM

   Is Main in FM mode? Press RETURN if YES, Ctrl+C if NO
   ```

4. **Waits for user confirmation**
   - User checks radio display
   - Presses RETURN to continue
   - Or Ctrl+C to abort if something is wrong

## Example Output

```
================================================================================
IC-9700 INTERACTIVE HARDWARE VALIDATOR
================================================================================

This validator will pause at EACH step for your verification.
You can confirm radio behavior visually before proceeding.

📡 Connecting to IC-9700 on /dev/cu.usbserial-A50285BI...
✅ Connected to IC-9700

Press RETURN to start interactive tests

================================================================================
TEST 1: 4-State VFO Configuration Reading
================================================================================

This test reads all 4 VFO states from your IC-9700:
  - Main VFO A frequency
  - Main VFO B frequency
  - Sub VFO A frequency
  - Sub VFO B frequency

Press RETURN to read current 4-state VFO configuration

📊 Current IC-9700 Configuration:
   ┌─ Main Receiver (UHF 70cm (430-450 MHz))
   │  ├─ VFO A: 446.000000 MHz
   │  └─ VFO B: 435.050000 MHz
   └─ Sub Receiver (VHF 2m (144-148 MHz))
      ├─ VFO A: 145.030000 MHz
      └─ VFO B: 145.080000 MHz

👀 VERIFY ON RADIO:
  1. Check that Main band matches: UHF 70cm (430-450 MHz)
  2. Check that Main VFO A frequency is: 446.000000 MHz
  3. Check that Main VFO B frequency is: 435.050000 MHz
  4. Check that Sub band matches: VHF 2m (144-148 MHz)
  5. Check that Sub VFO A frequency is: 145.030000 MHz
  6. Check that Sub VFO B frequency is: 145.080000 MHz

Does this match your radio display? Press RETURN if YES, Ctrl+C to abort

✅ Test 1 PASSED: 4-state VFO reading works correctly

[... continues through all 4 tests ...]

================================================================================
✅ ALL INTERACTIVE TESTS COMPLETED SUCCESSFULLY
================================================================================

IC-9700 4-state VFO implementation validated!
```

## Comparison: XCTest vs Interactive Validator

| Feature | `swift test` (XCTest) | `swift run` (Interactive) |
|---------|----------------------|---------------------------|
| **Interactive stdin** | ❌ No (`readLine()` fails) | ✅ Yes (`readLine()` works) |
| **Real-time output** | ❌ Buffered | ✅ Immediate |
| **User verification** | ❌ Impossible | ✅ At each step |
| **Manual config** | ❌ Cannot prompt | ✅ Can prompt and wait |
| **Automated CI/CD** | ✅ Yes | ❌ No (requires human) |

## Running Both

- **XCTest** (`swift test --filter IC9700HardwareTests`): Automated tests for CI/CD
- **Interactive** (`swift run IC9700InteractiveValidator`): Manual validation with radio

## Implementation Details

**File**: `Sources/IC9700InteractiveValidator/main.swift`

**Key Features**:
- Uses `@main` struct (required for `swift run` executables)
- `readLine()` for user input (only works outside XCTest)
- `fflush(stdout)` to ensure prompts display immediately
- `VFOState` structure to capture and display all 4 VFO configurations
- Comprehensive error handling with descriptive messages

**Architecture**:
```swift
@main
struct IC9700InteractiveValidator {
    static func main() async {
        let validator = Validator()
        try await validator.run()
    }
}

class Validator {
    private var rig: RigController?

    func run() async throws {
        try await connectToRadio()
        try await test1_InitialStateReading()
        try await test2_BandExchange()
        // ... more tests
    }

    private func askUser(_ prompt: String) {
        print(prompt, terminator: "")
        fflush(stdout)
        _ = readLine()  // ← Only works with swift run!
        print("")
    }
}
```

## Troubleshooting

### Serial Port Not Found
```
❌ ERROR: IC9700_SERIAL_PORT environment variable not set

Usage:
  IC9700_SERIAL_PORT="/dev/cu.usbserial-XXXX" swift run IC9700InteractiveValidator
```

**Solution**: Set the environment variable with your actual serial port:
```bash
# List available serial ports
ls /dev/cu.*

# Run with correct port
IC9700_SERIAL_PORT="/dev/cu.usbserial-A50285BI" swift run IC9700InteractiveValidator
```

### Connection Failed
```
❌ Validator failed: RigError.connectionFailed
```

**Possible causes**:
1. Wrong serial port name
2. Radio not powered on
3. USB cable not connected
4. CI-V not configured on radio (Menu → Set → Connectors → USB)
5. Another program already using the port

### Tests Fail to Pause

If the validator doesn't pause for input, you may be running it incorrectly:

**Wrong**:
```bash
swift test --filter IC9700InteractiveValidator  # ❌ XCTest doesn't support readLine()
```

**Correct**:
```bash
swift run IC9700InteractiveValidator  # ✅ Works with readLine()
```

## See Also

- **IC9700_4STATE_VFO_IMPLEMENTATION.md** - Complete implementation details
- **IC9700_VFO_ARCHITECTURE.md** - 4-state VFO architecture explanation
- **Tests/RigControlTests/HardwareTests/IC9700HardwareTests.swift** - Automated XCTest tests
- **Sources/IC9700ManualValidation/main.swift** - Similar pattern for Level commands

---

**Status**: ✅ Ready to use
**Build Status**: ✅ Compiles successfully
**Implementation**: Complete
**Documentation**: Complete
