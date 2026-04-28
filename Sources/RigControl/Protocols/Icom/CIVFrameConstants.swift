import Foundation

// MARK: - CI-V Command and Code Constants

/// Extensions on `CIVFrame` that define the complete set of command codes,
/// sub-command codes, mode codes, and filter codes used by the Icom CI-V protocol.
///
/// Separating these constants from the frame struct itself keeps `CIVFrame.swift`
/// focused on serialisation logic while centralising all "magic bytes" here
/// for easy reference during maintenance.
extension CIVFrame {
    /// CI-V command byte definitions.
    ///
    /// These are the primary command bytes sent in CI-V frames. Many commands
    /// require an additional sub-command byte — see the corresponding `*Code` enum.
    public enum Command {
        // MARK: - Basic Operations
        /// Read band edge frequencies (0x02)
        public static let readBandEdge: UInt8 = 0x02
        /// Read operating frequency (0x03)
        public static let readFrequency: UInt8 = 0x03
        /// Read operating mode (0x04)
        public static let readMode: UInt8 = 0x04
        /// Set operating frequency (0x05)
        public static let setFrequency: UInt8 = 0x05
        /// Set operating mode (0x06)
        public static let setMode: UInt8 = 0x06
        /// Select VFO mode (0x07)
        public static let selectVFO: UInt8 = 0x07

        // MARK: - Memory Operations
        /// Select memory mode (0x08)
        public static let selectMemory: UInt8 = 0x08
        /// Write current settings to memory channel (0x09)
        public static let memoryWrite: UInt8 = 0x09
        /// Copy memory channel contents to active VFO (0x0A)
        public static let memoryToVFO: UInt8 = 0x0A
        /// Clear a memory channel (0x0B)
        public static let memoryClear: UInt8 = 0x0B

        // MARK: - Scan Operations
        /// Scan control — see `ScanCode` for sub-commands (0x0E)
        public static let scan: UInt8 = 0x0E

        // MARK: - Control Operations
        /// Split operation control (0x0F)
        public static let split: UInt8 = 0x0F
        /// Set tuning step — see `TuningStep` for values (0x10)
        public static let tuningStep: UInt8 = 0x10
        /// Attenuator — see `AttenuatorCode` for values (0x11)
        public static let attenuator: UInt8 = 0x11
        /// Antenna selection (0x12)
        public static let antenna: UInt8 = 0x12
        /// Announce / broadcast control — see `AnnounceCode` (0x13)
        public static let announce: UInt8 = 0x13
        /// Set or read transceiver-level settings — see `SettingsCode` (0x14)
        public static let settings: UInt8 = 0x14
        /// Read meter levels — see `LevelRead` (0x15)
        public static let readLevel: UInt8 = 0x15
        /// Toggle radio functions — see `FunctionCode` (0x16)
        public static let function: UInt8 = 0x16

        // MARK: - Advanced Operations
        /// Read transceiver model ID (0x19)
        public static let readID: UInt8 = 0x19
        /// Advanced settings — see `AdvancedCode` (0x1A)
        public static let advancedSettings: UInt8 = 0x1A
        /// Tone control — see `ToneCode` (0x1B)
        public static let tone: UInt8 = 0x1B
        /// PTT control — see sub-command byte for TX/RX (0x1C)
        public static let ptt: UInt8 = 0x1C
        /// TX frequency band selection (0x1E)
        public static let txBand: UInt8 = 0x1E
        /// RIT/XIT control — see `RITXITCode` (0x21)
        public static let ritXit: UInt8 = 0x21
    }

