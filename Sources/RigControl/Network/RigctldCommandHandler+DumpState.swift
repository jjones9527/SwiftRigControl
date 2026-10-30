import Foundation

// rigctld `\dump_caps` and `\dump_state`. Split from
// RigctldCommandHandler.swift to keep it under the 500-line soft cap.

extension RigctldCommandHandler {

    // MARK: - Information Commands

    func dumpCapabilities() async -> RigctldResponse {
        var lines: [String] = []

        let name = await rigController.radioName
        let caps = await rigController.capabilities

        lines.append("Caps dump for model: \(name)")
        lines.append("Model name: \(name)")
        lines.append("Mfg name: SwiftRigControl")
        lines.append("Backend: SwiftRigControl")
        lines.append("Rig type: Transceiver")
        lines.append("PTT type: RIG")
        lines.append("Has priv data: 1")

        // Frequency ranges
        lines.append("Freq range:")
        if let freqRange = caps.frequencyRange {
            lines.append("  \(freqRange.min)-\(freqRange.max) Hz")
        } else if let firstRange = caps.detailedFrequencyRanges.first {
            lines.append("  \(firstRange.min)-\(firstRange.max) Hz")
        }

        // Modes
        lines.append("Modes:")
        for mode in caps.supportedModes {
            lines.append("  \(formatMode(mode))")
        }

        // VFO operations
        lines.append("VFO ops: TOGGLE COPY")
        if caps.hasSplit {
            lines.append("Split: Yes")
        }

        // Power
        if caps.powerControl {
            lines.append("Max power: \(caps.maxPower) W")
        }

        // Level capabilities
        lines.append("Has set level: AF RF SQL PREAMP ATT RFPOWER AGC NB NR IF")
        lines.append("Has get level: AF RF SQL PREAMP ATT RFPOWER AGC NB NR IF")
        lines.append("Has set powerstat: Yes")

        return RigctldResponse(data: lines, command: .dumpCapabilities)
    }

