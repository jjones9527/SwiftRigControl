import Foundation

/// In-memory `CATProtocol` implementation that behaves like a generic
/// radio without any real hardware.
///
/// `DummyCATProtocol` is the Swift analogue of Hamlib's Model 1
/// ("Dummy" rig, `rigs/dummy/dummy.c`). It holds frequency, mode, PTT,
/// VFO, power, split, RIT/XIT, DSP, and memory state as actor-isolated
/// fields and returns them on read. There is no transport, no
/// serialization, and no vendor protocol — just a working radio that
/// app developers can drive through the standard `RigController` API.
///
/// ## When to use it
///
/// - **SwiftUI previews.** Build your `RadioControlView` against
///   `RigController(radio: .dummy(), connection: .mock)` and your
///   `#Preview` works with no hardware.
/// - **Demo and example apps.** Ship a working build that doesn't
///   require a connected rig.
/// - **Integration tests for app code.** Test that "PTT button
///   toggles and the indicator updates" without faking byte sequences.
/// - **Tutorials.** Walk newcomers through SwiftRigControl's API
///   without making them buy a radio first.
///
/// ## When NOT to use it
///
/// - **Testing protocol implementations.** Use ``MockSerialTransport``
///   with the real `CATProtocol` (e.g. `IcomCIVProtocol`) instead.
///   `DummyCATProtocol` does not exercise any vendor byte protocol.
/// - **Reproducing radio quirks.** The dummy is "compliant" — it
///   accepts any frequency, any mode, any power level within the
///   advertised capabilities. Real radios reject more than that.
///
/// ## Example
///
/// ```swift
/// let rig = try RigController(radio: .dummy(), connection: .mock)
/// try await rig.connect()
///
/// try await rig.setFrequency(14_230_000, vfo: .a)
/// try await rig.setMode(.usb, vfo: .a)
/// try await rig.setPTT(true)
///
/// let f = try await rig.frequency()       // 14_230_000
/// let m = try await rig.mode()            // .usb
/// let tx = try await rig.isPTTEnabled()   // true
/// ```
public actor DummyCATProtocol: CATProtocol {

    /// A no-op transport used purely to satisfy `CATProtocol`'s
    /// `transport` requirement. The dummy holds all state internally
    /// and never reads from or writes to the transport.
    public let transport: any SerialTransport

    public let capabilities: RigCapabilities

    // MARK: - In-memory state

    private var connected: Bool = false
    private var frequencyByVFO: [VFO: UInt64] = [
        .a: 14_200_000, .b: 14_200_000, .main: 14_200_000, .sub: 144_200_000,
    ]
    private var modeByVFO: [VFO: Mode] = [
        .a: .usb, .b: .usb, .main: .usb, .sub: .fm,
    ]
    private var currentVFO: VFO = .a
    private var pttOn: Bool = false
    private var powerLevel: Int = 50
    private var splitOn: Bool = false
    private var ritState: RITXITState = .disabled
    private var xitState: RITXITState = .disabled
    private var sMeterRaw: Int = 80   // mid-range S-meter, ~S3
    private var agcSpeed: AGCSpeed = .fast
    private var noiseBlanker: NoiseBlanker = .off
    private var noiseReduction: NoiseReduction = .off
    private var ifFilter: IFFilter = .filter1
    private var afGain: Int = 128
    private var rfGain: Int = 255
    private var squelch: Int = 0
    private var preamp: Int = 0
    private var attenuator: Int = 0
    private var powerState: Bool = true
    private var memoryChannels: [Int: MemoryChannel] = [:]
    private let memoryChannelCount: Int = 99

    /// Simulated TX-meter raw values (0–241), one per
    /// ``MeterReading/Kind``. Defaults are plausible idle readings
    /// — RF power 0, SWR 0 (1:1), voltage ~13.8 V, current ~1 A,
    /// etc. Tests / previews override via ``simulateMeter(_:raw:)``.
    private var meterRaw: [MeterReading.Kind: Int] = [
        .rfPower: 0, .swr: 0, .alc: 0, .comp: 0,
        // Voltage default: ~13.8 V on the Icom Vd curve, which
        // linearly maps (13, 10V) → (241, 16V). Solve for 13.8V → raw=157.
        .voltage: 157,
        // Current default: ~1 A on the Id curve (0, 0A) → (97, 10A).
        .current: 10,
    ]

    /// Test/preview helper. When non-nil, every operation on the
    /// dummy throws this error instead of returning a normal value.
    /// Lets tests simulate "the radio went away" without yanking a
    /// USB cable. Not part of `CATProtocol`.
    private var injectedFailure: RigError?

    // MARK: - Initialization

    /// Required by `CATProtocol`. Constructs a dummy with the full
    /// default capability set (`RigCapabilities()` with all flags at
    /// their default true / sensible values).
    public init(transport: any SerialTransport) {
        self.transport = transport
        self.capabilities = RigCapabilities()
    }

    /// Constructs a dummy with caller-supplied capabilities. Use this
    /// to simulate a VHF/UHF-only radio, a QRP rig, or a receiver that
    /// rejects transmit on certain bands.
    public init(transport: any SerialTransport, capabilities: RigCapabilities) {
        self.transport = transport
        self.capabilities = capabilities
    }

    // MARK: - Connection

    public func connect() async throws {
        // The transport is a no-op, but we open it for symmetry with
        // real protocols — anything observing the transport state
        // (e.g. a `MockSerialTransport` wired in for inspection) sees
        // the same lifecycle a real protocol would produce.
        if let injectedFailure {
            throw injectedFailure
        }
        try await transport.open()
        connected = true
    }

    public func disconnect() async {
        connected = false
        await transport.close()
    }

    // MARK: - Frequency

    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws {
        try requireConnected()
        try requireFrequencyValid(hz)
        frequencyByVFO[vfo] = hz
    }

    public func getFrequency(vfo: VFO) async throws -> UInt64 {
        try requireConnected()
        return frequencyByVFO[vfo] ?? frequencyByVFO[.a] ?? 0
    }

    // MARK: - Mode

    public func setMode(_ mode: Mode, vfo: VFO) async throws {
        try requireConnected()
        guard capabilities.supportedModes.contains(mode) else {
            throw RigError.invalidParameter("Mode \(mode) not supported by this radio")
        }
        modeByVFO[vfo] = mode
    }

    public func getMode(vfo: VFO) async throws -> Mode {
        try requireConnected()
        return modeByVFO[vfo] ?? modeByVFO[.a] ?? .usb
    }

    // MARK: - PTT

    public func setPTT(_ enabled: Bool) async throws {
        try requireConnected()
        pttOn = enabled
    }

    public func getPTT() async throws -> Bool {
        try requireConnected()
        return pttOn
    }

    // MARK: - VFO

    public func selectVFO(_ vfo: VFO) async throws {
        try requireConnected()
        currentVFO = vfo
    }

    // MARK: - Power

    public func setPower(_ level: Int) async throws {
        try requireConnected()
        guard capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported")
        }
        powerLevel = max(0, min(level, capabilities.maxPower))
    }

    public func getPower() async throws -> Int {
        try requireConnected()
        guard capabilities.powerControl else {
            throw RigError.unsupportedOperation("Power control not supported")
        }
        return powerLevel
    }

    // MARK: - Split

    public func setSplit(_ enabled: Bool) async throws {
        try requireConnected()
        guard capabilities.hasSplit else {
            throw RigError.unsupportedOperation("Split operation not supported")
        }
        splitOn = enabled
    }

    public func getSplit() async throws -> Bool {
        try requireConnected()
        return splitOn
    }

    // MARK: - Signal strength

    public func getSignalStrength() async throws -> SignalStrength {
        try requireConnected()
        // 0-241 raw range; same encoding used elsewhere in the library.
        let sUnits = min(sMeterRaw / 24, 9)
        let overS9 = sUnits >= 9 ? min((sMeterRaw - 216) / 4, 60) : 0
        return SignalStrength(sUnits: sUnits, overS9: overS9, raw: sMeterRaw)
    }

    /// Test/preview helper — sets the simulated S-meter reading.
    /// Has no analogue on real radios; not part of `CATProtocol`.
    public func simulateSignalStrength(raw: Int) {
        sMeterRaw = max(0, min(raw, 241))
    }

    /// Test/preview helper — when set, every operation throws this
    /// error instead of returning normally. Pass `nil` to clear.
    /// Use to simulate "the radio went away" for connection-health
    /// and reconnect tests. Not part of `CATProtocol`.
    public func simulateFailure(_ error: RigError?) {
        injectedFailure = error
    }

    /// Test/preview helper — sets the simulated raw value the
    /// dummy will return on the next read of the specified TX
    /// meter. Has no analogue on real radios; not part of
    /// `CATProtocol`.
    public func simulateMeter(_ kind: MeterReading.Kind, raw: Int) {
        meterRaw[kind] = max(0, min(raw, 255))
    }

    // MARK: - TX meters

    public func getRFPowerOut() async throws -> MeterReading {
        try requireConnected()
        return MeterReading.decode(kind: .rfPower, raw: meterRaw[.rfPower] ?? 0)
    }

    public func getSWR() async throws -> MeterReading {
        try requireConnected()
        return MeterReading.decode(kind: .swr, raw: meterRaw[.swr] ?? 0)
    }

    public func getALC() async throws -> MeterReading {
        try requireConnected()
        return MeterReading.decode(kind: .alc, raw: meterRaw[.alc] ?? 0)
    }

    public func getComp() async throws -> MeterReading {
        try requireConnected()
        return MeterReading.decode(kind: .comp, raw: meterRaw[.comp] ?? 0)
    }

    public func getVoltage() async throws -> MeterReading {
        try requireConnected()
        return MeterReading.decode(kind: .voltage, raw: meterRaw[.voltage] ?? 0)
    }

    public func getCurrent() async throws -> MeterReading {
        try requireConnected()
        return MeterReading.decode(kind: .current, raw: meterRaw[.current] ?? 0)
    }

    // MARK: - RIT / XIT

    public func setRIT(_ state: RITXITState) async throws {
        try requireConnected()
        ritState = state
    }

    public func getRIT() async throws -> RITXITState {
        try requireConnected()
        return ritState
    }

    public func setXIT(_ state: RITXITState) async throws {
        try requireConnected()
        xitState = state
    }

    public func getXIT() async throws -> RITXITState {
        try requireConnected()
        return xitState
    }

    // MARK: - DSP

    public func setAGC(_ speed: AGCSpeed) async throws {
        try requireConnected()
        agcSpeed = speed
    }

    public func getAGC() async throws -> AGCSpeed {
        try requireConnected()
        return agcSpeed
    }

    public func setNoiseBlanker(_ config: NoiseBlanker) async throws {
        try requireConnected()
        noiseBlanker = config
    }

    public func getNoiseBlanker() async throws -> NoiseBlanker {
        try requireConnected()
        return noiseBlanker
    }

    public func setNoiseReduction(_ config: NoiseReduction) async throws {
        try requireConnected()
        noiseReduction = config
    }

    public func getNoiseReduction() async throws -> NoiseReduction {
        try requireConnected()
        return noiseReduction
    }

    public func setIFFilter(_ filter: IFFilter) async throws {
        try requireConnected()
        ifFilter = filter
    }

    public func getIFFilter() async throws -> IFFilter {
        try requireConnected()
        return ifFilter
    }

    // MARK: - Level controls

    public func setAFGain(_ level: Int) async throws {
        try requireConnected()
        afGain = clamp(level)
    }

    public func getAFGain() async throws -> Int {
        try requireConnected()
        return afGain
    }

    public func setRFGain(_ level: Int) async throws {
        try requireConnected()
        rfGain = clamp(level)
    }

    public func getRFGain() async throws -> Int {
        try requireConnected()
        return rfGain
    }

    public func setSquelch(_ level: Int) async throws {
        try requireConnected()
        squelch = clamp(level)
    }

    public func getSquelch() async throws -> Int {
        try requireConnected()
        return squelch
    }

    public func setPreamp(_ level: Int) async throws {
        try requireConnected()
        preamp = max(0, min(level, 2))
    }

    public func getPreamp() async throws -> Int {
        try requireConnected()
        return preamp
    }

    public func setAttenuator(_ dB: Int) async throws {
        try requireConnected()
        attenuator = max(0, dB)
    }

    public func getAttenuator() async throws -> Int {
        try requireConnected()
        return attenuator
    }

    // MARK: - Power state

    public func setPowerState(_ on: Bool) async throws {
        // Power-state changes are always allowed — they're meta to the
        // radio's CAT loop, not part of normal operation.
        powerState = on
    }

    public func getPowerState() async throws -> Bool {
        powerState
    }

    // MARK: - Memory channels

    public func setMemoryChannel(_ channel: MemoryChannel) async throws {
        try requireConnected()
        memoryChannels[channel.number] = channel
    }

    public func getMemoryChannel(_ number: Int) async throws -> MemoryChannel {
        try requireConnected()
        guard let channel = memoryChannels[number] else {
            throw RigError.commandFailed("Memory channel \(number) is empty")
        }
        return channel
    }

    public func getMemoryChannelCount() async throws -> Int {
        try requireConnected()
        return memoryChannelCount
    }

    public func clearMemoryChannel(_ number: Int) async throws {
        try requireConnected()
        memoryChannels.removeValue(forKey: number)
    }

    // MARK: - Private helpers

    private func requireConnected() throws {
        if let injectedFailure {
            throw injectedFailure
        }
        guard connected else {
            throw RigError.notConnected
        }
    }

    private func requireFrequencyValid(_ hz: UInt64) throws {
        guard let range = capabilities.frequencyRange else {
            return
        }
        guard hz >= range.min, hz <= range.max else {
            throw RigError.invalidParameter(
                "Frequency \(hz) Hz outside dummy radio range \(range.min)–\(range.max) Hz"
            )
        }
    }

    private func clamp(_ value: Int) -> Int {
        max(0, min(value, 255))
    }
}
