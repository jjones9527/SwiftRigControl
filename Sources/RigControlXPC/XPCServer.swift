import Foundation
import RigControl

/// Server implementation for the RigControl XPC helper.
///
/// XPCServer receives XPC calls from sandboxed applications and controls
/// radios using the RigControl library. This runs in the privileged helper
/// which has access to serial ports.
public class XPCServer: NSObject, RigControlXPCProtocol {
    /// The current rig controller instance
    private var rigController: RigController?

    /// Task for async operations
    private var currentTask: Task<Void, Never>?

    public override init() {
        super.init()
    }

    // MARK: - Connection Management

    public func connectToRadio(
        radioModel: String,
        serialPort: String,
        baudRate: NSNumber?,
        withReply reply: @escaping (NSError?) -> Void
    ) {
        currentTask = Task {
            do {
                // Map radio model string to RadioDefinition
                guard let radio = radioDefinitionFromString(radioModel) else {
                    reply(createError(.invalidRadioModel, message: "Unknown radio model: \(radioModel)"))
                    return
                }

                // Create controller
                let baud = baudRate?.intValue
                let controller = RigController(
                    radio: radio,
                    connection: .serial(path: serialPort, baudRate: baud)
                )

                // Connect
                try await controller.connect()

                rigController = controller
                reply(nil)
            } catch {
                reply(error as NSError)
            }
        }
    }

    public func disconnect(withReply reply: @escaping () -> Void) {
        currentTask = Task {
            await rigController?.disconnect()
            rigController = nil
            reply()
        }
    }

    // MARK: - Frequency Control

    public func setFrequency(
        _ hz: UInt64,
        vfo: String,
        withReply reply: @escaping (NSError?) -> Void
    ) {
        currentTask = Task {
            guard let rig = rigController else {
                reply(createError(.notConnected, message: "Radio not connected"))
                return
            }

            guard let vfoEnum = VFO(rawValue: vfo) else {
                reply(createError(.invalidVFO, message: "Invalid VFO: \(vfo)"))
                return
            }

            do {
                try await rig.setFrequency(hz, vfo: vfoEnum)
                reply(nil)
            } catch {
                reply(error as NSError)
            }
        }
    }

    public func getFrequency(
        vfo: String,
        withReply reply: @escaping (UInt64, NSError?) -> Void
    ) {
        currentTask = Task {
            guard let rig = rigController else {
                reply(0, createError(.notConnected, message: "Radio not connected"))
                return
            }

            guard let vfoEnum = VFO(rawValue: vfo) else {
                reply(0, createError(.invalidVFO, message: "Invalid VFO: \(vfo)"))
                return
            }

            do {
                let freq = try await rig.frequency(vfo: vfoEnum)
                reply(freq, nil)
            } catch {
                reply(0, error as NSError)
            }
        }
    }

    // MARK: - Mode Control

    public func setMode(
        _ mode: String,
        vfo: String,
        withReply reply: @escaping (NSError?) -> Void
    ) {
        currentTask = Task {
            guard let rig = rigController else {
                reply(createError(.notConnected, message: "Radio not connected"))
                return
            }

            guard let vfoEnum = VFO(rawValue: vfo) else {
                reply(createError(.invalidVFO, message: "Invalid VFO: \(vfo)"))
                return
            }

            guard let modeEnum = Mode(rawValue: mode) else {
                reply(createError(.invalidMode, message: "Invalid mode: \(mode)"))
                return
            }

            do {
                try await rig.setMode(modeEnum, vfo: vfoEnum)
                reply(nil)
            } catch {
                reply(error as NSError)
            }
        }
    }

    public func getMode(
        vfo: String,
        withReply reply: @escaping (String?, NSError?) -> Void
    ) {
        currentTask = Task {
            guard let rig = rigController else {
                reply(nil, createError(.notConnected, message: "Radio not connected"))
                return
            }

            guard let vfoEnum = VFO(rawValue: vfo) else {
                reply(nil, createError(.invalidVFO, message: "Invalid VFO: \(vfo)"))
                return
            }

            do {
                let mode = try await rig.mode(vfo: vfoEnum)
                reply(mode.rawValue, nil)
            } catch {
                reply(nil, error as NSError)
            }
        }
    }

    // MARK: - PTT Control

    public func setPTT(
        _ enabled: Bool,
        withReply reply: @escaping (NSError?) -> Void
    ) {
        currentTask = Task {
            guard let rig = rigController else {
                reply(createError(.notConnected, message: "Radio not connected"))
                return
            }

            do {
                try await rig.setPTT(enabled)
                reply(nil)
            } catch {
                reply(error as NSError)
            }
        }
    }

