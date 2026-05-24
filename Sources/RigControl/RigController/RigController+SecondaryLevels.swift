import Foundation

// MARK: - Secondary level controls (v1.1 parity)

extension RigController {

    /// Sets microphone gain (0-100).
    public func setMicGain(_ level: Int) async throws {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait((any SupportsMicGain).self, named: "Mic gain")
        try await p.setMicGain(level)
    }

    /// Reads microphone gain (0-100).
    public func micGain() async throws -> Int {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait((any SupportsMicGain).self, named: "Mic gain")
        return try await p.getMicGain()
    }

    /// Sets the speech compressor *level* (0-100). Distinct from
    /// the on/off toggle — see ``setFunction(_:enabled:)`` with
    /// ``RigFunction/compressor``.
    public func setCompressorLevel(_ level: Int) async throws {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait((any SupportsCompressorLevel).self, named: "Compressor level")
        try await p.setCompressorLevel(level)
    }

    /// Reads the compressor level (0-100).
    public func compressorLevel() async throws -> Int {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait((any SupportsCompressorLevel).self, named: "Compressor level")
        return try await p.getCompressorLevel()
    }

    /// Sets the sidetone-monitor gain (0-100).
    public func setMonitorGain(_ level: Int) async throws {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait((any SupportsMonitorGain).self, named: "Monitor gain")
        try await p.setMonitorGain(level)
    }

    /// Reads the sidetone-monitor gain (0-100).
    public func monitorGain() async throws -> Int {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait((any SupportsMonitorGain).self, named: "Monitor gain")
        return try await p.getMonitorGain()
    }

    /// Sets VOX gain / sensitivity (0-100).
    public func setVOXGain(_ level: Int) async throws {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait((any SupportsVOXGain).self, named: "VOX gain")
        try await p.setVOXGain(level)
    }

    /// Reads VOX gain / sensitivity (0-100).
    public func voxGain() async throws -> Int {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait((any SupportsVOXGain).self, named: "VOX gain")
        return try await p.getVOXGain()
    }

    /// Sets VOX delay / hang time (0-100, scaled per-radio).
    public func setVOXDelay(_ level: Int) async throws {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait((any SupportsVOXDelay).self, named: "VOX delay")
        try await p.setVOXDelay(level)
    }

    /// Reads VOX delay / hang time (0-100, scaled per-radio).
    public func voxDelay() async throws -> Int {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait((any SupportsVOXDelay).self, named: "VOX delay")
        return try await p.getVOXDelay()
    }

    /// Sets IF shift (0-100, centred at 50).
    public func setIFShift(_ level: Int) async throws {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait((any SupportsIFShift).self, named: "IF shift")
        try await p.setIFShift(level)
    }

    /// Reads IF shift (0-100, centred at 50).
    public func ifShift() async throws -> Int {
        guard connected else { throw RigError.notConnected }
        let p = try requireTrait((any SupportsIFShift).self, named: "IF shift")
        return try await p.getIFShift()
    }
}
