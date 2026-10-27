import Testing
@testable import RigControl

/// Interpolation matches Hamlib `rig_raw2val` (`src/cal.c`).
@Suite struct CalibrationTableTests {

    @Test func interpolatesAndClampsLikeRigRaw2Val() {
        let table = CalibrationTable([(130, 0), (0, -54), (255, 60)])   // unsorted on purpose
        #expect(table.value(forRaw: 0) == -54)
        #expect(table.value(forRaw: 65) == -27)
        #expect(table.value(forRaw: 130) == 0)
        #expect(table.value(forRaw: 192) == 30)
        #expect(table.value(forRaw: -5) == -54)
        #expect(table.value(forRaw: 300) == 60)
    }

    @Test func emptyTableReturnsRaw() {
        #expect(CalibrationTable([]).value(forRaw: 42) == 42)
    }

    @Test func signalStrengthFromCalibratedDB() {
        #expect(SignalStrength(dBRelativeToS9: 0, raw: 130).description == "S9+0")
        #expect(SignalStrength(dBRelativeToS9: 20, raw: 172).description == "S9+20")
        #expect(SignalStrength(dBRelativeToS9: -12, raw: 95).sUnits == 7)
        #expect(SignalStrength(dBRelativeToS9: -54, raw: 0).sUnits == 0)
        #expect(SignalStrength(dBRelativeToS9: -9, raw: 105).calibratedDBRelativeToS9 == -9)
        #expect(SignalStrength(sUnits: 5, raw: 1).calibratedDBRelativeToS9 == nil)
    }
}
