import Foundation
import Testing
@testable import RigControl

/// rigctld values the way Hamlib clients send them (found by
/// `Scripts/hamlib-coverage.py`, 2026-10-30):
///
/// - `L PREAMP` is a value from the model's preamp list, not a stage
///   (`icom.c:3650-3675`, `kenwood.c:3591-3613`, `newcat.c:4457-4474`).
/// - Hamlib's dashed mode names `FM-D`, `USB-D`, `LSB-D`, `CW-R`, `RTTY-R`
///   (`misc.c:460-480`).
/// - `U RIT` / `U XIT` switch the clarifier and keep its offset.
@Suite struct RigctldHamlibValueTests {

    private func makeHandler(preampLevels: [Int] = []) async throws -> (RigController, RigctldCommandHandler) {
        let caps = RigCapabilities(
            frequencyRange: FrequencyRange(min: 30_000, max: 60_000_000),
            preampLevels: preampLevels
        )
        let rig = try RigController(radio: .dummy(name: "Test", capabilities: caps), connection: .mock)
        try await rig.connect()
        return (rig, RigctldCommandHandler(rigController: rig))
    }

    // MARK: - PREAMP

    @Test func preampValueSelectsStageByPosition() async throws {
        let (rig, handler) = try await makeHandler(preampLevels: [10, 16])   // IC-7600
        #expect(await handler.handle(.setLevel(name: "PREAMP", value: "16")).returnCode == .ok)
        #expect(try await rig.preamp() == 2)
        #expect(await handler.handle(.getLevel(name: "PREAMP")).data == ["16"])

        #expect(await handler.handle(.setLevel(name: "PREAMP", value: "0")).returnCode == .ok)
        #expect(await handler.handle(.getLevel(name: "PREAMP")).data == ["0"])
    }

    @Test func preampValueNotInTheListIsInvalid() async throws {
        let (_, handler) = try await makeHandler(preampLevels: [10, 16])
        // Hamlib returns -RIG_EINVAL here; we used to read 10 as stage 10.
        #expect(await handler.handle(.setLevel(name: "PREAMP", value: "12")).returnCode == .invalidParam)
    }

    @Test func preampWithoutAListIsTheStage() async throws {
        let (rig, handler) = try await makeHandler()
        #expect(await handler.handle(.setLevel(name: "PREAMP", value: "1")).returnCode == .ok)
        #expect(try await rig.preamp() == 1)
        #expect(await handler.handle(.getLevel(name: "PREAMP")).data == ["1"])
    }

    // MARK: - Mode names

    @Test(arguments: [("FM-D", Mode.dataFM), ("USB-D", .dataUSB), ("LSB-D", .dataLSB),
                      ("CW-R", .cwR), ("RTTY-R", .rttyR)])
    func hamlibDashedModeNamesParse(name: String, mode: Mode) async throws {
        let (rig, handler) = try await makeHandler()
        #expect(await handler.handle(.setMode(mode: name, passband: 0)).returnCode == .ok)
        #expect(try await rig.mode(cached: false) == mode)
    }

    // MARK: - RIT / XIT functions

    @Test func ritFunctionKeepsTheOffset() async throws {
        let (rig, handler) = try await makeHandler()
        try await rig.setRIT(RITXITState(enabled: true, offset: 250))

        #expect(await handler.handle(.setFunc(name: "RIT", enabled: false)).returnCode == .ok)
        #expect(try await rig.getRIT(cached: false) == RITXITState(enabled: false, offset: 250))
        #expect(await handler.handle(.getFunc(name: "RIT")).data == ["0"])

        #expect(await handler.handle(.setFunc(name: "RIT", enabled: true)).returnCode == .ok)
        #expect(try await rig.getRIT(cached: false) == RITXITState(enabled: true, offset: 250))
        #expect(await handler.handle(.getFunc(name: "RIT")).data == ["1"])
    }

    @Test func xitFunctionKeepsTheOffset() async throws {
        let (rig, handler) = try await makeHandler()
        try await rig.setXIT(RITXITState(enabled: false, offset: -100))
        #expect(await handler.handle(.setFunc(name: "XIT", enabled: true)).returnCode == .ok)
        #expect(try await rig.getXIT(cached: false) == RITXITState(enabled: true, offset: -100))
    }

    // MARK: - Codable

    @Test func capabilitiesEncodedBeforePreampLevelsStillDecode() throws {
        let encoded = try JSONEncoder().encode(RigCapabilities(preampLevels: [10, 16]))
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(object.keys.contains("preampLevelStorage"))
        object.removeValue(forKey: "preampLevelStorage")   // what a v1.3 encoder wrote
        let old = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(RigCapabilities.self, from: old)
        #expect(decoded.preampLevels == [])
        #expect(try JSONDecoder().decode(RigCapabilities.self, from: encoded).preampLevels == [10, 16])
    }
}
