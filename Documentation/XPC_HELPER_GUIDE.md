# XPC Helper Guide for Mac App Store Apps

This guide explains how to use SwiftRigControl in Mac App Store (sandboxed) applications using the XPC helper.

## Why XPC Helper?

Mac App Store applications run in a **sandbox** that prevents direct access to serial ports. SwiftRigControl uses an **XPC helper** to work around this limitation:

```
┌─────────────────────────┐
│  Sandboxed App          │
│  (Mac App Store)        │
│                         │
│  ┌──────────────┐       │
│  │  XPCClient   │───────┼────> XPC Connection
│  └──────────────┘       │
└─────────────────────────┘
                               │
                               │
                               ↓
                     ┌─────────────────────┐
                     │  XPC Helper         │
                     │  (Privileged)       │
                     │                     │
                     │  ┌──────────────┐   │
                     │  │  XPCServer   │   │
                     │  └──────┬───────┘   │
                     │         │           │
                     │  ┌──────▼───────┐   │
                     │  │ RigControl   │   │
                     │  └──────┬───────┘   │
                     │         │           │
                     └─────────┼───────────┘
                               │
                               ↓
                     /dev/cu.IC9700 (Serial Port)
```

## Architecture Components

### 1. XPCProtocol
Defines the interface between app and helper (`Sources/RigControlXPC/XPCProtocol.swift`).

### 2. XPCClient
Lives in your sandboxed app, communicates with helper (`Sources/RigControlXPC/XPCClient.swift`).

### 3. XPCServer
Lives in the helper, controls radios (`Sources/RigControlXPC/XPCServer.swift`).

### 4. RigControlHelper
The helper executable (`Sources/RigControlHelper/main.swift`).

## Using XPC in Your App

### Step 1: Add Dependencies

In your app's `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftRigControl.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "RigControlXPC", package: "SwiftRigControl")
        ]
    )
]
```

### Step 2: Install the Helper

The helper must be installed once before first use. This requires administrator privileges.

```swift
import RigControlXPC

// In your app, when user clicks "Install Helper" button:
func installHelper() {
    // This will prompt for admin password
    // Implementation depends on SMJobBless
    // See Apple's SMJobBless documentation
}
```

### Step 3: Connect to Helper

```swift
import RigControlXPC

let client = XPCClient.shared

do {
    // Connect to the helper
    try await client.connect()
    print("✓ Connected to helper")
} catch {
    print("❌ Failed to connect to helper: \(error)")
}
```

### Step 4: Connect to Radio

```swift
do {
    // Connect to IC-9700
    try await client.connectToRadio(
        radio: "IC-9700",
        port: "/dev/cu.IC9700",
        baudRate: 115200
    )
    print("✓ Connected to IC-9700")
} catch {
    print("❌ Failed to connect to radio: \(error)")
}
```

### Step 5: Control the Radio

```swift
do {
    // Set frequency to 14.230 MHz
    try await client.setFrequency(14_230_000, vfo: .a)
    print("✓ Frequency set")

    // Set mode to USB
    try await client.setMode(.usb, vfo: .a)
    print("✓ Mode set")

    // Check current state
    let freq = try await client.frequency(vfo: .a)
    let mode = try await client.mode(vfo: .a)
    print("Current: \(formatFreq(freq)) \(mode)")

    // PTT control
    try await client.setPTT(true)
    print("✓ PTT ON")

    // Wait...
    try await Task.sleep(nanoseconds: 1_000_000_000)

    try await client.setPTT(false)
    print("✓ PTT OFF")

} catch {
    print("❌ Error: \(error)")
}
```

### Step 6: Disconnect

```swift
// Disconnect from radio
await client.disconnectRadio()

// Disconnect from helper
await client.disconnect()
```

## Complete Example

```swift
import SwiftUI
import RigControlXPC

@main
struct MyRadioApp: App {
    @StateObject private var radioController = RadioController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(radioController)
        }
    }
}

@MainActor
class RadioController: ObservableObject {
    @Published var isConnected = false
    @Published var currentFrequency: UInt64 = 0
    @Published var currentMode: String = ""
    @Published var errorMessage: String?

    private let client = XPCClient.shared

