import Foundation

/// Protocol defining the XPC interface between sandboxed apps and the privileged helper.
///
/// This protocol enables sandboxed Mac App Store applications to control amateur
/// radio transceivers through the XPC helper, which runs outside the sandbox and
/// has access to serial ports.
///
/// The XPC helper architecture:
/// - Sandboxed App → XPCClient → XPC Connection → XPCServer (in helper) → RigControl
@objc protocol RigControlXPCProtocol {
    // MARK: - Connection Management

    /// Connects to a radio via serial port.
    ///
    /// - Parameters:
    ///   - radioModel: The radio model identifier (e.g., "IC-9700", "K3")
    ///   - serialPort: Path to the serial port (e.g., "/dev/cu.IC9700")
    ///   - baudRate: Baud rate (optional, uses radio default if nil)
    ///   - reply: Completion handler with error if connection fails
    func connectToRadio(
        radioModel: String,
        serialPort: String,
        baudRate: NSNumber?,
        withReply reply: @escaping (NSError?) -> Void
    )

    /// Disconnects from the currently connected radio.
    ///
    /// - Parameter reply: Completion handler
    func disconnect(withReply reply: @escaping () -> Void)

    // MARK: - Frequency Control

    /// Sets the operating frequency.
    ///
    /// - Parameters:
    ///   - hz: Frequency in Hertz
    ///   - vfo: VFO identifier ("A", "B", "Main", "Sub")
    ///   - reply: Completion handler with error if operation fails
    func setFrequency(
        _ hz: UInt64,
        vfo: String,
        withReply reply: @escaping (NSError?) -> Void
    )

    /// Gets the current operating frequency.
    ///
    /// - Parameters:
    ///   - vfo: VFO identifier
    ///   - reply: Completion handler with frequency in Hz or error
    func getFrequency(
        vfo: String,
        withReply reply: @escaping (UInt64, NSError?) -> Void
    )

    // MARK: - Mode Control

    /// Sets the operating mode.
    ///
    /// - Parameters:
    ///   - mode: Mode identifier ("LSB", "USB", "CW", "FM", etc.)
    ///   - vfo: VFO identifier
    ///   - reply: Completion handler with error if operation fails
    func setMode(
        _ mode: String,
        vfo: String,
        withReply reply: @escaping (NSError?) -> Void
    )

    /// Gets the current operating mode.
    ///
    /// - Parameters:
    ///   - vfo: VFO identifier
    ///   - reply: Completion handler with mode string or error
    func getMode(
        vfo: String,
        withReply reply: @escaping (String?, NSError?) -> Void
    )

    // MARK: - PTT Control

    /// Sets the PTT (Push-To-Talk) state.
    ///
    /// - Parameters:
    ///   - enabled: True to transmit, false to receive
    ///   - reply: Completion handler with error if operation fails
    func setPTT(
        _ enabled: Bool,
        withReply reply: @escaping (NSError?) -> Void
    )

    /// Gets the current PTT state.
    ///
    /// - Parameter reply: Completion handler with PTT state or error
    func getPTT(
        withReply reply: @escaping (Bool, NSError?) -> Void
    )

    // MARK: - VFO Control

    /// Selects the active VFO.
    ///
    /// - Parameters:
    ///   - vfo: VFO identifier
    ///   - reply: Completion handler with error if operation fails
    func selectVFO(
        _ vfo: String,
        withReply reply: @escaping (NSError?) -> Void
    )

    // MARK: - Power Control

    /// Sets the RF power level.
    ///
    /// - Parameters:
    ///   - watts: Power level in watts
    ///   - reply: Completion handler with error if operation fails
    func setPower(
        _ watts: Int,
        withReply reply: @escaping (NSError?) -> Void
    )

    /// Gets the current RF power level.
    ///
    /// - Parameter reply: Completion handler with power in watts or error
    func getPower(
        withReply reply: @escaping (Int, NSError?) -> Void
    )

    // MARK: - Split Operation

    /// Enables or disables split operation.
    ///
    /// - Parameters:
    ///   - enabled: True to enable split, false to disable
    ///   - reply: Completion handler with error if operation fails
    func setSplit(
        _ enabled: Bool,
        withReply reply: @escaping (NSError?) -> Void
    )

    /// Gets the current split operation state.
    ///
    /// - Parameter reply: Completion handler with split state or error
    func getSplit(
        withReply reply: @escaping (Bool, NSError?) -> Void
    )

    // MARK: - Radio Information

    /// Gets the capabilities of the connected radio.
    ///
    /// - Parameter reply: Completion handler with capabilities dictionary or error
    func getCapabilities(
        withReply reply: @escaping ([String: Any]?, NSError?) -> Void
    )

    /// Gets the name of the connected radio.
    ///
    /// - Parameter reply: Completion handler with radio name or error
    func getRadioName(
        withReply reply: @escaping (String?, NSError?) -> Void
    )

    /// Checks if a radio is currently connected.
    ///
    /// - Parameter reply: Completion handler with connection state
    func isConnected(
        withReply reply: @escaping (Bool) -> Void
    )
}

/// Constants for XPC communication
public enum XPCConstants {
    /// The Mach service name for the helper
    public static let machServiceName = "com.swiftrigcontrol.helper"

    /// XPC error domain
    public static let errorDomain = "com.swiftrigcontrol.xpc"

    /// XPC error codes
    public enum ErrorCode: Int {
        case notConnected = 1000
        case invalidRadioModel = 1001
        case invalidVFO = 1002
        case invalidMode = 1003
        case connectionFailed = 1004
        case operationFailed = 1005
    }
}
