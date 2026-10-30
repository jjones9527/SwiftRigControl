// HamlibDiffClient — SwiftRigControl side of the Hamlib differential audit.
//
// Connects one catalog radio to a serial path (normally a pty relayed to a
// Hamlib simulator by Scripts/hamlib-diff-audit.py), then executes rigctl
// command lines read from stdin through RigctldCommandHandler, the same
// command strings Hamlib's rigctl runs. The driver records the bytes on
// the pty, so this tool only reports results.
//
// Protocol on stdout:
//   READY                      after connect() succeeds
//   CONNECT-ERROR <message>    if connect() fails (then exits 1)
//   <response lines>           rigctld default-format response
//   @@END                      after each command
// EOF on stdin disconnects and exits.
//
// Usage:
//   swift run HamlibDiffClient --radio "Elecraft KX3" --port /dev/ttys012 [--baud 38400]
//   swift run HamlibDiffClient --list      # catalog names

import Foundation
import RigControl

func argument(_ name: String) -> String? {
    let args = CommandLine.arguments
    guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
    return args[index + 1]
}

func emit(_ line: String) {
    FileHandle.standardOutput.write(Data((line + "\n").utf8))
}

/// A transport that is never opened; it only lets `--list --power` build
/// each radio's protocol to report its type.
actor UnopenedTransport: SerialTransport {
    func open() async throws {}
    func close() async {}
    func write(_ data: Data) async throws {}
    func read(timeout: TimeInterval) async throws -> Data { Data() }
    func readUntil(terminator: UInt8, timeout: TimeInterval) async throws -> Data { Data() }
    var isOpen: Bool { false }
    func flush() async throws {}
    func setDTR(_ enabled: Bool) async throws {}
    func setRTS(_ enabled: Bool) async throws {}
}

/// The capability traits a protocol conforms to, for `--list --traits`.
func traitNames(_ proto: any CATProtocol) -> [String] {
    var names: [String] = []
    func add(_ conforms: Bool, _ name: String) { if conforms { names.append(name) } }
    add(proto is any SupportsPower, "Power")
    add(proto is any SupportsSplit, "Split")
    add(proto is any SupportsSignalStrength, "SignalStrength")
    add(proto is any SupportsRIT, "RIT")
    add(proto is any SupportsXIT, "XIT")
    add(proto is any SupportsAGC, "AGC")
    add(proto is any SupportsNoiseBlanker, "NoiseBlanker")
    add(proto is any SupportsNoiseReduction, "NoiseReduction")
    add(proto is any SupportsIFFilter, "IFFilter")
    add(proto is any SupportsAFGain, "AFGain")
    add(proto is any SupportsRFGain, "RFGain")
    add(proto is any SupportsSquelch, "Squelch")
    add(proto is any SupportsPreamp, "Preamp")
    add(proto is any SupportsAttenuator, "Attenuator")
    add(proto is any SupportsRemotePowerState, "RemotePowerState")
    add(proto is any SupportsMemoryChannels, "MemoryChannels")
    add(proto is any SupportsTXMeters, "TXMeters")
    add(proto is any SupportsCWKeyer, "CWKeyer")
    add(proto is any SupportsSendCW, "SendCW")
    add(proto is any SupportsScanning, "Scanning")
    add(proto is any SupportsAntenna, "Antenna")
    add(proto is any SupportsVFOOperations, "VFOOperations")
    add(proto is any SupportsFunctions, "Functions")
    add(proto is any SupportsMicGain, "MicGain")
    add(proto is any SupportsCompressorLevel, "CompressorLevel")
    add(proto is any SupportsMonitorGain, "MonitorGain")
    add(proto is any SupportsVOXGain, "VOXGain")
    add(proto is any SupportsVOXDelay, "VOXDelay")
    add(proto is any SupportsIFShift, "IFShift")
    return names
}

if CommandLine.arguments.contains("--list"), CommandLine.arguments.contains("--traits") {
    // "<name>\t<protocol>\t<trait,trait,...>"
    let transport = UnopenedTransport()
    for radio in RadioDefinition.allSupportedRadios {
        let proto = radio.createProtocol(transport: transport)
        emit("\(radio.fullName)\t\(type(of: proto))\t\(traitNames(proto).joined(separator: ","))")
    }
    exit(0)
}

if CommandLine.arguments.contains("--list") {
    // `--list --power` adds "<TAB>protocol<TAB>maxPower<TAB>units<TAB>powerControl",
    // for picking out the radios whose RFPOWER scaling depends on max power.
    let showPower = CommandLine.arguments.contains("--power")
    let transport = UnopenedTransport()
    for radio in RadioDefinition.allSupportedRadios {
        guard showPower else {
            emit(radio.fullName)
            continue
        }
        let caps = radio.capabilities
        let units: String
        switch caps.powerUnits {
        case .percentage: units = "percentage"
        case .watts(let max): units = "watts(\(max))"
        }
        let proto = type(of: radio.createProtocol(transport: transport))
        emit("\(radio.fullName)\t\(proto)\t\(caps.maxPower)\t\(units)\t\(caps.powerControl)")
    }
    exit(0)
}

guard let name = argument("--radio"), let port = argument("--port") else {
    FileHandle.standardError.write(Data("usage: HamlibDiffClient --radio <full name> --port <path> [--baud N]\n".utf8))
    exit(2)
}

guard let radio = RadioDefinition.allSupportedRadios.first(where: { $0.fullName == name }) else {
    emit("CONNECT-ERROR unknown radio \(name)")
    exit(1)
}

let baud = argument("--baud").flatMap(Int.init)
let rig: RigController
do {
    rig = try RigController(radio: radio, connection: .serial(path: port, baudRate: baud))
    try await rig.connect()
} catch {
    emit("CONNECT-ERROR \(error)")
    exit(1)
}

emit("READY")

let parser = RigctldCommandParser()
let handler = RigctldCommandHandler(rigController: rig)
while let line = readLine() {
    let response: RigctldResponse
    do {
        response = await handler.handle(try parser.parse(line))
    } catch {
        response = RigctldResponse(error: .invalidParam)
    }
    for responseLine in response.formatDefault().split(separator: "\n", omittingEmptySubsequences: false)
    where !responseLine.isEmpty {
        emit(String(responseLine))
    }
    emit("@@END")
}

await rig.disconnect()