    /// VFO selection sub-commands (used with `Command.selectVFO` 0x07).
    public enum VFOSelect {
        /// Select VFO A (0x00)
        public static let vfoA: UInt8 = 0x00
        /// Select VFO B (0x01)
        public static let vfoB: UInt8 = 0x01
        /// Exchange main and sub bands (0xB0)
        public static let exchangeBands: UInt8 = 0xB0
        /// Equalise main and sub bands — copy main to sub (0xB1)
        public static let equalizeBands: UInt8 = 0xB1
        /// Turn dualwatch off (0xC0)
        public static let dualwatchOff: UInt8 = 0xC0
        /// Turn dualwatch on (0xC1)
        public static let dualwatchOn: UInt8 = 0xC1
        /// Select main receiver (0xD0)
        public static let main: UInt8 = 0xD0
        /// Select sub receiver (0xD1)
        public static let sub: UInt8 = 0xD1
    }

    /// RIT/XIT sub-commands (used with `Command.ritXit` 0x21).
    public enum RITXITCode {
        /// RIT frequency offset (0x00)
        public static let ritFrequency: UInt8 = 0x00
        /// RIT on/off toggle (0x01)
        public static let ritOnOff: UInt8 = 0x01
        /// XIT frequency offset — not supported by all radios (0x02)
        public static let xitFrequency: UInt8 = 0x02
        /// XIT on/off toggle — not supported by all radios (0x03)
        public static let xitOnOff: UInt8 = 0x03
    }

    /// Mode byte values (used as the first data byte in set-mode 0x06 / read-mode 0x04 frames).
    ///
    /// The second data byte carries the filter selection — see `FilterCode`.
    /// Data sub-modes (DATA-USB, DATA-LSB, DATA-FM) reuse the corresponding voice
    /// mode byte and activate DATA mode via `FilterCode.data` (0x00) as the filter byte.
    public enum ModeCode {
        /// LSB — Lower Sideband (0x00)
        public static let lsb: UInt8 = 0x00
        /// USB — Upper Sideband (0x01)
        public static let usb: UInt8 = 0x01
        /// AM — Amplitude Modulation (0x02)
        public static let am: UInt8 = 0x02
        /// CW — Continuous Wave, normal sideband (0x03)
        public static let cw: UInt8 = 0x03
        /// RTTY — Radio Teletype, normal sideband (0x04)
        public static let rtty: UInt8 = 0x04
        /// FM — Narrow-band Frequency Modulation (0x05)
        public static let fm: UInt8 = 0x05
        /// WFM — Wide-band FM, used on broadcast frequencies (0x06)
        public static let wfm: UInt8 = 0x06
        /// CW-R — CW reverse sideband (0x07)
        public static let cwR: UInt8 = 0x07
        /// RTTY-R — RTTY reverse sideband (0x08)
        public static let rttyR: UInt8 = 0x08
        /// PSK — Phase Shift Keying, normal sideband (0x12)
        public static let psk: UInt8 = 0x12
        /// PSK-R — PSK reverse sideband (0x13)
        public static let pskR: UInt8 = 0x13
    }

    /// Filter byte values (second data byte in set-mode 0x06 frames).
    ///
    /// ## Special value: DATA sub-mode (0x00)
    /// When the filter byte is **0x00**, the radio enters its DATA sub-mode for
    /// the given mode code:
    /// - LSB + 0x00 → DATA-LSB
    /// - USB + 0x00 → DATA-USB
    /// - FM  + 0x00 → DATA-FM
    ///
    /// This activates the flat audio path and separate DATA connector/level settings.
    /// Filter bytes 0x01–0x03 select FIL1/FIL2/FIL3 in normal (voice) mode.
    public enum FilterCode {
        /// DATA sub-mode indicator — activates the radio's DATA audio path (0x00)
        public static let data: UInt8 = 0x00
        /// Filter 1 — widest preset bandwidth for the current mode (0x01)
        public static let fil1: UInt8 = 0x01
        /// Filter 2 — medium-width preset bandwidth for the current mode (0x02)
        public static let fil2: UInt8 = 0x02
        /// Filter 3 — narrowest preset bandwidth for the current mode (0x03)
        public static let fil3: UInt8 = 0x03
    }

