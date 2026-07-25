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
    /// > Note: Requires a **Windows** PC running PowerSDR. PowerSDR
    /// > itself is Windows-only; this definition targets the virtual
    /// > COM port PowerSDR exposes. A Mac alone cannot drive this
    /// > radio — connect from macOS to a Windows machine over a
    /// > serial-over-network tunnel (e.g. `socat`, `com2tcp`) whose
    /// > endpoint on the Windows side is PowerSDR's CAT port.
    /// > See ``RadioDefinition/hostRequirement`` /
    /// > ``RadioDefinition/HostRequirement/windowsCompanion(app:)``.
    ///
    /// PowerSDR drives the original FlexRadio 1500/3000/5000A and
    /// Apache Labs ANAN HPSDR boxes.
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
        },
        hostRequirement: .windowsCompanion(app: "PowerSDR")
    )

    /// Thetis (TAPR) — open-source PowerSDR fork.
    ///
    /// > Note: Requires a **Windows** PC running Thetis. Thetis is
    /// > Windows-only; this definition targets the virtual COM port
    /// > Thetis exposes for CAT control. A Mac alone cannot drive
    /// > this radio — connect from macOS to the Windows machine over
    /// > a serial-over-network tunnel. See
    /// > ``RadioDefinition/hostRequirement`` /
    /// > ``RadioDefinition/HostRequirement/windowsCompanion(app:)``.
    ///
    /// Thetis is the TAPR-maintained fork of PowerSDR used with
    /// HPSDR / ANAN hardware.
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
        },
        hostRequirement: .windowsCompanion(app: "Thetis")
    )

    // MARK: - v1.2.0 Group I — TS-2000-emulation SDR clients

    /// SDR-Console (Simon Brown) — Windows-first SDR client.
    ///
    /// > Note: Requires a **Windows** PC running SDR-Console.
    /// > SDR-Console (`sdr-radio.com`) is Windows-only; this
    /// > definition targets the virtual serial port SDR-Console
    /// > exposes for CAT control. A Mac alone cannot drive this
    /// > radio — connect from macOS to the Windows machine over a
    /// > serial-over-network tunnel. See
    /// > ``RadioDefinition/hostRequirement`` /
    /// > ``RadioDefinition/HostRequirement/windowsCompanion(app:)``.
    ///
    /// SDR-Console drives external SDR hardware through a
    /// TS-2000-style Kenwood CAT emulation. Cross-checked against
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
        },
        hostRequirement: .windowsCompanion(app: "SDR-Console")
    )

    /// PiHPSDR (OpenHPSDR) — open-source SDR client for HPSDR /
    /// ANAN hardware, most commonly running on Raspberry Pi (also
    /// desktop Linux).
    ///
    /// > Note: Requires a **Linux** or **Raspberry Pi** host running
    /// > PiHPSDR. PiHPSDR does not run on macOS; this definition
    /// > targets the virtual serial port PiHPSDR exposes for CAT
    /// > control. A Mac alone cannot drive this radio — connect
    /// > from macOS to the Pi/Linux machine over a
    /// > serial-over-network tunnel (e.g. `socat`). See
    /// > ``RadioDefinition/hostRequirement`` /
    /// > ``RadioDefinition/HostRequirement/linuxCompanion(app:)``.
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
        },
        hostRequirement: .linuxCompanion(app: "PiHPSDR")
    )
}
