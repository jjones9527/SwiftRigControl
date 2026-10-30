import Foundation
import Darwin

// MARK: - FlexRadio SmartSDR network discovery
//
// FlexRadio 6000 / 8000 / Aurora radios announce themselves by broadcasting
// a VITA-49 packet to UDP port 4992 on the local subnet. Clients only
// listen; there is no request. The 28-byte header is seven big-endian
// words (header, stream ID, class ID high, class ID low, integer
// timestamp, fractional timestamp high/low). Discovery packets use stream
// ID 0x800 and packet class code 0xFFFF in the low half of class ID low.
// The payload is an ASCII, NUL-padded, space-separated `key=value` list
// shaped like a SmartSDR status line:
//
//   discovery_protocol_version=3.0.0.2 model=FLEX-6600 serial=1234-5678-6600-0001
//   version=3.4.23.1234 nickname=Shack_Radio callsign=VA3ZTF ip=192.168.1.50
//   port=4992 status=Available inuse_ip= inuse_host= ... available_clients=2
//   max_slices=4 available_slices=4 ...
//
// Spaces in the nickname are sent as underscores. Firmware since 1.4 only
// sends this VITA-49 form (the pre-1.4 plain-text form is not handled).
// Sources: FlexRadio smartsdr-api-docs wiki "Discovery protocol" and
// FlexLib `Discovery.cs`. Hamlib has no SmartSDR discovery (`smartsdr.c`
// takes the radio address from the user), so there is no Hamlib
// reference to cross-check; this is a beyond-Hamlib feature (ROADMAP 6.4).

/// One FlexRadio SmartSDR discovery broadcast, decoded.
///
/// Returned by ``FlexRadioDiscovery``. Pass ``connection`` and
/// ``radioDefinition(slice:)`` straight to ``RigController``:
///
/// ```swift
/// let radios = try await FlexRadioDiscovery().discover()
/// if let flex = radios.first(where: \.isAvailable) {
///     let rig = try RigController(
///         radio: flex.radioDefinition(slice: 0),
///         connection: flex.connection
///     )
///     try await rig.connect()
/// }
/// ```
public struct FlexRadioAnnouncement: Sendable, Equatable {
    /// Radio model, e.g. `FLEX-6600`.
    public let model: String

    /// Radio serial number. Stable per radio; ``FlexRadioDiscovery``
    /// uses it to tell radios apart.
    public let serial: String

    /// SmartSDR firmware version, if announced.
    public let version: String?

    /// User-assigned radio name with underscores turned back into
    /// spaces, if announced.
    public let nickname: String?

    /// Operator callsign configured on the radio, if announced.
    public let callsign: String?

    /// IPv4 address of the radio's SmartSDR API, dotted decimal.
    public let host: String

    /// TCP port of the SmartSDR API (4992 unless the radio says otherwise).
    public let port: UInt16

    /// Radio status, e.g. `Available` or `In_Use`, if announced.
    public let status: String?

    /// How many more GUI clients the radio will accept, if announced.
    public let availableClients: Int?

    /// How many more slices the radio can open, if announced.
    public let availableSlices: Int?

    /// Every `key=value` pair in the payload, undecoded, for fields this
    /// type doesn't surface (`inuse_host`, `gui_client_programs`, …).
    public let fields: [String: String]

    /// Memberwise initializer, public so tests and apps can build
    /// announcements without a radio on the network.
    public init(
        model: String,
        serial: String,
        version: String? = nil,
        nickname: String? = nil,
        callsign: String? = nil,
        host: String,
        port: UInt16 = FlexRadioDiscovery.smartSDRAPIPort,
        status: String? = nil,
        availableClients: Int? = nil,
        availableSlices: Int? = nil,
        fields: [String: String] = [:]
    ) {
        self.model = model
        self.serial = serial
        self.version = version
        self.nickname = nickname
        self.callsign = callsign
        self.host = host
        self.port = port
        self.status = status
        self.availableClients = availableClients
        self.availableSlices = availableSlices
        self.fields = fields
    }

    /// `false` only when the radio reports a status other than
    /// `Available` (typically `In_Use`). A radio that doesn't announce
    /// a status counts as available.
    public var isAvailable: Bool {
        status.map { $0 == "Available" } ?? true
    }

    /// The TCP connection for the radio's native SmartSDR API.
    public var connection: ConnectionType {
        .tcp(host: host, port: port)
    }

