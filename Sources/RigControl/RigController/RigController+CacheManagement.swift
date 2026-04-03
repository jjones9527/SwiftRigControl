import Foundation

// MARK: - Cache Management

extension RigController {

    /// Manually invalidate all cached state.
    ///
    /// This forces all subsequent queries to fetch fresh data from the radio.
    /// Useful after manual radio adjustments or when cache inconsistency is suspected.
    ///
    /// - Example:
    /// ```swift
    /// // After manual radio adjustments
    /// await rig.invalidateCache()
    /// let freshFreq = try await rig.frequency()
    /// ```
    public func invalidateCache() async {
        await stateCache.invalidate()
    }

    /// Get cache statistics for debugging.
    ///
    /// - Returns: Statistics about the current cache state
    public func cacheStatistics() async -> CacheStatistics {
        await stateCache.statistics()
    }
}
