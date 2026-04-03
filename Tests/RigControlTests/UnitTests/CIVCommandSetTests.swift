import Testing
@testable import RigControl

/// Unit tests for CIVCommandSet protocol implementations
@Suite struct CIVCommandSetTests {

    // MARK: - IC7100CommandSet Tests

    @Test func ic7100Properties() {
        let commandSet = IC7100CommandSet()
        #expect(commandSet.civAddress == 0x88)
        #expect(commandSet.powerUnits == .percentage)
        #expect(commandSet.echoesCommands)
        #expect(commandSet.requiresVFOSelection) // .currentOnly requires VFO selection
    }

    @Test func ic7100ModeCommand() {
        let commandSet = IC7100CommandSet()

        // IC-7100 does NOT include filter byte
        let (cmd, data) = commandSet.setModeCommand(mode: 0x01) // USB
        #expect(cmd == [0x06])
        #expect(data == [0x01]) // Mode only, no filter
    }

    @Test func ic7100PowerCommand() {
        let commandSet = IC7100CommandSet()

        // Test 50%
        let (cmd, data) = commandSet.setPowerCommand(value: 50)
        #expect(cmd == [0x14, 0x0A])
        #expect(data.count == 2) // BCD encoded

        // Decode to verify
        let scale = BCDEncoding.decodePower(data)
        let percentage = (scale * 100) / 255
        #expect(abs(percentage - 50) <= 1)
    }

    @Test func ic7100PTTCommand() {
        let commandSet = IC7100CommandSet()

        // Test TX
        let (cmdTX, dataTX) = commandSet.setPTTCommand(enabled: true)
        #expect(cmdTX == [0x1C, 0x00])
        #expect(dataTX == [0x01])

        // Test RX
        let (cmdRX, dataRX) = commandSet.setPTTCommand(enabled: false)
        #expect(cmdRX == [0x1C, 0x00])
        #expect(dataRX == [0x00])
    }

    @Test func ic7100VFOCommand() {
        let commandSet = IC7100CommandSet()

        // IC-7100 uses .currentOnly model - requires VFO selection (switch to desired VFO)
        let cmdA = commandSet.selectVFOCommand(.a)
        #expect(cmdA != nil)
        #expect(cmdA?.command == [0x07])
        #expect(cmdA?.data == [0x00]) // VFO A

        let cmdB = commandSet.selectVFOCommand(.b)
        #expect(cmdB != nil)
        #expect(cmdB?.command == [0x07])
        #expect(cmdB?.data == [0x01]) // VFO B
    }

    @Test func ic7100ParseModeResponse() throws {
        let commandSet = IC7100CommandSet()

        // Simulate response: FE FE E0 88 04 01 FD (mode = USB)
        let frame = CIVFrame(to: 0xE0, from: 0x88, command: [0x04], data: [0x01])
        let mode = try commandSet.parseModeResponse(frame)
        #expect(mode == 0x01) // USB
    }

    @Test func ic7100ParsePowerResponse() throws {
        let commandSet = IC7100CommandSet()

        // Simulate 100% power response
        let powerBCD = BCDEncoding.encodePower(255)
        let frame = CIVFrame(to: 0xE0, from: 0x88, command: [0x14, 0x0A], data: powerBCD)
        let power = try commandSet.parsePowerResponse(frame)
        #expect(power == 100)
    }

    @Test func ic7100ParsePTTResponse() throws {
        let commandSet = IC7100CommandSet()

        // Simulate TX response
        let frameTX = CIVFrame(to: 0xE0, from: 0x88, command: [0x1C, 0x00], data: [0x01])
        #expect(try commandSet.parsePTTResponse(frameTX))

        // Simulate RX response
        let frameRX = CIVFrame(to: 0xE0, from: 0x88, command: [0x1C, 0x00], data: [0x00])
        #expect(try !commandSet.parsePTTResponse(frameRX))
    }

    // MARK: - IC9700CommandSet Tests

    @Test func ic9700Properties() {
        let commandSet = IC9700CommandSet()
        #expect(commandSet.civAddress == 0xA2)
        #expect(commandSet.powerUnits == .percentage)
        #expect(commandSet.echoesCommands) // IC-9700 echoes commands over USB
        #expect(commandSet.requiresVFOSelection)
    }

    @Test func ic9700ModeCommand() {
        let commandSet = IC9700CommandSet()

        // IC-9700 does NOT include filter byte (requiresModeFilter = false)
        let (cmd, data) = commandSet.setModeCommand(mode: 0x01) // USB
        #expect(cmd == [0x06])
        #expect(data == [0x01]) // Mode only, no filter
    }

    @Test func ic9700PowerCommand() {
        let commandSet = IC9700CommandSet()

        // Test 75%
        let (cmd, data) = commandSet.setPowerCommand(value: 75)
        #expect(cmd == [0x14, 0x0A])
        #expect(data.count == 2)

        // Decode to verify
        let scale = BCDEncoding.decodePower(data)
        let percentage = (scale * 100) / 255
        #expect(abs(percentage - 75) <= 1)
    }

