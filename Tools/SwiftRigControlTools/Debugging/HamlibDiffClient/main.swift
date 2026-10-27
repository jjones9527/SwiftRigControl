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

if CommandLine.arguments.contains("--list") {
    for radio in RadioDefinition.allSupportedRadios {
        emit(radio.fullName)
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