    /// Scan sub-commands (used with `Command.scan` 0x0E).
    public enum ScanCode {
        /// Stop any ongoing scan (0x00)
        public static let stop: UInt8 = 0x00
        /// Programmed/memory scan start (0x01)
        public static let programmedMemory: UInt8 = 0x01
        /// Programmed scan start (0x02)
        public static let programmed: UInt8 = 0x02
        /// Delta-F scan start (0x03)
        public static let deltaF: UInt8 = 0x03
        /// Fine programmed scan start (0x12)
        public static let fineProgrammed: UInt8 = 0x12
        /// Fine delta-F scan start (0x13)
        public static let fineDeltaF: UInt8 = 0x13
        /// Memory scan start (0x22)
        public static let memory: UInt8 = 0x22
        /// Select-memory scan start (0x23)
        public static let selectMemory: UInt8 = 0x23
        /// Disable scan auto-resume (0xD0)
        public static let resumeOff: UInt8 = 0xD0
        /// Enable scan auto-resume (0xD3)
        public static let resumeOn: UInt8 = 0xD3
    }

    /// Tuning step values (used with `Command.tuningStep` 0x10).
    ///
    /// Selects the frequency increment applied when the main dial is rotated.
    public enum TuningStep {
        /// 10 Hz per step (0x00)
        public static let step10Hz: UInt8 = 0x00
        /// 100 Hz per step (0x01)
        public static let step100Hz: UInt8 = 0x01
        /// 1 kHz per step (0x02)
        public static let step1kHz: UInt8 = 0x02
        /// 2.5 kHz per step (0x03)
        public static let step2_5kHz: UInt8 = 0x03
        /// 5 kHz per step (0x04)
        public static let step5kHz: UInt8 = 0x04
        /// 9 kHz per step — standard AM broadcast channel spacing (0x05)
        public static let step9kHz: UInt8 = 0x05
        /// 10 kHz per step (0x06)
        public static let step10kHz: UInt8 = 0x06
        /// 12.5 kHz per step — standard VHF/UHF FM channel spacing (0x07)
        public static let step12_5kHz: UInt8 = 0x07
        /// 25 kHz per step — wide-band FM channel spacing (0x08)
        public static let step25kHz: UInt8 = 0x08
    }

    /// Attenuator level codes (used with `Command.attenuator` 0x11).
    ///
    /// The dB value is BCD-encoded as the sub-command byte following 0x11.
    /// Not all steps are available on every radio model — consult the manual.
    ///
    /// - IC-7100, IC-705: 0, 6, 12, 18 dB
    /// - IC-7300, IC-7610, IC-7851, IC-7800: 0, 10, 20 dB
    /// - IC-9700: 0, 3, 6, 9, 12 dB
    public enum AttenuatorCode {
        /// Attenuator off — full receive sensitivity (0x00)
        public static let off: UInt8 = 0x00
        /// 3 dB attenuation — IC-9700 only (0x03)
        public static let dB3: UInt8 = 0x03
        /// 6 dB attenuation — IC-7100, IC-705, IC-9700 (0x06)
        public static let dB6: UInt8 = 0x06
        /// 9 dB attenuation — IC-9700 only (0x09)
        public static let dB9: UInt8 = 0x09
        /// 10 dB attenuation — IC-7300, IC-7610, IC-7851, IC-7800 (0x10)
        public static let dB10: UInt8 = 0x10
        /// 12 dB attenuation — IC-7100, IC-705, IC-9700 (0x12)
        public static let dB12: UInt8 = 0x12
        /// 18 dB attenuation — IC-7100, IC-705 (0x18)
        public static let dB18: UInt8 = 0x18
        /// 20 dB attenuation — IC-7300, IC-7610, IC-7851, IC-7800 (0x20)
        public static let dB20: UInt8 = 0x20
        /// 30 dB attenuation — IC-7800 only (0x30)
        public static let dB30: UInt8 = 0x30
    }

