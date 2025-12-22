import Foundation
import RigControl

/// Simple test tool for rigctld server
///
/// This tool starts a rigctld-compatible server on port 4532 and waits for connections.
/// You can test it with:
///   telnet localhost 4532
///   nc localhost 4532
///   rigctl -m 2 -r localhost:4532
@main
struct RigctldTest {
    static func main() async {
        print("SwiftRigControl rigctld Server Test")
        print("=====================================\n")

        // Parse command line arguments
        let arguments = CommandLine.arguments
        var port: UInt16 = 4532
        var serialPort: String?
        var baudRate: UInt32 = 19200
        var radioModel: String = "IC-7600"

        var i = 1
        while i < arguments.count {
            switch arguments[i] {
            case "-p", "--port":
                if i + 1 < arguments.count, let p = UInt16(arguments[i + 1]) {
                    port = p
                    i += 1
                }
            case "-s", "--serial":
                if i + 1 < arguments.count {
                    serialPort = arguments[i + 1]
                    i += 1
                }
            case "-b", "--baud":
                if i + 1 < arguments.count, let b = UInt32(arguments[i + 1]) {
                    baudRate = b
                    i += 1
                }
            case "-r", "--radio":
                if i + 1 < arguments.count {
                    radioModel = arguments[i + 1]
                    i += 1
                }
            case "-h", "--help":
                printUsage()
                return
            default:
                break
            }
            i += 1
        }

        // Determine radio type
        let radio: RadioDefinition
        switch radioModel.uppercased() {
        case "IC-9700", "IC9700", "9700":
            radio = RadioDefinition.icomIC9700()
        case "IC-7610", "IC7610", "7610":
            radio = RadioDefinition.icomIC7610()
        case "IC-7300", "IC7300", "7300":
            radio = RadioDefinition.icomIC7300()
        case "IC-7600", "IC7600", "7600":
            radio = RadioDefinition.icomIC7600()
        case "IC-7100", "IC7100", "7100":
            radio = RadioDefinition.icomIC7100()
        case "IC-705", "IC705", "705":
            radio = RadioDefinition.icomIC705()
        default:
            print("Unknown radio model: \(radioModel)")
            print("Using IC-7600 as default")
            radio = RadioDefinition.icomIC7600()
        }

        print("Configuration:")
        print("  Radio:       \(radioModel)")
        print("  Port:        \(port)")
        if let serialPort = serialPort {
            print("  Serial Port: \(serialPort)")
            print("  Baud Rate:   \(baudRate)")
        } else {
            print("  Mode:        Simulation (no serial port)")
        }
        print("")

        // Create rig controller
        let rig: RigController
        if let serialPort = serialPort {
            rig = try RigController(
                radio: radio,
                connection: .serial(path: serialPort, baudRate: Int(baudRate))
            )

            print("Connecting to radio...")
            do {
                try await rig.connect()
                print("✓ Connected to radio")

                // Test basic communication
                if let freq = try? await rig.frequency(vfo: .a, cached: false) {
                    print("  Current frequency: \(Double(freq) / 1_000_000.0) MHz")
                }
                if let mode = try? await rig.mode(vfo: .a, cached: false) {
                    print("  Current mode: \(mode.rawValue)")
                }
                print("")
            } catch {
                print("✗ Failed to connect: \(error)")
                print("  Continuing in simulation mode...")
                print("")
            }
        } else {
            rig = try RigController(
                radio: radio,
                connection: .serial(path: "/dev/null", baudRate: 19200)
            )
        }

        // Start rigctld server
        let server = RigControlServer(rigController: rig)

        do {
            try await server.start(port: port)
            print("✓ rigctld server started on port \(port)")
            print("")
            print("Test commands:")
            print("  telnet localhost \(port)")
            print("  nc localhost \(port)")
            print("  rigctl -m 2 -r localhost:\(port)")
            print("")
            print("Example rigctld commands:")
            print("  f              # Get frequency")
            print("  F 14230000     # Set frequency to 14.230 MHz")
            print("  m              # Get mode")
            print("  M USB 2400     # Set mode to USB")
            print("  \\dump_state    # Get radio capabilities")
            print("  q              # Quit")
            print("")
            print("Press Ctrl+C to stop server")
            print("")

            // Keep running indefinitely
            while true {
                try await Task.sleep(for: .seconds(3600))
            }
        } catch {
            print("✗ Failed to start server: \(error)")
            Foundation.exit(1)
        }
    }

    static func printUsage() {
        print("""
        Usage: RigctldTest [options]

        Options:
          -p, --port <port>        TCP port to listen on (default: 4532)
          -s, --serial <path>      Serial port path (e.g., /dev/cu.usbserial-0)
          -b, --baud <rate>        Baud rate (default: 19200)
          -r, --radio <model>      Radio model (default: IC-7600)
                                   Supported: IC-9700, IC-7610, IC-7300, IC-7600, IC-7100, IC-705
          -h, --help               Show this help message

        Examples:
          # Run with simulated radio (no serial port)
          RigctldTest

          # Connect to IC-7600 on serial port
          RigctldTest -s /dev/cu.usbserial-0 -b 19200 -r IC-7600

          # Use custom port
          RigctldTest -p 4533
        """)
    }
}
