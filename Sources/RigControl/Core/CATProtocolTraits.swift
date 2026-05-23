import Foundation

// MARK: - Capability trait protocols (Phase 5.1)
//
// Each trait below is a refinement of CATProtocol that adds the
// methods for one specific radio feature. Protocols *opt in* to
// the traits they actually support — there are no "throws on
// unsupported" default implementations to inherit by accident.
//
// Rationale: a fat protocol with default-throw extensions allows
// a conformer to silently "support" a feature it doesn't actually
// implement (by inheriting the default). With trait protocols
// the conformance list is the contract: if a radio doesn't list
// `SupportsAGC`, calling `setAGC` on it will throw
// `.unsupportedOperation` *and the compiler can see this*.
//
// RigController dispatches each call via `as? any SupportsX` so
// app code keeps using the same `rig.setAGC(.fast)` shape it
// always has — only the internal dispatch and the error source
// changed.
//
// Naming convention: `Supports<Feature>` (parallels
// `RigCapabilities.supports*` flags). Unusual for Swift but
// makes the type-predicate reading natural:
// `proto is any SupportsDSP`.

// MARK: - Power control

/// Conforming radios support setting and reading RF transmit power.
public protocol SupportsPower: CATProtocol {
    /// See ``CATProtocol`` doc on the protocol-wide setPower
    /// for the unit semantics (depends on
    /// ``RigCapabilities/powerUnits``).
    func setPower(_ level: Int) async throws

    /// Reads the current RF power level in the radio's native units.
    func getPower() async throws -> Int
}

// MARK: - Split operation

/// Conforming radios support split-VFO operation
/// (receive on one VFO, transmit on another).
public protocol SupportsSplit: CATProtocol {
    /// Enables or disables split.
    func setSplit(_ enabled: Bool) async throws

    /// Returns `true` if split is currently enabled.
    func getSplit() async throws -> Bool
}

// MARK: - Signal strength

/// Conforming radios expose an S-meter reading.
public protocol SupportsSignalStrength: CATProtocol {
    /// Reads the current receive signal strength.
    func getSignalStrength() async throws -> SignalStrength
}

// MARK: - RIT / XIT

/// Conforming radios support Receiver Incremental Tuning.
public protocol SupportsRIT: CATProtocol {
    /// Sets the RIT enabled state and offset.
    func setRIT(_ state: RITXITState) async throws

    /// Reads the current RIT state.
    func getRIT() async throws -> RITXITState
}

/// Conforming radios support Transmitter Incremental Tuning.
public protocol SupportsXIT: CATProtocol {
    /// Sets the XIT enabled state and offset.
    func setXIT(_ state: RITXITState) async throws

    /// Reads the current XIT state.
    func getXIT() async throws -> RITXITState
}

// MARK: - DSP

/// Conforming radios expose Automatic Gain Control.
public protocol SupportsAGC: CATProtocol {
    func setAGC(_ speed: AGCSpeed) async throws
    func getAGC() async throws -> AGCSpeed
}

/// Conforming radios expose the noise blanker.
public protocol SupportsNoiseBlanker: CATProtocol {
    func setNoiseBlanker(_ config: NoiseBlanker) async throws
    func getNoiseBlanker() async throws -> NoiseBlanker
}

/// Conforming radios expose noise reduction (DSP NR).
public protocol SupportsNoiseReduction: CATProtocol {
    func setNoiseReduction(_ config: NoiseReduction) async throws
    func getNoiseReduction() async throws -> NoiseReduction
}

/// Conforming radios expose IF filter selection.
public protocol SupportsIFFilter: CATProtocol {
    func setIFFilter(_ filter: IFFilter) async throws
    func getIFFilter() async throws -> IFFilter
}

// MARK: - Audio / RF levels

/// Conforming radios expose AF (audio) gain control.
public protocol SupportsAFGain: CATProtocol {
    func setAFGain(_ level: Int) async throws
    func getAFGain() async throws -> Int
}

/// Conforming radios expose RF (receiver) gain control.
public protocol SupportsRFGain: CATProtocol {
    func setRFGain(_ level: Int) async throws
    func getRFGain() async throws -> Int
}

/// Conforming radios expose a squelch level.
public protocol SupportsSquelch: CATProtocol {
    func setSquelch(_ level: Int) async throws
    func getSquelch() async throws -> Int
}

/// Conforming radios expose the front-end preamplifier.
public protocol SupportsPreamp: CATProtocol {
    func setPreamp(_ level: Int) async throws
    func getPreamp() async throws -> Int
}

/// Conforming radios expose the front-end attenuator.
public protocol SupportsAttenuator: CATProtocol {
    func setAttenuator(_ dB: Int) async throws
    func getAttenuator() async throws -> Int
}

// MARK: - Power state

/// Conforming radios support remote power on/off via CAT.
public protocol SupportsRemotePowerState: CATProtocol {
    func setPowerState(_ on: Bool) async throws
    func getPowerState() async throws -> Bool
}

// MARK: - Memory channels

/// Conforming radios support memory channel storage and recall.
public protocol SupportsMemoryChannels: CATProtocol {
    func setMemoryChannel(_ channel: MemoryChannel) async throws
    func getMemoryChannel(_ number: Int) async throws -> MemoryChannel
    func getMemoryChannelCount() async throws -> Int
    func clearMemoryChannel(_ number: Int) async throws
}

// MARK: - Transmit meters (Phase 4.1)

/// Conforming radios expose transmit-side meter readings.
///
/// Not every conformer supports every meter — the per-meter
/// `supports*Meter` flags on ``RigCapabilities`` are still the
/// authoritative gate for *which* meters work. Conforming to
/// `SupportsTXMeters` only declares that the radio exposes the
/// metering API at all (so the type system knows about the
/// methods).
public protocol SupportsTXMeters: CATProtocol {
    func getRFPowerOut() async throws -> MeterReading
    func getSWR() async throws -> MeterReading
    func getALC() async throws -> MeterReading
    func getComp() async throws -> MeterReading
    func getVoltage() async throws -> MeterReading
    func getCurrent() async throws -> MeterReading
}

// MARK: - CW (Phase 4.2)

/// Conforming radios expose the built-in CW keyer
/// (speed / pitch / break-in mode).
public protocol SupportsCWKeyer: CATProtocol {
    func setCWSpeed(_ speed: CWSpeed) async throws
    func getCWSpeed() async throws -> CWSpeed
    func setCWPitch(_ pitch: CWPitch) async throws
    func getCWPitch() async throws -> CWPitch
    func setBreakIn(_ mode: BreakInMode) async throws
    func getBreakIn() async throws -> BreakInMode
}

/// Conforming radios support radio-generated CW message
/// transmission (text → Morse via CAT).
public protocol SupportsSendCW: CATProtocol {
    func sendCW(_ text: String) async throws
    func stopCW() async throws
}

// MARK: - Scanning (Phase 4.3)

/// Conforming radios support scan control. *Which* scan kinds
/// the radio actually accepts is gated by the `supports*Scan`
/// flags on ``RigCapabilities``.
public protocol SupportsScanning: CATProtocol {
    func startScan(_ kind: ScanKind) async throws
    func stopScan() async throws
}

// MARK: - Antenna (Phase 4.4)

/// Conforming radios support software antenna selection.
public protocol SupportsAntenna: CATProtocol {
    func selectAntenna(_ index: Int) async throws
    func getAntenna() async throws -> Int
}
