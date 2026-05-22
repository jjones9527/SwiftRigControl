import Foundation

extension RadioDefinition {

    /// A generic in-memory dummy radio definition, the Swift equivalent
    /// of Hamlib's Model 1 ("Dummy") rig.
    ///
    /// Use this for SwiftUI previews, demo apps, tutorials, and
    /// integration tests of app code that should not require real
    /// hardware. The returned definition is wired to
    /// ``DummyCATProtocol`` and accepts any frequency, mode, and
    /// control value within the supplied capabilities.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Default HF rig
    /// let rig = try RigController(radio: .dummy(), connection: .mock)
    /// try await rig.connect()
    /// try await rig.setFrequency(14_230_000, vfo: .a)
    /// let f = try await rig.frequency()   // 14_230_000
    /// ```
    ///
    /// ```swift
    /// // VHF/UHF dummy (no HF support, no ATU)
    /// let vhfCaps = RigCapabilities(
    ///     hasATU: false,
    ///     supportedModes: [.fm, .fmN, .usb, .cw],
    ///     frequencyRange: FrequencyRange(min: 144_000_000, max: 450_000_000)
    /// )
    /// let vhf = try RigController(
    ///     radio: .dummy(name: "VHF Dummy", capabilities: vhfCaps),
    ///     connection: .mock
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - name: Model name shown by `RigController.radioName`.
    ///     Defaults to `"Dummy"`.
    ///   - capabilities: Capability set the dummy advertises and
    ///     enforces. Defaults to the all-defaults `RigCapabilities()`,
    ///     which is a generous "full-featured HF rig" profile.
    /// - Returns: A `RadioDefinition` whose `protocolFactory` builds a
    ///   ``DummyCATProtocol``. `verificationStatus` is `.definition` —
    ///   it is not a real radio, so it cannot be hardware-verified.
    public static func dummy(
        name: String = "Dummy",
        capabilities: RigCapabilities = RigCapabilities()
    ) -> RadioDefinition {
        RadioDefinition(
            manufacturer: .dummy,
            model: name,
            defaultBaudRate: 9600,
            capabilities: capabilities,
            civAddress: nil,
            verificationStatus: .definition,
            protocolFactory: { transport in
                DummyCATProtocol(transport: transport, capabilities: capabilities)
            }
        )
    }
}
