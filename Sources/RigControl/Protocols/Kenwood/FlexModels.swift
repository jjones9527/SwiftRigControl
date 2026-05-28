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
}
