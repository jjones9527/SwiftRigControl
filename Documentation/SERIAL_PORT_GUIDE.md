# Serial Port Configuration Guide

Complete guide for configuring serial communications between your Mac and amateur radio transceivers.

## Table of Contents

1. [Overview](#overview)
2. [Finding Serial Ports](#finding-serial-ports)
3. [Radio-Specific Configuration](#radio-specific-configuration)
4. [USB Driver Installation](#usb-driver-installation)
5. [Testing Serial Communication](#testing-serial-communication)
6. [Common Issues](#common-issues)
7. [Advanced Configuration](#advanced-configuration)

## Overview

Amateur radio transceivers connect to macOS via USB or traditional RS-232 serial ports. Most modern radios use USB cables that present as virtual serial ports to the operating system.

### Connection Types

1. **USB-to-Serial (Most Common)**
   - Radio connects via USB cable
   - Appears as `/dev/cu.usbserial-*` or similar
   - May require driver installation

2. **Built-in USB CAT Interface**
   - Modern radios with native USB
   - Appears with radio-specific name
   - Usually works without additional drivers

3. **Traditional RS-232**
   - Older radios with DE-9 connector
   - Requires USB-to-Serial adapter
   - Appears as `/dev/cu.usbserial-*`

## Finding Serial Ports

### List All Available Ports

```bash
# Show all serial ports
ls -la /dev/cu.*

# Filter for USB serial devices
ls -la /dev/cu.* | grep usb

# Search for specific radio
ls -la /dev/cu.* | grep -i icom
```

### Common Port Naming Patterns

| Driver/Chip | Port Pattern | Example |
|-------------|--------------|---------|
| Silicon Labs CP210x | `/dev/cu.SLAB_USBtoUART` | Most Icom radios |
| FTDI | `/dev/cu.usbserial-*` | Some Yaesu, Elecraft |
| CH340 | `/dev/cu.wchusbserial*` | Generic USB-serial |
| Prolific PL2303 | `/dev/cu.usbserial*` | Older adapters |
| Radio Native | `/dev/cu.IC9700` | Some Icom with drivers |

### Identifying Your Radio's Port

**Method 1: Plug and compare**
```bash
# Before connecting radio
ls /dev/cu.* > before.txt

# After connecting radio
ls /dev/cu.* > after.txt

# See what changed
diff before.txt after.txt
```

**Method 2: System Information**
```bash
# Open System Information
# Applications > Utilities > System Information
# Hardware > USB

# Look for your radio or USB-serial adapter
# Note the location and BSD name
```

**Method 3: Using ioreg**
```bash
# List USB devices with serial info
ioreg -p IOUSB -l -w 0 | grep -i "usb serial\|icom\|yaesu\|kenwood\|elecraft"

# More detailed for a specific port
ioreg -c IOSerialBSDClient -r -t
```

## Radio-Specific Configuration

### Icom Radios

#### IC-9700, IC-7610, IC-7300

**Default Settings:**
- Baud Rate: 115200
- Data Bits: 8
- Stop Bits: 1
- Parity: None
- Flow Control: None

**Radio Configuration:**
1. Press **MENU**
2. Navigate to: **SET > Connectors > USB**
3. Settings:
   - **USB Function**: CI-V (not AF OUTPUT)
   - **USB Baud Rate**: 115200
   - **USB Send/Receive**: ON
   - **CI-V USB Port**: ON
   - **CI-V USB Baud Rate**: 115200 (or Auto)
   - **CI-V USB Echo Back**: OFF
   - **CI-V Transceive**: OFF (recommended)
   - **CI-V Address**: Default (usually 0xA2, 0x98, or 0x94)

**Finding Port:**
```bash
# Silicon Labs driver required
# Port usually appears as:
ls /dev/cu.SLAB_USBtoUART*

# Or with Icom driver:
ls /dev/cu.IC*
```

**SwiftRigControl Setup:**
```swift
let rig = RigController(
    radio: .icomIC9700,
    connection: .serial(path: "/dev/cu.SLAB_USBtoUART", baudRate: 115200)
)
```

#### IC-7600, IC-7100, IC-705

**Default Settings:**
- Baud Rate: 19200 (older default)
- Otherwise same as above

**Radio Configuration:**
Same menu path but check:
- **CI-V Baud Rate**: 19200 (can be changed to 115200)

**SwiftRigControl Setup:**
```swift
let rig = RigController(
    radio: .icomIC7100,
    connection: .serial(path: "/dev/cu.SLAB_USBtoUART", baudRate: 19200)
)
```

### Yaesu Radios

#### FTDX-10, FT-991A, FT-710, FT-891

**Default Settings:**
- Baud Rate: 38400
- Data Bits: 8
- Stop Bits: 1 (FT-991A) or 2 (FTDX-10)
- Parity: None
- Flow Control: None

**Radio Configuration:**
1. Press **MENU**
2. Navigate to: **CAT** or **PC CONTROL**
3. Settings:
   - **CAT RATE**: 38400
   - **CAT TOT**: 10ms or 100ms
   - **CAT RTS**: DISABLE
   - **PC CONTROL**: PC
   - **PTT Port**: CAT

**Finding Port:**
```bash
# FTDI chip common
ls /dev/cu.usbserial-*

# Some may appear as:
ls /dev/cu.*FTDX* or ls /dev/cu.*FT991*
```

**SwiftRigControl Setup:**
```swift
let rig = RigController(
    radio: .yaesuFTDX10,
    connection: .serial(path: "/dev/cu.usbserial-FTDX10", baudRate: 38400)
)
```

#### FT-817 (Portable)

**Default Settings:**
- Baud Rate: 38400
- Connection via mini-DIN or USB (with adapter)

**Radio Configuration:**
1. Press and hold **FUNC**
2. Press **C** (FW/REV)
3. Rotate dial to: **CAT RATE**
4. Set to: **38400**

### Kenwood Radios

#### TS-890S, TS-990S, TS-590SG

**Default Settings:**
- Baud Rate: 115200
- Data Bits: 8
- Stop Bits: 1
- Parity: None
- Flow Control: None

**Radio Configuration:**
1. Press **MENU**
2. Navigate to: **COM** or **USB**
3. Settings:
   - **USB BAUD**: 115200
   - **USB COM**: ON
   - **USB CAT**: ON
   - **PC/TS-590**: AUTO or PC
   - **USB SEND**: ON

**SwiftRigControl Setup:**
```swift
let rig = RigController(
    radio: .kenwoodTS890S,
    connection: .serial(path: "/dev/cu.usbserial-TS890", baudRate: 115200)
)
```

#### TS-480SAT, TS-2000, TM-D710

**Default Settings:**
- Baud Rate: 57600 or 9600 (older)

**Radio Configuration:**
Menu path similar, but check:
- **BAUD RATE**: 57600 (or 9600)

**SwiftRigControl Setup:**
```swift
let rig = RigController(
    radio: .kenwoodTS2000,
    connection: .serial(path: "/dev/cu.usbserial-TS2000", baudRate: 57600)
)
```

### Elecraft Radios

#### K3, K3S, K4, KX3

**Default Settings:**
- Baud Rate: 38400
- Data Bits: 8
- Stop Bits: 2
- Parity: None
- Flow Control: None (Xon/Xoff optional)

**Radio Configuration:**
1. Press **CONFIG**
2. Navigate to: **RS-232**
3. Settings:
   - **BAUD**: 38400
   - **STOP BITS**: 2
   - **DATA**: 8
   - **PARITY**: NONE
   - **MODE**: CMD (command mode)

**SwiftRigControl Setup:**
```swift
let rig = RigController(
    radio: .elecraftK3,
    connection: .serial(path: "/dev/cu.usbserial-K3", baudRate: 38400)
)
```

#### K2

**Default Settings:**
- Baud Rate: 4800 (lower for older hardware)
- Otherwise same as K3

**Radio Configuration:**
1. **MENU** > **RS232**
2. Set **BAUD**: 4800

#### KX2

**Default Settings:**
- Baud Rate: 38400
- Uses micro-USB connector

**Radio Configuration:**
Same as KX3, accessed via:
1. **MENU** (hold **MSG/KHZ**)
2. **CONFIG** > **RS-232**

## USB Driver Installation

### Silicon Labs CP210x (Most Icom)

**Check if needed:**
```bash
# Connect radio and check
ls /dev/cu.SLAB_USBtoUART

# If port doesn't appear, install driver
```

**Installation:**
1. Download from: https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers
2. Choose "CP210x VCP Mac OSX Driver"
3. Install and restart Mac
4. Check System Settings > Privacy & Security for driver approval

**Post-Installation:**
```bash
# Verify driver loaded
kextstat | grep -i silabs

# Port should now appear
ls /dev/cu.SLAB_USBtoUART
```

### FTDI (Some Yaesu, Elecraft)

**Check if needed:**
```bash
ls /dev/cu.usbserial-*
```

**Installation:**
macOS includes FTDI drivers by default (10.9+). If needed:
1. Download from: https://ftdichip.com/drivers/vcp-drivers/
2. Choose "VCP" (Virtual COM Port) drivers for macOS
3. Install and restart

### CH340 (Generic USB-Serial)

**Installation:**
1. Download from: https://github.com/adrianmihalko/ch340g-ch34g-ch34x-mac-os-x-driver
2. Install .pkg file
3. Restart Mac
4. Approve in System Settings > Privacy & Security

**Unload conflicting driver (if needed):**
```bash
# Some Macs have conflicting driver
sudo kextunload -b com.apple.driver.usb.cdc

# Load CH340 driver
sudo kextload /Library/Extensions/usbserial.kext
```

## Testing Serial Communication

### Using screen (Built-in)

```bash
# Connect to radio
screen /dev/cu.SLAB_USBtoUART 115200

# For Kenwood/Yaesu, type: FA;
# Should get response like: FA00014230000;

# For Icom, send hex (trickier with screen)
# Exit with: Ctrl-A, then K, then Y
```

### Using cu (Built-in)

```bash
# Connect to radio
cu -l /dev/cu.SLAB_USBtoUART -s 115200

# Type commands (for text-based protocols)
# Exit with: ~.
```

### Using Python (Simple Test Script)

```python
#!/usr/bin/env python3
import serial
import time

# Configure for your radio
port = "/dev/cu.SLAB_USBtoUART"
baud = 115200

# Open serial port
ser = serial.Serial(port, baud, timeout=1)

# Test for Kenwood/Yaesu/Elecraft (text protocol)
ser.write(b"FA;")
response = ser.read(100)
print(f"Response: {response}")

# Test for Icom (binary protocol) - read frequency
cmd = bytes([0xFE, 0xFE, 0x94, 0xE0, 0x03, 0xFD])
ser.write(cmd)
response = ser.read(100)
print(f"Response (hex): {response.hex()}")

ser.close()
```

### Using Swift (Minimal Test)

```swift
import Foundation
import RigControl

let rig = RigController(
    radio: .icomIC9700,
    connection: .serial(path: "/dev/cu.SLAB_USBtoUART", baudRate: 115200)
)

Task {
    do {
        try await rig.connect()
        print("✅ Connected successfully")

        let freq = try await rig.frequency()
        print("✅ Current frequency: \(freq) Hz")

        await rig.disconnect()
        print("✅ Disconnected")
    } catch {
        print("❌ Error: \(error)")
    }
}

RunLoop.main.run()
```

## Common Issues

### Port Permissions

**Issue:** "Permission denied" when opening port

**Solution:**
```bash
# Check port ownership
ls -l /dev/cu.SLAB_USBtoUART

# Should be owned by you (not root)
# If not, add yourself to appropriate group

# For development, you can chmod (not recommended for production)
sudo chmod 666 /dev/cu.SLAB_USBtoUART
```

### Port Not Appearing

**Issue:** Radio connected but no /dev/cu.* entry

**Solutions:**
1. Install appropriate USB driver (see above)
2. Try different USB cable
3. Try different USB port on Mac
4. Check System Settings > Privacy & Security for blocked drivers
5. Restart Mac after driver installation

### Multiple Ports

**Issue:** Several /dev/cu.* ports appear

**Solution:**
```bash
# Try each one in your code
# Or identify by:

# Check which is actual data port (not just power)
ls -lt /dev/cu.* | head

# Most recent is usually the one you just plugged in

# Or use System Information to match BSD name
```

### Port Disappears During Operation

**Issue:** Port vanishes while app is running

**Solutions:**
1. Disable USB power management:
   ```bash
   sudo pmset -a usb 1
   ```

2. Prevent sleep:
   ```bash
   sudo pmset -a sleep 0
   sudo pmset -a disksleep 0
   ```

3. In code, handle disconnection gracefully:
   ```swift
   do {
       try await rig.setFrequency(freq, vfo: .a)
   } catch {
       print("Connection lost, attempting reconnect...")
       await rig.disconnect()
       try await Task.sleep(nanoseconds: 1_000_000_000)
       try await rig.connect()
   }
   ```

## Advanced Configuration

### Custom Baud Rates

Some radios support non-standard baud rates:

```swift
// Icom supports: 300, 1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200
let rig = RigController(
    radio: .icomIC7300,
    connection: .serial(path: "/dev/cu.IC7300", baudRate: 57600)  // Custom
)

// Kenwood TS-890S supports: 4800, 9600, 19200, 38400, 57600, 115200
// Yaesu typically: 4800, 9600, 19200, 38400

// Always match radio's menu setting
```

### Multiple Radios

Running multiple radios simultaneously:

```swift
// Radio 1: IC-9700 for VHF/UHF
let vhfRig = RigController(
    radio: .icomIC9700,
    connection: .serial(path: "/dev/cu.SLAB_USBtoUART", baudRate: 115200)
)

// Radio 2: IC-7300 for HF
let hfRig = RigController(
    radio: .icomIC7300,
    connection: .serial(path: "/dev/cu.SLAB_USBtoUART1", baudRate: 115200)
)

// Each radio needs unique port
try await vhfRig.connect()
try await hfRig.connect()
```

### Flow Control

Most amateur radios don't use hardware flow control, but some do:

**RTS/CTS (Hardware Flow Control):**
- Generally: OFF/DISABLE for most radios
- Icom: Not used
- Yaesu: Usually RTS=DISABLE in menu
- Kenwood: Usually not applicable
- Elecraft: Optional, usually off

**XON/XOFF (Software Flow Control):**
- Rarely used in amateur radio
- Elecraft K3: Optional for slow systems
- Generally: OFF

The library uses no flow control by default, which works for 99% of setups.

### Serial Port Aliases

Create friendly aliases for your radios:

```bash
# Add to ~/.zshrc or ~/.bash_profile
alias radio-hf='ls -la /dev/cu.SLAB_USBtoUART'
alias radio-vhf='ls -la /dev/cu.IC9700'

# Or create symlinks (requires root)
sudo ln -s /dev/cu.SLAB_USBtoUART /dev/cu.my-ic7300
```

Then in code:
```swift
let rig = RigController(
    radio: .icomIC7300,
    connection: .serial(path: "/dev/cu.my-ic7300", baudRate: 115200)
)
```

## Quick Reference

### Icom
- **Port**: `/dev/cu.SLAB_USBtoUART`
- **Baud**: 115200 (modern) or 19200 (older)
- **Driver**: Silicon Labs CP210x
- **Menu**: SET > Connectors > USB > CI-V

### Yaesu
- **Port**: `/dev/cu.usbserial-*`
- **Baud**: 38400
- **Driver**: FTDI (built-in macOS)
- **Menu**: CAT or PC CONTROL

### Kenwood
- **Port**: `/dev/cu.usbserial-*`
- **Baud**: 115200 (modern) or 57600 (older)
- **Driver**: Usually FTDI
- **Menu**: COM or USB

### Elecraft
- **Port**: `/dev/cu.usbserial-*`
- **Baud**: 38400 (K3/KX3) or 4800 (K2)
- **Driver**: FTDI (built-in macOS)
- **Menu**: CONFIG > RS-232

## Next Steps

- See [USAGE_EXAMPLES.md](USAGE_EXAMPLES.md) for code examples
- See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
- See [API_DOCUMENTATION.md](API_DOCUMENTATION.md) for complete API reference

**73!**
