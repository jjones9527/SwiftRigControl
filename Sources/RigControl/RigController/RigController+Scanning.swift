import Foundation

// MARK: - Scanning (Phase 4.3)

extension RigController {

    /// Starts a scan on the radio.
    ///
    /// Scans run asynchronously inside the radio — this call
    /// returns immediately, and the radio continues scanning until
    /// it finds a signal, the operator presses a front-panel
    /// button, or you call ``stopScan()``.
    ///
    /// SwiftRigControl does NOT change the radio's VFO or memory
    /// selection on your behalf. If you want a memory scan and the
    /// radio is in VFO mode, recall a memory channel first.
    /// (Hamlib silently switches modes here; we don't, because the
    /// side effect is surprising and hides bugs.)
    ///
    /// - Parameter kind: Which scan mode to start. See ``ScanKind``
    ///   for the per-radio support matrix.
    /// - Throws:
    ///   - ``RigError/notConnected`` if not connected.
    ///   - ``RigError/unsupportedOperation(_:)`` if the radio does
    ///     not advertise the requested scan kind. Check the matching
    ///     `RigCapabilities.supports*Scan` flag to gate UI elements.
    public func startScan(_ kind: ScanKind) async throws {
        try requireConnected()
        let p = try requireTrait((any SupportsScanning).self, named: "Scanning")
        try await p.startScan(kind)
    }

    /// Stops any scan currently in progress. Safe to call when no
    /// scan is active.
    ///
    /// - Throws: ``RigError/notConnected`` if not connected,
    ///   ``RigError/unsupportedOperation(_:)`` if the radio does
    ///   not support scanning at all.
    public func stopScan() async throws {
        try requireConnected()
        let p = try requireTrait((any SupportsScanning).self, named: "Scanning")
        try await p.stopScan()
    }

    /// Internal: shared guard.
    private func requireConnected() throws {
        guard connected else { throw RigError.notConnected }
    }
}
