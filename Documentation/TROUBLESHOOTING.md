# SwiftRigControl Troubleshooting Guide

This guide helps you diagnose and resolve common issues when using SwiftRigControl.

## Table of Contents

1. [Connection Issues](#connection-issues)
2. [Command Failures](#command-failures)
3. [Serial Port Problems](#serial-port-problems)
4. [XPC Helper Issues](#xpc-helper-issues)
5. [Radio-Specific Issues](#radio-specific-issues)
6. [Performance Issues](#performance-issues)
7. [Build and Integration Issues](#build-and-integration-issues)

## Connection Issues

### Error: `RigError.timeout`

**Symptoms:**
- Radio doesn't respond to commands
- Connection hangs or times out
- Error message: "Radio did not respond"

**Possible Causes and Solutions:**

#### 1. Wrong Serial Port

```bash
# List all serial ports on macOS
ls /dev/cu.*

# Look for your radio
ls /dev/cu.* | grep -i icom    # For Icom
ls /dev/cu.* | grep -i FTDX    # For Yaesu
ls /dev/cu.* | grep -i TS      # For Kenwood
```

Common port patterns:
- `/dev/cu.SLAB_USBtoUART` - Silicon Labs USB-to-serial chip
- `/dev/cu.usbserial-*` - Generic USB serial
- `/dev/cu.IC9700`, `/dev/cu.IC7300` - Direct Icom naming
- `/dev/cu.wchusbserial*` - CH340 USB serial chip

**Solution:** Use the correct port path in your `RigController` initialization.

#### 2. Incorrect Baud Rate

Each radio has a default baud rate, but it may have been changed in settings.

**Default baud rates:**
- Icom modern radios (IC-9700, IC-7610, IC-7300): 115200
- Icom older radios (IC-7600, IC-7100, IC-705): 19200
- Yaesu (all models): 38400
- Kenwood modern (TS-890S, TS-990S, TS-590SG): 115200
- Kenwood older (TS-480SAT, TS-2000, TM-D710): 57600
- Elecraft K3/K4/KX3: 38400
- Elecraft K2: 4800

**Solution:** Check your radio's menu settings and match the baud rate:
```swift
RigController(
    radio: .icomIC7300,
    connection: .serial(path: "/dev/cu.IC7300", baudRate: 19200)  // Override default
)
```

#### 3. Radio CAT/CI-V Not Enabled

**For Icom radios:**
1. Press **MENU**
2. Navigate to **SET > Connectors > CI-V**
3. Ensure:
   - CI-V Baud Rate matches your code
   - CI-V Address matches (default is fine)
   - CI-V USB Port: ON
   - CI-V Transceive: OFF (recommended)

**For Yaesu radios:**
1. Press **MENU**
2. Navigate to **CAT RATE** or **CAT OPERATION**
3. Set CAT RATE to 38400 (default)
4. Enable CAT if there's an ON/OFF option

**For Kenwood radios:**
1. **MENU** > **COM** > **USB BAUD**
2. Set to 115200 (modern) or 57600 (older)
3. Ensure USB COM is enabled

**For Elecraft radios:**
1. **CONFIG** > **RS-232**
2. Set baud rate to 38400 (K3/K4) or 4800 (K2)

#### 4. Cable Issues

**Test the cable:**
```bash
# Send a test command (Icom example)
# This sends a "read frequency" command
echo -ne '\xFE\xFE\x94\xE0\x03\xFD' > /dev/cu.IC7300

# If you get a response, cable is working
```

**Solutions:**
- Try a different USB cable
- Check cable is fully inserted
- Try a different USB port on your Mac
- For Icom, ensure you're using the correct cable (not just a straight-through cable)

#### 5. Radio Not Powered On

Obvious but often overlooked!

**Solution:** Turn on your radio and wait 5-10 seconds for it to fully boot.

###Error: `RigError.notConnected`

**Symptoms:**
- Error occurs immediately when trying to send commands
- `rig.isConnected` returns `false`

**Cause:** Forgot to call `connect()` or connection failed silently.

**Solution:**
```swift
// Always connect first
try await rig.connect()

// Verify connection succeeded
guard rig.isConnected else {
    print("Failed to connect!")
    return
}

// Now safe to send commands
try await rig.setFrequency(14_230_000, vfo: .a)
```

### Error: `RigError.invalidResponse`

**Symptoms:**
- Radio responds but with unexpected data
- Works sometimes but not consistently

**Possible Causes:**

#### 1. Protocol Mismatch

Using the wrong radio definition for your actual radio.

**Solution:** Ensure you're using the correct `RadioDefinition`:
```swift
// Wrong - IC-7300 using IC-9700 definition
let rig = RigController(
    radio: .icomIC9700,  // ❌ Wrong!
    connection: .serial(path: "/dev/cu.IC7300", baudRate: 115200)
)

// Correct
let rig = RigController(
    radio: .icomIC7300,  // ✅ Correct
    connection: .serial(path: "/dev/cu.IC7300", baudRate: 115200)
)
```

#### 2. Corrupted Serial Data

Serial buffer has residual data from previous operations.

**Solution:** The library automatically flushes buffers on connect, but you can manually disconnect and reconnect:
```swift
await rig.disconnect()
try await Task.sleep(nanoseconds: 500_000_000)  // 500ms
try await rig.connect()
```

#### 3. Radio Firmware Issues

Some radios have firmware bugs that cause intermittent issues.

**Solution:** Update your radio's firmware to the latest version.

## Command Failures

### Error: `RigError.unsupportedOperation`

**Symptoms:**
- Error message like "Split operation not supported"
- Specific features don't work

**Cause:** Attempting to use a feature the radio doesn't support.

**Solution:** Check capabilities before using features:
```swift
// Check if radio supports split
if rig.capabilities.hasSplit {
    try await rig.setSplit(true)
} else {
    print("Radio doesn't support split operation")
}

// Check power control
if rig.capabilities.powerControl {
    try await rig.setPower(50)
}

// Check dual receiver
if rig.capabilities.hasDualReceiver {
    try await rig.setFrequency(14_230_000, vfo: .main)
    try await rig.setFrequency(7_100_000, vfo: .sub)
}
```

### Error: `RigError.invalidParameter`

**Symptoms:**
- Error when setting power: "Power must be between 0 and X watts"
- Invalid frequency or mode

**Cause:** Parameter out of range for the radio.

**Solution:**
```swift
// Power example
let maxPower = rig.capabilities.maxPower
let desiredPower = min(yourPower, maxPower)
try await rig.setPower(desiredPower)

// Frequency example - check range
let (minFreq, maxFreq) = rig.capabilities.frequencyRange
if frequency >= minFreq && frequency <= maxFreq {
    try await rig.setFrequency(frequency, vfo: .a)
}

// Mode example - check supported modes
if rig.capabilities.supportedModes.contains(.dataUSB) {
    try await rig.setMode(.dataUSB, vfo: .a)
}
```

### PTT Not Working

**Symptoms:**
- `setPTT(true)` completes but radio doesn't transmit
- No error but PTT doesn't activate

**Possible Causes:**

#### 1. Radio PTT Settings

**For Icom:**
1. **MENU** > **SET** > **Connectors** > **CI-V** > **CI-V USB TX**
2. Set to **ON**

**For Yaesu:**
1. **MENU** > **CAT** or **PC CONTROL**
2. Enable PTT via CAT

**For Kenwood:**
1. **MENU** > **COM** > **USB**
2. Enable PTT control

#### 2. Software PTT Disabled

Some radios require explicit enabling of software PTT.

**Solution:** Check your radio manual for "Computer PTT", "CAT PTT", or "CI-V PTT" settings.

#### 3. Verify PTT Command

```swift
// Enable PTT
try await rig.setPTT(true)

// Verify it's actually on
let pttEnabled = try await rig.isPTTEnabled()
print("PTT is: \(pttEnabled ? "ON" : "OFF")")

// Wait for transmission
try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

// Disable PTT
try await rig.setPTT(false)
```

## Serial Port Problems

### Permission Denied

**Symptoms:**
- Error when opening serial port
- "Permission denied" in error message

**Cause:** macOS sandbox restrictions (especially in Mac App Store apps).

**Solution:** Use the XPC helper for sandboxed apps:
```swift
// For Mac App Store apps
import RigControlXPC

let client = XPCClient.shared
try await client.connect()
try await client.connectToRadio(radio: "IC-9700", port: "/dev/cu.IC9700")
```

See [XPC Helper Guide](XPC_HELPER_GUIDE.md) for complete setup.

### Port Already in Use

**Symptoms:**
- "Resource busy" error
- Can't open serial port

**Cause:** Another application is using the port.

**Solution:**

```bash
# Find what's using the port
lsof | grep cu.IC9700

# Kill the process if needed
kill <PID>
```

Common culprits:
- Other ham radio software (WSJT-X, fldigi, etc.)
- Previous instance of your app still running
- System services

**Code solution:**
```swift
// Always disconnect when done
defer {
    Task {
        await rig.disconnect()
    }
}
```

### Port Disappears

**Symptoms:**
- Port works initially but then disappears
- USB device disconnects randomly

**Possible Causes:**

#### 1. USB Power Management

macOS may put USB devices to sleep.

**Solution:**
```bash
# Disable USB sleep in System Settings
# System Settings > Battery > Options > Prevent automatic sleeping

# Or disable for specific USB hub
sudo pmset -a usb 1
```

#### 2. Loose USB Connection

**Solution:** Try a different USB port or cable with better shielding.

#### 3. Radio Sleep Mode

Some radios go into sleep mode after inactivity.

**Solution:** Disable sleep mode in radio settings or send periodic keep-alive commands:
```swift
// Keep-alive task
Task {
    while rig.isConnected {
        try? await rig.frequency()  // Simple query to keep radio awake
        try await Task.sleep(nanoseconds: 30_000_000_000)  // Every 30 seconds
    }
}
```

## XPC Helper Issues

### XPC Helper Not Installed

**Symptoms:**
- XPCClient connection fails
- "Service not found" error

**Solution:** Install the XPC helper using SMJobBless:

```swift
import ServiceManagement

func installHelper() throws {
    var error: Unmanaged<CFError>?

    if !SMJobBless(
        kSMDomainSystemLaunchd,
        "com.swiftrigcontrol.helper" as CFString,
        nil,
        &error
    ) {
        if let error = error?.takeRetainedValue() {
            throw error
        }
    }
}
```

See [XPC_HELPER_GUIDE.md](XPC_HELPER_GUIDE.md) for complete installation instructions.

### XPC Helper Permission Issues

**Symptoms:**
- XPC helper installed but can't access serial ports
- Works for some ports but not others

**Cause:** Incorrect helper permissions or code signing.

**Solution:**
1. Ensure helper is properly code signed
2. Check `Info.plist` has correct permissions
3. Reinstall helper with correct entitlements

### XPC Connection Interrupted

**Symptoms:**
- Connection works then suddenly drops
- "Connection interrupted" errors

**Solution:**
```swift
// Implement reconnection logic
class XPCManager {
    let client = XPCClient.shared

    func connectWithRetry(maxAttempts: Int = 3) async throws {
        for attempt in 1...maxAttempts {
            do {
                try await client.connect()
                return
            } catch {
                if attempt == maxAttempts {
                    throw error
                }
                try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
            }
        }
    }
}
```

## Radio-Specific Issues

### Icom CI-V Address Conflicts

**Symptoms:**
- Multiple Icom radios on same CI-V bus cause conflicts
- Wrong radio responds to commands

**Solution:** Each radio needs a unique CI-V address:
```swift
// If you have multiple Icom radios, ensure each has unique address
// Check radio menu: SET > Connectors > CI-V > CI-V Address
```

### Yaesu CAT Compatibility Mode

**Symptoms:**
- Some Yaesu radios have "CAT compatibility mode"
- Commands work in one mode but not another

**Solution:**
```
// In radio menu
MENU > CAT SELECT > FT-450 (or FT-950, FTDX-9000, etc.)

// Use mode that matches the protocol
// Modern Yaesu radios use Kenwood-compatible protocol
```

### Kenwood VFO Selection Issues

**Symptoms:**
- VFO selection doesn't work as expected
- Split operation behaves strangely

**Cause:** Kenwood uses `FR` (receive) and `FT` (transmit) VFO commands differently.

**Solution:** Use `selectVFO` for receive frequency control:
```swift
// Select VFO A for receive
try await rig.selectVFO(.a)

// Set frequency
try await rig.setFrequency(14_230_000, vfo: .a)
```

### Elecraft Echo Mode

**Symptoms:**
- Elecraft radios echo commands back
- May cause confusion with responses

**Cause:** This is normal Elecraft behavior.

**Solution:** The library handles echo automatically. No action needed.

## Performance Issues

### Slow Response Times

**Symptoms:**
- Commands take several seconds to complete
- App feels sluggish

**Possible Causes:**

#### 1. Baud Rate Too Low

**Solution:** Use higher baud rate if supported:
```swift
// Check if your radio supports higher baud rates
// Modern Icom/Kenwood: 115200
// Yaesu/Elecraft: 38400
```

#### 2. Too Many Sequential Commands

**Solution:** Batch related commands together with small delays:
```swift
// Slow - each command waits for response
try await rig.setFrequency(14_230_000, vfo: .a)
try await rig.setMode(.usb, vfo: .a)
try await rig.setPower(50)

// Better - use Task groups for independent operations
await withTaskGroup(of: Void.self) { group in
    group.addTask {
        try? await rig.setMode(.usb, vfo: .a)
    }
    group.addTask {
        if rig.capabilities.powerControl {
            try? await rig.setPower(50)
        }
    }
    // Note: setFrequency should complete before mode change
}
```

#### 3. Excessive Polling

**Solution:** Don't poll the radio too frequently:
```swift
// Bad - polls every 100ms (10 Hz)
Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
    Task {
        try? await rig.frequency()
    }
}

// Better - poll every 1-2 seconds
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    Task {
        try? await rig.frequency()
    }
}
```

### Memory Leaks

**Symptoms:**
- App memory usage grows over time
- Eventual crashes or slowdowns

**Solution:**

```swift
// Always disconnect when done
class RadioManager {
    var rig: RigController?

    func cleanup() async {
        await rig?.disconnect()
        rig = nil
    }

    deinit {
        // For sync cleanup
        Task {
            await cleanup()
        }
    }
}
```

## Build and Integration Issues

### Swift Package Manager Build Errors

**Symptoms:**
- Can't build project
- Package resolution failures

**Solution:**

```bash
# Clean build folder
rm -rf .build

# Reset package cache
rm -rf ~/Library/Caches/org.swift.swiftpm

# Resolve packages again
swift package resolve

# Build
swift build
```

### Xcode Integration Issues

**Symptoms:**
- Xcode can't find SwiftRigControl module
- Build succeeds in command line but fails in Xcode

**Solution:**

1. File > Packages > Reset Package Caches
2. Product > Clean Build Folder (Cmd+Shift+K)
3. Close and reopen project
4. Ensure deployment target is macOS 13.0 or later

### IOKit Linking Errors

**Symptoms:**
- Undefined symbols for IOKit functions
- Linker errors mentioning IOKit

**Solution:**

The package automatically links IOKit, but if you have issues:

```swift
// In your app's Package.swift
.target(
    name: "YourApp",
    dependencies: ["RigControl"],
    linkerSettings: [
        .linkedFramework("IOKit")
    ]
)
```

### Code Signing Issues

**Symptoms:**
- App runs in Xcode but not as standalone
- "App is damaged" errors

**Solution:**

1. Ensure app is properly code signed
2. For XPC helper, must be signed with same team ID
3. Enable "Hardened Runtime" capability
4. Add "com.apple.security.device.serial" entitlement

```xml
<!-- In your entitlements file -->
<key>com.apple.security.device.serial</key>
<true/>
```

## Getting More Help

If you're still experiencing issues:

1. **Check GitHub Issues:** https://github.com/jjones9527/SwiftRigControl/issues
2. **Enable Debug Logging:**
   ```swift
   import os.log
   let logger = Logger(subsystem: "com.yourapp", category: "radio")
   logger.debug("Command sent: setFrequency(14230000)")
   ```
3. **Create Minimal Reproduction:**
   ```swift
   // Simplest possible case that demonstrates the issue
   let rig = RigController(radio: .icomIC7300, connection: .serial(path: "/dev/cu.IC7300", baudRate: nil))
   try await rig.connect()
   try await rig.setFrequency(14_230_000, vfo: .a)
   ```
4. **File an Issue:** Include:
   - macOS version
   - Radio model and firmware version
   - SwiftRigControl version
   - Complete error messages
   - Minimal reproduction code

## Diagnostic Checklist

Before filing an issue, verify:

- [ ] Radio is powered on
- [ ] USB cable is connected and working
- [ ] Correct serial port path
- [ ] Correct baud rate
- [ ] Radio CAT/CI-V is enabled in settings
- [ ] No other software using the port
- [ ] Using correct `RadioDefinition` for your radio
- [ ] Called `connect()` before sending commands
- [ ] Checked radio capabilities before using features
- [ ] Latest radio firmware
- [ ] Latest SwiftRigControl version

**73 de VA3ZTF and good luck!**
