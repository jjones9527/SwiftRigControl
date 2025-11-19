# SwiftRigControl Usage Examples

This document provides comprehensive examples for common amateur radio control scenarios using SwiftRigControl.

## Table of Contents

1. [Basic Operations](#basic-operations)
2. [Digital Mode Applications](#digital-mode-applications)
3. [Split Operation](#split-operation)
4. [Power Control](#power-control)
5. [Multi-VFO Operations](#multi-vfo-operations)
6. [Error Handling Patterns](#error-handling-patterns)
7. [Mac App Store Apps (XPC)](#mac-app-store-apps-xpc)
8. [SwiftUI Integration](#swiftui-integration)
9. [Logging and Monitoring](#logging-and-monitoring)

## Basic Operations

### Simple Frequency and Mode Control

```swift
import RigControl

func basicExample() async throws {
    // Create controller for IC-9700
    let rig = RigController(
        radio: .icomIC9700,
        connection: .serial(path: "/dev/cu.IC9700", baudRate: nil)  // nil uses default
    )

    // Connect to radio
    try await rig.connect()

    // Set up for 20m USB
    try await rig.setFrequency(14_230_000, vfo: .a)  // 14.230 MHz
    try await rig.setMode(.usb, vfo: .a)

    // Read current settings
    let freq = try await rig.frequency()
    let mode = try await rig.mode()
    print("Radio is on \(Double(freq) / 1_000_000) MHz, mode: \(mode)")

    // Clean up
    await rig.disconnect()
}
```

### Working with Different Manufacturers

```swift
// Icom IC-7300
let icom = RigController(
    radio: .icomIC7300,
    connection: .serial(path: "/dev/cu.SLAB_USBtoUART", baudRate: 115200)
)

// Yaesu FTDX-10
let yaesu = RigController(
    radio: .yaesuFTDX10,
    connection: .serial(path: "/dev/cu.usbserial-FTDX10", baudRate: 38400)
)

// Kenwood TS-890S
let kenwood = RigController(
    radio: .kenwoodTS890S,
    connection: .serial(path: "/dev/cu.usbserial-TS890", baudRate: 115200)
)

// Elecraft K3
let elecraft = RigController(
    radio: .elecraftK3,
    connection: .serial(path: "/dev/cu.usbserial-K3", baudRate: 38400)
)

// All radios use identical API!
try await icom.setFrequency(14_230_000, vfo: .a)
try await yaesu.setFrequency(14_230_000, vfo: .a)
try await kenwood.setFrequency(14_230_000, vfo: .a)
try await elecraft.setFrequency(14_230_000, vfo: .a)
```

## Digital Mode Applications

### SSTV (Slow Scan Television)

```swift
import RigControl
import AVFoundation

class SSTVController {
    let rig: RigController

    init(radio: RadioDefinition, port: String) {
        self.rig = RigController(
            radio: radio,
            connection: .serial(path: port, baudRate: nil)
        )
    }

    func transmitSSTVImage() async throws {
        // Connect to radio
        try await rig.connect()

        // Set up for SSTV on 20m
        try await rig.setFrequency(14_230_000, vfo: .a)  // 20m SSTV calling frequency
        try await rig.setMode(.usb, vfo: .a)              // USB for digital modes

        // Reduce power for digital mode (optional)
        if rig.capabilities.powerControl {
            try await rig.setPower(25)  // 25 watts
        }

        // Enable PTT
        try await rig.setPTT(true)

        // Wait for TX to stabilize
        try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

        // Transmit SSTV audio here
        // ... (your SSTV encoding code) ...

        // Disable PTT
        try await rig.setPTT(false)

        print("SSTV transmission complete")
    }
}
```

### FT8 / FT4 (WSJT-X style)

```swift
class FT8Controller {
    let rig: RigController

    func setupForFT8(band: Band) async throws {
        try await rig.connect()

        // Set up frequency based on band
        let frequency: UInt64
        switch band {
        case .m20: frequency = 14_074_000  // 20m FT8
        case .m40: frequency = 7_074_000   // 40m FT8
        case .m80: frequency = 3_573_000   // 80m FT8
        case .m15: frequency = 21_074_000  // 15m FT8
        default: frequency = 14_074_000
        }

        try await rig.setFrequency(frequency, vfo: .a)
        try await rig.setMode(.dataUSB, vfo: .a)  // Use DATA mode if available

        // Set appropriate power (FT8 typically uses 5-25W)
        if rig.capabilities.powerControl {
            try await rig.setPower(10)
        }
    }

    func transmitFT8Cycle() async throws {
        // Enable PTT at start of 15-second cycle
        try await rig.setPTT(true)

        // Transmit audio
        // ... (your FT8 encoding) ...

        // Wait for cycle to complete (13 seconds of audio + margin)
        try await Task.sleep(nanoseconds: 13_500_000_000)

        // Disable PTT
        try await rig.setPTT(false)
    }
}

enum Band {
    case m160, m80, m60, m40, m30, m20, m17, m15, m12, m10, m6
}
```

### PSK31

```swift
func setupForPSK31() async throws {
    try await rig.connect()

    // PSK31 on 20m
    try await rig.setFrequency(14_070_000, vfo: .a)  // 20m PSK calling frequency
    try await rig.setMode(.usb, vfo: .a)

    // Low power for PSK31 (5-10W typical)
    if rig.capabilities.powerControl {
        try await rig.setPower(10)
    }
}

func transmitPSKMessage(_ message: String) async throws {
    try await rig.setPTT(true)

    // Generate PSK31 audio from message
    // ... (your PSK31 encoder) ...

    try await rig.setPTT(false)
}
```

## Split Operation

### DX Pileup Management

```swift
func setupForDXSplit() async throws {
    guard rig.capabilities.hasSplit else {
        throw RigError.unsupportedOperation("Radio doesn't support split operation")
    }

    try await rig.connect()

    // Set RX frequency (where DX is transmitting)
    try await rig.setFrequency(14_195_000, vfo: .a)
    try await rig.setMode(.usb, vfo: .a)

    // Set TX frequency (where DX is listening)
    try await rig.setFrequency(14_225_000, vfo: .b)  // Listening up 30 kHz
    try await rig.setMode(.usb, vfo: .b)

    // Enable split operation
    try await rig.setSplit(true)

    print("Split operation enabled:")
    print("  RX: 14.195 MHz (VFO A)")
    print("  TX: 14.225 MHz (VFO B)")
}

func disableSplit() async throws {
    try await rig.setSplit(false)
    print("Split operation disabled")
}
```

### Satellite Operations

```swift
class SatelliteController {
    let rig: RigController

    func trackSatellite(uplinkFreq: UInt64, downlinkFreq: UInt64) async throws {
        try await rig.connect()

        // Use dual receiver radios for full duplex
        if rig.capabilities.hasDualReceiver {
            // Main receiver on downlink
            try await rig.setFrequency(downlinkFreq, vfo: .main)
            try await rig.setMode(.fm, vfo: .main)

            // Sub receiver on uplink (monitoring your own signal)
            try await rig.setFrequency(uplinkFreq, vfo: .sub)
            try await rig.setMode(.fm, vfo: .sub)
        } else {
            // Single receiver - use split
            try await rig.setFrequency(downlinkFreq, vfo: .a)  // RX
            try await rig.setFrequency(uplinkFreq, vfo: .b)     // TX
            try await rig.setSplit(true)
        }
    }

    func updateDopplerShift(rxShift: Int64, txShift: Int64) async throws {
        let currentRX = try await rig.frequency(vfo: .main)
        let currentTX = try await rig.frequency(vfo: .sub)

        // Apply Doppler correction
        let newRX = UInt64(Int64(currentRX) + rxShift)
        let newTX = UInt64(Int64(currentTX) + txShift)

        try await rig.setFrequency(newRX, vfo: .main)
        try await rig.setFrequency(newTX, vfo: .sub)
    }
}
```

## Power Control

### Adaptive Power Control

```swift
class AdaptivePowerController {
    let rig: RigController

    func setOptimalPower(distance: Double, mode: Mode) async throws {
        guard rig.capabilities.powerControl else {
            print("Radio doesn't support power control")
            return
        }

        // Calculate power based on distance and mode
        let basePower: Int
        switch mode {
        case .cw, .rtty, .dataUSB, .dataLSB:
            // Digital modes - lower power
            basePower = 25
        case .ssb, .usb, .lsb:
            // Voice modes - moderate power
            basePower = 50
        case .am:
            // AM - higher power due to lower efficiency
            basePower = 75
        default:
            basePower = 50
        }

        // Adjust for distance (simple example)
        let adjustedPower: Int
        if distance < 500 {  // km
            adjustedPower = basePower / 2
        } else if distance < 2000 {
            adjustedPower = basePower
        } else {
            adjustedPower = min(basePower * 2, rig.capabilities.maxPower)
        }

        try await rig.setPower(adjustedPower)
        print("Power set to \(adjustedPower)W for \(Int(distance))km contact")
    }
}
```

### QRP Operations

```swift
func setupForQRP() async throws {
    // QRP = low power operations (typically 5W or less)
    try await rig.connect()

    try await rig.setFrequency(7_030_000, vfo: .a)  // 40m CW QRP frequency
    try await rig.setMode(.cw, vfo: .a)

    if rig.capabilities.powerControl {
        try await rig.setPower(5)  // 5 watts QRP
        let actualPower = try await rig.power()
        print("QRP power set to \(actualPower)W")
    }
}
```

## Multi-VFO Operations

### VFO Scanning

```swift
func scanFrequencies(start: UInt64, end: UInt64, step: UInt64) async throws {
    try await rig.connect()

    var currentFreq = start
    while currentFreq <= end {
        try await rig.setFrequency(currentFreq, vfo: .a)

        // Wait and check for activity
        try await Task.sleep(nanoseconds: 500_000_000)  // 500ms

        // In a real app, you'd check S-meter or audio level here
        print("Scanning: \(Double(currentFreq) / 1_000_000) MHz")

        currentFreq += step
    }
}

// Example: Scan 20m band in 5 kHz steps
try await scanFrequencies(
    start: 14_000_000,    // 14.000 MHz
    end: 14_350_000,      // 14.350 MHz
    step: 5_000           // 5 kHz
)
```

### A/B VFO Comparison

```swift
func compareFrequencies(freqA: UInt64, freqB: UInt64) async throws {
    try await rig.connect()

    // Set up both VFOs
    try await rig.setFrequency(freqA, vfo: .a)
    try await rig.setMode(.usb, vfo: .a)

    try await rig.setFrequency(freqB, vfo: .b)
    try await rig.setMode(.usb, vfo: .b)

    // Switch between them
    for _ in 0..<5 {
        print("Listening on VFO A: \(Double(freqA) / 1_000_000) MHz")
        try await rig.selectVFO(.a)
        try await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds

        print("Listening on VFO B: \(Double(freqB) / 1_000_000) MHz")
        try await rig.selectVFO(.b)
        try await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds
    }
}
```

## Error Handling Patterns

### Comprehensive Error Handling

```swift
func robustRadioControl() async {
    let rig = RigController(
        radio: .icomIC7300,
        connection: .serial(path: "/dev/cu.IC7300", baudRate: nil)
    )

    do {
        try await rig.connect()

        // Verify connection
        guard rig.isConnected else {
            print("Failed to connect to radio")
            return
        }

        try await rig.setFrequency(14_230_000, vfo: .a)
        try await rig.setMode(.usb, vfo: .a)

    } catch RigError.notConnected {
        print("❌ Radio is not connected")
        print("   Check that the radio is powered on and USB cable is connected")

    } catch RigError.timeout {
        print("❌ Radio did not respond")
        print("   Possible causes:")
        print("   - Wrong serial port")
        print("   - Incorrect baud rate")
        print("   - Radio CI-V/CAT settings incorrect")
        print("   - Cable issue")

    } catch RigError.commandFailed(let reason) {
        print("❌ Command failed: \(reason)")
        print("   The radio rejected the command")

    } catch RigError.unsupportedOperation(let message) {
        print("❌ Operation not supported: \(message)")

    } catch RigError.invalidParameter(let message) {
        print("❌ Invalid parameter: \(message)")

    } catch RigError.invalidResponse {
        print("❌ Invalid response from radio")
        print("   The radio sent an unexpected response")
        print("   This may indicate a protocol mismatch or firmware issue")

    } catch {
        print("❌ Unexpected error: \(error)")
    }

    await rig.disconnect()
}
```

### Retry Logic

```swift
func setFrequencyWithRetry(
    _ frequency: UInt64,
    maxRetries: Int = 3
) async throws {
    var lastError: Error?

    for attempt in 1...maxRetries {
        do {
            try await rig.setFrequency(frequency, vfo: .a)
            print("✅ Frequency set successfully")
            return
        } catch RigError.timeout {
            print("⚠️  Attempt \(attempt)/\(maxRetries) timed out")
            lastError = RigError.timeout

            if attempt < maxRetries {
                // Exponential backoff
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 100_000_000))
            }
        } catch {
            // Don't retry other errors
            throw error
        }
    }

    throw lastError ?? RigError.timeout
}
```

### Connection Health Monitoring

```swift
actor RadioHealthMonitor {
    let rig: RigController
    var isHealthy = false

    func startMonitoring() async {
        while true {
            do {
                // Test basic communication
                _ = try await rig.frequency()

                if !isHealthy {
                    print("✅ Radio connection restored")
                    isHealthy = true
                }

            } catch {
                if isHealthy {
                    print("⚠️  Radio connection lost: \(error)")
                    isHealthy = false
                }
            }

            // Check every 5 seconds
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }
}
```

## Mac App Store Apps (XPC)

### Basic XPC Client Usage

```swift
import RigControlXPC

class MyRadioApp {
    let xpcClient = XPCClient.shared

    func setupRadio() async throws {
        // Connect to XPC helper
        try await xpcClient.connect()

        // Connect to radio through helper
        try await xpcClient.connectToRadio(
            radio: "IC-9700",
            port: "/dev/cu.IC9700",
            baudRate: nil
        )

        // Use same API as RigControl
        try await xpcClient.setFrequency(14_230_000, vfo: .a)
        try await xpcClient.setMode(.usb, vfo: .a)

        print("Radio configured via XPC helper")
    }

    func cleanup() async {
        await xpcClient.disconnectRadio()
        await xpcClient.disconnect()
    }
}
```

### XPC with SwiftUI

```swift
import SwiftUI
import RigControlXPC

@main
struct RadioControlApp: App {
    var body: some Scene {
        WindowGroup {
            RadioControlView()
        }
    }
}

struct RadioControlView: View {
    @StateObject private var controller = RadioController()

    var body: some View {
        VStack(spacing: 20) {
            Text("Radio Control")
                .font(.title)

            if controller.isConnected {
                Text("Connected to \(controller.radioModel)")
                    .foregroundColor(.green)

                FrequencyControl(controller: controller)
                ModeSelector(controller: controller)
                PTTButton(controller: controller)

                Button("Disconnect") {
                    Task {
                        await controller.disconnect()
                    }
                }
            } else {
                ConnectionView(controller: controller)
            }
        }
        .padding()
        .task {
            await controller.initialize()
        }
    }
}

@MainActor
class RadioController: ObservableObject {
    @Published var isConnected = false
    @Published var radioModel = ""
    @Published var frequency: UInt64 = 14_230_000
    @Published var mode: String = "USB"

    private let xpcClient = XPCClient.shared

    func initialize() async {
        do {
            try await xpcClient.connect()
        } catch {
            print("Failed to connect to XPC helper: \(error)")
        }
    }

    func connectToRadio(model: String, port: String) async {
        do {
            try await xpcClient.connectToRadio(radio: model, port: port)
            isConnected = true
            radioModel = model
        } catch {
            print("Failed to connect to radio: \(error)")
        }
    }

    func setFrequency(_ freq: UInt64) async {
        do {
            try await xpcClient.setFrequency(freq, vfo: .a)
            frequency = freq
        } catch {
            print("Failed to set frequency: \(error)")
        }
    }

    func disconnect() async {
        await xpcClient.disconnectRadio()
        isConnected = false
    }
}
```

## SwiftUI Integration

### Complete Radio Control Panel

```swift
struct RadioControlPanel: View {
    @StateObject private var radio = RadioViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // Frequency Display
            HStack {
                Text("Frequency:")
                TextField("Frequency", value: $radio.frequency, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                Text("Hz")

                Button("Set") {
                    Task {
                        await radio.updateFrequency()
                    }
                }
            }

            // Mode Selector
            Picker("Mode", selection: $radio.selectedMode) {
                Text("LSB").tag("LSB")
                Text("USB").tag("USB")
                Text("CW").tag("CW")
                Text("FM").tag("FM")
                Text("AM").tag("AM")
            }
            .pickerStyle(.segmented)
            .onChange(of: radio.selectedMode) { _ in
                Task {
                    await radio.updateMode()
                }
            }

            // PTT Button
            Button(action: { Task { await radio.togglePTT() }}) {
                Text(radio.isTransmitting ? "TRANSMITTING" : "RECEIVE")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(radio.isTransmitting ? Color.red : Color.green)
                    .cornerRadius(10)
            }

            // Power Control
            if radio.supportsPowerControl {
                HStack {
                    Text("Power: \(radio.powerLevel)W")
                    Slider(value: $radio.powerLevelDouble, in: 0...Double(radio.maxPower))
                        .onChange(of: radio.powerLevelDouble) { _ in
                            Task {
                                await radio.updatePower()
                            }
                        }
                }
            }
        }
        .padding()
    }
}

@MainActor
class RadioViewModel: ObservableObject {
    @Published var frequency: UInt64 = 14_230_000
    @Published var selectedMode = "USB"
    @Published var isTransmitting = false
    @Published var powerLevel = 50
    @Published var powerLevelDouble: Double = 50.0
    @Published var supportsPowerControl = true
    @Published var maxPower = 100

    private var rig: RigController?

    func initialize(radio: RadioDefinition, port: String) async {
        rig = RigController(radio: radio, connection: .serial(path: port, baudRate: nil))

        do {
            try await rig?.connect()
            supportsPowerControl = rig?.capabilities.powerControl ?? false
            maxPower = rig?.capabilities.maxPower ?? 100
        } catch {
            print("Failed to initialize: \(error)")
        }
    }

    func updateFrequency() async {
        do {
            try await rig?.setFrequency(frequency, vfo: .a)
        } catch {
            print("Failed to set frequency: \(error)")
        }
    }

    func updateMode() async {
        guard let mode = Mode(rawValue: selectedMode) else { return }
        do {
            try await rig?.setMode(mode, vfo: .a)
        } catch {
            print("Failed to set mode: \(error)")
        }
    }

    func togglePTT() async {
        do {
            try await rig?.setPTT(!isTransmitting)
            isTransmitting.toggle()
        } catch {
            print("Failed to toggle PTT: \(error)")
        }
    }

    func updatePower() async {
        powerLevel = Int(powerLevelDouble)
        do {
            try await rig?.setPower(powerLevel)
        } catch {
            print("Failed to set power: \(error)")
        }
    }
}
```

## Logging and Monitoring

### Command Logging

```swift
class LoggingRigController {
    let rig: RigController
    private let logger: Logger

    init(radio: RadioDefinition, port: String) {
        self.rig = RigController(
            radio: radio,
            connection: .serial(path: port, baudRate: nil)
        )
        self.logger = Logger(subsystem: "com.example.radioapp", category: "RigControl")
    }

    func setFrequency(_ freq: UInt64, vfo: VFO = .a) async throws {
        logger.info("Setting frequency to \(freq) Hz on VFO \(vfo.rawValue)")

        let start = Date()
        do {
            try await rig.setFrequency(freq, vfo: vfo)
            let duration = Date().timeIntervalSince(start)
            logger.info("✅ Frequency set successfully in \(duration, format: .fixed(precision: 3))s")
        } catch {
            logger.error("❌ Failed to set frequency: \(error.localizedDescription)")
            throw error
        }
    }

    func logRadioCapabilities() {
        let caps = rig.capabilities
        logger.info("""
            Radio Capabilities:
              Model: \(rig.radioName)
              VFO B: \(caps.hasVFOB)
              Split: \(caps.hasSplit)
              Power Control: \(caps.powerControl)
              Max Power: \(caps.maxPower)W
              Dual Receiver: \(caps.hasDualReceiver)
              ATU: \(caps.hasATU)
              Modes: \(caps.supportedModes.map { $0.rawValue }.joined(separator: ", "))
            """)
    }
}
```

### Performance Monitoring

```swift
actor PerformanceMonitor {
    private var commandTimes: [String: [TimeInterval]] = [:]

    func measureCommand<T>(_ name: String, operation: () async throws -> T) async rethrows -> T {
        let start = Date()
        let result = try await operation()
        let duration = Date().timeIntervalSince(start)

        commandTimes[name, default: []].append(duration)

        // Print statistics every 10 commands
        if let times = commandTimes[name], times.count % 10 == 0 {
            let avg = times.reduce(0, +) / Double(times.count)
            let max = times.max() ?? 0
            let min = times.min() ?? 0
            print("\(name) stats: avg=\(Int(avg*1000))ms, min=\(Int(min*1000))ms, max=\(Int(max*1000))ms")
        }

        return result
    }
}

// Usage
let monitor = PerformanceMonitor()
await monitor.measureCommand("setFrequency") {
    try await rig.setFrequency(14_230_000, vfo: .a)
}
```

---

## Additional Resources

- [API Documentation](API_DOCUMENTATION.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Serial Port Configuration](SERIAL_PORT_GUIDE.md)
- [XPC Helper Guide](XPC_HELPER_GUIDE.md)

## Contributing Examples

Have a useful example? Please contribute! See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

**73 de VA3ZTF**
