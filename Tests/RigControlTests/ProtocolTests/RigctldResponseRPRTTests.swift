import Foundation
import Testing
@testable import RigControl

/// Regression tests for issue #15 — `RigctldResponse.formatDefault`
/// must always emit `RPRT <n>\n` as the response trailer, matching
/// real Hamlib rigctld's wire format.
///
/// Prior behaviour: `.ok` responses with empty data returned just a
/// bare `\n`.  Hamlib's netrigctl client treats that as an invalid
/// response and returns `-5 Communication timed out`, which Direwolf
/// logs as `Hamlib Error: rig_set_ptt command` for every PTT
/// state change over the CAT-through-rigctld path.
///
/// Fixed behaviour: always emit `RPRT 0\n` (for `.ok`) or
/// `RPRT <errcode>\n` (for errors), after any data lines.
@Suite struct RigctldResponseRPRTTests {

    // MARK: - `.ok` set-command responses (empty data)

    @Test func okWithEmptyDataEmitsRPRT0Trailer() {
        let response = RigctldResponse.ok()
        let formatted = response.formatDefault()
        #expect(formatted == "RPRT 0\n",
                "Bare .ok must emit exactly 'RPRT 0\\n' — that's the wire format Hamlib rigctld returns for `T 0`, `F <hz>`, `M USB 2400`, etc.")
    }

    @Test func okAlwaysEndsWithRPRTTrailer() {
        // Any successful response must have `RPRT 0\n` as its trailer,
        // whether or not there's data ahead of it.  This is the
        // load-bearing invariant Hamlib's netrigctl client relies on
        // to know a response is complete.
        let responses: [RigctldResponse] = [
            .ok(),
            .frequency(14_100_000),
            .mode("USB", passband: 2400),
            .ptt(true),
            .power(50),
        ]
        for response in responses {
            let formatted = response.formatDefault()
            #expect(formatted.hasSuffix("RPRT 0\n"),
                    "Response \(response) formatted as '\(formatted)' — must end with 'RPRT 0\\n'")
        }
    }

    // MARK: - Data + RPRT ordering

    @Test func responseWithDataPutsDataBeforeRPRT() {
        // `f` (get_freq) response should be:
        //   14100000\n
        //   RPRT 0\n
        // Data on its own line, then the trailer.
        let response = RigctldResponse.frequency(14_100_000)
        let formatted = response.formatDefault()
        #expect(formatted == "14100000\nRPRT 0\n")
    }

    @Test func multipleDataLinesEachOnOwnLineBeforeRPRT() {
        // `m` (get_mode) returns Mode and Passband on separate lines,
        // then RPRT.
        let response = RigctldResponse.mode("USB", passband: 2400)
        let formatted = response.formatDefault()
        #expect(formatted == "USB\n2400\nRPRT 0\n")
    }

    // MARK: - Error responses

    @Test func errorResponsesEmitRPRTWithNonZeroCode() {
        let response = RigctldResponse.error(.notSupported)
        let formatted = response.formatDefault()
        // notSupported = -11 (Hamlib RIG_ENAVAIL) — see
        // RigctldProtocol.ReturnCode.  Aligned with canonical
        // Hamlib rig_errcode_e in v1.2.15.
        #expect(formatted == "RPRT -11\n")
    }

    // MARK: - Round-trip against Hamlib's expectations

    /// Concrete wire-format matrix from real Hamlib rigctld,
    /// captured to guard against future format drift.
    @Test func matchesRealHamlibRigctldWireFormat() {
        // Format: (response, expected default-protocol output)
        let cases: [(RigctldResponse, String)] = [
            (.ok(), "RPRT 0\n"),
            (.frequency(14_100_000), "14100000\nRPRT 0\n"),
            (.mode("USB", passband: 2400), "USB\n2400\nRPRT 0\n"),
            (.ptt(false), "0\nRPRT 0\n"),
            (.ptt(true), "1\nRPRT 0\n"),
            (.power(50), "50\nRPRT 0\n"),
        ]
        for (response, expected) in cases {
            let actual = response.formatDefault()
            #expect(actual == expected,
                    "formatDefault mismatch: got '\(actual)', expected '\(expected)'")
        }
    }
}
