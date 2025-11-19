# Migrating from Hamlib to SwiftRigControl

This guide helps developers migrate amateur radio control applications from Hamlib (C library) to SwiftRigControl (native Swift).

## Table of Contents

1. [Why Migrate?](#why-migrate)
2. [Architecture Differences](#architecture-differences)
3. [Initialization](#initialization)
4. [Frequency Control](#frequency-control)
5. [Mode Control](#mode-control)
6. [PTT Control](#ptt-control)
7. [VFO Operations](#vfo-operations)
8. [Error Handling](#error-handling)
9. [Complete Migration Example](#complete-migration-example)
10. [Feature Comparison](#feature-comparison)

## Why Migrate?

### Advantages of SwiftRigControl

1. **Native Swift**
   - Type-safe Swift API
   - Modern async/await (no callbacks)
   - Actor-based concurrency
   - Swift error handling

2. **macOS Integration**
   - Built specifically for macOS
   - Direct IOKit access (no external dependencies)
   - Mac App Store compatible (via XPC helper)
   - Swift Package Manager integration

3. **Better Developer Experience**
   - Clean, modern API
   - Comprehensive documentation
   - Unit tested
   - No C bridge required

4. **Smaller Footprint**
   - Single Swift package (no Hamlib .dylib)
   - Easier deployment
   - Simpler dependencies

### When to Stay with Hamlib

- Cross-platform requirements (Linux, Windows)
- Need for exotic/rare radio support
- Integration with existing Hamlib-based tools
- C/C++ codebase

## Architecture Differences

### Hamlib Architecture

```c
// C-based with function pointers and structs
RIG *rig = rig_init(RIG_MODEL_IC9700);
rig_open(rig);
rig_set_freq(rig, RIG_VFO_A, 14230000);
rig_cleanup(rig);
```

**Characteristics:**
- Procedural C API
- Manual memory management
- Synchronous blocking calls
- Pointer-based error handling
- Global state

### SwiftRigControl Architecture

```swift
// Swift-based with async/await and actors
let rig = RigController(
    radio: .icomIC9700,
    connection: .serial(path: "/dev/cu.IC9700", baudRate: 115200)
)
try await rig.connect()
try await rig.setFrequency(14_230_000, vfo: .a)
await rig.disconnect()
```

**Characteristics:**
- Object-oriented Swift API
- Automatic memory management (ARC)
- Async/await for concurrency
- Thrown errors for error handling
- Actor isolation for thread safety

## Initialization

### Hamlib

```c
#include <hamlib/rig.h>

// Initialize radio
RIG *rig = rig_init(RIG_MODEL_IC9700);
if (!rig) {
    fprintf(stderr, "rig_init failed\n");
    return -1;
}

// Set serial port parameters
strncpy(rig->state.rigport.pathname, "/dev/cu.IC9700", FILPATHLEN);
rig->state.rigport.parm.serial.rate = 115200;

// Open connection
int ret = rig_open(rig);
if (ret != RIG_OK) {
    fprintf(stderr, "rig_open failed: %s\n", rigerror(ret));
    rig_cleanup(rig);
    return -1;
}
```

### SwiftRigControl

```swift
import RigControl

// Initialize and connect
let rig = RigController(
    radio: .icomIC9700,
    connection: .serial(path: "/dev/cu.IC9700", baudRate: 115200)
)

do {
    try await rig.connect()
} catch {
    print("Failed to connect: \(error)")
}
```

**Key Differences:**
- No manual model lookup (compile-time radio selection)
- No manual memory management
- Async/await instead of blocking calls
- Swift error handling instead of return codes

## Frequency Control

### Hamlib - Set Frequency

```c
freq_t freq = 14230000;  // 14.230 MHz
int ret = rig_set_freq(rig, RIG_VFO_A, freq);
if (ret != RIG_OK) {
    fprintf(stderr, "rig_set_freq failed: %s\n", rigerror(ret));
}
```

### SwiftRigControl - Set Frequency

```swift
try await rig.setFrequency(14_230_000, vfo: .a)
```

### Hamlib - Get Frequency

```c
freq_t freq;
int ret = rig_get_freq(rig, RIG_VFO_A, &freq);
if (ret != RIG_OK) {
    fprintf(stderr, "rig_get_freq failed: %s\n", rigerror(ret));
} else {
    printf("Frequency: %.0f Hz\n", freq);
}
```

### SwiftRigControl - Get Frequency

```swift
let freq = try await rig.frequency(vfo: .a)
print("Frequency: \(freq) Hz")
```

**Key Differences:**
- No pointer arguments (return value instead)
- Type-safe VFO enum (.a, .b, .main, .sub)
- Throws errors instead of return codes
- UInt64 instead of typedef freq_t

## Mode Control

### Hamlib - Set Mode

```c
rmode_t mode = RIG_MODE_USB;
pbwidth_t width = RIG_PASSBAND_NORMAL;
int ret = rig_set_mode(rig, RIG_VFO_A, mode, width);
if (ret != RIG_OK) {
    fprintf(stderr, "rig_set_mode failed: %s\n", rigerror(ret));
}
```

### SwiftRigControl - Set Mode

```swift
try await rig.setMode(.usb, vfo: .a)
```

**Note:** SwiftRigControl doesn't expose passband width (uses radio defaults)

### Hamlib - Get Mode

```c
rmode_t mode;
pbwidth_t width;
int ret = rig_get_mode(rig, RIG_VFO_A, &mode, &width);
if (ret != RIG_OK) {
    fprintf(stderr, "rig_get_mode failed: %s\n", rigerror(ret));
} else {
    printf("Mode: %s, Width: %ld Hz\n", rig_strrmode(mode), width);
}
```

### SwiftRigControl - Get Mode

```swift
let mode = try await rig.mode(vfo: .a)
print("Mode: \(mode.rawValue)")  // e.g., "USB"
```

### Mode Mapping

| Hamlib | SwiftRigControl |
|--------|-----------------|
| `RIG_MODE_LSB` | `.lsb` |
| `RIG_MODE_USB` | `.usb` |
| `RIG_MODE_CW` | `.cw` |
| `RIG_MODE_CWR` | `.cwR` |
| `RIG_MODE_AM` | `.am` |
| `RIG_MODE_FM` | `.fm` |
| `RIG_MODE_WFM` | `.fmN` (FM narrow) |
| `RIG_MODE_RTTY` | `.rtty` |
| `RIG_MODE_PKTLSB` | `.dataLSB` |
| `RIG_MODE_PKTUSB` | `.dataUSB` |

## PTT Control

### Hamlib - Set PTT

```c
// Enable PTT (transmit)
int ret = rig_set_ptt(rig, RIG_VFO_A, RIG_PTT_ON);
if (ret != RIG_OK) {
    fprintf(stderr, "rig_set_ptt failed: %s\n", rigerror(ret));
}

// Transmit audio here...

// Disable PTT (receive)
ret = rig_set_ptt(rig, RIG_VFO_A, RIG_PTT_OFF);
```

### SwiftRigControl - Set PTT

```swift
// Enable PTT (transmit)
try await rig.setPTT(true)

// Transmit audio here...

// Disable PTT (receive)
try await rig.setPTT(false)
```

### Hamlib - Get PTT

```c
ptt_t ptt;
int ret = rig_get_ptt(rig, RIG_VFO_A, &ptt);
if (ret != RIG_OK) {
    fprintf(stderr, "rig_get_ptt failed: %s\n", rigerror(ret));
} else {
    printf("PTT: %s\n", ptt == RIG_PTT_ON ? "ON" : "OFF");
}
```

### SwiftRigControl - Get PTT

```swift
let isTransmitting = try await rig.isPTTEnabled()
print("PTT: \(isTransmitting ? "ON" : "OFF")")
```

## VFO Operations

### Hamlib - Select VFO

```c
int ret = rig_set_vfo(rig, RIG_VFO_B);
if (ret != RIG_OK) {
    fprintf(stderr, "rig_set_vfo failed: %s\n", rigerror(ret));
}
```

### SwiftRigControl - Select VFO

```swift
try await rig.selectVFO(.b)
```

### Hamlib - Split Operation

```c
// Enable split (RX on VFO A, TX on VFO B)
int ret = rig_set_split_freq(rig, RIG_VFO_TX, 14225000);
ret = rig_set_split_mode(rig, RIG_VFO_TX, RIG_MODE_USB, RIG_PASSBAND_NORMAL);
ret = rig_set_split_vfo(rig, RIG_VFO_RX, RIG_SPLIT_ON, RIG_VFO_B);
```

### SwiftRigControl - Split Operation

```swift
// Set frequencies
try await rig.setFrequency(14_195_000, vfo: .a)  // RX
try await rig.setFrequency(14_225_000, vfo: .b)  // TX

// Set modes
try await rig.setMode(.usb, vfo: .a)
try await rig.setMode(.usb, vfo: .b)

// Enable split
try await rig.setSplit(true)
```

## Error Handling

### Hamlib - Error Handling

```c
int ret = rig_set_freq(rig, RIG_VFO_A, 14230000);

switch (ret) {
    case RIG_OK:
        printf("Success\n");
        break;
    case -RIG_EINVAL:
        fprintf(stderr, "Invalid parameter\n");
        break;
    case -RIG_ECONF:
        fprintf(stderr, "Invalid configuration\n");
        break;
    case -RIG_ENAVAIL:
        fprintf(stderr, "Function not available\n");
        break;
    case -RIG_EIO:
        fprintf(stderr, "I/O error\n");
        break;
    default:
        fprintf(stderr, "Error: %s\n", rigerror(ret));
}
```

### SwiftRigControl - Error Handling

```swift
do {
    try await rig.setFrequency(14_230_000, vfo: .a)
    print("Success")
} catch RigError.notConnected {
    print("Radio not connected")
} catch RigError.timeout {
    print("I/O error - radio didn't respond")
} catch RigError.invalidParameter(let message) {
    print("Invalid parameter: \(message)")
} catch RigError.unsupportedOperation(let message) {
    print("Function not available: \(message)")
} catch {
    print("Error: \(error)")
}
```

### Error Code Mapping

| Hamlib | SwiftRigControl |
|--------|-----------------|
| `RIG_OK` | Success (no error) |
| `-RIG_EINVAL` | `RigError.invalidParameter` |
| `-RIG_ECONF` | `RigError.invalidResponse` |
| `-RIG_ENAVAIL` | `RigError.unsupportedOperation` |
| `-RIG_EIO` | `RigError.timeout` |
| `-RIG_EPROTO` | `RigError.invalidResponse` |
| `-RIG_ERJCTED` | `RigError.commandFailed` |

## Complete Migration Example

### Hamlib Version

```c
#include <hamlib/rig.h>
#include <stdio.h>
#include <unistd.h>

int main() {
    RIG *rig;
    freq_t freq = 14230000;
    rmode_t mode = RIG_MODE_USB;
    pbwidth_t width = RIG_PASSBAND_NORMAL;
    int ret;

    // Initialize
    rig = rig_init(RIG_MODEL_IC9700);
    if (!rig) {
        fprintf(stderr, "rig_init failed\n");
        return 1;
    }

    // Configure
    strncpy(rig->state.rigport.pathname, "/dev/cu.IC9700", FILPATHLEN);
    rig->state.rigport.parm.serial.rate = 115200;

    // Open
    ret = rig_open(rig);
    if (ret != RIG_OK) {
        fprintf(stderr, "rig_open failed: %s\n", rigerror(ret));
        rig_cleanup(rig);
        return 1;
    }

    // Set frequency and mode
    ret = rig_set_freq(rig, RIG_VFO_A, freq);
    if (ret != RIG_OK) {
        fprintf(stderr, "rig_set_freq failed: %s\n", rigerror(ret));
    }

    ret = rig_set_mode(rig, RIG_VFO_A, mode, width);
    if (ret != RIG_OK) {
        fprintf(stderr, "rig_set_mode failed: %s\n", rigerror(ret));
    }

    // Enable PTT
    ret = rig_set_ptt(rig, RIG_VFO_A, RIG_PTT_ON);
    if (ret != RIG_OK) {
        fprintf(stderr, "rig_set_ptt failed: %s\n", rigerror(ret));
    }

    // Transmit for 2 seconds
    sleep(2);

    // Disable PTT
    ret = rig_set_ptt(rig, RIG_VFO_A, RIG_PTT_OFF);

    // Cleanup
    rig_close(rig);
    rig_cleanup(rig);

    return 0;
}
```

### SwiftRigControl Version

```swift
import RigControl
import Foundation

@main
struct RadioApp {
    static func main() async {
        let rig = RigController(
            radio: .icomIC9700,
            connection: .serial(path: "/dev/cu.IC9700", baudRate: 115200)
        )

        do {
            // Connect
            try await rig.connect()

            // Set frequency and mode
            try await rig.setFrequency(14_230_000, vfo: .a)
            try await rig.setMode(.usb, vfo: .a)

            // Enable PTT
            try await rig.setPTT(true)

            // Transmit for 2 seconds
            try await Task.sleep(nanoseconds: 2_000_000_000)

            // Disable PTT
            try await rig.setPTT(false)

            // Disconnect (automatic cleanup)
            await rig.disconnect()

        } catch {
            print("Error: \(error)")
        }
    }
}
```

**Line Count:**
- Hamlib: ~60 lines
- SwiftRigControl: ~30 lines (50% reduction)

## Feature Comparison

### Frequency Control

| Feature | Hamlib | SwiftRigControl |
|---------|--------|-----------------|
| Set frequency | ✅ | ✅ |
| Get frequency | ✅ | ✅ |
| Frequency range check | ✅ Manual | ✅ Automatic |
| VFO A/B | ✅ | ✅ |
| Main/Sub RX | ✅ | ✅ (maps to A/B) |

### Mode Control

| Feature | Hamlib | SwiftRigControl |
|---------|--------|-----------------|
| Set mode | ✅ | ✅ |
| Get mode | ✅ | ✅ |
| Passband width | ✅ | ❌ (uses defaults) |
| Mode validation | ✅ Manual | ✅ Automatic |

### PTT Control

| Feature | Hamlib | SwiftRigControl |
|---------|--------|-----------------|
| Set PTT | ✅ | ✅ |
| Get PTT | ✅ | ✅ |
| PTT via RTS/DTR | ✅ | ❌ (CAT only) |

### VFO Operations

| Feature | Hamlib | SwiftRigControl |
|---------|--------|-----------------|
| Select VFO | ✅ | ✅ |
| Copy VFO A→B | ✅ | ❌ |
| Exchange A↔B | ✅ | ❌ |
| Split operation | ✅ | ✅ |
| Set split freq | ✅ | ✅ (via setFrequency) |

### Power Control

| Feature | Hamlib | SwiftRigControl |
|---------|--------|-----------------|
| Set power level | ✅ | ✅ |
| Get power level | ✅ | ✅ |
| Power in watts | ✅ | ✅ |
| Power in % | ✅ | ✅ (auto-convert) |

### Radio Information

| Feature | Hamlib | SwiftRigControl |
|---------|--------|-----------------|
| Get capabilities | ✅ | ✅ |
| Get radio info | ✅ | ✅ |
| Get model name | ✅ | ✅ |
| S-meter reading | ✅ | ❌ (future) |
| TX meter reading | ✅ | ❌ (future) |

### Advanced Features

| Feature | Hamlib | SwiftRigControl |
|---------|--------|-----------------|
| Scanning | ✅ | Manual impl |
| Channel memory | ✅ | ❌ (future) |
| Tuning steps | ✅ | ❌ (future) |
| RIT/XIT | ✅ | ❌ (future) |
| Antenna selection | ✅ | ❌ (future) |
| Preamp/Attenuator | ✅ | ❌ (future) |

## Migration Checklist

- [ ] Replace Hamlib headers with `import RigControl`
- [ ] Convert `rig_init()` to `RigController(radio:connection:)`
- [ ] Remove manual memory management (`rig_cleanup`)
- [ ] Convert function calls to async/await
- [ ] Replace return code checks with do/try/catch
- [ ] Update VFO constants (RIG_VFO_A → .a)
- [ ] Update mode constants (RIG_MODE_USB → .usb)
- [ ] Remove passband width parameters
- [ ] Test with your radio
- [ ] Update build system to use Swift Package Manager

## Common Gotchas

### 1. Async/Await Requirement

**Hamlib (Synchronous):**
```c
rig_set_freq(rig, RIG_VFO_A, 14230000);  // Blocks until complete
printf("Frequency set\n");
```

**SwiftRigControl (Asynchronous):**
```swift
// Must use await
try await rig.setFrequency(14_230_000, vfo: .a)
print("Frequency set")

// Function must be async
func setRadioFrequency() async throws {  // Note: async
    try await rig.setFrequency(14_230_000, vfo: .a)
}
```

### 2. Error Handling

**Hamlib:**
```c
// Always check return codes
if (rig_set_freq(...) != RIG_OK) {
    // Handle error
}
```

**SwiftRigControl:**
```swift
// Errors are thrown, must use try
try await rig.setFrequency(...)

// Or catch
do {
    try await rig.setFrequency(...)
} catch {
    // Handle error
}
```

### 3. Radio Model Selection

**Hamlib (Runtime):**
```c
// Model selected at runtime with integer constant
RIG *rig = rig_init(RIG_MODEL_IC9700);  // Could be wrong at runtime
```

**SwiftRigControl (Compile-time):**
```swift
// Type-safe enum at compile time
let rig = RigController(radio: .icomIC9700)  // Compiler checks validity
```

### 4. Cleanup

**Hamlib (Manual):**
```c
// Must manually cleanup
rig_close(rig);
rig_cleanup(rig);
```

**SwiftRigControl (Automatic):**
```swift
// ARC handles cleanup automatically
await rig.disconnect()  // Optional explicit cleanup
// rig is automatically deallocated when out of scope
```

## Additional Resources

- [SwiftRigControl Usage Examples](USAGE_EXAMPLES.md)
- [API Documentation](API_DOCUMENTATION.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Serial Port Configuration](SERIAL_PORT_GUIDE.md)

## Getting Help

- GitHub Issues: https://github.com/yourusername/SwiftRigControl/issues
- Hamlib compatibility questions welcome

**73 and happy migrating!**
