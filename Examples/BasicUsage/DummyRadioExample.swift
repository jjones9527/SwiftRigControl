import Foundation
import RigControl

// Example: Driving SwiftRigControl with no hardware
//
// This example demonstrates the `RadioDefinition.dummy(...)` factory —
// the Swift analogue of Hamlib's Model 1 ("Dummy") rig — which lets
// app developers build, preview, and demo their apps without owning
// (or being plugged into) a real radio.
//
// Use cases:
//   • SwiftUI #Preview blocks
//   • Demo / sample apps shipped to App Store reviewers
//   • Tutorials and screencasts
//   • Integration tests of app code that should not require hardware
//
// IMPORTANT: this is reference code, not a registered executable in
// Package.swift. Copy the relevant pieces into your own app target.

@main
struct DummyRadioExample {
    static func main() async {
        print("SwiftRigControl — Dummy Radio Example")
        print("======================================\n")

        do {
            // 1. Pick a dummy radio. The default capability set is a
            //    full-featured HF rig. Override capabilities to model
            //    a VHF rig, QRP rig, or receiver.
            let rig = try RigController(radio: .dummy(), connection: .mock)

            print("Radio: \(rig.radioName)")
            print("Verification status: \(rig.verificationStatus.displayName)\n")

            try await rig.connect()
            print("✓ Connected\n")

            // 2. Drive it through the standard RigController API —
            //    exactly as you would a real radio.
            try await rig.setFrequency(14_230_000, vfo: .a)
            try await rig.setMode(.usb, vfo: .a)
            try await rig.setPower(50)

            let f = try await rig.frequency()
            let m = try await rig.mode()
            let p = try await rig.power()
            let signal = try await rig.signalStrength()

            print("Frequency: \(f) Hz")
            print("Mode:      \(m)")
            print("Power:     \(p)")
            print("Signal:    \(signal.description)\n")

            // 3. PTT round-trips just like the real thing.
            try await rig.setPTT(true)
            print("PTT on:  \(try await rig.isPTTEnabled())")
            try await rig.setPTT(false)
            print("PTT off: \(try await rig.isPTTEnabled())\n")

            // 4. Custom capabilities — model a 2m FM mobile rig.
            let vhf = RigCapabilities(
                hasSplit: false,
                maxPower: 50,
                supportedModes: [.fm, .fmN],
                frequencyRange: FrequencyRange(min: 144_000_000, max: 148_000_000),
                hasATU: false,
                requiresVFOSelection: false,
                supportsRIT: false,
                supportsXIT: false,
                supportsCTCSS: true,
                supportsDuplex: true
            )
            let vhfRig = try RigController(
                radio: .dummy(name: "2m FM Mobile", capabilities: vhf),
                connection: .mock
            )
            try await vhfRig.connect()
            try await vhfRig.setFrequency(146_520_000, vfo: .a)
            try await vhfRig.setMode(.fm, vfo: .a)
            print("VHF rig:   \(vhfRig.radioName) @ \(try await vhfRig.frequency()) Hz, \(try await vhfRig.mode())")

            // 5. Out-of-range frequency or unsupported mode raise the
            //    same RigError types a real radio would — so app
            //    error-handling code is exercised under the dummy too.
            do {
                try await vhfRig.setFrequency(14_230_000, vfo: .a)
            } catch RigError.invalidParameter(let why) {
                print("✓ Rejected (as expected): \(why)")
            }

            await rig.disconnect()
            await vhfRig.disconnect()
            print("\n✓ Done.")
        } catch {
            print("Error: \(error)")
        }
    }
}

// MARK: - SwiftUI preview pattern (illustrative)
//
// In a SwiftUI app you typically expose the RigController as an
// observable property on a view model, then construct a dummy-backed
// controller for previews:
//
//   @MainActor
//   final class RadioViewModel: ObservableObject {
//       @Published var frequency: UInt64 = 0
//       @Published var mode: Mode = .usb
//
//       private let rig: RigController
//
//       init(rig: RigController) { self.rig = rig }
//
//       static var preview: RadioViewModel {
//           let rig = try! RigController(radio: .dummy(), connection: .mock)
//           Task { try? await rig.connect() }
//           return RadioViewModel(rig: rig)
//       }
//   }
//
//   #Preview {
//       RadioControlView(viewModel: .preview)
//   }
//
// No hardware required, no XPC helper required, no serial port required.