    /// Announce sub-commands (used with `Command.announce` 0x13).
    ///
    /// Controls which information the radio broadcasts unsolicited over CI-V.
    public enum AnnounceCode {
        /// Announce all available information (0x00)
        public static let all: UInt8 = 0x00
        /// Announce frequency and S-meter reading only (0x01)
        public static let frequencyAndSMeter: UInt8 = 0x01
        /// Announce operating mode only (0x02)
        public static let mode: UInt8 = 0x02
    }

    /// Settings sub-commands (used with `Command.settings` 0x14).
    ///
    /// Each constant selects a specific transceiver parameter for read or write.
    /// Values are typically BCD-encoded in the frame data bytes.
    public enum SettingsCode {
        /// AF (audio) output level (0x01)
        public static let afLevel: UInt8 = 0x01
        /// RF (receiver) gain level (0x02)
        public static let rfLevel: UInt8 = 0x02
        /// Squelch level (0x03)
        public static let squelchLevel: UInt8 = 0x03
        /// Noise reduction (NR) level (0x06)
        public static let nrLevel: UInt8 = 0x06
        /// Inner twin passband tuning (PBT) position (0x07)
        public static let innerPBT: UInt8 = 0x07
        /// Outer twin passband tuning (PBT) position (0x08)
        public static let outerPBT: UInt8 = 0x08
        /// CW pitch frequency (0x09)
        public static let cwPitch: UInt8 = 0x09
        /// RF transmit power level (0x0A)
        public static let rfPower: UInt8 = 0x0A
        /// Microphone gain (0x0B)
        public static let micGain: UInt8 = 0x0B
        /// CW keyer speed in WPM (0x0C)
        public static let keySpeed: UInt8 = 0x0C
        /// Manual notch filter position (0x0D)
        public static let notchPosition: UInt8 = 0x0D
        /// Speech compressor level (0x0E)
        public static let compLevel: UInt8 = 0x0E
        /// CW break-in delay (0x0F)
        public static let breakInDelay: UInt8 = 0x0F
        /// Main/sub balance position (0x10)
        public static let balance: UInt8 = 0x10
        /// Noise blanker (NB) level (0x12)
        public static let nbLevel: UInt8 = 0x12
        /// Drive gain (0x14)
        public static let driveGain: UInt8 = 0x14
        /// Monitor level (sidetone / TX monitor) (0x15)
        public static let monitorGain: UInt8 = 0x15
        /// VOX sensitivity (0x16)
        public static let voxGain: UInt8 = 0x16
        /// Anti-VOX sensitivity (0x17)
        public static let antiVoxGain: UInt8 = 0x17
        /// Display brightness level (0x19)
        public static let brightLevel: UInt8 = 0x19
    }

    /// Meter level sub-commands (used with `Command.readLevel` 0x15).
    ///
    /// Returns a two-byte BCD value in the data field representing the current
    /// meter reading (0000–0255).
    public enum LevelRead {
        /// Squelch open/closed status (0x01)
        public static let squelch: UInt8 = 0x01
        /// Receive S-meter level (0x02)
        public static let sMeter: UInt8 = 0x02
        /// Transmit RF power meter (0x11)
        public static let rfPowerMeter: UInt8 = 0x11
        /// SWR meter (0x12)
        public static let swrMeter: UInt8 = 0x12
        /// ALC meter (0x13)
        public static let alcMeter: UInt8 = 0x13
        /// Compression meter (0x14)
        public static let compMeter: UInt8 = 0x14
        /// Supply voltage meter (0x15)
        public static let vdMeter: UInt8 = 0x15
        /// PA current meter (0x16)
        public static let idMeter: UInt8 = 0x16
    }