    func connect() async {
        do {
            // Connect to helper
            try await client.connect()

            // Connect to radio
            try await client.connectToRadio(
                radio: "IC-9700",
                port: "/dev/cu.IC9700"
            )

            isConnected = true
            await updateStatus()

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setFrequency(_ hz: UInt64) async {
        do {
            try await client.setFrequency(hz, vfo: .a)
            await updateStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setMode(_ mode: Mode) async {
        do {
            try await client.setMode(mode, vfo: .a)
            await updateStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setPTT(_ enabled: Bool) async {
        do {
            try await client.setPTT(enabled)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateStatus() async {
        do {
            currentFrequency = try await client.frequency(vfo: .a)
            let mode = try await client.mode(vfo: .a)
            currentMode = mode.rawValue
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() async {
        await client.disconnectRadio()
        await client.disconnect()
        isConnected = false
    }
}

struct ContentView: View {
    @EnvironmentObject var radio: RadioController

    var body: some View {
        VStack(spacing: 20) {
            if radio.isConnected {
                VStack {
                    Text("Frequency: \(formatFrequency(radio.currentFrequency))")
                    Text("Mode: \(radio.currentMode)")

                    HStack {
                        Button("14.230 MHz") {
                            Task {
                                await radio.setFrequency(14_230_000)
                            }
                        }

                        Button("USB") {
                            Task {
                                await radio.setMode(.usb)
                            }
                        }
                    }

                    Button("Disconnect") {
                        Task {
                            await radio.disconnect()
                        }
                    }
                }
            } else {
                Button("Connect to IC-9700") {
                    Task {
                        await radio.connect()
                    }
                }
            }

            if let error = radio.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            }
        }
        .padding()
    }

    private func formatFrequency(_ hz: UInt64) -> String {
        let mhz = Double(hz) / 1_000_000.0
        return String(format: "%.6f MHz", mhz)
    }
}
```

## Helper Installation (SMJobBless)

The helper must be installed using Apple's SMJobBless framework. This is a complex process:

### 1. Code Signing Requirements

- Both app and helper must be code signed
- Helper must be signed with the same Team ID as the app
- Helper bundle ID: `com.yourteam.yourapp.helper`

### 2. Info.plist Configuration

**App's Info.plist:**
```xml
<key>SMPrivilegedExecutables</key>
<dict>
    <key>com.yourteam.yourapp.helper</key>
    <string>identifier "com.yourteam.yourapp.helper" and anchor apple generic and certificate leaf[subject.CN] = "YourCertificate"</string>
</dict>
```

**Helper's Info.plist:**
```xml
<key>CFBundleIdentifier</key>
<string>com.yourteam.yourapp.helper</string>
<key>SMAuthorizedClients</key>
<array>
    <string>identifier "com.yourteam.yourapp" and anchor apple generic and certificate leaf[subject.CN] = "YourCertificate"</string>
</array>
```

### 3. Installation Code

```swift
import ServiceManagement

func installHelper() throws {
    var authRef: AuthorizationRef?

    // Create authorization
    let status = AuthorizationCreate(nil, nil, [], &authRef)
    guard status == errAuthorizationSuccess else {
        throw NSError(domain: "SMJobBless", code: Int(status))
    }

    defer {
        if let authRef = authRef {
            AuthorizationFree(authRef, [])
        }
    }

    // Install helper
    var error: Unmanaged<CFError>?
    let success = SMJobBless(
        kSMDomainSystemLaunchd,
        "com.yourteam.yourapp.helper" as CFString,
        authRef,
        &error
    )

    if !success {
        if let error = error?.takeRetainedValue() {
            throw error
        }
    }
}
```

## Supported Radios

All radios supported by RigControl work through XPC:

### Icom
- IC-9700, IC-7610, IC-7300, IC-7600, IC-7100, IC-705

### Elecraft
- K2, K3, K3S, K4, KX2, KX3

## Troubleshooting

### Helper Won't Install
- Check code signing: `codesign -dv --verbose=4 YourHelper`
- Verify Info.plist SMAuthorizedClients/SMPrivilegedExecutables
- Check Console.app for launchd errors

### Can't Connect to Helper
- Verify helper is running: `sudo launchctl list | grep yourhelper`
- Check Mach service name matches: `com.swiftrigcontrol.helper`
- Look for XPC errors in Console.app

### Radio Won't Connect
- Verify serial port path is correct
- Check helper has permission to access serial ports
- Try running helper manually to see errors

### XPC Connection Interrupted
- Helper may have crashed - check Console.app
- System may have unloaded helper - try reconnecting
- Check for memory issues

## Security Considerations

### Sandboxing
- Your app runs in a sandbox (good for security)
- Helper runs outside sandbox (required for serial access)
- Communication only via XPC (secure)

### Permissions
- Helper requires root/admin to install (one-time)
- Helper runs as root (necessary for serial port access)
- App requests minimal permissions

### Code Signing
- Both app and helper must be properly signed
- Helper signature verified by system before installation
- Prevents malicious helper replacement

## Performance

XPC adds minimal overhead:
- Typical latency: 1-5ms for simple calls
- Frequency changes: ~10-50ms total (mostly radio response time)
- PTT: Fast enough for real-time use
- No noticeable lag for normal operation

## Limitations

### No Direct Hardware Access
- App cannot directly access serial ports
- All operations go through helper
- Helper manages single radio connection at a time

### Installation Required
- User must install helper (admin password required)
- Installation is one-time process
- Helper persists across app launches

### Mac App Store Only
- XPC helper required for sandboxed apps
- Non-sandboxed apps can use RigControl directly
- Choose based on distribution method

## Best Practices

### 1. Check Helper Installation
```swift
func isHelperInstalled() -> Bool {
    // Check if helper is available
    // Return true if SMJobCopyDictionary succeeds
}
```

### 2. Handle Connection Errors
```swift
do {
    try await client.connect()
} catch {
    // Show user-friendly error
    // Offer to install/reinstall helper
}
```

### 3. Reconnect on Interruption
```swift
// XPC connection can be interrupted
// Implement reconnection logic
func handleInterruption() {
    Task {
        try? await client.connect()
    }
}
```

### 4. Disconnect on Quit
```swift
func applicationWillTerminate(_ notification: Notification) {
    Task {
        await XPCClient.shared.disconnectRadio()
        await XPCClient.shared.disconnect()
    }
}
```

## Resources

- [Apple SMJobBless Documentation](https://developer.apple.com/documentation/servicemanagement/1431078-smjobbless)
- [Apple XPC Documentation](https://developer.apple.com/documentation/xpc)
- [App Sandbox Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/AppSandboxDesignGuide/)
- [Even Better Apps documentation (WWDC)](https://developer.apple.com/videos/play/wwdc2011/203/)

## Summary

The XPC helper enables SwiftRigControl to work in Mac App Store applications:

- ✅ Sandboxed app communicates via XPC
- ✅ Helper runs with serial port access
- ✅ All RigControl features available
- ✅ Minimal performance overhead
- ✅ Secure architecture

For non-Mac App Store apps, use RigControl directly (simpler, no helper needed).
