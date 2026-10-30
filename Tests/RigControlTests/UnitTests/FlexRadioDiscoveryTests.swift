import Foundation
import Darwin
import Testing
@testable import RigControl

@Suite struct FlexRadioDiscoveryTests {

    /// Builds a discovery datagram: 28-byte VITA-49 header (stream ID
    /// 0x800, class ID 0x534CFFFF) then the NUL-padded ASCII payload.
    static func packet(
        _ payload: String,
        streamID: UInt32 = 0x0000_0800,
        classIDLow: UInt32 = 0x534C_FFFF
    ) -> Data {
        var bytes: [UInt8] = []
        func append(_ word: UInt32) {
            bytes += [24, 16, 8, 0].map { UInt8((word >> $0) & 0xFF) }
        }
        append(0x5880_0000)         // header word
        append(streamID)
        append(0x0000_1C2D)         // class ID high (FlexRadio OUI)
        append(classIDLow)
        append(1_798_000_000)       // integer timestamp
        append(0)
        append(0)
        bytes += Array(payload.utf8)
        while bytes.count % 4 != 0 { bytes.append(0) }
        return Data(bytes)
    }

    static let flex6600Payload = """
        discovery_protocol_version=3.0.0.2 model=FLEX-6600 serial=1234-5678-6600-0001 \
        version=3.4.23.1234 nickname=Shack_Radio callsign=VA3ZTF ip=192.168.1.50 \
        port=4992 status=Available inuse_ip= inuse_host= max_licensed_version=v3 \
        available_clients=2 max_slices=4 available_slices=3
        """

    @Test func parsesCurrentDiscoveryPayload() throws {
        let radio = try #require(FlexRadioAnnouncement.parse(datagram: Self.packet(Self.flex6600Payload)))
        #expect(radio.model == "FLEX-6600")
        #expect(radio.serial == "1234-5678-6600-0001")
        #expect(radio.version == "3.4.23.1234")
        #expect(radio.nickname == "Shack Radio")
        #expect(radio.callsign == "VA3ZTF")
        #expect(radio.host == "192.168.1.50")
        #expect(radio.port == 4992)
        #expect(radio.status == "Available")
        #expect(radio.isAvailable)
        #expect(radio.availableClients == 2)
        #expect(radio.availableSlices == 3)
        #expect(radio.fields["max_licensed_version"] == "v3")
        #expect(radio.fields["inuse_ip"] == "")
    }

