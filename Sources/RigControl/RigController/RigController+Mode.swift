import Foundation

// MARK: - Mode Control

extension RigController {

    /// Sets the operating mode of the specified VFO.
    ///
    /// - Parameters:
    ///   - mode: The desired operating mode
    ///   - vfo: The VFO to set (defaults to VFO A)
    ///
    /// - Throws: `RigError` if operation fails
    ///
    /// - Example:
    /// ```swift
    /// try await rig.setMode(.usb, vfo: .a)  // USB for SSTV on 20m
    /// ```
    public func setMode(_ mode: Mode, vfo: VFO = .a) async throws {
        guard connected else {
            throw RigError.notConnected
        }
        try await proto.setMode(mode, vfo: vfo)
        // Invalidate cached mode for this VFO
        await stateCache.invalidate("mode_\(vfo)")
    }

    /// Gets the current operating mode of the specified VFO.
    ///
    /// - Parameters:
    ///   - vfo: The VFO to query (defaults to VFO A)
    ///   - cached: Whether to use cached value if available (defaults to true)
    /// - Returns: The current operating mode
    /// - Throws: `RigError` if operation fails
    ///
    /// # Caching
    /// When `cached` is true, returns cached mode if available and recent.
    /// Set `cached` to false to force a fresh query.
    public func mode(vfo: VFO = .a, cached: Bool = true) async throws -> Mode {
        guard connected else {
            throw RigError.notConnected
        }

        if cached,
           let value: Mode = await stateCache.getIfValid("mode_\(vfo)", maxAge: 0.5) {
            return value
        }
        if !cached {
            await stateCache.invalidate("mode_\(vfo)")
        }
        let value = try await proto.getMode(vfo: vfo)
        await stateCache.store(value, forKey: "mode_\(vfo)")
        return value
    }
}
