import Foundation

// MARK: - VFO Control

extension RigController {

    /// Selects which VFO is active.
    ///
    /// - Parameter vfo: The VFO to select
    /// - Throws: `RigError` if operation fails
    public func selectVFO(_ vfo: VFO) async throws {
        guard connected else {
            throw RigError.notConnected
        }
        try await proto.selectVFO(vfo)
    }
}
