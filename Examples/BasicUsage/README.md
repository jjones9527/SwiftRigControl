# Basic Usage Example

This example demonstrates the basic usage of SwiftRigControl with an Icom IC-9700.

## What it does

1. Connects to the radio
2. Displays radio capabilities
3. Reads current frequency and mode
4. Sets frequency to 14.230 MHz (20m SSTV calling frequency)
5. Sets mode to USB
6. Tests PTT control (keys for 1 second)
7. Demonstrates power control (if supported)
8. Disconnects cleanly

## Before running

1. **Connect your radio** via USB
2. **Find the serial port**:
   ```bash
   ls /dev/cu.* | grep -i icom
   ```
3. **Edit `main.swift`** and update `serialPort` to match your port
4. **Ensure antenna is connected** (for PTT test)

## Running

```bash
cd Examples/BasicUsage
swift run
```

## Expected output

```
SwiftRigControl - Basic Usage Example
==========================================

Creating rig controller for IC-9700...
Connecting to radio at /dev/cu.IC9700...
✓ Connected to Icom IC-9700

Radio Capabilities:
  - Has VFO B: true
  - Has Split: true
  - Power Control: true
  - Max Power: 100W
  - Dual Receiver: true

Reading current radio state...
✓ Current frequency: 14.074000 MHz
✓ Current mode: usb

Setting frequency to 14.230 MHz (20m SSTV calling)...
✓ Frequency set

Setting mode to USB...
✓ Mode set

Verifying settings...
✓ Frequency: 14.230000 MHz
✓ Mode: usb

Testing PTT control (will key for 1 second)...
WARNING: Make sure your antenna is connected!
✓ PTT ON
✓ PTT OFF

Reading RF power level...
✓ Current power: 100W

Setting power to 50W...
✓ Power set

✓ Verified power: 50W

Disconnecting...
✓ Disconnected

Example completed successfully!
```

## Troubleshooting

**Error: Cannot open serial port**
- Check that `/dev/cu.*` path is correct
- Ensure no other app is using the port
- Check cable connection

**Error: Timeout**
- Verify radio is powered on
- Check CI-V address matches (IC-9700 = 0xA2)
- Verify baud rate (IC-9700 default = 115200)
- Check CI-V transceive settings on radio

**Error: Command failed**
- Radio may not support the operation
- Check frequency is within radio's range
- Verify mode is supported

## Modifying for other radios

For IC-7300:
```swift
let rig = RigController(
    radio: .icomIC7300,
    connection: .serial(path: "/dev/cu.IC7300", baudRate: 115200)
)
```

For IC-705:
```swift
let rig = RigController(
    radio: .icomIC705,
    connection: .serial(path: "/dev/cu.IC705", baudRate: 19200)
)
```
