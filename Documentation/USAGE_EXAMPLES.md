# SwiftRigControl Usage Examples

This document provides comprehensive examples for common amateur radio control scenarios using SwiftRigControl.

## Table of Contents

1. [Basic Operations](#basic-operations)
2. [Digital Mode Applications](#digital-mode-applications)
3. [Split Operation](#split-operation)
4. [RIT/XIT Operations](#ritxit-operations-v110) (v1.1.0)
5. [Power Control](#power-control)
6. [Multi-VFO Operations](#multi-vfo-operations)
7. [Error Handling Patterns](#error-handling-patterns)
8. [Mac App Store Apps (XPC)](#mac-app-store-apps-xpc)
9. [SwiftUI Integration](#swiftui-integration)
10. [Logging and Monitoring](#logging-and-monitoring)

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

## RIT/XIT Operations (v1.1.0)

RIT (Receiver Incremental Tuning) and XIT (Transmitter Incremental Tuning) allow fine-tuning of receive and transmit frequencies independently from the displayed VFO frequency.

### CW Zero-Beating

```swift
import RigControl

class CWController {
    let rig: RigController

    /// Adjust RIT to zero-beat a CW signal
    func zeroBeatSignal(offsetHz: Int) async throws {
        // Check if radio supports RIT
        guard rig.capabilities.supportsRIT else {
            print("Radio doesn't support RIT")
            return
        }

        // Validate offset range
        guard abs(offsetHz) <= 9999 else {
            throw RigError.invalidParameter("Offset must be ±9999 Hz")
        }

        // Enable RIT with the measured offset
        try await rig.setRIT(RITXITState(enabled: true, offset: offsetHz))
        print("RIT enabled with \(offsetHz) Hz offset")
    }

    /// Clear RIT after QSO
    func clearRIT() async throws {
        try await rig.setRIT(.disabled)
        print("RIT disabled")
    }

    /// Incremental RIT adjustment
    func adjustRIT(by deltaHz: Int) async throws {
        let current = try await rig.getRIT()
        let newOffset = current.offset + deltaHz

        guard abs(newOffset) <= 9999 else {
            print("Offset limit reached")
            return
        }

        try await rig.setRIT(RITXITState(enabled: true, offset: newOffset))
        print("RIT adjusted to \(newOffset) Hz")
    }
}

// Usage
let cw = CWController(rig: rig)

// Zero-beat a signal that's 450 Hz high
try await cw.zeroBeatSignal(offsetHz: 450)

// Fine-tune by ear
try await cw.adjustRIT(by: 50)   // +50 Hz
try await cw.adjustRIT(by: -20)  // -20 Hz

// Clear when done
try await cw.clearRIT()
```

### Contest Split Operation

```swift
import RigControl

class ContestSplitController {
    let rig: RigController

    /// Set up split operation with XIT for pileup
    func setupPileupSplit(listenFreq: UInt64, txOffset: Int) async throws {
        // Set main VFO to listening frequency
        try await rig.setFrequency(listenFreq, vfo: .a)
        try await rig.setMode(.ssb, vfo: .a)

        // Enable split operation
        try await rig.enableSplit(true)

        // Use XIT to shift transmit frequency (if supported)
        if rig.capabilities.supportsXIT {
            try await rig.setXIT(RITXITState(enabled: true, offset: txOffset))
            print("Split enabled: RX=\(listenFreq), TX offset=\(txOffset) Hz")
        } else {
            // Fall back to VFO B for split if XIT not supported
            let txFreq = UInt64(Int64(listenFreq) + Int64(txOffset))
            try await rig.setFrequency(txFreq, vfo: .b)
            print("Split enabled: RX=\(listenFreq), TX=\(txFreq)")
        }
    }

    /// DX pileup scanner - listen around calling frequency
    func scanPileup(centerFreq: UInt64, range: Int = 5000) async throws {
        print("Scanning ±\(range) Hz around \(centerFreq)")

        // Enable RIT for scanning
        try await rig.setRIT(RITXITState(enabled: true, offset: -range))

        // Scan from low to high
        for offset in stride(from: -range, through: range, by: 100) {
            try await rig.setRIT(RITXITState(enabled: true, offset: offset))

            // Check signal strength
            let signal = try await rig.signalStrength()
            if signal.isStrongSignal {
                print("Strong signal at \(offset) Hz: \(signal.description)")
            }

            try await Task.sleep(nanoseconds: 100_000_000) // 100ms per step
        }

        // Disable RIT when done
        try await rig.setRIT(.disabled)
    }
}

// Usage for contest pileup
let contest = ContestSplitController(rig: rig)

// Listen on 14.195, transmit 2 kHz up
try await contest.setupPileupSplit(
    listenFreq: 14_195_000,
    txOffset: 2000
)

// Scan for stations
try await contest.scanPileup(centerFreq: 14_195_000, range: 3000)
```

### Fine-Tuning for Data Modes

```swift
import RigControl

class DataModeController {
    let rig: RigController

    /// Fine-tune frequency for FT8/FT4 decode
    func optimizeForDecoding() async throws {
        // Read current RIT state
        let ritState = try await rig.getRIT()
        print("Current RIT: \(ritState.description)")

        // Most FT8/FT4 stations are within ±100 Hz of frequency
        // Adjust RIT to maximize decodes
        let testOffsets = [-50, 0, 50]

        for offset in testOffsets {
            try await rig.setRIT(RITXITState(enabled: true, offset: offset))
            print("Testing offset: \(offset) Hz")

            // Let decoder run for one cycle (15 seconds for FT8)
            try await Task.sleep(nanoseconds: 15_000_000_000)

            // Your app would count decodes here
            // Pick the offset with best results
        }
    }

    /// Automatic frequency calibration
    func calibrateWithWWV(wwvFreq: UInt64 = 10_000_000) async throws {
        print("Calibrating with WWV on \(wwvFreq) Hz")

        try await rig.setFrequency(wwvFreq, vfo: .a)
        try await rig.setMode(.am, vfo: .a)

        // Measure apparent offset by zero-beating the tone
        // (your app would use audio analysis here)
        let measuredOffset = -23  // Example: 23 Hz low

        // Apply correction with RIT
        try await rig.setRIT(RITXITState(enabled: true, offset: measuredOffset))
        print("Calibration offset applied: \(measuredOffset) Hz")
    }
}
```

### Checking RIT/XIT Support

```swift
import RigControl

func checkRITXITSupport(for radio: RigController) async {
    let caps = radio.capabilities

    if caps.supportsRIT {
        print("✓ Radio supports RIT")

        // Try to read current RIT state
        do {
            let ritState = try await radio.getRIT()
            print("  Current RIT: \(ritState.description)")
        } catch {
            print("  Error reading RIT: \(error)")
        }
    } else {
        print("✗ Radio does not support RIT")
    }

    if caps.supportsXIT {
        print("✓ Radio supports XIT")

        do {
            let xitState = try await radio.getXIT()
            print("  Current XIT: \(xitState.description)")
        } catch {
            print("  Error reading XIT: \(error)")
        }
    } else {
        print("✗ Radio does not support XIT (may use RIT for both RX/TX)")
    }
}

// Check capabilities
try await checkRITXITSupport(for: rig)
```

## Memory Channel Operations (v1.2.0)

Memory channels allow you to store complete radio configurations for quick recall. SwiftRigControl provides a universal memory channel model that works across all radio manufacturers.

### Basic Memory Channel Management

```swift
import RigControl

class MemoryChannelManager {
    let rig: RigController

    init(rig: RigController) {
        self.rig = rig
    }

    /// Store current configuration to a memory channel
    func storeCurrentFrequency(to channelNumber: Int, name: String) async throws {
        // Get current settings
        let freq = try await rig.frequency(vfo: .a, cached: false)
        let mode = try await rig.mode(vfo: .a, cached: false)

        // Create memory channel
        let channel = MemoryChannel(
            number: channelNumber,
            frequency: freq,
            mode: mode,
            name: name
        )

        // Store to radio
        try await rig.setMemoryChannel(channel)
        print("Stored channel \(channelNumber): \(name) at \(Double(freq)/1_000_000) MHz")
    }

    /// Recall a memory channel
    func recall(channelNumber: Int) async throws {
        let channel = try await rig.getMemoryChannel(channelNumber)
        print("Recalling: \(channel.description)")

        // Apply to current VFO
        try await rig.recallMemoryChannel(channelNumber)
        print("Now operating on \(Double(channel.frequency)/1_000_000) MHz \(channel.mode)")
    }

    /// List all populated memory channels
    func listChannels() async throws {
        let count = try await rig.memoryChannelCount()
        print("Radio has \(count) memory channels\n")

        var populated = 0
        for i in 0..<count {
            do {
                let channel = try await rig.getMemoryChannel(i)
                print("[\(i)] \(channel.description)")
                populated += 1
            } catch {
                // Channel is empty, skip
                continue
            }
        }

        print("\nTotal populated: \(populated)/\(count)")
    }
}
```

### Contest Memory Bank Setup

Set up memory channels for a contest with commonly used frequencies:

```swift
import RigControl

class ContestMemorySetup {
    let rig: RigController

    func setupCQWWContestMemories() async throws {
        print("Setting up CQ WW Contest memory banks...")

        let contestChannels = [
            // 160m
            MemoryChannel(number: 1, frequency: 1_830_000, mode: .cw, name: "160m CW"),
            MemoryChannel(number: 2, frequency: 1_850_000, mode: .lsb, name: "160m SSB"),

            // 80m
            MemoryChannel(number: 10, frequency: 3_530_000, mode: .cw, name: "80m CW"),
            MemoryChannel(number: 11, frequency: 3_790_000, mode: .lsb, name: "80m SSB"),

            // 40m
            MemoryChannel(number: 20, frequency: 7_030_000, mode: .cw, name: "40m CW"),
            MemoryChannel(number: 21, frequency: 7_190_000, mode: .lsb, name: "40m SSB"),

            // 20m
            MemoryChannel(number: 30, frequency: 14_030_000, mode: .cw, name: "20m CW"),
            MemoryChannel(number: 31, frequency: 14_200_000, mode: .usb, name: "20m SSB"),

            // 15m
            MemoryChannel(number: 40, frequency: 21_030_000, mode: .cw, name: "15m CW"),
            MemoryChannel(number: 41, frequency: 21_300_000, mode: .usb, name: "15m SSB"),

            // 10m
            MemoryChannel(number: 50, frequency: 28_030_000, mode: .cw, name: "10m CW"),
            MemoryChannel(number: 51, frequency: 28_400_000, mode: .usb, name: "10m SSB")
        ]

        for channel in contestChannels {
            try await rig.setMemoryChannel(channel)
            print("✓ Stored: \(channel.description)")
        }

        print("\nContest memories ready!")
    }

    /// Quick band change during contest
    func switchToBand(_ band: String, mode: Mode) async throws {
        let channelMap: [String: Int] = [
            "160CW": 1, "160SSB": 2,
            "80CW": 10, "80SSB": 11,
            "40CW": 20, "40SSB": 21,
            "20CW": 30, "20SSB": 31,
            "15CW": 40, "15SSB": 41,
            "10CW": 50, "10SSB": 51
        ]

        let key = band + (mode == .cw ? "CW" : "SSB")
        guard let channelNum = channelMap[key] else {
            throw RigError.invalidParameter("Unknown band/mode combination")
        }

        try await rig.recallMemoryChannel(channelNum)
        print("Switched to \(band) \(mode)")
    }
}

// Usage
let setup = ContestMemorySetup(rig: rig)
try await setup.setupCQWWContestMemories()

// Quick band change during contest
try await setup.switchToBand("20", mode: .usb)
```

### VHF/UHF Repeater Memory Manager

Create and manage repeater channels with CTCSS tones and offsets:

```swift
import RigControl

struct RepeaterInfo {
    let name: String
    let rxFrequency: UInt64
    let offset: Int  // Hz (positive for +, negative for -)
    let tone: Double?  // CTCSS tone in Hz
    let mode: Mode
}

class RepeaterMemoryManager {
    let rig: RigController

    /// Program common repeaters into memory
    func programRepeaters() async throws {
        let repeaters = [
            // 2m repeaters
            RepeaterInfo(
                name: "W1AW/R",
                rxFrequency: 146_880_000,  // 146.880 MHz
                offset: -600_000,          // -600 kHz standard 2m offset
                tone: 100.0,               // 100 Hz CTCSS
                mode: .fm
            ),
            RepeaterInfo(
                name: "2m Call",
                rxFrequency: 146_520_000,  // 146.520 MHz simplex
                offset: 0,
                tone: nil,
                mode: .fm
            ),

            // 70cm repeaters
            RepeaterInfo(
                name: "Local 70",
                rxFrequency: 442_100_000,  // 442.100 MHz
                offset: 5_000_000,         // +5 MHz standard 70cm offset
                tone: 127.3,               // 127.3 Hz CTCSS
                mode: .fm
            ),
            RepeaterInfo(
                name: "70cm Call",
                rxFrequency: 446_000_000,  // 446.000 MHz simplex
                offset: 0,
                tone: nil,
                mode: .fm
            )
        ]

        for (index, repeater) in repeaters.enumerated() {
            let channel = MemoryChannel(
                number: index + 60,  // Start at channel 60
                frequency: repeater.rxFrequency,
                mode: repeater.mode,
                name: repeater.name,
                toneFrequency: repeater.tone,
                duplexOffset: repeater.offset != 0 ? repeater.offset : nil
            )

            try await rig.setMemoryChannel(channel)
            print("✓ Programmed: \(repeater.name)")
            print("  RX: \(Double(repeater.rxFrequency)/1_000_000) MHz")
            if repeater.offset != 0 {
                let txFreq = UInt64(Int64(repeater.rxFrequency) + Int64(repeater.offset))
                print("  TX: \(Double(txFreq)/1_000_000) MHz")
            }
            if let tone = repeater.tone {
                print("  Tone: \(tone) Hz")
            }
        }
    }

    /// Quick repeater access
    func accessRepeater(named name: String) async throws {
        let count = try await rig.memoryChannelCount()

        // Search for repeater by name
        for i in 0..<count {
            if let channel = try? await rig.getMemoryChannel(i),
               channel.name == name {
                try await rig.recallMemoryChannel(i)
                print("Accessing: \(channel.description)")
                return
            }
        }

        throw RigError.invalidParameter("Repeater '\(name)' not found in memory")
    }
}

// Usage
let repeaterMgr = RepeaterMemoryManager(rig: rig)
try await repeaterMgr.programRepeaters()
try await repeaterMgr.accessRepeater(named: "W1AW/R")
```

### DX Memory Bank with Split Operation

Store DX frequencies with split operation settings:

```swift
import RigControl

class DXMemoryBank {
    let rig: RigController

    /// Store a DX station with split operation
    func storeDXSplit(
        channel: Int,
        name: String,
        rxFrequency: UInt64,
        txFrequency: UInt64,
        mode: Mode = .usb
    ) async throws {
        let dxChannel = MemoryChannel(
            number: channel,
            frequency: rxFrequency,
            mode: mode,
            name: name,
            splitEnabled: true,
            txFrequency: txFrequency
        )

        try await rig.setMemoryChannel(dxChannel)
        print("Stored DX split: \(name)")
        print("  RX: \(Double(rxFrequency)/1_000_000) MHz")
        print("  TX: \(Double(txFrequency)/1_000_000) MHz")
    }

    /// Recall DX channel and configure split
    func recallDXSplit(channel: Int) async throws {
        let dxChannel = try await rig.getMemoryChannel(channel)

        // Apply RX frequency and mode
        try await rig.setFrequency(dxChannel.frequency, vfo: .a)
        try await rig.setMode(dxChannel.mode, vfo: .a)

        // If split is configured, set up VFO B and enable split
        if let splitEnabled = dxChannel.splitEnabled, splitEnabled,
           let txFreq = dxChannel.txFrequency {
            try await rig.setFrequency(txFreq, vfo: .b)
            try await rig.setMode(dxChannel.mode, vfo: .b)
            try await rig.setSplit(true)
            print("Split operation enabled")
        }

        print("Operating: \(dxChannel.description)")
    }
}

// Usage - store DX pileup channels
let dxBank = DXMemoryBank(rig: rig)

// Store a DX station listening 5 kHz up
try await dxBank.storeDXSplit(
    channel: 90,
    name: "3B7DX",
    rxFrequency: 14_195_000,  // Listen on 14.195
    txFrequency: 14_200_000   // Transmit on 14.200
)

// Recall and activate split
try await dxBank.recallDXSplit(channel: 90)
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