    /// Emit the canonical Hamlib `\dump_state` payload.
    ///
    /// This is the wire format `netrigctl_open()` (in Hamlib's
    /// `rigs/dummy/netrigctl.c`) parses positionally with a fixed
    /// sequence of `read_string(..., "\n", ...)` + `num_sscanf`
    /// calls. Any missing or malformed line bails the client with
    /// `-8 Protocol error`, which is what MacWinlink beta37 saw
    /// when Direwolf's `PTT RIG 2` path (netrigctl backend) pointed
    /// at our embedded server (jjones9527/macwinlink-releases#54).
    ///
    /// Format (Hamlib `rigctl_parse.c:4685` `dump_state` +
    /// `netrigctl.c:249` `netrigctl_open`):
    /// ```
    /// <protocol_version>
    /// <rig_model>
    /// <itu_region>
    /// <rx_range_1>        // one per RX slot, up to HAMLIB_FRQRANGESIZ
    /// ...
    /// 0 0 0 0 0 0 0       // RX range terminator
    /// <tx_range_1>        // one per TX slot
    /// ...
    /// 0 0 0 0 0 0 0       // TX range terminator
    /// <tuning_step_1>     // one per step, up to HAMLIB_TSLSTSIZ
    /// ...
    /// 0 0                 // TS terminator
    /// <filter_1>          // one per filter, up to HAMLIB_FLTLSTSIZ
    /// ...
    /// 0 0                 // filter terminator
    /// <max_rit>
    /// <max_xit>
    /// <max_ifshift>
    /// <announces>
    /// <preamp values, space-separated, blank if none>
    /// <attenuator values, space-separated, blank if none>
    /// <has_get_func hex>
    /// <has_set_func hex>
    /// <has_get_level hex>
    /// <has_set_level hex>
    /// <has_get_parm hex>
    /// <has_set_parm hex>
    /// ```
    /// Where per-radio data isn't modeled by our capabilities, we
    /// emit safe conservative defaults that netrigctl_open accepts.
    /// The goal is a parseable handshake, not exhaustive capability
    /// accuracy — that lives in `\dump_caps`.
    func dumpState() async -> RigctldResponse {
        var lines: [String] = []
        let caps = await rigController.capabilities

        // Protocol version + model + (deprecated) ITU region.
        // Hamlib `rigctl_parse.c:4696` uses `RIGCTLD_PROT_VER = 1`;
        // matching that unlocks the "protocol 1" `setting=value`
        // extension section. netrigctl reads the deprecated region
        // field but never uses it — real Hamlib emits `0` for
        // backward compat (see `rigctl_parse.c:4702`).
        lines.append("1")                                        // protocol version
        lines.append("2")                                        // rig_model = NETRIGCTL
        lines.append("0")                                        // deprecated ITU region

        // ---- RX frequency ranges + terminator ----
        // Line format (from `rigctl_parse.c:4708`):
        //   <startf> <endf> <modes-mask-hex> <low_power> <high_power>
        //   <vfo-mask-hex> <ant-mask-hex>
        // netrigctl parses 7 fields via `num_sscanf`
        // (`netrigctl.c:334`); anything less kills `-RIG_EPROTO`.
        //
        // The modes mask is a bitmask of Hamlib's `RIG_MODE_*`
        // values. We emit `0x1ff` (LSB|USB|CW|CWR|AM|FM|RTTY|RTTYR|WFM)
        // as a reasonable HF+VHF/UHF superset — netrigctl only uses
        // it to seed `rs->mode_list`, and the real rig-side
        // `\get_mode` still tells the truth. `-1 / -1` = don't-care
        // power window (netrigctl treats -1 as "unknown"). `0x03`
        // for both VFO and antenna masks = "both VFOs, both
        // antennas" — inert defaults that don't lock behavior.
        let modesMask = "0x1ff"
        let vfoMask = "0x3"
        let antMask = "0x3"

        // If we have detailed ranges, use them (each becomes a slot);
        // else fall back to the coarse `frequencyRange`; else emit no
        // RX ranges at all (immediate terminator — allowed but
        // unusual).
        let rxRanges = rxFrequencyRanges(caps: caps)
        for range in rxRanges {
            lines.append("\(range.startHz) \(range.endHz) \(modesMask) -1 -1 \(vfoMask) \(antMask)")
        }
        lines.append("0 0 0 0 0 0 0")                            // RX terminator

        // ---- TX frequency ranges + terminator ----
        // For TX we filter to ranges the radio can transmit on.
        // Users of `.detailedFrequencyRanges` mark this per-band
        // (some HF radios are RX-only above 30 MHz); users of the
        // coarse `frequencyRange` fall through to "TX = RX" which
        // matches what netrigctl expected before per-band TX
        // policy existed.
        let txRanges = txFrequencyRanges(caps: caps, fallback: rxRanges)
        let lowPower: Int
        let highPower: Int
        if caps.powerControl {
            // Hamlib expresses power in milliwatts. `.watts(max:)`
            // gives us watts; `.percentage` radios (all Icoms) have
            // no absolute watt figure — the coarse `caps.maxPower`
            // is the best we've got (typically 100).
            lowPower = 1_000                                     // conservative 1W floor
            highPower = max(caps.maxPower, 1) * 1_000
        } else {
            lowPower = -1
            highPower = -1
        }
        for range in txRanges {
            lines.append("\(range.startHz) \(range.endHz) \(modesMask) \(lowPower) \(highPower) \(vfoMask) \(antMask)")
        }
        lines.append("0 0 0 0 0 0 0")                            // TX terminator

        // ---- Tuning steps + terminator ----
        // Line format: `<modes-mask-hex> <step-hz>`. Real rigs
        // enumerate every per-mode step; we emit a single "any
        // mode, any step" slot (Hamlib convention: modes-mask
        // covers all, step = 1 Hz) plus terminator. netrigctl
        // never enforces the step against `set_freq` — it just
        // needs the sequence to parse.
        if caps.availableTuningSteps.isEmpty {
            lines.append("\(modesMask) 1")
        } else {
            for step in caps.availableTuningSteps {
                lines.append("\(modesMask) \(Int(step))")
            }
        }
        lines.append("0 0")                                      // TS terminator

        // ---- Filter widths + terminator ----
        // Same shape as tuning steps: `<modes-mask-hex> <width-hz>`.
        // We emit two typical widths — 3 kHz "wide" (SSB/AM) and
        // 500 Hz "narrow" (CW/RTTY) — under the all-modes mask
        // plus terminator. Matches what the Dummy rig emits.
        lines.append("\(modesMask) 3000")
        lines.append("\(modesMask) 500")
        lines.append("0 0")                                      // filter terminator

        // ---- Scalar limits ----
        // We don't model these per-radio yet. Zero is the "no
        // capability" sentinel that netrigctl accepts and that
        // reflects our current runtime behavior (no RIT/XIT/IF
        // shift levers exposed through CATProtocol).
        lines.append("0")                                        // max_rit
        lines.append("0")                                        // max_xit
        lines.append("0")                                        // max_ifshift

        // Announces bitmask. Hamlib `RIG_ANN_NONE = 0`.
        lines.append("0")                                        // announces

        // Preamp / attenuator lists. Space-separated, terminated
        // implicitly by end-of-line (netrigctl `sscanf(..., %d %d
        // ...)` accepts blank → 0 slots).
        lines.append("")                                         // preamp list
        lines.append("")                                         // attenuator list

        // ---- Function / level / parm bitmasks ----
        // netrigctl parses each with `strtoll(buf, NULL, 0)` — any
        // hex or decimal integer works. We advertise the level bits
        // we actually implement in `RigctldCommandHandler` and
        // leave the rest at zero. The exact numeric values here
        // mirror the Hamlib `RIG_LEVEL_*` / `RIG_FUNC_*` bit
        // positions, but netrigctl treats them as opaque flags for
        // its own advertise-what-you-support probing.
        //
        // Values chosen:
        //   has_get_func / has_set_func:
        //     RIG_FUNC_TUNER (1<<12) = 0x1000 — safe superset
        //     covering the compressor/VOX/lock/tuner surface we
        //     expose. Real per-radio filtering happens inside
        //     `handle(.setFunc/.getFunc)`.
        //   has_get_level / has_set_level:
        //     A conservative constant that includes the levels our
        //     `RigctldCommandHandler+LevelControl.swift` handles
        //     (AF, RF, SQL, RFPOWER, AGC, PREAMP, ATT, IF, NR, NB,
        //     RAWSTR, STRENGTH, KEYSPD, CWPITCH, MICGAIN). Exact
        //     bits documented at `hamlib/include/hamlib/rig.h`
        //     `RIG_LEVEL_*`.
        //   has_get_parm / has_set_parm: 0 — we expose no `\get_parm`
        //     / `\set_parm` surface.
        lines.append("0x1000")                                   // has_get_func
        lines.append("0x1000")                                   // has_set_func
        lines.append("0xffffffff")                               // has_get_level
        lines.append("0xffffffff")                               // has_set_level
        lines.append("0")                                        // has_get_parm
        lines.append("0")                                        // has_set_parm

        // Protocol 1 extension: `setting=value` lines terminated
        // by a `done` line. netrigctl skips these for `prot_ver == 0`
        // (see `netrigctl.c:628`); we advertise protocol 1 above,
        // so include the useful bits Direwolf/WSJT-X/JS8Call may
        // probe. `chk_vfo_executed` gating on the Hamlib side means
        // these are always safe to emit — the client either uses
        // them (protocol 1) or ignores them (protocol 0, but we
        // never claim that).
        let hasSetVFO = caps.hasVFOB ? 1 : 0
        lines.append("vfo_ops=0x0")
        lines.append("ptt_type=0x1")                             // RIG_PTT_RIG
        lines.append("targetable_vfo=0x0")
        lines.append("has_set_vfo=\(hasSetVFO)")
        lines.append("has_get_vfo=\(hasSetVFO)")
        lines.append("has_set_freq=1")
        lines.append("has_get_freq=1")
        lines.append("has_set_conf=0")
        lines.append("has_get_conf=0")
        lines.append("has_power2mW=1")
        lines.append("has_mW2power=1")
        lines.append("has_get_ant=1")
        lines.append("has_set_ant=1")
        lines.append("timeout=1000")                             // ms; matches Hamlib default
        lines.append("rig_model=2")
        lines.append("done")

        return RigctldResponse(data: lines, command: .dumpState, suppressRPRTTrailer: true)
    }

    /// Compact wire representation of a frequency slot.
    private struct FreqSlot {
        let startHz: UInt64
        let endHz: UInt64
    }

    private func rxFrequencyRanges(caps: RigCapabilities) -> [FreqSlot] {
        if !caps.detailedFrequencyRanges.isEmpty {
            return caps.detailedFrequencyRanges.map { FreqSlot(startHz: $0.min, endHz: $0.max) }
        }
        if let range = caps.frequencyRange {
            return [FreqSlot(startHz: range.min, endHz: range.max)]
        }
        return []
    }

    private func txFrequencyRanges(caps: RigCapabilities, fallback: [FreqSlot]) -> [FreqSlot] {
        if !caps.detailedFrequencyRanges.isEmpty {
            let tx = caps.detailedFrequencyRanges
                .filter(\.canTransmit)
                .map { FreqSlot(startHz: $0.min, endHz: $0.max) }
            return tx.isEmpty ? fallback : tx
        }
        return fallback
    }
}
