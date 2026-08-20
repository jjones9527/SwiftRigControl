import Foundation
import Testing
@testable import RigControl

/// Locks `RigctldProtocol.ReturnCode` raw values to Hamlib's
/// canonical `rig_errcode_e` numbering (see
/// `hamlib/include/hamlib/rig.h`).
///
/// Motivation: macwinlink-releases#66 (v1.2.14 field report on
/// IC-7100 with Direwolf).  Every PTT toggle logged
///
///   `rig_set_ptt returning(-10) Command performed, but arg
///   truncated, result not guaranteed`
///
/// in Direwolf's log.  Root cause: our `ReturnCode` enum had grown
/// with a SwiftRigControl-invented `.communicationError = -5`
/// wedged between `.notImplemented = -4` and `.timeout`, shifting
/// every subsequent value by one relative to Hamlib.  Our
/// `.rejected = -10` was being decoded by Hamlib as
/// `RIG_ETRUNC` "arg truncated", not `RIG_ERJCTED` "rejected".
///
/// v1.2.15 re-aligned the raw values.  These tests are the
/// regression net so nobody re-invents a code that collides with
/// Hamlib.
@Suite struct RigctldReturnCodeHamlibParityTests {

    // MARK: - Individual code parity vs Hamlib rig.h

    @Test func okIsZero() {
        #expect(RigctldProtocol.ReturnCode.ok.rawValue == 0)
    }

    @Test func invalidParamIsMinus1() {
        // Hamlib RIG_EINVAL = 1 → wire -1
        #expect(RigctldProtocol.ReturnCode.invalidParam.rawValue == -1)
    }

    @Test func invalidConfigIsMinus2() {
        // Hamlib RIG_ECONF = 2 → wire -2
        #expect(RigctldProtocol.ReturnCode.invalidConfig.rawValue == -2)
    }

    @Test func outOfMemoryIsMinus3() {
        // Hamlib RIG_ENOMEM = 3 → wire -3
        #expect(RigctldProtocol.ReturnCode.outOfMemory.rawValue == -3)
    }

    @Test func notImplementedIsMinus4() {
        // Hamlib RIG_ENIMPL = 4 → wire -4
        #expect(RigctldProtocol.ReturnCode.notImplemented.rawValue == -4)
    }

    @Test func timeoutIsMinus5() {
        // Hamlib RIG_ETIMEOUT = 5 → wire -5.  Pre-v1.2.15 this
        // was incorrectly -6 because a SwiftRigControl-invented
        // `.communicationError = -5` was wedged in front.
        #expect(RigctldProtocol.ReturnCode.timeout.rawValue == -5)
    }

    @Test func ioErrorIsMinus6() {
        // Hamlib RIG_EIO = 6 → wire -6.  Pre-v1.2.15 this was
        // incorrectly -7.
        #expect(RigctldProtocol.ReturnCode.ioError.rawValue == -6)
    }

    @Test func internalErrorIsMinus7() {
        // Hamlib RIG_EINTERNAL = 7 → wire -7.  Pre-v1.2.15 -8.
        #expect(RigctldProtocol.ReturnCode.internalError.rawValue == -7)
    }

    @Test func protocolErrorIsMinus8() {
        // Hamlib RIG_EPROTO = 8 → wire -8.  Pre-v1.2.15 -9.
        #expect(RigctldProtocol.ReturnCode.protocolError.rawValue == -8)
    }

    @Test func rejectedIsMinus9() {
        // Hamlib RIG_ERJCTED = 9 → wire -9.  Pre-v1.2.15 this was
        // -10, which Hamlib decoded as RIG_ETRUNC — the exact
        // symptom in macwinlink-releases#66.
        #expect(RigctldProtocol.ReturnCode.rejected.rawValue == -9)
    }

    @Test func argTruncatedIsMinus10() {
        // Hamlib RIG_ETRUNC = 10 → wire -10.  SwiftRigControl
        // does not intentionally emit this; the case exists so
        // external decoders can classify it.  Locking the value
        // guards against anyone re-purposing -10 as
        // "rejected" (the pre-v1.2.15 bug).
        #expect(RigctldProtocol.ReturnCode.argTruncated.rawValue == -10)
    }

    @Test func notSupportedIsMinus11() {
        // Hamlib RIG_ENAVAIL = 11 → wire -11.  Pre-v1.2.15 -12.
        #expect(RigctldProtocol.ReturnCode.notSupported.rawValue == -11)
    }

    @Test func vfoNotTargetableIsMinus12() {
        // Hamlib RIG_ENTARGET = 12 → wire -12.  Pre-v1.2.15 -13.
        #expect(RigctldProtocol.ReturnCode.vfoNotTargetable.rawValue == -12)
    }

    @Test func busErrorIsMinus13() {
        // Hamlib RIG_BUSERROR = 13 → wire -13.
        #expect(RigctldProtocol.ReturnCode.busError.rawValue == -13)
    }

    @Test func busBusyIsMinus14() {
        // Hamlib RIG_BUSBUSY = 14 → wire -14.  Pre-v1.2.15 this
        // was the (semantically confused) `.error = -14`.
        #expect(RigctldProtocol.ReturnCode.busBusy.rawValue == -14)
    }

    // MARK: - Wire-format parity for the exact bug from the field

    /// The exact wire response macwinlink-releases#66 needs
    /// SwiftRigControl to emit when the CI-V write actually gets
    /// rejected by the radio.  Post-v1.2.15 this must be
    /// `RPRT -9\n` (RIG_ERJCTED), not `RPRT -10\n` (RIG_ETRUNC).
    @Test func rejectedFormatsAsRPRTMinus9() {
        let response = RigctldResponse.error(.rejected)
        let formatted = response.formatDefault()
        #expect(formatted == "RPRT -9\n",
                "Rejected must format as `RPRT -9\\n` (Hamlib RIG_ERJCTED). Got: \(formatted.debugDescription).")
        #expect(formatted.utf8.count == 8)
    }

    @Test func timeoutFormatsAsRPRTMinus5() {
        let response = RigctldResponse.error(.timeout)
        let formatted = response.formatDefault()
        #expect(formatted == "RPRT -5\n",
                "Timeout must format as `RPRT -5\\n` (Hamlib RIG_ETIMEOUT). Got: \(formatted.debugDescription).")
    }

    @Test func ioErrorFormatsAsRPRTMinus6() {
        let response = RigctldResponse.error(.ioError)
        let formatted = response.formatDefault()
        #expect(formatted == "RPRT -6\n",
                "ioError must format as `RPRT -6\\n` (Hamlib RIG_EIO). Got: \(formatted.debugDescription).")
    }

    @Test func protocolErrorFormatsAsRPRTMinus8() {
        let response = RigctldResponse.error(.protocolError)
        let formatted = response.formatDefault()
        #expect(formatted == "RPRT -8\n",
                "protocolError must format as `RPRT -8\\n` (Hamlib RIG_EPROTO). Got: \(formatted.debugDescription).")
    }

    @Test func notSupportedFormatsAsRPRTMinus11() {
        let response = RigctldResponse.error(.notSupported)
        let formatted = response.formatDefault()
        #expect(formatted == "RPRT -11\n",
                "notSupported must format as `RPRT -11\\n` (Hamlib RIG_ENAVAIL). Got: \(formatted.debugDescription).")
    }
}
