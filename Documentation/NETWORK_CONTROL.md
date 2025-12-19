# Network Control (rigctld Protocol)

SwiftRigControl includes a complete implementation of the Hamlib rigctld protocol, enabling remote control of amateur radio transceivers over TCP/IP networks.

## Table of Contents
- [Overview](#overview)
- [Quick Start](#quick-start)
- [Protocol Modes](#protocol-modes)
- [Command Reference](#command-reference)
- [Server API](#server-api)
- [Client Examples](#client-examples)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

## Overview

The rigctld protocol is Hamlib's standard network protocol for remote rig control. It provides:

- **TCP/IP Access**: Control radios over local network or internet
- **Multi-Client Support**: Multiple simultaneous client connections
- **Protocol Compatibility**: Compatible with Hamlib's rigctl and other clients
- **Two Response Modes**: Default (minimal) and Extended (verbose with return codes)

### Architecture

```
┌──────────────┐         ┌────────────────┐         ┌──────────────┐
│   rigctl     │◄───────►│ RigControlServer│◄───────►│ RigController │
│  (Client)    │  TCP    │   (rigctld)     │  Swift  │              │
└──────────────┘  4532   └────────────────┘   API   └──────┬───────┘
                                                             │
                                                             ▼
                                                      ┌──────────────┐
                                                      │  Radio       │
                                                      │  (CI-V/CAT)  │
                                                      └──────────────┘
```

## Quick Start

### Starting a rigctld Server

```swift
import RigControl

// Create rig controller
let rig = RigController(
    radio: RadioDefinition.icomIC7600(),
    connection: .serial(path: "/dev/cu.usbserial-0", baudRate: 19200)
)

try await rig.connect()

// Create and start rigctld server
let server = RigControlServer(rigController: rig)
try await server.start(port: 4532)

print("rigctld server listening on port 4532")

// Server runs until stopped
// ... your application logic ...

await server.stop()
```

### Using the Test Tool

SwiftRigControl includes a ready-to-use test tool:

```bash
# Run with simulated radio (no serial connection)
.build/debug/RigctldTest

# Connect to real radio
.build/debug/RigctldTest -s /dev/cu.usbserial-0 -b 19200 -r IC-7600

# Use custom port
.build/debug/RigctldTest -p 4533
```

### Connecting Clients

Once the server is running, connect using any rigctld-compatible client:

```bash
# Using Hamlib's rigctl
rigctl -m 2 -r localhost:4532

# Using telnet
telnet localhost 4532

# Using netcat
nc localhost 4532
```

## Protocol Modes

The rigctld protocol supports two response modes:

### Default Protocol

Minimal responses containing only the requested data. Best for machine-to-machine communication.

**Example:**
```
Client: f\n
Server: 14230000\n

Client: m\n
Server: USB\n
Server: 2400\n
```

### Extended Response Protocol

Verbose responses with command echo and return codes. Best for interactive use and debugging.

**Example:**
```
Client: \get_freq\n
Server: get_freq: 14230000\n
Server: RPRT 0\n

Client: \get_mode\n
Server: get_mode: USB 2400\n
Server: RPRT 0\n
```

**Enable Extended Protocol:**
```
Client: \set_ext_response 1\n
Server: set_ext_response:\n
Server: RPRT 0\n
```

## Command Reference

### Frequency Commands

| Command | Short | Long | Parameters | Description |
|---------|-------|------|------------|-------------|
| Get Frequency | `f` | `\get_freq` | None | Returns frequency in Hz |
| Set Frequency | `F` | `\set_freq` | `<hz>` | Sets frequency in Hz |

**Examples:**
```
f                    # Get: 14230000
F 14230000          # Set to 14.230 MHz
\set_freq 7074000   # Set to 7.074 MHz
```

### Mode Commands

| Command | Short | Long | Parameters | Description |
|---------|-------|------|------------|-------------|
| Get Mode | `m` | `\get_mode` | None | Returns mode and passband |
| Set Mode | `M` | `\set_mode` | `<mode> [passband]` | Sets operating mode |

**Supported Modes:** LSB, USB, CW, CWR, AM, FM, FMN, WFM, RTTY, RTTYR, PKTLSB (DATA-LSB), PKTUSB (DATA-USB), PKTFM (DATA-FM)

**Examples:**
```
m                    # Get: USB\n2400
M USB 2400          # Set USB with 2400 Hz passband
\set_mode CW 500    # Set CW with 500 Hz passband
```

### VFO Commands

| Command | Short | Long | Parameters | Description |
|---------|-------|------|------------|-------------|
| Get VFO | `v` | `\get_vfo` | None | Returns current VFO |
| Set VFO | `V` | `\set_vfo` | `<vfo>` | Selects VFO |

**VFO Names:** VFOA, VFOB, MAIN, SUB

**Examples:**
```
v                    # Get: VFOA
V VFOB              # Select VFO B
\set_vfo MAIN       # Select main VFO
```

### PTT Commands

| Command | Short | Long | Parameters | Description |
|---------|-------|------|------------|-------------|
| Get PTT | `t` | `\get_ptt` | None | Returns PTT state (0/1) |
| Set PTT | `T` | `\set_ptt` | `<state>` | Sets PTT (0=off, 1=on) |

**Examples:**
```
t                    # Get: 0
T 1                 # Enable PTT
\set_ptt 0          # Disable PTT
```

### Level Commands (DSP Controls)

| Command | Short | Long | Parameters | Description |
|---------|-------|------|------------|-------------|
| Get Level | `l` | `\get_level` | `<name>` | Gets level value (AGC, etc.) |
| Set Level | `L` | `\set_level` | `<name> <value>` | Sets level value |

**Supported Levels:**
- **AGC**: Automatic Gain Control speed
  - Values: 0=OFF, 1=FAST, 2=MEDIUM, 3=SLOW, 4=AUTO
  - Not all radios support all values (IC-7600/7300/7610 lack OFF)

- **NB**: Noise Blanker (impulse noise suppression)
  - Values: 0=OFF, 1-255=enabled with level
  - Level control available on IC-9700, IC-7100, IC-705
  - IC-7600, IC-7300, IC-7610 support on/off only (level ignored)

- **NR**: Noise Reduction (continuous noise suppression)
  - Values: 0=OFF, 1-255=enabled with level
  - Level control available on all modern Icom radios

- **IF**: IF (Intermediate Frequency) Filter selection
  - Values: 1=FIL1 (wide), 2=FIL2 (medium), 3=FIL3 (narrow)
  - Available on IC-7600, IC-7300, IC-7610, IC-9700, and other modern radios
  - Each mode has independent filter settings

**Examples:**
```
l AGC               # Get current AGC: 1
L AGC 1             # Set fast AGC
L AGC 2             # Set medium AGC
\get_level AGC      # Get AGC (long form)

l NB                # Get NB state: 0 (off) or 1-255 (level)
L NB 0              # Disable noise blanker
L NB 5              # Enable NB with level 5
\set_level NB 10    # Enable NB with level 10 (long form)

l NR                # Get NR state: 0 (off) or 1-255 (level)
L NR 0              # Disable noise reduction
L NR 8              # Enable NR with level 8
\set_level NR 15    # Enable NR with level 15 (long form)

l IF                # Get IF filter: 1, 2, or 3
L IF 1              # Select FIL1 (wide filter)
L IF 2              # Select FIL2 (medium filter)
L IF 3              # Select FIL3 (narrow filter for weak signals)
\set_level IF 3     # Select narrow filter (long form)
```

### Split Operation Commands

| Command | Short | Long | Parameters | Description |
|---------|-------|------|------------|-------------|
| Get Split | `s` | `\get_split_vfo` | None | Returns split state and TX VFO |
| Set Split | `S` | `\set_split_vfo` | `<enable> [txvfo]` | Enables/disables split |
| Get Split Freq | `i` | `\get_split_freq` | None | Returns TX frequency |
| Set Split Freq | `I` | `\set_split_freq` | `<hz>` | Sets TX frequency |
| Get Split Mode | `x` | `\get_split_mode` | None | Returns TX mode |
| Set Split Mode | `X` | `\set_split_mode` | `<mode> [passband]` | Sets TX mode |

**Examples:**
```
s                    # Get split: 0 VFOB
S 1 VFOB            # Enable split, TX on VFO B
I 14235000          # Set TX frequency
X LSB 2400          # Set TX mode to LSB
```

### Information Commands

| Command | Short | Long | Parameters | Description |
|---------|-------|------|------------|-------------|
| Dump Caps | N/A | `\dump_caps` | None | Returns radio capabilities |
| Dump State | N/A | `\dump_state` | None | Returns radio state info |
| Check VFO | N/A | `\chk_vfo` | None | Checks if VFO mode is on |

### Power Conversion Commands

| Command | Short | Long | Parameters | Description |
|---------|-------|------|------------|-------------|
| Power to mW | `2` | `\power2mW` | `<pwr> <freq> <mode>` | Converts normalized power to milliwatts |
| mW to Power | `4` | `\mW2power` | `<mw> <freq> <mode>` | Converts milliwatts to normalized power |

### Protocol Control

| Command | Short | Long | Parameters | Description |
|---------|-------|------|------------|-------------|
| Extended Response | N/A | `\set_ext_response` | `<0\|1>` | Enables/disables extended responses |
| Quit | `q` | `\quit` | None | Closes connection |

## Server API

### RigControlServer

The main server class for rigctld protocol.

```swift
public actor RigControlServer {
    /// Initialize with a rig controller
    public init(rigController: RigController)

    /// Start the server on specified port
    /// - Parameter port: TCP port (default: 4532)
    /// - Throws: RigControlServerError if server cannot start
    public func start(port: UInt16 = 4532) async throws

    /// Stop the server and close all connections
    public func stop() async

    /// Check if server is currently running
    public var isRunning: Bool { get }

    /// Current listening port (nil if stopped)
    public var port: UInt16? { get }
}
```

### Error Handling

```swift
public enum RigControlServerError: Error {
    /// Server is already running
    case alreadyRunning

    /// Cannot bind to port (may be in use)
    case cannotBind(port: UInt16)

    /// Connection closed by client
    case connectionClosed

    /// Failed to encode response
    case encodingError
}
```

### Return Codes

The server returns standard rigctld return codes in extended mode:

| Code | Name | Description |
|------|------|-------------|
| 0 | OK | Command succeeded |
| -1 | INVALID_PARAM | Invalid parameter |
| -2 | INVALID_CONFIG | Invalid configuration |
| -3 | OUT_OF_MEMORY | Out of memory |
| -4 | NOT_IMPLEMENTED | Feature not implemented |
| -5 | COMMUNICATION_ERROR | Radio communication error |
| -6 | TIMEOUT | Operation timed out |
| -7 | IO_ERROR | I/O error |
| -8 | INTERNAL_ERROR | Internal server error |
| -9 | PROTOCOL_ERROR | Protocol error |
| -10 | REJECTED | Command rejected by radio |
| -11 | ARGUMENT_ERROR | Argument error |
| -12 | NOT_SUPPORTED | Operation not supported |
| -13 | VFO_NOT_TARGETABLE | VFO cannot be targeted |
| -14 | ERROR | Generic error |

## Client Examples

### Python Client

```python
import socket

# Connect to rigctld server
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect(('localhost', 4532))

# Get frequency
sock.send(b'f\n')
freq = sock.recv(1024).decode().strip()
print(f"Frequency: {freq} Hz")

# Set mode
sock.send(b'M USB 2400\n')
response = sock.recv(1024)

# Enable extended responses
sock.send(b'\\set_ext_response 1\n')
sock.recv(1024)

# Get mode with extended response
sock.send(b'\\get_mode\n')
response = sock.recv(1024).decode()
print(response)  # get_mode: USB 2400\nRPRT 0\n

sock.close()
```

### Shell Script

```bash
#!/bin/bash

# Connect to rigctld
exec 3<>/dev/tcp/localhost/4532

# Get frequency
echo "f" >&3
read freq <&3
echo "Frequency: $freq Hz"

# Set frequency
echo "F 14230000" >&3
read response <&3

# Get mode
echo "m" >&3
read mode <&3
read passband <&3
echo "Mode: $mode, Passband: $passband Hz"

# Close connection
echo "q" >&3
exec 3<&-
```

### rigctl (Hamlib)

```bash
# Interactive mode
rigctl -m 2 -r localhost:4532

# Execute single command
rigctl -m 2 -r localhost:4532 f

# Set frequency
rigctl -m 2 -r localhost:4532 F 14230000

# Get mode
rigctl -m 2 -r localhost:4532 m
```

## Testing

### Manual Testing

1. **Start the test server:**
   ```bash
   .build/debug/RigctldTest -p 4532
   ```

2. **Connect with netcat:**
   ```bash
   nc localhost 4532
   ```

3. **Try commands:**
   ```
   f                    # Get frequency
   F 14230000          # Set frequency
   m                    # Get mode
   M USB 2400          # Set mode
   \set_ext_response 1  # Enable extended responses
   \get_freq            # Get frequency (extended)
   q                    # Quit
   ```

### Automated Testing

```bash
# Create test script
cat > test_rigctld.sh << 'EOF'
#!/bin/bash
echo "f" | nc localhost 4532           # Test get frequency
echo "F 14230000" | nc localhost 4532  # Test set frequency
echo "m" | nc localhost 4532           # Test get mode
echo "M USB 2400" | nc localhost 4532  # Test set mode
EOF

chmod +x test_rigctld.sh
./test_rigctld.sh
```

### Unit Testing

```swift
import XCTest
@testable import RigControl

final class RigctldProtocolTests: XCTestCase {
    func testCommandParsing() async throws {
        let parser = RigctldCommandParser()

        // Test frequency commands
        let setFreq = try parser.parse("F 14230000")
        XCTAssertEqual(setFreq, .setFrequency(hz: 14230000))

        let getFreq = try parser.parse("f")
        XCTAssertEqual(getFreq, .getFrequency)

        // Test long commands
        let longFreq = try parser.parse("\\set_freq 14230000")
        XCTAssertEqual(longFreq, .setFrequency(hz: 14230000))
    }

    func testResponseFormatting() {
        // Test default protocol
        let freq = RigctldResponse.frequency(14230000)
        XCTAssertEqual(freq.formatDefault(), "14230000\n")

        // Test extended protocol
        let mode = RigctldResponse.mode("USB", passband: 2400,
                                       command: .getMode)
        let extended = mode.formatExtended()
        XCTAssertTrue(extended.contains("get_mode:"))
        XCTAssertTrue(extended.contains("RPRT 0"))
    }
}
```

## Troubleshooting

### Server Won't Start

**Error: "Cannot bind to port 4532"**

- Port may already be in use by another rigctld instance
- Check with: `lsof -i :4532`
- Kill existing process or use different port: `.build/debug/RigctldTest -p 4533`

### No Response from Server

- Verify server is running: `nc -zv localhost 4532`
- Check firewall settings
- Try connecting with verbose netcat: `nc -v localhost 4532`

### Commands Return RPRT -5

**Communication Error** - Usually means:
- Radio is not connected
- Serial port path is incorrect
- Baud rate mismatch
- Radio is powered off

Check radio connection:
```swift
try await rig.connect()
let freq = try await rig.frequency(vfo: .a, cached: false)
print("Radio is responding: \(freq) Hz")
```

### Commands Return RPRT -12

**Not Supported** - The radio doesn't support this operation:
- Check radio capabilities: `\dump_caps`
- Verify feature is available for your radio model

### Extended Responses Not Working

Ensure you've enabled extended mode:
```
\set_ext_response 1
```

This setting is per-connection and resets when disconnecting.

## Performance Considerations

### Multiple Clients

The server supports multiple simultaneous connections. Each client:
- Has its own command parser and response formatter
- Maintains independent extended/default protocol mode
- Shares the same RigController instance (thread-safe via actors)

### Latency

Typical command latency depends on:
- Network latency (< 1ms on localhost, varies on network)
- Radio communication speed (20-100ms for Icom CI-V at 19200 baud)
- Command complexity

### Throughput

The server can handle:
- 100+ commands/second on localhost
- Limited primarily by radio communication speed
- CI-V protocol: ~10-50 commands/second depending on baud rate

## Advanced Usage

### Custom Radio Models

```swift
// Define custom radio
let customRadio = RadioDefinition(
    name: "Custom Radio",
    manufacturer: "Custom",
    protocol: createCustomProtocol(),
    capabilities: customCapabilities()
)

let rig = RigController(
    radio: customRadio,
    connection: .serial(path: "/dev/cu.custom", baudRate: 115200)
)

let server = RigControlServer(rigController: rig)
try await server.start()
```

### Multiple Radios

Run separate servers for multiple radios:

```swift
// Radio 1
let rig1 = RigController(
    radio: RadioDefinition.icomIC7600(),
    connection: .serial(path: "/dev/cu.IC7600", baudRate: 19200)
)
let server1 = RigControlServer(rigController: rig1)
try await server1.start(port: 4532)

// Radio 2
let rig2 = RigController(
    radio: RadioDefinition.icomIC9700(),
    connection: .serial(path: "/dev/cu.IC9700", baudRate: 115200)
)
let server2 = RigControlServer(rigController: rig2)
try await server2.start(port: 4533)
```

### Integration with Web Services

```swift
import Vapor

func routes(_ app: Application) throws {
    // Start rigctld server
    let server = RigControlServer(rigController: globalRig)
    try await server.start()

    // HTTP endpoint for frequency
    app.get("frequency") { req async throws -> String in
        let freq = try await globalRig.frequency(vfo: .a, cached: false)
        return "\(freq)"
    }
}
```

## References

- [Hamlib rigctld Documentation](https://github.com/Hamlib/Hamlib/wiki/rigctld)
- [SwiftRigControl API Documentation](../README.md)
- [Icom CI-V Protocol](../ICOM_PROTOCOL.md)
- [Contributing Guidelines](../CONTRIBUTING.md)

## Support

For issues, questions, or contributions:
- GitHub Issues: https://github.com/your-repo/SwiftRigControl/issues
- Discussions: https://github.com/your-repo/SwiftRigControl/discussions

## License

SwiftRigControl is available under the MIT license. See LICENSE for details.
