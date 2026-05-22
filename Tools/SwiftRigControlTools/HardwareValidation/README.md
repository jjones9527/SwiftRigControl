# Hardware Validation Tools

Professional-grade standalone validation tools for testing Icom radios with SwiftRigControl.

## Overview

These tools provide comprehensive hardware validation for supported radios. They are designed for:

- **Beta testers** - Validate your hardware configuration
- **Field testing** - Quick diagnostics and verification
- **Development** - Test CI-V protocol implementations
- **Quality assurance** - Systematic feature validation

Each validator is a standalone executable that tests all major radio functions using only public APIs.

## Supported Radios

| Radio | Validator | Bands | Tests | Coverage | Key Features |
|-------|-----------|-------|-------|----------|--------------|
| IC-7100 | `IC7100Validator` | HF/VHF/UHF | 15 | ~75% | Multi-band, D-STAR capable |
| IC-7600 | `IC7600Validator` | HF/6m | 15 | ~85% | High-performance dual receiver |
| IC-9700 | `IC9700Validator` | VHF/UHF/1.2GHz | 15 | ~80% | Satellite mode, dual receiver |
| K2 | `K2Validator` | HF (160m-10m) | 13 | ~90% | QRP transceiver (0-15W) |

## Quick Start

### Prerequisites

1. Radio connected via USB serial
2. Swift 6.2+ installed
3. macOS 13+ (Ventura or later)

### Find Your Serial Port

```bash
ls /dev/cu.usbserial*
```

Common patterns:
- `/dev/cu.usbserial-2110` - IC-7100
- `/dev/cu.usbserial-2120` - IC-7600, IC-9700
- `/dev/cu.usbserial-K2` - Elecraft K2

### Run a Validator

#### IC-7100
```bash
export IC7100_SERIAL_PORT="/dev/cu.usbserial-2110"
swift run IC7100Validator
```

#### IC-7600
```bash
export IC7600_SERIAL_PORT="/dev/cu.usbserial-2120"
swift run IC7600Validator
```

#### IC-9700
```bash
export IC9700_SERIAL_PORT="/dev/cu.usbserial-2120"
swift run IC9700Validator
```

#### Elecraft K2
```bash
export K2_SERIAL_PORT="/dev/cu.usbserial-K2"
swift run K2Validator
```

## What Gets Tested

All validators test these core functions:

### Basic Operations
- ✅ **Connection** - Establish CI-V communication
- ✅ **Frequency Control** - Read/write frequencies across all bands
- ✅ **Mode Control** - Test all supported modes (SSB, CW, FM, etc.)
- ✅ **VFO Operations** - Dual VFO switching and independent operation

### Advanced Features
- ✅ **Split Operation** - Independent TX/RX frequencies
- ✅ **Power Control** - Adjust transmit power (0-100W)
- ✅ **PTT Control** - Transmit/receive switching (with safety confirmation)
- ✅ **Signal Strength** - S-meter readings
- ✅ **RIT/XIT** - Receiver/transmitter incremental tuning
- ✅ **Rapid Switching** - Performance benchmarks

### Radio-Specific Features

#### IC-7100 (15 tests, ~75% coverage)
- **RF Controls**: Attenuator, Preamp, AGC, Noise Blanker
- **Audio/DSP**: TWIN PBT, Manual Notch, Twin Peak Filter, DSP Filter Type
- **Transmit**: VOX, Anti-VOX, Compression, Break-in, Monitor
- **Display**: LCD Backlight/Contrast, Dial Lock

#### IC-7600 (15 tests, ~85% coverage)
- **RF Controls**: Attenuator (4 levels), Preamp, AGC, Squelch
- **Audio/DSP**: TWIN PBT, Notch, Audio Peak Filter, Twin Peak Filter, Filter Width
- **Transmit**: Compression, Break-in, Monitor
- **Dual Receiver**: Dual Watch, Band Exchange/Equalize, Audio Balance
- **Specialized**: Band Edge Detection, Display Brightness, AGC Time Constant

#### IC-9700 (15 tests, ~80% coverage)
- **RF Controls**: Attenuator, Preamp, AGC, NR Level, Squelch Status
- **Audio/DSP**: Manual Notch, Notch Position, Monitor, Monitor Gain
- **Transmit**: VOX, Anti-VOX, Digital Squelch, PO Meter Level
- **Advanced**: Satellite Mode, Dual Watch, Dial Lock

