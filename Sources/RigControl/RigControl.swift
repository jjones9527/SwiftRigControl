/// SwiftRigControl - Native Swift library for controlling amateur radio transceivers
///
/// This library provides a modern, type-safe interface for controlling amateur radio
/// transceivers on macOS. It supports multiple manufacturers and protocols including:
/// - Icom (CI-V protocol)
/// - Elecraft (text-based protocol) - Coming soon
/// - Yaesu (CAT protocol) - Coming soon
/// - Kenwood (text-based protocol) - Coming soon
///
/// ## Basic Usage
///
/// ```swift
/// import RigControl
///
/// let rig = RigController(
///     radio: .icomIC9700,
///     connection: .serial(path: "/dev/cu.IC9700", baudRate: 115200)
/// )
///
/// try await rig.connect()
/// try await rig.setFrequency(14_230_000, vfo: .a)
/// try await rig.setMode(.usb, vfo: .a)
/// try await rig.setPTT(true)
/// ```
///
/// ## Supported Radios
///
/// ### Icom
/// - IC-9700 (VHF/UHF/1.2GHz)
/// - IC-7610 (HF/6m SDR)
/// - IC-7300 (HF/6m)
/// - IC-7600 (HF/6m)
/// - IC-7100 (HF/VHF/UHF)
/// - IC-705 (Portable HF/VHF/UHF)
///
/// ## Mac App Store Compatibility
///
/// For sandboxed applications, use the XPC helper:
///
/// ```swift
/// import RigControlXPC
///
/// let xpc = XPCClient.shared
/// try await xpc.connect()
/// try await xpc.setFrequency(14_230_000, vfo: .a)
/// ```

// Re-export all public types
@_exported import struct Foundation.Data

// Core types
public typealias VFO = VFO
public typealias Mode = Mode
public typealias RigError = RigError
public typealias RigCapabilities = RigCapabilities
public typealias RigController = RigController
public typealias RadioDefinition = RadioDefinition
public typealias ConnectionType = ConnectionType

// Protocols
public typealias CATProtocol = CATProtocol
public typealias SerialTransport = SerialTransport
public typealias SerialConfiguration = SerialConfiguration

// Transport implementations
public typealias IOKitSerialPort = IOKitSerialPort
