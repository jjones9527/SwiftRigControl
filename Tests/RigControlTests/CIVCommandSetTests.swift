import XCTest
@testable import RigControl

/// Unit tests for CIVCommandSet protocol implementations
final class CIVCommandSetTests: XCTestCase {

    // MARK: - IC7100CommandSet Tests

    func testIC7100Properties() {
        let commandSet = IC7100CommandSet()
        XCTAssertEqual(commandSet.civAddress, 0x88)
        XCTAssertEqual(commandSet.powerUnits, .percentage)
        XCTAssertTrue(commandSet.echoesCommands)
        XCTAssertFalse(commandSet.requiresVFOSelection)
    }

    func testIC7100ModeCommand() {
        let commandSet = IC7100CommandSet()

        // IC-7100 does NOT include filter byte
        let (cmd, data) = commandSet.setModeCommand(mode: 0x01) // USB
        XCTAssertEqual(cmd, [0x06])
        XCTAssertEqual(data, [0x01]) // Mode only, no filter
    }

    func testIC7100PowerCommand() {
        let commandSet = IC7100CommandSet()

        // Test 50%
        let (cmd, data) = commandSet.setPowerCommand(value: 50)
        XCTAssertEqual(cmd, [0x14, 0x0A])
        XCTAssertEqual(data.count, 2) // BCD encoded

        // Decode to verify
        let scale = BCDEncoding.decodePower(data)
        let percentage = (scale * 100) / 255
        XCTAssertEqual(percentage, 50, accuracy: 1)
    }

    func testIC7100PTTCommand() {
        let commandSet = IC7100CommandSet()

        // Test TX
        let (cmdTX, dataTX) = commandSet.setPTTCommand(enabled: true)
        XCTAssertEqual(cmdTX, [0x1C, 0x00])
        XCTAssertEqual(dataTX, [0x01])

        // Test RX
        let (cmdRX, dataRX) = commandSet.setPTTCommand(enabled: false)
        XCTAssertEqual(cmdRX, [0x1C, 0x00])
        XCTAssertEqual(dataRX, [0x00])
    }

    func testIC7100VFOCommand() {
        let commandSet = IC7100CommandSet()

        // IC-7100 doesn't require VFO selection
        XCTAssertNil(commandSet.selectVFOCommand(.a))
        XCTAssertNil(commandSet.selectVFOCommand(.b))
    }

    func testIC7100ParseModeResponse() throws {
        let commandSet = IC7100CommandSet()

        // Simulate response: FE FE E0 88 04 01 FD (mode = USB)
        let frame = CIVFrame(to: 0xE0, from: 0x88, command: [0x04], data: [0x01])
        let mode = try commandSet.parseModeResponse(frame)
        XCTAssertEqual(mode, 0x01) // USB
    }

    func testIC7100ParsePowerResponse() throws {
        let commandSet = IC7100CommandSet()

        // Simulate 100% power response
        let powerBCD = BCDEncoding.encodePower(255)
        let frame = CIVFrame(to: 0xE0, from: 0x88, command: [0x14, 0x0A], data: powerBCD)
        let power = try commandSet.parsePowerResponse(frame)
        XCTAssertEqual(power, 100)
    }

    func testIC7100ParsePTTResponse() throws {
        let commandSet = IC7100CommandSet()

        // Simulate TX response
        let frameTX = CIVFrame(to: 0xE0, from: 0x88, command: [0x1C, 0x00], data: [0x01])
        XCTAssertTrue(try commandSet.parsePTTResponse(frameTX))

        // Simulate RX response
        let frameRX = CIVFrame(to: 0xE0, from: 0x88, command: [0x1C, 0x00], data: [0x00])
        XCTAssertFalse(try commandSet.parsePTTResponse(frameRX))
    }

    // MARK: - IC9700CommandSet Tests

    func testIC9700Properties() {
        let commandSet = IC9700CommandSet()
        XCTAssertEqual(commandSet.civAddress, 0xA2)
        XCTAssertEqual(commandSet.powerUnits, .percentage)
        XCTAssertFalse(commandSet.echoesCommands)
        XCTAssertTrue(commandSet.requiresVFOSelection)
    }