    public func getPTT(
        withReply reply: @escaping (Bool, NSError?) -> Void
    ) {
        currentTask = Task {
            guard let rig = rigController else {
                reply(false, createError(.notConnected, message: "Radio not connected"))
                return
            }

            do {
                let enabled = try await rig.isPTTEnabled()
                reply(enabled, nil)
            } catch {
                reply(false, error as NSError)
            }
        }
    }

    // MARK: - VFO Control

    public func selectVFO(
        _ vfo: String,
        withReply reply: @escaping (NSError?) -> Void
    ) {
        currentTask = Task {
            guard let rig = rigController else {
                reply(createError(.notConnected, message: "Radio not connected"))
                return
            }

            guard let vfoEnum = VFO(rawValue: vfo) else {
                reply(createError(.invalidVFO, message: "Invalid VFO: \(vfo)"))
                return
            }

            do {
                try await rig.selectVFO(vfoEnum)
                reply(nil)
            } catch {
                reply(error as NSError)
            }
        }
    }

    // MARK: - Power Control

    public func setPower(
        _ watts: Int,
        withReply reply: @escaping (NSError?) -> Void
    ) {
        currentTask = Task {
            guard let rig = rigController else {
                reply(createError(.notConnected, message: "Radio not connected"))
                return
            }

            do {
                try await rig.setPower(watts)
                reply(nil)
            } catch {
                reply(error as NSError)
            }
        }
    }

    public func getPower(
        withReply reply: @escaping (Int, NSError?) -> Void
    ) {
        currentTask = Task {
            guard let rig = rigController else {
                reply(0, createError(.notConnected, message: "Radio not connected"))
                return
            }

            do {
                let watts = try await rig.power()
                reply(watts, nil)
            } catch {
                reply(0, error as NSError)
            }
        }
    }

    // MARK: - Split Operation

    public func setSplit(
        _ enabled: Bool,
        withReply reply: @escaping (NSError?) -> Void
    ) {
        currentTask = Task {
            guard let rig = rigController else {
                reply(createError(.notConnected, message: "Radio not connected"))
                return
            }

            do {
                try await rig.setSplit(enabled)
                reply(nil)
            } catch {
                reply(error as NSError)
            }
        }
    }

    public func getSplit(
        withReply reply: @escaping (Bool, NSError?) -> Void
    ) {
        currentTask = Task {
            guard let rig = rigController else {
                reply(false, createError(.notConnected, message: "Radio not connected"))
                return
            }

            do {
                let enabled = try await rig.isSplitEnabled()
                reply(enabled, nil)
            } catch {
                reply(false, error as NSError)
            }
        }
    }

    // MARK: - Radio Information

    public func getCapabilities(
        withReply reply: @escaping ([String: Any]?, NSError?) -> Void
    ) {
        guard let rig = rigController else {
            reply(nil, createError(.notConnected, message: "Radio not connected"))
            return
        }

        let caps = rig.capabilities
        let dict: [String: Any] = [
            "hasVFOB": caps.hasVFOB,
            "hasSplit": caps.hasSplit,
            "powerControl": caps.powerControl,
            "maxPower": caps.maxPower,
            "hasDualReceiver": caps.hasDualReceiver,
            "hasATU": caps.hasATU
        ]

        reply(dict, nil)
    }

    public func getRadioName(
        withReply reply: @escaping (String?, NSError?) -> Void
    ) {
        guard let rig = rigController else {
            reply(nil, createError(.notConnected, message: "Radio not connected"))
            return
        }

        reply(rig.radioName, nil)
    }

    public func isConnected(
        withReply reply: @escaping (Bool) -> Void
    ) {
        reply(rigController?.isConnected ?? false)
    }

    // MARK: - Private Methods

    private func createError(_ code: XPCConstants.ErrorCode, message: String) -> NSError {
        return NSError(
            domain: XPCConstants.errorDomain,
            code: code.rawValue,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private func radioDefinitionFromString(_ model: String) -> RadioDefinition? {
        switch model.uppercased() {
        // Icom
        case "IC-9700", "IC9700", "9700":
            return .icomIC9700
        case "IC-7610", "IC7610", "7610":
            return .icomIC7610
        case "IC-7300", "IC7300", "7300":
            return .icomIC7300
        case "IC-7600", "IC7600", "7600":
            return .icomIC7600
        case "IC-7100", "IC7100", "7100":
            return .icomIC7100
        case "IC-705", "IC705", "705":
            return .icomIC705

        // Elecraft
        case "K2":
            return .elecraftK2
        case "K3":
            return .elecraftK3
        case "K3S":
            return .elecraftK3S
        case "K4":
            return .elecraftK4
        case "KX2":
            return .elecraftKX2
        case "KX3":
            return .elecraftKX3

        default:
            return nil
        }
    }
}
