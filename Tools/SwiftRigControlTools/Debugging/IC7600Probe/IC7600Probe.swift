import Foundation
import RigControl

/// One-shot debugging probe: sends a single raw CI-V frame to the
/// IC-7600 and prints whatever comes back. Used to investigate the
/// three remaining IC7600Validator failures (Squelch read,
/// PBT/level set, Band Edge read) without modifying the protocol
/// layer.
///
/// Usage:
///   export IC7600_SERIAL_PORT="/dev/cu.usbserial-1120"
///   swift run IC7600Probe pbt        # set inner PBT 128
///   swift run IC7600Probe squelch    # read squelch condition
///   swift run IC7600Probe bandedge   # read band edge
@main
struct IC7600Probe {
    static func main() async {
        guard let port = ProcessInfo.processInfo.environment["IC7600_SERIAL_PORT"] else {
            print("Set IC7600_SERIAL_PORT first."); exit(1)
        }
        let which = CommandLine.arguments.dropFirst().first ?? "squelch"

        let config = SerialConfiguration(path: port, baudRate: 19200)
        let transport = IOKitSerialPort(configuration: config)
        do {
            try await transport.open()
            try await transport.flush()

            // Build the test frame.
            let civAddr: UInt8 = ProcessInfo.processInfo.environment["CIV"]
            .flatMap { UInt8($0, radix: 16) } ?? 0x7A
            let bytes: [UInt8]
            switch which {
            case "pbt":
                // 0x14 0x07 [0x01, 0x28]  — inner PBT = 128 (BCD big-endian)
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x14, 0x07, 0x01, 0x28, 0xFD]
            case "pbtread":
                // 0x14 0x07 (no data) — read inner PBT
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x14, 0x07, 0xFD]
            case "squelch":
                // 0x15 0x01 — read squelch condition
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x15, 0x01, 0xFD]
            case "bandedge":
                // 0x02 — read band edge
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x02, 0xFD]
            case "setfm":
                // Set FM (mode code 0x05, FIL1 = 0x01)
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x06, 0x05, 0x01, 0xFD]
            case "setusb":
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x06, 0x01, 0x01, 0xFD]
            case "selmain":
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x07, 0xD0, 0xFD]
            case "selsub":
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x07, 0xD1, 0xFD]
            case "selvfoa":
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x07, 0x00, 0xFD]
            case "selvfob":
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x07, 0x01, 0xFD]
            case "attoff":
                // Attenuator OFF — 0x11 0x00
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x11, 0x00, 0xFD]
            case "att10":
                // Attenuator 10dB — 0x11 0x10
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x11, 0x10, 0xFD]
            case "att20":
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x11, 0x20, 0xFD]
            case "satoff":
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x16, 0x5A, 0x00, 0xFD]
            case "saton":
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x16, 0x5A, 0x01, 0xFD]
            case "satread":
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x16, 0x5A, 0xFD]
            case "dsqloff":
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x16, 0x5B, 0x00, 0xFD]
            case "dsqlread":
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x16, 0x5B, 0xFD]
            case "preoff":
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x16, 0x02, 0x00, 0xFD]
            case "preon1":
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x16, 0x02, 0x01, 0xFD]
            case "preon2":
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x16, 0x02, 0x02, 0xFD]
            case "dwoff":
                // IC-9700 dualwatch: 0x16 0x59 [0/1] per Hamlib
                // S_MEM_DUALMODE — NOT the 0x07 0xC2/0xC3 form.
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x16, 0x59, 0x00, 0xFD]
            case "dwon":
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x16, 0x59, 0x01, 0xFD]
            case "dwread":
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x16, 0x59, 0xFD]
            case "dataoff":
                // 0x1A 0x06 0x00 0x00 — clear data sub-mode flag
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x1A, 0x06, 0x00, 0x00, 0xFD]
            case "agcread":
                // 0x1A 0x04 — read AGC time constant
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x1A, 0x04, 0xFD]
            case "agcset":
                // 0x1A 0x04 0x05 — set AGC time constant to value 5
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x1A, 0x04, 0x05, 0xFD]
            case "agcset0":
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x1A, 0x04, 0x00, 0xFD]
            case "agcset10":
                bytes = [0xFE, 0xFE, civAddr, 0xE0, 0x1A, 0x04, 0x0A, 0xFD]
            default:
                print("Unknown probe '\(which)'. Try: pbt | pbtread | squelch | bandedge")
                await transport.close(); exit(1)
            }

            print("→ TX: \(bytes.map { String(format: "%02X", $0) }.joined(separator: " "))")
            try await transport.write(Data(bytes))

            // Read up to three frames so we see echo + ACK separately
            // on USB-echo radios.
            for i in 1...3 {
                do {
                    let rx = try await transport.readUntil(terminator: 0xFD, timeout: 0.8)
                    let hex = [UInt8](rx).map { String(format: "%02X", $0) }.joined(separator: " ")
                    print("← RX #\(i): \(hex)")
                } catch {
                    print("← RX #\(i): (timeout)")
                    break
                }
            }
            await transport.close()
        } catch {
            print("error: \(error)")
            exit(1)
        }
    }
}