    func testIC9700ModeCommand() {
        let commandSet = IC9700CommandSet()

        // IC-9700 DOES include filter byte
        let (cmd, data) = commandSet.setModeCommand(mode: 0x01) // USB
        XCTAssertEqual(cmd, [0x06])
        XCTAssertEqual(data, [0x01, 0x00]) // Mode + default filter
    }

    func testIC9700PowerCommand() {
        let commandSet = IC9700CommandSet()

        // Test 75%
        let (cmd, data) = commandSet.setPowerCommand(value: 75)
        XCTAssertEqual(cmd, [0x14, 0x0A])
        XCTAssertEqual(data.count, 2)

        // Decode to verify
        let scale = BCDEncoding.decodePower(data)
        let percentage = (scale * 100) / 255
        XCTAssertEqual(percentage, 75, accuracy: 1)
    }

    func testIC9700VFOCommand() {
        let commandSet = IC9700CommandSet()

        // IC-9700 requires VFO selection
        let cmdA = commandSet.selectVFOCommand(.a)
        XCTAssertNotNil(cmdA)
        XCTAssertEqual(cmdA?.command, [0x07])
        XCTAssertEqual(cmdA?.data, [0x00]) // VFO A

        let cmdMain = commandSet.selectVFOCommand(.main)
        XCTAssertNotNil(cmdMain)
        XCTAssertEqual(cmdMain?.command, [0x07])
        XCTAssertEqual(cmdMain?.data, [0xD0]) // Main receiver
    }

    // MARK: - StandardIcomCommandSet Tests

    func testStandardCommandSetProperties() {
        let commandSet = StandardIcomCommandSet(civAddress: 0x94)
        XCTAssertEqual(commandSet.civAddress, 0x94)
        XCTAssertEqual(commandSet.powerUnits, .percentage)
        XCTAssertFalse(commandSet.echoesCommands)
        XCTAssertTrue(commandSet.requiresVFOSelection)
    }

    func testStandardCommandSetCustomization() {
        let commandSet = StandardIcomCommandSet(
            civAddress: 0xA4,
            echoesCommands: true,
            requiresVFOSelection: false
        )
        XCTAssertEqual(commandSet.civAddress, 0xA4)
        XCTAssertTrue(commandSet.echoesCommands)
        XCTAssertFalse(commandSet.requiresVFOSelection)
    }

    func testStandardModeCommand() {
        let commandSet = StandardIcomCommandSet(civAddress: 0x94)

        // Standard radios include filter byte
        let (cmd, data) = commandSet.setModeCommand(mode: 0x00) // LSB
        XCTAssertEqual(cmd, [0x06])
        XCTAssertEqual(data, [0x00, 0x00]) // Mode + default filter
    }

    func testStandardFrequencyCommand() throws {
        let commandSet = StandardIcomCommandSet(civAddress: 0x94)

        // Test 14.250 MHz
        let (cmd, data) = commandSet.setFrequencyCommand(frequency: 14_250_000)
        XCTAssertEqual(cmd, [0x05])
        XCTAssertEqual(data.count, 5)

        // Verify encoding
        let freq = try BCDEncoding.decodeFrequency(data)
        XCTAssertEqual(freq, 14_250_000)
    }

    func testStandardParseFrequencyResponse() throws {
        let commandSet = StandardIcomCommandSet(civAddress: 0x94)

        // Simulate frequency response for 7.200 MHz
        let freqBCD = BCDEncoding.encodeFrequency(7_200_000)
        let frame = CIVFrame(to: 0xE0, from: 0x94, command: [0x03], data: freqBCD)
        let freq = try commandSet.parseFrequencyResponse(frame)
        XCTAssertEqual(freq, 7_200_000)
    }

    // MARK: - Convenience Initializers Tests

    func testIC705ConvenienceInit() {
        let commandSet = StandardIcomCommandSet.ic705
        XCTAssertEqual(commandSet.civAddress, 0xA4)
        XCTAssertTrue(commandSet.echoesCommands)
        XCTAssertFalse(commandSet.requiresVFOSelection)
    }

    func testIC7300ConvenienceInit() {
        let commandSet = StandardIcomCommandSet.ic7300
        XCTAssertEqual(commandSet.civAddress, 0x94)
        XCTAssertFalse(commandSet.echoesCommands)
        XCTAssertTrue(commandSet.requiresVFOSelection)
    }

