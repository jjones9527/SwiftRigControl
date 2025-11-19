import Foundation
import RigControlXPC

/// Main entry point for the RigControl XPC helper.
///
/// This helper runs as a privileged process and provides serial port access
/// to sandboxed Mac App Store applications.
///
/// The helper is installed using SMJobBless and communicates with apps via XPC.

class HelperDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Configure the connection
        newConnection.exportedInterface = NSXPCInterface(with: RigControlXPCProtocol.self)
        newConnection.exportedObject = XPCServer()

        // Resume the connection
        newConnection.resume()

        return true
    }
}

/// Main function
func main() {
    // Create the XPC listener
    let listener = NSXPCListener(machServiceName: XPCConstants.machServiceName)

    // Set up the delegate
    let delegate = HelperDelegate()
    listener.delegate = delegate

    // Start listening
    listener.resume()

    print("RigControlHelper started, listening for connections...")

    // Run the run loop
    RunLoop.current.run()
}

// Run the helper
main()