#### Elecraft K2 (13 tests, ~90% coverage)
- **QRP Features**: 0-15W power control, fine frequency resolution (10 Hz)
- **CW Specialty**: CW and CW-R modes (K2 specialty)
- **HF Coverage**: All HF bands (160m-10m)
- **Advanced**: RIT/XIT, Band Edge Testing, Rapid Switching

## Safety Features

### State Management
- **Automatic save/restore** - Original radio state is preserved
- **Graceful failure** - Radio restored even if tests fail
- **Non-destructive** - All tests return radio to initial state

### PTT Protection
- **User confirmation** required before transmit tests
- **Low power default** - PTT tests use 10W unless specified
- **Dummy load reminder** - Prompts to verify safe load
- **Frequency display** - Shows exact TX frequency for verification

## Sample Output

```
======================================================================
IC-7600 Hardware Validation
======================================================================
Configuration:
  Radio: Icom IC-7600
  CI-V Address: 0x7A (default)
  Baud Rate: 19200
  Bands: HF + 6m (160m-6m)
  Max Power: 100W
  Port: /dev/cu.usbserial-2120

✓ Connected to IC-7600

💾 Saving radio state...
   Frequency: 14.250000 MHz
   Mode: USB
   Power: 100W

📡 Test 1: Multi-Band Frequency Control
   ✓ 160m CW: 1.850000 MHz
   ✓ 80m LSB: 3.700000 MHz
   ✓ 40m LSB: 7.100000 MHz
   ✓ 30m CW: 10.125000 MHz
   ✓ 20m USB: 14.200000 MHz
   ✓ 17m USB: 18.100000 MHz
   ✓ 15m USB: 21.200000 MHz
   ✓ 12m USB: 24.950000 MHz
   ✓ 10m USB: 28.500000 MHz
   ✓ 6m USB: 50.100000 MHz
   ✓ ✅ Multi-band frequency control: PASS

...

======================================================================
Test Summary for IC-7600
======================================================================
✅ Passed:  10
❌ Failed:  0
⏭️  Skipped: 0
📊 Total:   10
======================================================================
Success Rate: 100.0%
======================================================================

🔄 Restoring original radio state...
✓ Radio state restored
✓ Disconnected from IC-7600
```

## Troubleshooting

### Serial Port Issues

**Problem**: `❌ Serial port not configured`

**Solution**:
```bash
# List available ports
ls /dev/cu.*

# Set environment variable
export IC7600_SERIAL_PORT="/dev/cu.usbserial-XXXX"
```

### Connection Failures

**Problem**: `❌ Fatal error: timeout`

**Possible causes**:
1. Wrong serial port
2. Radio not powered on
3. USB cable issue
4. CI-V transceive enabled (should be OFF)
5. Wrong baud rate setting

**Radio Settings**:
- **IC-7100**: 19200 baud, CI-V address 0x88, transceive OFF
- **IC-7600**: 19200 baud, CI-V address 0x7A, transceive OFF
- **IC-9700**: 19200 baud, CI-V address 0xA2, transceive OFF
- **K2**: 4800 baud (default for K2)

### PTT Test Failures

**Problem**: PTT test fails or skipped

**Solution**:
1. Ensure dummy load is connected
2. Verify antenna tuner (if used) is properly configured
3. Check SWR is acceptable
4. Confirm you answered 'y' to PTT confirmation prompt

### Build Errors

**Problem**: `swift build` fails

**Solution**:
```bash
# Clean build
rm -rf .build
swift build

# Check Swift version (need 6.2+)
swift --version
```

## Advanced Usage

### Custom Environment Variables

You can override default settings:

```bash
# Use non-standard baud rate (usually not needed)
IC7600_BAUD_RATE=9600 swift run IC7600Validator

# Run multiple radios in sequence
export IC7100_SERIAL_PORT="/dev/cu.usbserial-2110"
export IC7600_SERIAL_PORT="/dev/cu.usbserial-2120"
export IC9700_SERIAL_PORT="/dev/cu.usbserial-2120"
export K2_SERIAL_PORT="/dev/cu.usbserial-K2"

swift run IC7100Validator && \
swift run IC7600Validator && \
swift run IC9700Validator && \
swift run K2Validator
```

