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
/// ## Network Control (rigctld)
///
/// For remote rig control using the Hamlib rigctld protocol:
///
/// ```swift
/// import RigControl
///
/// let rig = RigController(
///     radio: .icomIC7600,
///     connection: .serial(path: "/dev/cu.IC-7600", baudRate: 19200)
/// )
/// try await rig.connect()
///
/// let server = RigControlServer(rigController: rig)
/// try await server.start(port: 4532)
///
/// // Clients can now connect using rigctl, telnet, or any TCP client
/// // rigctl -m 2 -r localhost:4532
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
