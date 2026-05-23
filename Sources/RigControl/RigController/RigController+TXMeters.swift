import Foundation

// MARK: - Transmit-side meter readings (Phase 4.1)

extension RigController {

    /// Reads the RF power output meter.
    ///
    /// Returns a ``MeterReading`` whose ``MeterReading/watts``
    /// accessor gives the calibrated output power in watts and
    /// ``MeterReading/normalized`` gives a 0..1 fraction-of-max
    /// suitable for a UI bar.
    ///
    /// Only meaningful during transmission. Reading while the radio
    /// is in receive returns a 0-valued reading (the meter is at
    /// rest), not an error.
    ///
    /// - Throws:
    ///   - ``RigError/notConnected`` if not connected.
    ///   - ``RigError/unsupportedOperation(_:)`` if the radio does
    ///     not expose an RF power meter (see
    ///     ``RigCapabilities/supportsRFPowerMeter``).
    public func rfPowerOut() async throws -> MeterReading {
        try requireConnected()
        let p = try requireTrait((any SupportsTXMeters).self, named: "RF power meter")
        return try await p.getRFPowerOut()
    }

    /// Reads the SWR meter. See ``MeterReading/swrRatio`` for the
    /// X:1 ratio. Only meaningful during transmission.
    ///
    /// - Throws: ``RigError/notConnected``,
    ///   ``RigError/unsupportedOperation(_:)``.
    public func swr() async throws -> MeterReading {
        try requireConnected()
        let p = try requireTrait((any SupportsTXMeters).self, named: "SWR meter")
        return try await p.getSWR()
    }

    /// Reads the ALC meter. Only ``MeterReading/normalized`` is
    /// meaningful (ALC has no standard physical unit). Only
    /// meaningful during transmission.
    ///
    /// - Throws: ``RigError/notConnected``,
    ///   ``RigError/unsupportedOperation(_:)``.
    public func alc() async throws -> MeterReading {
        try requireConnected()
        let p = try requireTrait((any SupportsTXMeters).self, named: "ALC meter")
        return try await p.getALC()
    }

    /// Reads the speech-compressor meter. See ``MeterReading/dB``
    /// for the compression amount.
    ///
    /// - Throws: ``RigError/notConnected``,
    ///   ``RigError/unsupportedOperation(_:)``.
    public func comp() async throws -> MeterReading {
        try requireConnected()
        let p = try requireTrait((any SupportsTXMeters).self, named: "Compressor meter")
        return try await p.getComp()
    }

    /// Reads the drain / supply voltage meter. See
    /// ``MeterReading/volts`` for the value.
    ///
    /// - Throws: ``RigError/notConnected``,
    ///   ``RigError/unsupportedOperation(_:)``.
    public func voltage() async throws -> MeterReading {
        try requireConnected()
        let p = try requireTrait((any SupportsTXMeters).self, named: "Voltage meter")
        return try await p.getVoltage()
    }

    /// Reads the drain / collector current meter. See
    /// ``MeterReading/amps`` for the value.
    ///
    /// - Throws: ``RigError/notConnected``,
    ///   ``RigError/unsupportedOperation(_:)``.
    public func current() async throws -> MeterReading {
        try requireConnected()
        let p = try requireTrait((any SupportsTXMeters).self, named: "Current meter")
        return try await p.getCurrent()
    }

    /// Internal: shared guard used by every TX-meter accessor.
    private func requireConnected() throws {
        guard connected else {
            throw RigError.notConnected
        }
    }
}
