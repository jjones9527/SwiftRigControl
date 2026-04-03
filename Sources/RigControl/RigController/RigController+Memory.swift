import Foundation

// MARK: - Memory Channel Operations

extension RigController {

    /// Stores a configuration to a memory channel.
    ///
    /// Writes the specified memory channel configuration to the radio's non-volatile memory.
    /// The channel can be recalled later for quick frequency/mode changes.
    ///
    /// - Parameter channel: Memory channel configuration to store
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if memory channels not supported
    ///   - `RigError.commandFailed` if radio rejects the channel configuration
    ///
    /// # Example
    /// ```swift
    /// // Create a memory channel for 20m FT8
    /// let channel = MemoryChannel(
    ///     number: 1,
    ///     frequency: 14_074_000,
    ///     mode: .dataUSB,
    ///     name: "20m FT8"
    /// )
    /// try await rig.setMemoryChannel(channel)
    /// ```
    public func setMemoryChannel(_ channel: MemoryChannel) async throws {
        guard connected else {
            throw RigError.notConnected
        }

        try await proto.setMemoryChannel(channel)
        // Invalidate cached channel data
        await stateCache.invalidate("mem_\(channel.number)")
    }

    /// Reads a memory channel configuration from the radio.
    ///
    /// Retrieves the stored configuration for the specified memory channel number.
    ///
    /// - Parameter number: Memory channel number to read
    /// - Returns: Memory channel configuration
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if memory channels not supported
    ///   - `RigError.commandFailed` if channel is empty or invalid
    ///
    /// # Example
    /// ```swift
    /// let channel = try await rig.getMemoryChannel(1)
    /// print("Channel \(channel.number): \(channel.description)")
    /// // "Ch 1 (20m FT8): 14.074 MHz dataUSB"
    /// ```
    public func getMemoryChannel(_ number: Int) async throws -> MemoryChannel {
        guard connected else {
            throw RigError.notConnected
        }

        return try await proto.getMemoryChannel(number)
    }

    /// Gets the total number of memory channels supported by the radio.
    ///
    /// Returns the maximum number of user-programmable memory channels.
    /// This may not include special channels (call channels, program scan edges, etc.).
    ///
    /// - Returns: Number of memory channels (e.g., 99, 100, 109)
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if memory not supported
    ///
    /// # Example
    /// ```swift
    /// let count = try await rig.memoryChannelCount()
    /// print("\(radioName) supports \(count) memory channels")
    /// ```
    public func memoryChannelCount() async throws -> Int {
        guard connected else {
            throw RigError.notConnected
        }

        return try await proto.getMemoryChannelCount()
    }

    /// Clears (erases) a memory channel.
    ///
    /// Removes the configuration from the specified memory channel, making it empty.
    ///
    /// - Parameter number: Memory channel number to clear
    /// - Throws:
    ///   - `RigError.notConnected` if not connected
    ///   - `RigError.unsupportedOperation` if memory not supported
    ///   - `RigError.commandFailed` if operation fails
    ///
    /// # Example
    /// ```swift
    /// try await rig.clearMemoryChannel(1)
    /// ```
    public func clearMemoryChannel(_ number: Int) async throws {
        guard connected else {
            throw RigError.notConnected
        }

        try await proto.clearMemoryChannel(number)
        // Invalidate cached channel data
        await stateCache.invalidate("mem_\(number)")
    }

    /// Recalls a memory channel configuration to the current VFO.
    ///
    /// Reads the specified memory channel and applies its frequency and mode to the current VFO.
    /// This is a convenience method that combines reading a channel and applying its settings.
    ///
    /// - Parameters:
    ///   - number: Memory channel number to recall
    ///   - vfo: Target VFO (default: .a)
    /// - Throws: `RigError` if operation fails or channel is empty
    ///
    /// # Example
    /// ```swift
    /// // Recall channel 1 settings to VFO A
    /// try await rig.recallMemoryChannel(1)
    /// ```
    public func recallMemoryChannel(_ number: Int, to vfo: VFO = .a) async throws {
        guard connected else {
            throw RigError.notConnected
        }

        // Read the channel
        let channel = try await getMemoryChannel(number)

        // Apply frequency and mode to the specified VFO
        try await setFrequency(channel.frequency, vfo: vfo)
        try await setMode(channel.mode, vfo: vfo)
    }

    /// Stores the current VFO configuration to a memory channel.
    ///
    /// Creates a new memory channel from the current VFO's frequency and mode.
    /// Optionally specify a name and additional parameters.
    ///
    /// - Parameters:
    ///   - number: Memory channel number to store to
    ///   - vfo: Source VFO to read from (default: .a)
    ///   - name: Optional channel name (max 10 characters for Icom)
    /// - Throws: `RigError` if operation fails
    ///
    /// # Example
    /// ```swift
    /// // Store current VFO A settings to channel 5
    /// try await rig.storeCurrentToMemory(5, name: "Contest")
    /// ```
    public func storeCurrentToMemory(_ number: Int, from vfo: VFO = .a, name: String? = nil) async throws {
        guard connected else {
            throw RigError.notConnected
        }

        // Read current VFO settings
        let frequency = try await self.frequency(vfo: vfo, cached: false)
        let mode = try await self.mode(vfo: vfo, cached: false)

        // Create and store channel
        let channel = MemoryChannel(
            number: number,
            frequency: frequency,
            mode: mode,
            name: name
        )

        try await setMemoryChannel(channel)
    }
}