    @Test func ic9700VFOCommand() {
        let commandSet = IC9700CommandSet()

        // IC-9700 requires VFO selection
        let cmdA = commandSet.selectVFOCommand(.a)
        #expect(cmdA != nil)
        #expect(cmdA?.command == [0x07])
        #expect(cmdA?.data == [0x00]) // VFO A

        let cmdMain = commandSet.selectVFOCommand(.main)
        #expect(cmdMain != nil)
        #expect(cmdMain?.command == [0x07])
        #expect(cmdMain?.data == [0xD0]) // Main receiver
    }

    // MARK: - StandardIcomCommandSet Tests

    @Test func standardCommandSetProperties() {
        let commandSet = StandardIcomCommandSet(civAddress: 0x94)
        #expect(commandSet.civAddress == 0x94)
        #expect(commandSet.powerUnits == .percentage)
        #expect(!commandSet.echoesCommands)
        #expect(commandSet.requiresVFOSelection)
    }

    @Test func standardCommandSetCustomization() {
        let commandSet = StandardIcomCommandSet(
            civAddress: 0xA4,
            echoesCommands: true
        )
        #expect(commandSet.civAddress == 0xA4)
        #expect(commandSet.echoesCommands)
    }

    @Test func standardModeCommand() {
        let commandSet = StandardIcomCommandSet(civAddress: 0x94)

        // Standard radios include filter byte (0x01 = FIL1, the default)
        let (cmd, data) = commandSet.setModeCommand(mode: 0x00) // LSB
        #expect(cmd == [0x06])
        #expect(data == [0x00, 0x01]) // Mode + FIL1 filter
    }

    @Test func standardFrequencyCommand() throws {
        let commandSet = StandardIcomCommandSet(civAddress: 0x94)

        // Test 14.250 MHz
        let (cmd, data) = commandSet.setFrequencyCommand(frequency: 14_250_000)
        #expect(cmd == [0x05])
        #expect(data.count == 5)

        // Verify encoding
        let freq = try BCDEncoding.decodeFrequency(data)
        #expect(freq == 14_250_000)
    }

    @Test func standardParseFrequencyResponse() throws {
        let commandSet = StandardIcomCommandSet(civAddress: 0x94)

        // Simulate frequency response for 7.200 MHz
        let freqBCD = BCDEncoding.encodeFrequency(7_200_000)
        let frame = CIVFrame(to: 0xE0, from: 0x94, command: [0x03], data: freqBCD)
        let freq = try commandSet.parseFrequencyResponse(frame)
        #expect(freq == 7_200_000)
    }

    // MARK: - Power Scale Tests

    @Test func powerScaleRoundTrip() throws {
        let commandSets: [any CIVCommandSet] = [
            IC7100CommandSet(),
            IC9700CommandSet(),
            StandardIcomCommandSet(civAddress: 0x94) // IC-7300
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
                #expect(
                    abs(parsedPower - testPower) <= 1,
                    "Power round-trip failed for \(testPower)% on address 0x\(String(format: "%02X", commandSet.civAddress))"
                )
            }
        }
    }

    // MARK: - Error Handling Tests

    @Test func invalidModeResponseThrows() {
        let commandSet = IC7100CommandSet()

        // Wrong command in response
        let badFrame = CIVFrame(to: 0xE0, from: 0x88, command: [0x05], data: [0x01])
        #expect(throws: RigError.invalidResponse) {
            try commandSet.parseModeResponse(badFrame)
        }

        // Empty data
        let emptyFrame = CIVFrame(to: 0xE0, from: 0x88, command: [0x04], data: [])
        #expect(throws: RigError.invalidResponse) {
            try commandSet.parseModeResponse(emptyFrame)
        }
    }

    @Test func invalidPowerResponseThrows() {
        let commandSet = IC7100CommandSet()

        // Wrong command
        let badFrame = CIVFrame(to: 0xE0, from: 0x88, command: [0x14, 0x0B], data: [0x00, 0x00])
        #expect(throws: RigError.invalidResponse) {
            try commandSet.parsePowerResponse(badFrame)
        }

        // Insufficient data
        let shortFrame = CIVFrame(to: 0xE0, from: 0x88, command: [0x14, 0x0A], data: [0x00])
        #expect(throws: RigError.invalidResponse) {
            try commandSet.parsePowerResponse(shortFrame)
        }
    }

    @Test func invalidPTTResponseThrows() {
        let commandSet = IC7100CommandSet()

        // Wrong command
        let badFrame = CIVFrame(to: 0xE0, from: 0x88, command: [0x1C, 0x01], data: [0x00])
        #expect(throws: RigError.invalidResponse) {
            try commandSet.parsePTTResponse(badFrame)
        }

        // Empty data
        let emptyFrame = CIVFrame(to: 0xE0, from: 0x88, command: [0x1C, 0x00], data: [])
        #expect(throws: RigError.invalidResponse) {
            try commandSet.parsePTTResponse(emptyFrame)
        }
    }

    @Test func invalidFrequencyResponseThrows() {
        let commandSet = StandardIcomCommandSet(civAddress: 0x94) // IC-7300

        // Wrong data length
        let shortFrame = CIVFrame(to: 0xE0, from: 0x94, command: [0x03], data: [0x00, 0x00])
        #expect(throws: RigError.invalidResponse) {
            try commandSet.parseFrequencyResponse(shortFrame)
        }
    }
}
