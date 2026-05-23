import Foundation

// MARK: - Antenna selection (Phase 4.4)

extension RigController {

    /// Selects the active antenna.
    ///
    /// Indexing is 1-based to match how the operator and the radio
    /// front panel refer to antenna jacks ("ANT 1", "ANT 2"). Most
    /// supported multi-antenna radios have two jacks.
    ///
    /// - Parameter index: Antenna number (1-based), in
    ///   `1...capabilities.antennaCount`.
    /// - Throws:
    ///   - ``RigError/notConnected`` if not connected.
    ///   - ``RigError/unsupportedOperation(_:)`` if the radio does
    ///     not support software antenna selection (i.e.
    ///     `capabilities.antennaCount <= 1`).
    ///   - ``RigError/invalidParameter(_:)`` if `index` is out of
    ///     range.
    ///   - ``RigError/commandFailed(_:)`` if the radio rejects the
    ///     command — common when an optional tuner (e.g., KAT-2 on
    ///     the K2) isn't installed.
    public func selectAntenna(_ index: Int) async throws {
        try requireConnected()
        let p = try requireTrait((any SupportsAntenna).self, named: "Antenna selection")
        try await p.selectAntenna(index)
    }

    /// Reads the currently-selected antenna.
    ///
    /// - Returns: Antenna number (1-based).
    /// - Throws: ``RigError/notConnected``,
    ///   ``RigError/unsupportedOperation(_:)``.
    public func antenna() async throws -> Int {
        try requireConnected()
        let p = try requireTrait((any SupportsAntenna).self, named: "Antenna selection")
        return try await p.getAntenna()
    }

    /// Internal: shared guard.
    private func requireConnected() throws {
        guard connected else { throw RigError.notConnected }
    }
}
