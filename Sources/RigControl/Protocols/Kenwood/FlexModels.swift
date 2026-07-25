import Foundation

extension RadioDefinition.Flex {

    /// Flex 6000-series — SmartSDR-driven SDR transceivers.
    ///
    /// Covers the 6300, 6400, 6500, 6600, and 6700 variants. SmartSDR
    /// exposes a Kenwood-derived CAT bridge on TCP port 4992; pair
    /// this definition with ``ConnectionType/tcp(host:port:)``:
    ///
    /// ```swift
    /// let rig = try RigController(
    ///     radio: .Flex.flex6000,
    ///     connection: .tcp(host: "flex-6400.local", port: 4992)
    /// )
    /// ```
    ///
    /// Cross-checked against Hamlib `rigs/kenwood/flex6xxx.c`
    /// (`RIG_MODEL_F6K`, `.port_type = RIG_PORT_NETWORK`).
    /// `defaultBaudRate` is moot on TCP but kept for protocol
    /// uniformity — `ConnectionType.tcp` ignores it.
    public static let flex6000 = RadioDefinition(
        manufacturer: .flex,
        model: "6000-series",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Flex.flex6000,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Flex.flex6000
            )
        }
    )

    /// PowerSDR (FlexRadio / Apache Labs) — virtual serial CAT
    /// bridge.
    ///
    /// PowerSDR drives the original FlexRadio 1500/3000/5000A and
    /// Apache Labs ANAN HPSDR boxes. CAT is delivered through a
    /// virtual COM port that PowerSDR's "CAT Control" feature opens
    /// — typically paired with com0com or a Mac equivalent.
    ///
    /// ```swift
    /// let rig = try RigController(
    ///     radio: .Flex.powerSDR,
    ///     connection: .serial(path: "/dev/cu.usbserial-CAT", baudRate: 38400)
    /// )
    /// ```
    ///
    /// Cross-checked against Hamlib `rigs/kenwood/flex6xxx.c`
    /// (`RIG_MODEL_POWERSDR`, `.port_type = RIG_PORT_SERIAL`).
    public static let powerSDR = RadioDefinition(
        manufacturer: .flex,
        model: "PowerSDR",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Flex.powerSDR,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Flex.powerSDR
            )
        }
    )

    /// Thetis (TAPR) — open-source PowerSDR fork.
    ///
    /// Thetis is the TAPR-maintained fork of PowerSDR used with
    /// HPSDR / ANAN hardware. CAT is delivered through a virtual
    /// COM port and uses the same command set as PowerSDR.
    ///
    /// ```swift
    /// let rig = try RigController(
    ///     radio: .Flex.thetis,
    ///     connection: .serial(path: "/dev/cu.usbserial-CAT", baudRate: 38400)
    /// )
    /// ```
    ///
    /// Cross-checked against Hamlib `rigs/kenwood/flex6xxx.c`
    /// (`RIG_MODEL_THETIS`).
    public static let thetis = RadioDefinition(
        manufacturer: .flex,
        model: "Thetis",
        defaultBaudRate: 38400,
        capabilities: RadioCapabilitiesDatabase.Flex.thetis,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Flex.thetis
            )
        }
    )

    // MARK: - v1.2.0 Group I — TS-2000-emulation SDR clients

    /// SDR-Console (Simon Brown) — Windows-first SDR client.
    ///
    /// SDR-Console (`sdr-radio.com`) drives external SDR hardware
    /// through a TS-2000-style Kenwood CAT emulation, typically
    /// paired with a virtual serial port. Cross-checked against
    /// Hamlib `rigs/kenwood/ts2000.c` (`RIG_MODEL_SDRCONSOLE`) —
    /// the Hamlib backend explicitly registers SDR-Console as a
    /// distinct model even though the wire protocol is a TS-2000
    /// subset.
    ///
    /// ```swift
    /// let rig = try RigController(
    ///     radio: .Flex.sdrConsole,
    ///     connection: .serial(path: "/dev/cu.usbserial-CAT", baudRate: 57600)
    /// )
    /// ```
    ///
    /// Per Hamlib the serial link runs 1200-115200 baud; the
    /// factory default (57600) matches the SDR-Console UI's
    /// out-of-the-box value.
    public static let sdrConsole = RadioDefinition(
        manufacturer: .flex,
        model: "SDR-Console",
        defaultBaudRate: 57600,
        capabilities: RadioCapabilitiesDatabase.Flex.sdrConsole,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Flex.sdrConsole
            )
        }
    )

    /// PiHPSDR (OpenHPSDR) — open-source SDR client for HPSDR /
    /// ANAN hardware, most commonly running on Raspberry Pi (also
    /// desktop Linux).
    ///
    /// Cross-checked against Hamlib `rigs/kenwood/pihpsdr.c`
    /// (`RIG_MODEL_HPSDR`) — the header comment cites the file as
    /// "TS-2000 Emulation (derived from ts2000.c)".
    ///
    /// ```swift
    /// let rig = try RigController(
    ///     radio: .Flex.pihpsdr,
    ///     connection: .serial(path: "/dev/cu.usbmodem-CAT", baudRate: 19200)
    /// )
    /// ```
    ///
    /// Per Hamlib the serial link runs 4800-38400 baud; the
    /// factory default (19200) matches PiHPSDR's shipped
    /// configuration.
    public static let pihpsdr = RadioDefinition(
        manufacturer: .flex,
        model: "PiHPSDR",
        defaultBaudRate: 19200,
        capabilities: RadioCapabilitiesDatabase.Flex.pihpsdr,
        protocolFactory: { transport in
            KenwoodProtocol(
                transport: transport,
                capabilities: RadioCapabilitiesDatabase.Flex.pihpsdr
            )
        }
    )
}
