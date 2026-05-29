import Foundation
import Testing
@testable import RigControl

/// Tests for ``RadioDiscovery`` — the orchestration layer — and
/// ``RadioIdentifyProbe`` — the per-vendor identify response parser.
///
/// Production code talks to `/dev/cu.*` via ``IOKitSerialPort``;
/// these tests inject a mock enumerator + mock probe so the
/// matching, ordering, and multi-radio logic can be exercised
/// without real hardware.
@Suite struct RadioDiscoveryTests {

    // MARK: - Single-radio detection

    @Test func detectReturnsFirstMatchingPort() async {
        let enumerator = MockEnumerator(ports: [
            "/dev/cu.usbserial-A1",
            "/dev/cu.usbserial-B2",
        ])
        let probe: RadioProbeFunction = { path, _, _ in
            if path == "/dev/cu.usbserial-B2" {
                return .matched(identityResponse: "94 00")
            }
            return .noResponse
        }
        let discovery = RadioDiscovery(enumerator: enumerator, probe: probe)
        let result = await discovery.detect(.Icom.ic7300())
        #expect(result?.portPath == "/dev/cu.usbserial-B2")
        #expect(result?.baudRate == RadioDefinition.Icom.ic7300().defaultBaudRate)
        #expect(result?.identityResponse == "94 00")
    }

    @Test func detectReturnsNilWhenNoMatch() async {
        let enumerator = MockEnumerator(ports: ["/dev/cu.usbserial-A1"])
        let probe: RadioProbeFunction = { _, _, _ in .noResponse }
        let discovery = RadioDiscovery(enumerator: enumerator, probe: probe)
        let result = await discovery.detect(.Icom.ic7300())
        #expect(result == nil)
    }

    @Test func detectSkipsPortsThatRespondWithWrongRadio() async {
        // The first port has *some* radio on it that isn't the
        // one we're looking for; the second has the target.
        let enumerator = MockEnumerator(ports: [
            "/dev/cu.usbserial-X",
            "/dev/cu.usbserial-Y",
        ])
        let probe: RadioProbeFunction = { path, _, _ in
            switch path {
            case "/dev/cu.usbserial-X":
                return .wrongRadio(identityResponse: "ID021;")
            case "/dev/cu.usbserial-Y":
                return .matched(identityResponse: "94 00")
            default:
                return .error
            }
        }
        let discovery = RadioDiscovery(enumerator: enumerator, probe: probe)
        let result = await discovery.detect(.Icom.ic7300())
        #expect(result?.portPath == "/dev/cu.usbserial-Y")
    }

    // MARK: - Multi-radio detection

    @Test func detectMultipleReturnsOneEntryPerRadioFound() async {
        let enumerator = MockEnumerator(ports: [
            "/dev/cu.usbserial-A",
            "/dev/cu.usbserial-B",
            "/dev/cu.usbserial-C",
        ])
        // Pretend port A is an IC-9700, port C is an FTDX-10,
        // port B is empty.
        let probe: RadioProbeFunction = { path, radio, _ in
            switch (path, radio.model) {
            case ("/dev/cu.usbserial-A", "IC-9700"):
                return .matched(identityResponse: "A2 00")
            case ("/dev/cu.usbserial-C", "FTDX-10"):
                return .matched(identityResponse: "ID0760;")
            default:
                return .noResponse
            }
        }
        let discovery = RadioDiscovery(enumerator: enumerator, probe: probe)
        let hits = await discovery.detect([
            .Icom.ic7300(),
            .Icom.ic9700(),
            .Yaesu.ftdx10,
        ])
        #expect(hits.count == 2)
        let radios = Set(hits.map { $0.radio.fullName })
        #expect(radios.contains("Icom IC-9700"))
        #expect(radios.contains("Yaesu FTDX-10"))
    }

    @Test func detectMultipleConsumesPortsExclusively() async {
        // If port A matches both candidates' identify (which it
        // physically can't, but a buggy probe could falsely
        // claim), the second candidate must not double-bind the
        // same port.
        let enumerator = MockEnumerator(ports: ["/dev/cu.usbserial-A"])
        let probe: RadioProbeFunction = { _, _, _ in
            .matched(identityResponse: "match")
        }
        let discovery = RadioDiscovery(enumerator: enumerator, probe: probe)
        let hits = await discovery.detect([
            .Icom.ic7300(),
            .Icom.ic9700(),
        ])
        #expect(hits.count == 1)
        #expect(hits.first?.radio.model == "IC-7300")
    }

    @Test func detectMultipleReturnsEmptyWhenNothingMatches() async {
        let enumerator = MockEnumerator(ports: ["/dev/cu.usbserial-A"])
        let probe: RadioProbeFunction = { _, _, _ in .noResponse }
        let discovery = RadioDiscovery(enumerator: enumerator, probe: probe)
        let hits = await discovery.detect([
            .Icom.ic7300(),
            .Yaesu.ftdx10,
        ])
        #expect(hits.isEmpty)
    }

    // MARK: - Port ordering

    @Test func enumeratorPriorityRanksUsbSerialFirst() {
        let unsorted = [
            "/dev/cu.Bluetooth-Incoming-Port",
            "/dev/cu.usbmodem14101",
            "/dev/cu.SLAB_USBtoUART",
            "/dev/cu.usbserial-A1B2",
        ]
        let sorted = unsorted.sorted(by: DefaultSerialPortEnumerator.priority)
        #expect(sorted[0].contains("usbserial"))
        #expect(sorted[1].contains("SLAB_USBtoUART"))
        #expect(sorted[2].contains("usbmodem"))
    }

    // MARK: - Kenwood-family ID response parsing

    @Test func isLikelyKenwoodFamilyIDAcceptsRealResponses() {
        // K2's response per Hamlib elecraft.c
        #expect(RadioIdentifyProbe.isLikelyKenwoodFamilyID("ID017;"))
        // TS-590S
        #expect(RadioIdentifyProbe.isLikelyKenwoodFamilyID("ID021;"))
        // FT-991 — 4-digit form
        #expect(RadioIdentifyProbe.isLikelyKenwoodFamilyID("ID0670;"))
        // Echoed query then real response (some USB adapters loop TX→RX)
        #expect(RadioIdentifyProbe.isLikelyKenwoodFamilyID("ID;ID019;"))
    }

    @Test func isLikelyKenwoodFamilyIDRejectsGarbage() {
        #expect(!RadioIdentifyProbe.isLikelyKenwoodFamilyID(""))
        #expect(!RadioIdentifyProbe.isLikelyKenwoodFamilyID(";"))
        #expect(!RadioIdentifyProbe.isLikelyKenwoodFamilyID("ID;"))         // no payload
        #expect(!RadioIdentifyProbe.isLikelyKenwoodFamilyID("ID;"))
        #expect(!RadioIdentifyProbe.isLikelyKenwoodFamilyID("FA0001425;")) // wrong command
        #expect(!RadioIdentifyProbe.isLikelyKenwoodFamilyID("IDxyz;"))     // non-digit payload
    }
}

// MARK: - Mock helpers

/// Returns a canned list of port paths so ``RadioDiscovery`` can be
/// driven without touching `/dev/`.
private struct MockEnumerator: SerialPortEnumerator {
    let ports: [String]
    func availablePorts() -> [String] { ports }
}