    /// The native SmartSDR definition for one of this radio's slices.
    ///
    /// - Parameter slice: Zero-based slice index, 0 (A) through 7 (H).
    /// - Returns: `RadioDefinition.Flex.smartSDRA` … `smartSDRH`.
    /// - Throws: `RigError.invalidParameter` if `slice` is outside `0...7`.
    public func radioDefinition(slice: Int) throws -> RadioDefinition {
        let slices: [RadioDefinition] = [
            .Flex.smartSDRA, .Flex.smartSDRB, .Flex.smartSDRC, .Flex.smartSDRD,
            .Flex.smartSDRE, .Flex.smartSDRF, .Flex.smartSDRG, .Flex.smartSDRH,
        ]
        guard slices.indices.contains(slice) else {
            throw RigError.invalidParameter("SmartSDR slice must be 0...7")
        }
        return slices[slice]
    }

    // MARK: Parsing

    /// Discovery stream ID (VITA-49 word 1).
    static let streamID: UInt32 = 0x0000_0800

    /// Discovery packet class code (low 16 bits of VITA-49 word 3).
    static let packetClassCode: UInt32 = 0xFFFF

    /// VITA-49 header length in bytes.
    static let headerLength = 28

    /// Decodes one UDP datagram.
    ///
    /// - Parameters:
    ///   - datagram: The UDP payload as received.
    ///   - sourceHost: The sender's address, used only if the payload has
    ///     no `ip=` field.
    /// - Returns: The announcement, or `nil` if the datagram isn't a
    ///   SmartSDR discovery packet or lacks a model, serial or address.
    static func parse(datagram: Data, sourceHost: String? = nil) -> FlexRadioAnnouncement? {
        let bytes = [UInt8](datagram)
        guard bytes.count > headerLength,
              word(bytes, at: 4) == streamID,
              word(bytes, at: 12) & 0xFFFF == packetClassCode else {
            return nil
        }

        let payload = bytes[headerLength...].prefix { $0 != 0 }
        let text = String(decoding: payload, as: UTF8.self)
        var fields: [String: String] = [:]
        for token in text.split(whereSeparator: \.isWhitespace) {
            let pair = token.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2, !pair[0].isEmpty else { continue }
            fields[String(pair[0])] = String(pair[1])
        }

        func value(_ key: String) -> String? {
            guard let value = fields[key], !value.isEmpty else { return nil }
            return value
        }

        guard let model = value("model"),
              let serial = value("serial"),
              let host = value("ip") ?? sourceHost else {
            return nil
        }

        return FlexRadioAnnouncement(
            model: model,
            serial: serial,
            version: value("version"),
            nickname: (value("nickname") ?? value("name"))?
                .replacingOccurrences(of: "_", with: " "),
            callsign: value("callsign"),
            host: host,
            port: value("port").flatMap(UInt16.init) ?? FlexRadioDiscovery.smartSDRAPIPort,
            status: value("status"),
            availableClients: value("available_clients").flatMap(Int.init),
            availableSlices: value("available_slices").flatMap(Int.init),
            fields: fields
        )
    }

    private static func word(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        bytes[offset..<(offset + 4)].reduce(0) { $0 << 8 | UInt32($1) }
    }
}

/// Errors from ``FlexRadioDiscovery``.
public enum FlexRadioDiscoveryError: Error, LocalizedError, Equatable {
    /// The UDP socket could not be created or configured; carries `errno`.
    case socketFailed(errno: Int32)

    /// The discovery port could not be bound; carries `errno`.
    case cannotBind(port: UInt16, errno: Int32)

    /// Human-readable description of the error.
    public var errorDescription: String? {
        switch self {
        case .socketFailed(let code):
            return "Could not open a UDP socket for FlexRadio discovery: \(String(cString: strerror(code)))"
        case .cannotBind(let port, let code):
            return "Could not listen on UDP port \(port) for FlexRadio discovery: \(String(cString: strerror(code)))"
        }
    }
}

/// Finds FlexRadio SmartSDR radios on the local network.
///
/// Listens for the discovery packets SmartSDR radios broadcast to UDP
/// port 4992. Nothing is sent, so listening is safe on any network. The
/// socket uses `SO_REUSEPORT`, so it coexists with SmartSDR for Mac or
/// another client listening on the same port.
///
/// ```swift
/// // One-shot scan.
/// for radio in try await FlexRadioDiscovery().discover(timeout: .seconds(3)) {
///     print(radio.model, radio.nickname ?? "", radio.host, radio.status ?? "")
/// }
///
/// // Or watch continuously, e.g. to keep a picker up to date.
/// for try await radio in FlexRadioDiscovery().announcements() {
///     print("Heard \(radio.serial) at \(radio.host)")
/// }
/// ```
///
/// Discovery only works on the radio's own subnet (broadcasts are not
/// routed); for SmartLink or a VPN, connect with the radio's address.
/// Sandboxed apps need the `com.apple.security.network.server`
/// entitlement to receive UDP.
public struct FlexRadioDiscovery: Sendable {
    /// UDP port SmartSDR radios broadcast discovery packets to.
    public static let discoveryPort: UInt16 = 4992