    /// Function toggle sub-commands (used with `Command.function` 0x16).
    ///
    /// Sends 0x00 (off) or 0x01 (on) as the data byte to enable/disable each function.
    public enum FunctionCode {
        /// Preamplifier — see `PreampCode` for level values (0x02)
        public static let preamp: UInt8 = 0x02
        /// Automatic Gain Control speed — see `AGCCode` (0x12)
        public static let agc: UInt8 = 0x12
        /// Noise blanker on/off (0x22)
        public static let noiseBlanker: UInt8 = 0x22
        /// Audio peak filter on/off (0x32)
        public static let audioPeakFilter: UInt8 = 0x32
        /// Noise reduction on/off (0x40)
        public static let noiseReduction: UInt8 = 0x40
        /// Auto-notch filter on/off (0x41)
        public static let autoNotch: UInt8 = 0x41
        /// Repeater CTCSS/DCS tone on/off (0x42)
        public static let repeaterTone: UInt8 = 0x42
        /// Tone squelch on/off (0x43)
        public static let toneSquelch: UInt8 = 0x43
        /// Speech compressor on/off (0x44)
        public static let speechCompressor: UInt8 = 0x44
        /// TX monitor on/off (0x45)
        public static let monitor: UInt8 = 0x45
        /// VOX on/off (0x46)
        public static let vox: UInt8 = 0x46
        /// CW break-in on/off (0x47)
        public static let breakIn: UInt8 = 0x47
        /// Manual notch on/off (0x48)
        public static let manualNotch: UInt8 = 0x48
        /// Twin peak filter on/off (0x4F)
        public static let twinPeakFilter: UInt8 = 0x4F
        /// Dial lock on/off (0x50)
        public static let dialLock: UInt8 = 0x50
    }

    /// Preamplifier level codes (used with `FunctionCode.preamp`).
    ///
    /// Not all radios have two preamp stages; consult the radio manual.
    public enum PreampCode {
        /// Preamplifier off — no added gain (0x00)
        public static let off: UInt8 = 0x00
        /// Preamp stage 1 — typically +10 dB (0x01)
        public static let preamp1: UInt8 = 0x01
        /// Preamp stage 2 — typically +20 dB; not available on all models (0x02)
        public static let preamp2: UInt8 = 0x02
    }

    /// AGC time-constant codes (used with `FunctionCode.agc` = 0x16/0x12).
    ///
    /// These are the canonical CI-V AGC byte values as used by Hamlib/rigctld.
    /// Note the non-sequential ordering: FAST=0x02, SLOW=0x03, MID=0x05.
    public enum AGCCode {
        /// AGC off — no automatic gain control (0x00)
        public static let off: UInt8 = 0x00
        /// Superfast AGC — very rapid gain recovery (0x01)
        public static let superFast: UInt8 = 0x01
        /// Fast AGC — rapid gain recovery; recommended for CW and digital modes (0x02)
        public static let fast: UInt8 = 0x02
        /// Slow AGC — gradual recovery; recommended for SSB and AM voice (0x03)
        public static let slow: UInt8 = 0x03
        /// User-defined AGC time constant (0x04)
        public static let user: UInt8 = 0x04
        /// Medium AGC — balanced recovery; suitable for most modes (0x05)
        public static let mid: UInt8 = 0x05
        /// Auto AGC — radio selects speed based on mode (0x06)
        public static let auto: UInt8 = 0x06
    }

    /// Advanced-settings sub-commands (used with `Command.advancedSettings` 0x1A).
    public enum AdvancedCode {
        /// Memory channel contents (0x00)
        public static let memoryContents: UInt8 = 0x00
        /// Band stacking register (0x01)
        public static let bandStacking: UInt8 = 0x01
        /// CW memory keyer contents (0x02)
        public static let memoryKeyer: UInt8 = 0x02
        /// IF filter width setting (0x03)
        public static let filterWidth: UInt8 = 0x03
        /// AGC time constant (0x04)
        public static let agcTimeConstant: UInt8 = 0x04
        /// Miscellaneous radio settings (0x05)
        public static let variousSettings: UInt8 = 0x05
    }

    /// Tone sub-commands (used with `Command.tone` 0x1B).
    public enum ToneCode {
        /// Repeater tone (CTCSS) frequency (0x00)
        public static let repeaterTone: UInt8 = 0x00
        /// Tone squelch (CTCSS) frequency (0x01)
        public static let toneSquelch: UInt8 = 0x01
    }
}