    func testIC7610ConvenienceInit() {
        let commandSet = StandardIcomCommandSet.ic7610
        XCTAssertEqual(commandSet.civAddress, 0x98)
    }

    func testIC7600ConvenienceInit() {
        let commandSet = StandardIcomCommandSet.ic7600
        XCTAssertEqual(commandSet.civAddress, 0x7A)
    }

    func testIC9100ConvenienceInit() {
        let commandSet = StandardIcomCommandSet.ic9100
        XCTAssertEqual(commandSet.civAddress, 0x7C)
    }

    // MARK: - Power Scale Tests

    func testPowerScaleRoundTrip() throws {
        let commandSets: [any CIVCommandSet] = [
            IC7100CommandSet(),
            IC9700CommandSet(),
            StandardIcomCommandSet.ic7300
        ]

        for commandSet in commandSets {
            // Test various power levels
            for testPower in [10, 25, 50, 75, 100] {
                let (_, data) = commandSet.setPowerCommand(value: testPower)

                // Create response frame
                let frame = CIVFrame(
                    to: 0xE0,
                    from: commandSet.civAddress,
                    command: [0x14, 0x0A],
                    data: data
                )

                let parsedPower = try commandSet.parsePowerResponse(frame)
                XCTAssertEqual(parsedPower, testPower, accuracy: 1,
                              "Power round-trip failed for \(testPower)% on address 0x\(String(format: "%02X", commandSet.civAddress))")
            }
        }
    }

    // MARK: - Error Handling Tests

    func testInvalidModeResponseThrows() {
        let commandSet = IC7100CommandSet()

        // Wrong command in response
        let badFrame = CIVFrame(to: 0xE0, from: 0x88, command: [0x05], data: [0x01])
        XCTAssertThrowsError(try commandSet.parseModeResponse(badFrame)) { error in
            XCTAssertEqual(error as? RigError, .invalidResponse)
        }

        // Empty data
        let emptyFrame = CIVFrame(to: 0xE0, from: 0x88, command: [0x04], data: [])
        XCTAssertThrowsError(try commandSet.parseModeResponse(emptyFrame)) { error in
            XCTAssertEqual(error as? RigError, .invalidResponse)
        }
    }

    func testInvalidPowerResponseThrows() {
        let commandSet = IC7100CommandSet()

        // Wrong command
        let badFrame = CIVFrame(to: 0xE0, from: 0x88, command: [0x14, 0x0B], data: [0x00, 0x00])
        XCTAssertThrowsError(try commandSet.parsePowerResponse(badFrame)) { error in
            XCTAssertEqual(error as? RigError, .invalidResponse)
        }

        // Insufficient data
        let shortFrame = CIVFrame(to: 0xE0, from: 0x88, command: [0x14, 0x0A], data: [0x00])
        XCTAssertThrowsError(try commandSet.parsePowerResponse(shortFrame)) { error in
            XCTAssertEqual(error as? RigError, .invalidResponse)
        }
    }

    func testInvalidPTTResponseThrows() {
        let commandSet = IC7100CommandSet()

        // Wrong command
        let badFrame = CIVFrame(to: 0xE0, from: 0x88, command: [0x1C, 0x01], data: [0x00])
        XCTAssertThrowsError(try commandSet.parsePTTResponse(badFrame)) { error in
            XCTAssertEqual(error as? RigError, .invalidResponse)
        }

        // Empty data
        let emptyFrame = CIVFrame(to: 0xE0, from: 0x88, command: [0x1C, 0x00], data: [])
        XCTAssertThrowsError(try commandSet.parsePTTResponse(emptyFrame)) { error in
            XCTAssertEqual(error as? RigError, .invalidResponse)
        }
    }

    func testInvalidFrequencyResponseThrows() {
        let commandSet = StandardIcomCommandSet.ic7300

        // Wrong data length
        let shortFrame = CIVFrame(to: 0xE0, from: 0x94, command: [0x03], data: [0x00, 0x00])
        XCTAssertThrowsError(try commandSet.parseFrequencyResponse(shortFrame)) { error in
            XCTAssertEqual(error as? RigError, .invalidResponse)
        }
    }
}