    /// TCP port of the SmartSDR API when a radio doesn't announce one.
    public static let smartSDRAPIPort: UInt16 = 4992

    /// UDP port this instance listens on.
    public let port: UInt16

    /// Creates a discovery listener.
    ///
    /// - Parameter port: UDP port to listen on. Leave at the default
    ///   outside tests.
    public init(port: UInt16 = FlexRadioDiscovery.discoveryPort) {
        self.port = port
    }

    /// Listens for `timeout` and returns each radio heard, once.
    ///
    /// Radios are told apart by serial number; if one is heard more than
    /// once its latest announcement wins. Results are in the order radios
    /// were first heard.
    ///
    /// - Parameter timeout: How long to listen. Radios broadcast
    ///   periodically, so a window of a few seconds is usually enough.
    /// - Returns: The radios heard, possibly none.
    /// - Throws: ``FlexRadioDiscoveryError`` if the port can't be opened.
    public func discover(timeout: Duration = .seconds(3)) async throws -> [FlexRadioAnnouncement] {
        var radios: [FlexRadioAnnouncement] = []
        for try await radio in stream(until: .now + timeout) {
            if let index = radios.firstIndex(where: { $0.serial == radio.serial }) {
                radios[index] = radio
            } else {
                radios.append(radio)
            }
        }
        return radios
    }

    /// Every discovery packet heard, until the consuming task is
    /// cancelled or stops iterating. Radios repeat their announcement,
    /// so the same radio appears many times.
    ///
    /// - Returns: A stream of announcements. It finishes with
    ///   ``FlexRadioDiscoveryError`` if the port can't be opened.
    public func announcements() -> AsyncThrowingStream<FlexRadioAnnouncement, Error> {
        stream(until: nil)
    }

    // MARK: Socket

    private func stream(until deadline: ContinuousClock.Instant?) -> AsyncThrowingStream<FlexRadioAnnouncement, Error> {
        let port = self.port
        return AsyncThrowingStream { continuation in
            let task = Task.detached {
                do {
                    try Self.listen(port: port, until: deadline) { continuation.yield($0) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Receives datagrams until `deadline` or task cancellation. `poll`
    /// waits at most `pollInterval` per turn so cancellation is noticed
    /// promptly without blocking a thread indefinitely.
    private static func listen(
        port: UInt16,
        until deadline: ContinuousClock.Instant?,
        onAnnouncement: (FlexRadioAnnouncement) -> Void
    ) throws {
        let fd = try openSocket(port: port)
        defer { close(fd) }

        let pollIntervalMs: Int32 = 100
        var buffer = [UInt8](repeating: 0, count: 65_536)
        while !Task.isCancelled {
            var timeoutMs = pollIntervalMs
            if let deadline {
                let remaining = ContinuousClock.now.duration(to: deadline)
                guard remaining > .zero else { return }
                let remainingMs = remaining.components.seconds * 1000
                    + remaining.components.attoseconds / 1_000_000_000_000_000
                timeoutMs = Int32(clamping: max(1, min(Int64(pollIntervalMs), remainingMs)))
            }

            var descriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let ready = poll(&descriptor, 1, timeoutMs)
            if ready < 0 {
                if errno == EINTR { continue }
                throw FlexRadioDiscoveryError.socketFailed(errno: errno)
            }
            guard ready > 0 else { continue }

            var source = sockaddr_in()
            var sourceLength = socklen_t(MemoryLayout<sockaddr_in>.size)
            let count = buffer.withUnsafeMutableBytes { raw in
                withUnsafeMutablePointer(to: &source) { pointer in
                    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        recvfrom(fd, raw.baseAddress, raw.count, 0, $0, &sourceLength)
                    }
                }
            }
            guard count > 0 else { continue }

            let datagram = Data(buffer[0..<count])
            if let announcement = FlexRadioAnnouncement.parse(datagram: datagram, sourceHost: dottedQuad(source.sin_addr)) {
                onAnnouncement(announcement)
            }
        }
    }

    private static func openSocket(port: UInt16) throws -> Int32 {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { throw FlexRadioDiscoveryError.socketFailed(errno: errno) }

        var yes: Int32 = 1
        let size = socklen_t(MemoryLayout<Int32>.size)
        guard setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, size) == 0,
              setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &yes, size) == 0 else {
            let code = errno
            close(fd)
            throw FlexRadioDiscoveryError.socketFailed(errno: code)
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr = in_addr(s_addr: INADDR_ANY)
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else {
            let code = errno
            close(fd)
            throw FlexRadioDiscoveryError.cannotBind(port: port, errno: code)
        }
        return fd
    }

    private static func dottedQuad(_ address: in_addr) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        var address = address
        guard inet_ntop(AF_INET, &address, &buffer, socklen_t(buffer.count)) != nil else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
