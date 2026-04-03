import Foundation

extension IcomCIVProtocol {

    // MARK: - Function Controls (IC-7600 Specific)

    /// Set preamp (IC-7600)
    /// - Parameter value: 0=OFF, 1=P.AMP1, 2=P.AMP2
    public func setPreampIC7600(_ value: UInt8) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setPreampIC7600 is only available on IC-7600")
        }
        try await setFunctionIC7600(CIVFrame.FunctionCode.preamp, value: value)
    }

    /// Read preamp setting (IC-7600)
    public func getPreampIC7600() async throws -> UInt8 {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getPreampIC7600 is only available on IC-7600")
        }
        return try await getFunctionIC7600(CIVFrame.FunctionCode.preamp)
    }

    /// Set AGC (IC-7600)
    /// - Parameter value: 1=FAST, 2=MID, 3=SLOW
    public func setAGCIC7600(_ value: UInt8) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setAGCIC7600 is only available on IC-7600")
        }
        try await setFunctionIC7600(CIVFrame.FunctionCode.agc, value: value)
    }

    /// Read AGC setting (IC-7600)
    public func getAGCIC7600() async throws -> UInt8 {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getAGCIC7600 is only available on IC-7600")
        }
        return try await getFunctionIC7600(CIVFrame.FunctionCode.agc)
    }

    /// Set audio peak filter (IC-7600)
    /// - Parameter enabled: true=ON, false=OFF
    public func setAudioPeakFilterIC7600(_ enabled: Bool) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setAudioPeakFilterIC7600 is only available on IC-7600")
        }
        try await setFunctionIC7600(CIVFrame.FunctionCode.audioPeakFilter, value: enabled ? 0x01 : 0x00)
    }

    /// Read audio peak filter setting (IC-7600)
    public func getAudioPeakFilterIC7600() async throws -> Bool {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getAudioPeakFilterIC7600 is only available on IC-7600")
        }
        let value = try await getFunctionIC7600(CIVFrame.FunctionCode.audioPeakFilter)
        return value != 0x00
    }

    /// Set monitor (IC-7600)
    /// - Parameter enabled: true=ON, false=OFF
    public func setMonitorIC7600(_ enabled: Bool) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setMonitorIC7600 is only available on IC-7600")
        }
        try await setFunctionIC7600(CIVFrame.FunctionCode.monitor, value: enabled ? 0x01 : 0x00)
    }

    /// Read monitor setting (IC-7600)
    public func getMonitorIC7600() async throws -> Bool {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getMonitorIC7600 is only available on IC-7600")
        }
        let value = try await getFunctionIC7600(CIVFrame.FunctionCode.monitor)
        return value != 0x00
    }

    /// Set break-in (IC-7600)
    /// - Parameter enabled: true=ON, false=OFF
    public func setBreakInIC7600(_ enabled: Bool) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setBreakInIC7600 is only available on IC-7600")
        }
        try await setFunctionIC7600(CIVFrame.FunctionCode.breakIn, value: enabled ? 0x01 : 0x00)
    }

    /// Read break-in setting (IC-7600)
    public func getBreakInIC7600() async throws -> Bool {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getBreakInIC7600 is only available on IC-7600")
        }
        let value = try await getFunctionIC7600(CIVFrame.FunctionCode.breakIn)
        return value != 0x00
    }

    /// Set manual notch (IC-7600)
    /// - Parameter enabled: true=ON, false=OFF
    public func setManualNotchIC7600(_ enabled: Bool) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setManualNotchIC7600 is only available on IC-7600")
        }
        try await setFunctionIC7600(CIVFrame.FunctionCode.manualNotch, value: enabled ? 0x01 : 0x00)
    }

    /// Read manual notch setting (IC-7600)
    public func getManualNotchIC7600() async throws -> Bool {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getManualNotchIC7600 is only available on IC-7600")
        }
        let value = try await getFunctionIC7600(CIVFrame.FunctionCode.manualNotch)
        return value != 0x00
    }

    /// Set twin peak filter (IC-7600)
    /// - Parameter enabled: true=ON, false=OFF
    public func setTwinPeakFilterIC7600(_ enabled: Bool) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setTwinPeakFilterIC7600 is only available on IC-7600")
        }
        try await setFunctionIC7600(CIVFrame.FunctionCode.twinPeakFilter, value: enabled ? 0x01 : 0x00)
    }

    /// Read twin peak filter setting (IC-7600)
    public func getTwinPeakFilterIC7600() async throws -> Bool {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getTwinPeakFilterIC7600 is only available on IC-7600")
        }
        let value = try await getFunctionIC7600(CIVFrame.FunctionCode.twinPeakFilter)
        return value != 0x00
    }

    /// Set dial lock (IC-7600)
    /// - Parameter enabled: true=ON, false=OFF
    public func setDialLockIC7600(_ enabled: Bool) async throws {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("setDialLockIC7600 is only available on IC-7600")
        }
        try await setFunctionIC7600(CIVFrame.FunctionCode.dialLock, value: enabled ? 0x01 : 0x00)
    }

    /// Read dial lock setting (IC-7600)
    public func getDialLockIC7600() async throws -> Bool {
        guard radioModel == .ic7600 else {
            throw RigError.unsupportedOperation("getDialLockIC7600 is only available on IC-7600")
        }
        let value = try await getFunctionIC7600(CIVFrame.FunctionCode.dialLock)
        return value != 0x00
    }

}
