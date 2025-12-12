# Adding Radio Support to SwiftRigControl

Complete guide for adding new radio models to SwiftRigControl.

## Table of Contents

1. [Before You Start](#before-you-start)
2. [Adding a Radio Using Existing Protocol](#adding-a-radio-using-existing-protocol)
3. [Implementing a New Protocol](#implementing-a-new-protocol)
4. [Testing Your Radio](#testing-your-radio)
5. [Documentation Requirements](#documentation-requirements)
6. [Pull Request Checklist](#pull-request-checklist)

---

## Before You Start

### Prerequisites

1. **Radio Documentation**: Obtain the official CAT/CI-V command reference manual
2. **Hardware Access**: Physical access to the radio for testing
3. **Reference Implementation**: Check Hamlib source code for reference
4. **Development Environment**: macOS 13+, Xcode 15+, Swift 5.9+

### Determine Protocol Type

SwiftRigControl supports four protocol families:

| Protocol | Manufacturers | Characteristics |
|----------|--------------|-----------------|
| **CI-V** | Icom | Binary protocol, BCD encoding, 0xFD terminator |
| **Elecraft** | Elecraft | Text protocol, semicolon terminator |
| **Yaesu CAT** | Yaesu | Text protocol, semicolon terminator |
| **Kenwood** | Kenwood | Text protocol, semicolon terminator |

If your radio uses one of these protocols, you can add it easily. Otherwise, you'll need to implement a new protocol.

---

## Adding a Radio Using Existing Protocol

This is the most common case - adding a new model that uses an existing protocol.

### Step 1: Gather Radio Information

Collect these details from the radio manual:

**For Icom Radios:**
- CI-V Address (hex, e.g., `0xA2`)
- Default baud rate
- Frequency range (min/max in Hz)
- Supported modes
- VFO architecture (targetable A/B, Main/Sub, or current-only)
- Echo behavior (does it echo commands over USB?)
- Mode filter requirement (does mode command need filter byte?)

**For Other Radios:**
- Default baud rate
- Frequency range
- Supported modes
- Command format specifics

**Example Reference Sources:**
- Official manual (CAT/CI-V command reference section)
- Hamlib source code: `rigs/<manufacturer>/<model>.c`
- Community forums and discussions

### Step 2: Create Radio Definition

Navigate to the appropriate models file based on manufacturer:

- Icom: `Sources/RigControl/Protocols/Icom/IcomModels.swift`
- Elecraft: `Sources/RigControl/Protocols/Elecraft/ElecraftModels.swift`
- Yaesu: `Sources/RigControl/Protocols/Yaesu/YaesuModels.swift`
- Kenwood: `Sources/RigControl/Protocols/Kenwood/KenwoodModels.swift`

#### Example: Adding IC-705 (Icom)

```swift
/// Icom IC-705 portable HF/VHF/UHF transceiver
public static let icomIC705 = RadioDefinition(
    manufacturer: .icom,
    model: "IC-705",
    defaultBaudRate: 19200,
    capabilities: RadioCapabilitiesDatabase.icomIC705,
    protocolFactory: { transport in
        IcomCIVProtocol(
            transport: transport,
            commandSet: .ic705,  // See Step 3
            capabilities: RadioCapabilitiesDatabase.icomIC705
        )
    }
)
```

### Step 3: Define Capabilities

Add capabilities in `Sources/RigControl/Models/RadioCapabilitiesDatabase.swift`:

```swift
public static let icomIC705 = RigCapabilities(
    hasVFOB: true,                    // Has VFO B
    hasSplit: true,                   // Supports split operation
    powerControl: true,               // Can control RF power
    maxPower: 10,                     // 10 watts max
    supportedModes: [                 // All supported modes
        .lsb, .usb, .cw, .cwR,
        .am, .fm, .fmN,
        .rtty, .rttyR,
        .dataLSB, .dataUSB, .dataFM
    ],
    frequencyRange: (30_000, 500_000_000),  // 30 kHz to 500 MHz
    hasDualReceiver: false,           // Single receiver
    hasATU: true,                     // Has antenna tuner
    requiresVFOSelection: false,      // Operates on current VFO
    requiresModeFilter: false,        // NO filter byte (like IC-7100)
    region: .region2                  // Default to Region 2 (Americas)
)
```

### Step 4: Define Command Set (Icom Only)

For Icom radios, define the command set in `Sources/RigControl/Protocols/Icom/CommandSets/StandardIcomCommandSet.swift`:

```swift
/// IC-705 portable HF/VHF/UHF transceiver
/// - VFO Model: Current Only (operates on current VFO)
/// - 19200 baud, 10W portable, NO mode filter byte
/// - IMPORTANT: Echoes commands over USB connection (like IC-7100)
public static var ic705: StandardIcomCommandSet {
    StandardIcomCommandSet(
        civAddress: 0xA4,               // From manual
        vfoModel: .currentOnly,         // Operates on current VFO only
        requiresModeFilter: false,      // NO filter byte
        echoesCommands: true            // Echoes over USB
    )
}
```

#### Icom VFO Models

Choose the correct VFO model:

```swift
public enum VFOOperationModel {
    case targetable    // Can target VFO A or B directly (IC-7300, IC-7700, etc.)
    case mainSub       // Uses Main/Sub receivers (IC-9700, IC-7610, IC-7600)
    case currentOnly   // Operates on current VFO (IC-7100, IC-705, IC-7200)
    case none          // No VFO selection (IC-R75 receiver)
}
```

**How to determine:**
- Check manual: Does it say "Main/Sub" or "VFO A/B"?
- Look at Hamlib: Check `rigs/icom/ic<model>.c` for VFO handling
- Review `ICOM_RADIO_ARCHITECTURES.md` for similar models

#### Icom Echo Behavior

Some Icom radios echo commands over USB before sending responses:

- **IC-7100, IC-705**: YES - echo commands (`echoesCommands: true`)
- **IC-7600**: YES - echo over USB (`echoesCommands: true`)
- **IC-7300, IC-7610, IC-9700**: NO - no echo (`echoesCommands: false`)

**How to determine:**
- Check Hamlib issues (search for model + "echo")
- Test with real hardware
- When in doubt, start with `false` and adjust if responses fail

### Step 5: Add to XPC Server (Optional)

If supporting sandboxed apps, add to `Sources/RigControlXPC/XPCServer.swift`:

```swift
private func radioDefinitionFromString(_ radio: String) throws -> RadioDefinition {
    switch radio {
    // ... existing radios ...

    case "IC-705", "IC705", "ic705":
        return .icomIC705

    // ... rest of cases ...
    }
}
```

### Step 6: Create Unit Tests

Add tests in `Tests/RigControlTests/<Manufacturer>ProtocolTests.swift`:

```swift
func testIC705Capabilities() {
    let radio = RadioDefinition.icomIC705

    // Verify basic properties
    XCTAssertEqual(radio.manufacturer, .icom)
    XCTAssertEqual(radio.model, "IC-705")
    XCTAssertEqual(radio.defaultBaudRate, 19200)

    // Verify capabilities
    XCTAssertTrue(radio.capabilities.hasVFOB)
    XCTAssertTrue(radio.capabilities.hasSplit)
    XCTAssertTrue(radio.capabilities.powerControl)
    XCTAssertEqual(radio.capabilities.maxPower, 10)
    XCTAssertFalse(radio.capabilities.hasDualReceiver)

    // Verify frequency range
    XCTAssertTrue(radio.capabilities.isFrequencyValid(14_230_000))
    XCTAssertTrue(radio.capabilities.isFrequencyValid(435_000_000))
}

func testIC705CommandSet() {
    let commandSet = StandardIcomCommandSet.ic705

    // Verify CI-V address
    XCTAssertEqual(commandSet.civAddress, 0xA4)

    // Verify VFO model
    XCTAssertEqual(commandSet.vfoModel, .currentOnly)

    // Verify NO mode filter
    XCTAssertFalse(commandSet.requiresModeFilter)

    // Verify echo behavior
    XCTAssertTrue(commandSet.echoesCommands)
}
```

### Step 7: Integration Testing

Create an integration test for hardware validation:

```swift
func testIC705RealHardware() async throws {
    guard let port = ProcessInfo.processInfo.environment["RIG_SERIAL_PORT"] else {
        throw XCTSkip("Set RIG_SERIAL_PORT=/dev/cu.IC705 to run")
    }

    let rig = RigController(
        radio: .icomIC705,
        connection: .serial(path: port, baudRate: nil)
    )

    try await rig.connect()

    // Test frequency setting
    try await rig.setFrequency(14_230_000, vfo: .a)
    let freq = try await rig.frequency(vfo: .a, cached: false)
    XCTAssertEqual(freq, 14_230_000, accuracy: 10)

    // Test mode setting (IC-705 uses NO filter byte!)
    try await rig.setMode(.usb, vfo: .a)
    let mode = try await rig.mode(vfo: .a, cached: false)
    XCTAssertEqual(mode, .usb)

    // Test power control (10W max)
    try await rig.setPower(5)
    let power = try await rig.power(cached: false)
    XCTAssertEqual(power, 5, accuracy: 1)

    await rig.disconnect()
}
```

Run with:
```bash
RIG_SERIAL_PORT=/dev/cu.IC705 swift test --filter testIC705RealHardware
```

### Step 8: Update Documentation

#### README.md

Add to the supported radios list:

```markdown
### Icom (CI-V Protocol) ✅

- **IC-9700** - VHF/UHF/1.2GHz all-mode transceiver (115200 baud, CI-V: 0xA2)
- **IC-705** - Portable HF/VHF/UHF transceiver (19200 baud, CI-V: 0xA4)  ← NEW
```

#### CHANGELOG.md

```markdown
## [1.X.X] - YYYY-MM-DD

### Added
- IC-705 portable HF/VHF/UHF transceiver support
```

#### ICOM_RADIO_ARCHITECTURES.md (Icom only)

Add to appropriate VFO model section:

```markdown
### 3. Current Only (.currentOnly)
**Operates on currently selected VFO, must switch before operations**

**Radios:**
- IC-7100 (HF/VHF/UHF, 100W, echoes commands, no filter byte)
- IC-705 (HF/VHF/UHF, 10W portable, echoes commands, no filter byte)  ← NEW
```

---

## Implementing a New Protocol

If your radio uses a protocol not yet in SwiftRigControl, you'll need to implement it.

### Step 1: Create Protocol Directory

```bash
mkdir -p Sources/RigControl/Protocols/YourManufacturer
```

Create two files:
- `YourProtocol.swift` - Protocol implementation
- `YourModels.swift` - Radio definitions

### Step 2: Implement CATProtocol

```swift
import Foundation

/// Your manufacturer's CAT protocol implementation.
public actor YourProtocol: CATProtocol {
    /// The serial transport for communication
    public let transport: any SerialTransport

    /// The capabilities of this radio
    public let capabilities: RigCapabilities

    /// Default timeout for radio responses
    private let responseTimeout: TimeInterval = 1.0

    /// Initializes a new protocol instance.
    public init(transport: any SerialTransport, capabilities: RigCapabilities) {
        self.transport = transport
        self.capabilities = capabilities
    }

    // MARK: - Connection

    public func connect() async throws {
        try await transport.open()
        try await transport.flush()
    }

    public func disconnect() async {
        await transport.close()
    }

    // MARK: - Frequency Control

    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws {
        // Build command
        let command = formatSetFrequencyCommand(hz, vfo: vfo)

        // Send command
        try await transport.write(Data(command.utf8))

        // Read response
        let response = try await readResponse()

        // Validate response
        guard isSuccessResponse(response) else {
            throw RigError.commandFailed("Radio rejected frequency")
        }
    }

    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        // Build query
        let query = formatGetFrequencyCommand(vfo: vfo)

        // Send query
        try await transport.write(Data(query.utf8))

        // Read response
        let response = try await readResponse()

        // Parse frequency from response
        return try parseFrequencyResponse(response)
    }

    // MARK: - Mode Control

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        let command = formatSetModeCommand(mode, vfo: vfo)
        try await transport.write(Data(command.utf8))

        let response = try await readResponse()
        guard isSuccessResponse(response) else {
            throw RigError.commandFailed("Radio rejected mode")
        }
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        let query = formatGetModeCommand(vfo: vfo)
        try await transport.write(Data(query.utf8))

        let response = try await readResponse()
        return try parseModeResponse(response)
    }

    // MARK: - PTT Control

    public func setPTT(_ enabled: Bool) async throws {
        let command = enabled ? "TX;" : "RX;"  // Example
        try await transport.write(Data(command.utf8))

        let response = try await readResponse()
        guard isSuccessResponse(response) else {
            throw RigError.commandFailed("Radio rejected PTT")
        }
    }

    public func getPTT() async throws -> Bool {
        try await transport.write(Data("TX;".utf8))
        let response = try await readResponse()
        return try parsePTTResponse(response)
    }

    // MARK: - VFO Control

    public func selectVFO(_ vfo: VFO) async throws {
        let command = formatSelectVFOCommand(vfo)
        try await transport.write(Data(command.utf8))

        let response = try await readResponse()
        guard isSuccessResponse(response) else {
            throw RigError.commandFailed("Radio rejected VFO selection")
        }
    }

    // MARK: - Split Operation

    public func setSplit(_ enabled: Bool) async throws {
        guard capabilities.hasSplit else {
            throw RigError.unsupportedOperation("Split not supported")
        }

        let command = formatSetSplitCommand(enabled)
        try await transport.write(Data(command.utf8))

        let response = try await readResponse()
        guard isSuccessResponse(response) else {
            throw RigError.commandFailed("Radio rejected split")
        }
    }

    public func getSplit() async throws -> Bool {
        guard capabilities.hasSplit else {
            throw RigError.unsupportedOperation("Split not supported")
        }

        try await transport.write(Data("FT;".utf8))  // Example
        let response = try await readResponse()
        return try parseSplitResponse(response)
    }

    // MARK: - Power Control

    public func setPower(_ value: Int) async throws {
        guard capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported")
        }

        let command = formatSetPowerCommand(value)
        try await transport.write(Data(command.utf8))

        let response = try await readResponse()
        guard isSuccessResponse(response) else {
            throw RigError.commandFailed("Radio rejected power setting")
        }
    }

    public func getPower() async throws -> Int {
        guard capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported")
        }

        try await transport.write(Data("PC;".utf8))  // Example
        let response = try await readResponse()
        return try parsePowerResponse(response)
    }

    // MARK: - Signal Strength

    public func getSignalStrength() async throws -> SignalStrength {
        try await transport.write(Data("SM0;".utf8))  // Example
        let response = try await readResponse()
        return try parseSignalStrengthResponse(response)
    }

    // MARK: - Private Helper Methods

    private func readResponse() async throws -> String {
        // Read until terminator (e.g., semicolon for text protocols)
        let data = try await transport.readUntil(
            terminator: UInt8(ascii: ";"),
            timeout: responseTimeout
        )

        guard let response = String(data: data, encoding: .ascii) else {
            throw RigError.invalidResponse
        }

        return response
    }

    private func isSuccessResponse(_ response: String) -> Bool {
        // Implement based on your protocol
        // Many text protocols echo the command as confirmation
        return !response.contains("?")  // Example: ? indicates error
    }

    // Implement command formatting methods
    private func formatSetFrequencyCommand(_ hz: UInt64, vfo: VFO) -> String {
        // Format based on your protocol
        // Example for Kenwood-style: "FA14230000;"
        return "FA\(String(format: "%011d", hz));"
    }

    private func formatGetFrequencyCommand(vfo: VFO) -> String {
        return "FA;"
    }

    private func parseFrequencyResponse(_ response: String) throws -> UInt64 {
        // Parse frequency from response
        // Example: "FA14230000;" -> 14230000
        let digits = response.filter { $0.isNumber }
        guard let freq = UInt64(digits) else {
            throw RigError.invalidResponse
        }
        return freq
    }

    // Implement remaining helper methods...
}
```

### Step 3: Create Radio Definitions

```swift
// In YourModels.swift
import Foundation

extension RadioDefinition {
    /// Your Manufacturer Model X
    public static let yourManufacturerModelX = RadioDefinition(
        manufacturer: .yourManufacturer,  // Add to RadioDefinition.Manufacturer enum
        model: "Model X",
        defaultBaudRate: 9600,
        capabilities: RadioCapabilitiesDatabase.yourManufacturerModelX,
        protocolFactory: { transport in
            YourProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.yourManufacturerModelX
            )
        }
    )
}
```

### Step 4: Comprehensive Testing

Create extensive unit tests with mock transport:

```swift
final class YourProtocolTests: XCTestCase {
    func testSetFrequency() async throws {
        let mock = MockTransport()
        let protocol = YourProtocol(transport: mock, capabilities: testCapabilities)

        // Configure mock responses
        mock.mockResponses = ["FA14230000;"]

        // Test command
        try await protocol.setFrequency(14_230_000, vfo: .a)

        // Verify sent command
        XCTAssertEqual(mock.recordedWrites.count, 1)
        XCTAssertTrue(mock.recordedWrites[0].contains("FA14230000"))
    }

    // Test all protocol methods...
}
```

### Step 5: Integration Testing

Test with real hardware extensively:

```bash
RIG_SERIAL_PORT=/dev/cu.YourRadio swift test --filter YourProtocolIntegrationTests
```

---

## Testing Your Radio

### Manual Testing Checklist

Test each capability with real hardware:

- [ ] Connect/disconnect
- [ ] Set frequency (multiple bands)
- [ ] Get frequency
- [ ] Set mode (all supported modes)
- [ ] Get mode
- [ ] PTT on/off
- [ ] Get PTT state
- [ ] Select VFO A/B (if applicable)
- [ ] Split operation (if supported)
- [ ] Power control (if supported)
- [ ] Signal strength reading

### Test with IcomInteractiveTest (Icom radios)

For Icom radios, use the comprehensive interactive test:

```bash
swift run IcomInteractiveTest
```

Select your radio and run through all test categories.

### Edge Cases to Test

- Minimum and maximum frequencies
- Invalid frequencies (outside range)
- All supported modes
- Rapid command sequences
- Connection recovery after disconnect
- Manual radio adjustments during operation

---

## Documentation Requirements

### Required Documentation Updates

1. **README.md**
   - Add to supported radios list
   - Add to specifications table

2. **CHANGELOG.md**
   - Add entry in "Added" section

3. **API_REFERENCE.md** (for new protocol only)
   - Document new protocol
   - Document radio definitions

4. **ICOM_RADIO_ARCHITECTURES.md** (Icom only)
   - Add to appropriate VFO model section
   - Document any special characteristics

5. **SERIAL_PORT_GUIDE.md** (if needed)
   - Add serial port configuration notes

---

## Pull Request Checklist

Before submitting your PR:

- [ ] Radio definition created
- [ ] Capabilities defined
- [ ] Command set configured (Icom)
- [ ] Unit tests added and passing
- [ ] Integration test with real hardware passes
- [ ] Documentation updated (README, CHANGELOG, etc.)
- [ ] Code follows style guidelines
- [ ] All existing tests still pass
- [ ] XPC server updated (if applicable)
- [ ] No compiler warnings

### PR Description Template

```markdown
## Description
Add support for [Manufacturer] [Model]

## Radio Specifications
- **Manufacturer**: [Manufacturer]
- **Model**: [Model]
- **Protocol**: [CI-V/Elecraft/Yaesu/Kenwood/New]
- **Baud Rate**: [Rate]
- **Frequency Range**: [Min - Max]
- **Max Power**: [Watts]
- **Special Features**: [Dual RX, ATU, etc.]

## Testing
- [x] Unit tests added
- [x] All existing tests pass
- [x] Tested with real hardware
- [x] Integration test passes

## Checklist
- [x] Code follows style guidelines
- [x] Documentation updated
- [x] CHANGELOG.md updated
- [x] No breaking changes

## Hardware Test Results
```
[Paste output from integration test or manual testing]
```
```

---

## Reference Resources

### Official Documentation
- **Icom**: CI-V Reference Manual for your model
- **Elecraft**: K3 Programmer's Reference
- **Yaesu**: CAT Operation Reference Manual
- **Kenwood**: PC Control Command Reference

### Hamlib Source Code
Excellent reference for protocol details:
- https://github.com/Hamlib/Hamlib
- Look in `rigs/<manufacturer>/<model>.c`

### SwiftRigControl Reference Implementations
Study similar radios:
- **Icom**: See `IcomModels.swift` for examples
- **Elecraft**: See `ElecraftModels.swift`
- **Yaesu**: See `YaesuModels.swift`
- **Kenwood**: See `KenwoodModels.swift`

### Community Resources
- SwiftRigControl GitHub Discussions
- Amateur Radio Stack Exchange
- Manufacturer-specific forums

---

## Getting Help

If you encounter issues:

1. **Check Existing Issues**: https://github.com/jjones9527/SwiftRigControl/issues
2. **Ask in Discussions**: https://github.com/jjones9527/SwiftRigControl/discussions
3. **Email**: va3ztf@gmail.com

Include:
- Radio model and firmware version
- macOS version and Swift version
- What you've tried
- Serial port output/logs if available
- Link to radio's CAT command reference

---

## Examples of Recent Additions

See these commits for examples:

- IC-705 addition: [commit hash]
- IC-7600 echo handling: [commit hash]
- Kenwood TH-D74 addition: [commit hash]

---

**Thank you for contributing to SwiftRigControl!**

**73 de VA3ZTF**