### Automated Testing

```bash
#!/bin/bash
# validate-all.sh - Test all connected radios

set -e  # Exit on first failure

echo "Starting comprehensive hardware validation..."

if [ -n "$IC7100_SERIAL_PORT" ]; then
    echo "Testing IC-7100..."
    swift run IC7100Validator
fi

if [ -n "$IC7600_SERIAL_PORT" ]; then
    echo "Testing IC-7600..."
    swift run IC7600Validator
fi

if [ -n "$IC9700_SERIAL_PORT" ]; then
    echo "Testing IC-9700..."
    swift run IC9700Validator
fi

if [ -n "$K2_SERIAL_PORT" ]; then
    echo "Testing Elecraft K2..."
    swift run K2Validator
fi

echo "All validations completed successfully!"
```

## For Developers

### Running XCTest Suite

For comprehensive automated testing during development:

```bash
# Run all hardware tests
swift test --filter HardwareTests

# Run specific radio tests
swift test --filter IC7600HardwareTests

# Run with verbose output
swift test --filter IC7600HardwareTests --verbose
```

### Validator vs XCTest

| Use Case | Tool | Command |
|----------|------|---------|
| Quick hardware check | Validator | `swift run IC7600Validator` |
| Beta testing | Validator | `swift run IC7600Validator` |
| Field diagnostics | Validator | `swift run IC7600Validator` |
| Automated CI/CD | XCTest | `swift test --filter IC7600HardwareTests` |
| Development | XCTest | `swift test --filter IC7600HardwareTests` |
| Debugging | XCTest | `swift test --filter IC7600HardwareTests --verbose` |

## Reporting Issues

When reporting hardware validation failures, please include:

1. **Validator output** - Full console output
2. **Radio model and firmware version**
3. **Serial port used** - `/dev/cu.usbserial-XXXX`
4. **Radio CI-V settings** - Address, baud rate, transceive setting
5. **macOS version** - `sw_vers`
6. **Swift version** - `swift --version`

Example:
```
Radio: IC-7600 (firmware 1.05)
Port: /dev/cu.usbserial-2120
CI-V: Address 0x7A, 19200 baud, transceive OFF
macOS: 14.2 (Sonoma)
Swift: 6.2

Test "RIT control" failed with timeout...
[attach full output]
```

## Architecture

### Design Principles

1. **Public APIs Only** - Validators use only public RigControl APIs
2. **Standalone** - Each validator is independent and self-contained
3. **Safe** - State save/restore, PTT confirmation, error handling
4. **Consistent** - Shared `ValidationHelpers` for common operations
5. **Extensible** - Easy to add new radios

### Directory Structure

```
HardwareValidation/
├── Shared/
│   └── ValidationHelpers.swift    # Common utilities
├── IC7100Validator/
│   └── main.swift                 # 15 tests, ~550 lines
├── IC7600Validator/
│   └── main.swift                 # 15 tests, ~660 lines
├── IC9700Validator/
│   └── main.swift                 # 15 tests, ~560 lines
├── K2Validator/
│   └── main.swift                 # 13 tests, ~490 lines
├── RigctldEmulator/
│   └── main.swift                 # rigctld compatibility server
└── README.md                      # This file
```

### Adding a New Radio

1. Create directory: `HardwareValidation/NewRadioValidator/`
2. Create `main.swift` using existing validators as template
3. Import `ValidationHelpers` for shared utilities
4. Update `Package.swift`:
   ```swift
   .executable(name: "NewRadioValidator", targets: ["NewRadioValidator"]),
   .executableTarget(
       name: "NewRadioValidator",
       dependencies: ["RigControl", "ValidationHelpers"],
       path: "HardwareValidation/NewRadioValidator"
   ),
   ```
5. Build and test: `swift run NewRadioValidator`
6. Update this README

## License

Part of SwiftRigControl - see main project LICENSE file.

## Support

- **Documentation**: See main project `Documentation/` directory
- **Issues**: https://github.com/anthropics/claude-code/issues (adjust to your repo)
- **Discussions**: Project discussions forum

---

**Note**: These validators are designed for hardware testing. For software unit tests and protocol validation, see `Tests/RigControlTests/`.