    @Test func inUseRadioIsNotAvailable() throws {
        let radio = try #require(FlexRadioAnnouncement.parse(datagram: Self.packet(
            "model=FLEX-8600 serial=42 ip=10.0.0.9 status=In_Use inuse_host=SHACK-PC"
        )))
        #expect(!radio.isAvailable)
        #expect(radio.fields["inuse_host"] == "SHACK-PC")
    }

    @Test func missingPortDefaultsToSmartSDRAPIPort() throws {
        let radio = try #require(FlexRadioAnnouncement.parse(datagram: Self.packet("model=FLEX-6400 serial=7 ip=10.0.0.2")))
        #expect(radio.port == 4992)
        guard case .tcp(let host, let port) = radio.connection else {
            Issue.record("Expected a TCP connection")
            return
        }
        #expect(host == "10.0.0.2")
        #expect(port == 4992)
    }

    @Test func sourceAddressIsFallbackForMissingIP() throws {
        let radio = try #require(FlexRadioAnnouncement.parse(
            datagram: Self.packet("model=FLEX-6400 serial=7 ip="),
            sourceHost: "10.0.0.3"
        ))
        #expect(radio.host == "10.0.0.3")
    }

    @Test func legacyNameFieldIsUsedForNickname() throws {
        let radio = try #require(FlexRadioAnnouncement.parse(datagram: Self.packet(
            "model=FLEX-6500 serial=9 version=1.4.0.0 name=Field_Day callsign=VA3ZTF ip=10.0.0.4 port=4992"
        )))
        #expect(radio.nickname == "Field Day")
    }

    @Test func rejectsNonDiscoveryPackets() {
        let payload = Self.flex6600Payload
        // Wrong stream ID (e.g. a VITA-49 meter or audio stream).
        #expect(FlexRadioAnnouncement.parse(datagram: Self.packet(payload, streamID: 0x0000_0700)) == nil)
        // Wrong packet class code.
        #expect(FlexRadioAnnouncement.parse(datagram: Self.packet(payload, classIDLow: 0x534C_8003)) == nil)
        // Header only, or shorter.
        #expect(FlexRadioAnnouncement.parse(datagram: Data(Self.packet("").prefix(28))) == nil)
        #expect(FlexRadioAnnouncement.parse(datagram: Data([0x58, 0x80])) == nil)
        // Missing serial, model or address.
        #expect(FlexRadioAnnouncement.parse(datagram: Self.packet("model=FLEX-6600 ip=10.0.0.1")) == nil)
        #expect(FlexRadioAnnouncement.parse(datagram: Self.packet("serial=1 ip=10.0.0.1")) == nil)
        #expect(FlexRadioAnnouncement.parse(datagram: Self.packet("model=FLEX-6600 serial=1")) == nil)
    }

    @Test func payloadStopsAtFirstNUL() throws {
        var data = Self.packet("model=FLEX-6600 serial=1 ip=10.0.0.1")
        data.append(contentsOf: [0, 0, 0, 0] + Array(" serial=garbage".utf8))
        let radio = try #require(FlexRadioAnnouncement.parse(datagram: data))
        #expect(radio.serial == "1")
    }

    @Test func radioDefinitionMapsSlicesAToH() throws {
        let radio = FlexRadioAnnouncement(model: "FLEX-6600", serial: "1", host: "10.0.0.1")
        #expect(try radio.radioDefinition(slice: 0).model == "SmartSDR Slice A")
        #expect(try radio.radioDefinition(slice: 7).model == "SmartSDR Slice H")
        #expect(throws: RigError.self) { try radio.radioDefinition(slice: 8) }
        #expect(throws: RigError.self) { try radio.radioDefinition(slice: -1) }
    }

    // MARK: - Socket

    @Test func discoverReceivesDatagramsAndDeduplicatesBySerial() async throws {
        let port = UInt16.random(in: 40_000...60_000)
        let discovery = FlexRadioDiscovery(port: port)
        async let found = discovery.discover(timeout: .milliseconds(800))

        try await Task.sleep(for: .milliseconds(200))
        try Self.sendLoopback(Self.packet("model=FLEX-6600 serial=A ip=10.0.0.1 status=In_Use"), port: port)
        try Self.sendLoopback(Self.packet("model=FLEX-8400 serial=B ip=10.0.0.2"), port: port)
        try Self.sendLoopback(Self.packet("model=FLEX-6600 serial=A ip=10.0.0.1 status=Available"), port: port)
        try Self.sendLoopback(Data("not a flex packet".utf8), port: port)

        let radios = try await found
        #expect(radios.map(\.serial) == ["A", "B"])
        #expect(radios.first?.status == "Available")
    }

    @Test func announcementsStreamYieldsUntilConsumerStops() async throws {
        let port = UInt16.random(in: 40_000...60_000)
        let consumer = Task {
            for try await radio in FlexRadioDiscovery(port: port).announcements() {
                return radio.serial as String?
            }
            return nil
        }
        // Resend until the listener, which binds asynchronously, hears one.
        for _ in 0..<20 {
            try await Task.sleep(for: .milliseconds(50))
            try Self.sendLoopback(Self.packet("model=FLEX-6700 serial=C ip=10.0.0.3"), port: port)
        }
        // If nothing arrived, cancelling ends the stream and the test fails
        // instead of hanging.
        consumer.cancel()
        #expect(try await consumer.value == "C")
    }

    static func sendLoopback(_ data: Data, port: UInt16) throws {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { throw FlexRadioDiscoveryError.socketFailed(errno: errno) }
        defer { close(fd) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let sent = data.withUnsafeBytes { raw in
            withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(fd, raw.baseAddress, raw.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == data.count else { throw FlexRadioDiscoveryError.socketFailed(errno: errno) }
    }
}
