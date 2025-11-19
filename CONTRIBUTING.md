# Contributing to SwiftRigControl

Thank you for your interest in contributing to SwiftRigControl! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [How Can I Contribute?](#how-can-i-contribute)
3. [Development Setup](#development-setup)
4. [Coding Standards](#coding-standards)
5. [Testing Requirements](#testing-requirements)
6. [Pull Request Process](#pull-request-process)
7. [Adding Radio Support](#adding-radio-support)
8. [Documentation](#documentation)

## Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers and help them learn
- Focus on constructive feedback
- Respect differing viewpoints and experiences
- Accept responsibility for mistakes

### Unacceptable Behavior

- Harassment, discrimination, or trolling
- Personal attacks or insults
- Publishing others' private information
- Spam or off-topic discussions

## How Can I Contribute?

### Reporting Bugs

Before creating a bug report:
1. **Check existing issues** to avoid duplicates
2. **Test with the latest version** to ensure it's not already fixed
3. **Gather information**: macOS version, Swift version, radio model

**Good Bug Report Includes:**
- Clear, descriptive title
- Steps to reproduce
- Expected vs actual behavior
- Code samples (minimal reproduction)
- System information
- Any error messages or logs

**Example:**
```markdown
**Title:** IC-7300 fails to set frequency above 50 MHz

**Description:**
Setting frequency above 50 MHz on IC-7300 throws RigError.commandFailed

**Steps to Reproduce:**
1. Connect to IC-7300
2. Call `rig.setFrequency(52_000_000, vfo: .a)`
3. Observe error

**Expected:** Frequency set to 52 MHz
**Actual:** Throws RigError.commandFailed

**Environment:**
- macOS 14.1
- Swift 5.9
- SwiftRigControl 1.0.0
- IC-7300 firmware 1.40
```

### Suggesting Enhancements

Enhancement suggestions are welcome! Include:
- Clear description of the feature
- Why it's useful (use cases)
- Possible implementation approach
- Any relevant examples from other projects

### Contributing Code

Areas where contributions are particularly welcome:

1. **Additional Radio Support**
   - New radio models for existing protocols
   - Support for additional manufacturers

2. **New Features**
   - S-meter reading
   - Channel memory operations
   - RIT/XIT support
   - Antenna selection

3. **Bug Fixes**
   - Protocol edge cases
   - Error handling improvements
   - Performance optimizations

4. **Documentation**
   - Usage examples
   - Tutorial content
   - Translation (if applicable)

5. **Testing**
   - Integration tests with real radios
   - Edge case coverage
   - Protocol validation

## Development Setup

### Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later
- Git

### Clone and Build

```bash
# Clone the repository
git clone https://github.com/yourusername/SwiftRigControl.git
cd SwiftRigControl

# Build the project
swift build

# Run tests
swift test

# Open in Xcode (optional)
open Package.swift
```

### Project Structure

```
SwiftRigControl/
├── Sources/
│   ├── RigControl/           # Core library
│   │   ├── Core/            # Protocols and controllers
│   │   ├── Transport/       # Serial communication
│   │   ├── Protocols/       # Radio protocol implementations
│   │   ├── Models/          # Data models
│   │   └── Utilities/       # Helper utilities
│   ├── RigControlXPC/        # XPC helper
│   └── RigControlHelper/     # XPC executable
├── Tests/
│   └── RigControlTests/      # Unit and integration tests
├── Documentation/            # Documentation files
└── Package.swift            # Swift Package Manager manifest
```

## Coding Standards

### Swift Style Guide

Follow standard Swift conventions:

#### Naming

```swift
// Classes, Structs, Enums, Protocols: PascalCase
class RigController { }
struct RadioDefinition { }
enum Mode { }
protocol CATProtocol { }

// Functions, Variables: camelCase
func setFrequency() { }
let currentFrequency: UInt64

// Constants: camelCase
let defaultBaudRate = 115200

// Enum cases: camelCase
enum VFO {
    case a, b, main, sub
}
```

#### Formatting

```swift
// Use 4 spaces for indentation (no tabs)
func exampleFunction() {
    if condition {
        doSomething()
    }
}

// Opening braces on same line
class MyClass {
    func myMethod() {
        // ...
    }
}

// Line length: prefer 100 characters max
```

#### Documentation

```swift
/// Brief description of the function.
///
/// Longer description with more details if needed.
///
/// - Parameters:
///   - frequency: The frequency in Hertz
///   - vfo: The VFO to set (defaults to .a)
///
/// - Throws: `RigError` if operation fails
///
/// - Example:
/// ```swift
/// try await rig.setFrequency(14_230_000, vfo: .a)
/// ```
public func setFrequency(_ frequency: UInt64, vfo: VFO = .a) async throws {
    // Implementation
}
```

### Concurrency

- Use `async/await` for all asynchronous operations
- Use `actor` for mutable shared state
- Avoid callbacks and completion handlers
- No blocking operations on main actor

```swift
// Good: async/await
public actor RigController {
    public func setFrequency(_ hz: UInt64) async throws {
        try await proto.setFrequency(hz, vfo: .a)
    }
}

// Bad: callbacks
public func setFrequency(_ hz: UInt64, completion: @escaping (Error?) -> Void) {
    // Don't do this
}
```

### Error Handling

```swift
// Use typed errors
public enum RigError: Error {
    case notConnected
    case timeout
    case commandFailed(String)
}

// Throw instead of returning error codes
func someOperation() async throws {
    guard connected else {
        throw RigError.notConnected
    }
    // ...
}
```

## Testing Requirements

### Unit Tests Required

All new code must include unit tests:

```swift
import XCTest
@testable import RigControl

final class MyFeatureTests: XCTestCase {
    func testFeature() async throws {
        // Arrange
        let mockTransport = MockTransport()
        let protocol = MyProtocol(transport: mockTransport)

        // Act
        try await protocol.someOperation()

        // Assert
        XCTAssertEqual(mockTransport.recordedWrites.count, 1)
    }
}
```

### Test Coverage

- Aim for 90%+ code coverage
- Test happy paths and error cases
- Test edge cases and boundary conditions
- Use MockTransport for protocol testing

### Integration Tests

If adding new radio support, include integration test template:

```swift
func testWithRealHardware() async throws {
    // Only runs when RIG_SERIAL_PORT is set
    guard let port = ProcessInfo.processInfo.environment["RIG_SERIAL_PORT"] else {
        throw XCTSkip("Set RIG_SERIAL_PORT to run integration tests")
    }

    let rig = RigController(
        radio: .yourRadio,
        connection: .serial(path: port, baudRate: nil)
    )

    try await rig.connect()
    // Test operations
    await rig.disconnect()
}
```

### Running Tests

```bash
# Run all tests
swift test

# Run with coverage
swift test --enable-code-coverage

# Run specific test
swift test --filter MyFeatureTests

# Run integration tests (requires hardware)
RIG_SERIAL_PORT=/dev/cu.IC9700 swift test --filter IntegrationTests
```

## Pull Request Process

### Before Submitting

1. **Create an issue first** for major changes
2. **Fork the repository** and create a branch
3. **Write tests** for your changes
4. **Run all tests** and ensure they pass
5. **Update documentation** as needed
6. **Follow coding standards**

### Branch Naming

```bash
# Feature branches
git checkout -b feature/add-icom-ic705-support

# Bug fix branches
git checkout -b fix/frequency-parsing-bug

# Documentation branches
git checkout -b docs/improve-xpc-guide
```

### Commit Messages

Follow conventional commits format:

```
type(scope): subject

body (optional)

footer (optional)
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `test`: Adding tests
- `refactor`: Code refactoring
- `perf`: Performance improvement
- `chore`: Maintenance tasks

**Examples:**
```
feat(protocols): add Icom IC-705 support

Implements CI-V protocol support for IC-705 portable transceiver.
Includes radio definition and unit tests.

Closes #42
```

```
fix(kenwood): correct VFO selection command

FR command was using incorrect parameter. Changed from FR0/FR1
to correct values per Kenwood documentation.

Fixes #67
```

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement

## Testing
- [ ] Unit tests added/updated
- [ ] All tests pass
- [ ] Tested with real hardware (if applicable)

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes (or documented)
```

### Review Process

1. **Automated checks** must pass (build, tests)
2. **Code review** by maintainer(s)
3. **Requested changes** addressed
4. **Approval** from maintainer
5. **Merge** by maintainer

### After Merge

- Your contribution will be acknowledged in release notes
- Branch will be deleted after merge
- Issue will be closed automatically (if linked)

## Adding Radio Support

### For Existing Protocol

If adding a radio that uses an existing protocol (e.g., another Icom radio):

1. **Create Radio Definition**

```swift
// In Sources/RigControl/Protocols/Icom/IcomModels.swift

public static let icomICYourModel = RadioDefinition(
    manufacturer: .icom,
    model: "IC-YourModel",
    defaultBaudRate: 115200,
    capabilities: RigCapabilities(
        hasVFOB: true,
        hasSplit: true,
        powerControl: true,
        maxPower: 100,
        supportedModes: [.lsb, .usb, .cw, .fm, .am],
        frequencyRange: (30_000, 60_000_000),
        hasDualReceiver: false,
        hasATU: true
    ),
    civAddress: 0xYY,  // From radio manual
    protocolFactory: { transport in
        IcomCIVProtocol(
            transport: transport,
            civAddress: 0xYY,
            capabilities: /* capabilities from above */
        )
    }
)
```

2. **Add to XPC Server** (if using XPC)

```swift
// In Sources/RigControlXPC/XPCServer.swift
// Add to radioDefinitionFromString() method

case "IC-YourModel", "ICYourModel":
    return .icomICYourModel
```

3. **Add Unit Tests**

```swift
// In Tests/RigControlTests/IcomCIVProtocolTests.swift

func testYourModelCapabilities() {
    let radio = RadioDefinition.icomICYourModel
    XCTAssertEqual(radio.defaultBaudRate, 115200)
    XCTAssertTrue(radio.capabilities.hasSplit)
}
```

4. **Update Documentation**

- Add to README.md supported radios list
- Add to SERIAL_PORT_GUIDE.md if configuration differs
- Update CHANGELOG.md

### For New Protocol

If implementing a protocol for a new manufacturer:

1. **Create Protocol Directory**
```
Sources/RigControl/Protocols/YourManufacturer/
├── YourProtocol.swift
└── YourModels.swift
```

2. **Implement CATProtocol**

```swift
public actor YourProtocol: CATProtocol {
    public let transport: any SerialTransport
    public let capabilities: RigCapabilities

    public func setFrequency(_ hz: UInt64, vfo: VFO) async throws {
        // Implementation
    }

    // Implement all CATProtocol requirements
}
```

3. **Add Comprehensive Tests**

4. **Update Documentation** extensively

5. **Discuss in Issue First** - new protocols require design review

## Documentation

### What to Document

- **Public APIs**: All public functions, classes, and protocols
- **Usage Examples**: Common use cases and patterns
- **Error Cases**: When and why errors occur
- **Edge Cases**: Unusual situations or limitations

### Documentation Style

```swift
/// Sets the operating frequency.
///
/// The frequency is specified in Hertz. For example, 14.230 MHz
/// should be passed as 14_230_000.
///
/// - Parameters:
///   - hz: Frequency in Hertz
///   - vfo: The VFO to set (defaults to VFO A)
///
/// - Throws:
///   - `RigError.notConnected` if not connected to radio
///   - `RigError.commandFailed` if radio rejects frequency
///   - `RigError.timeout` if radio doesn't respond
///
/// - Example:
/// ```swift
/// // Set to 20m SSTV calling frequency
/// try await rig.setFrequency(14_230_000, vfo: .a)
/// ```
public func setFrequency(_ hz: UInt64, vfo: VFO = .a) async throws {
    // Implementation
}
```

### Updating Documentation Files

When adding features:
- Update README.md if it's a major feature
- Add example to USAGE_EXAMPLES.md
- Add troubleshooting section if needed
- Update CHANGELOG.md

## Questions?

- **GitHub Issues**: For bugs and features
- **GitHub Discussions**: For questions and discussions
- **Email**: [project email if available]

## Recognition

Contributors will be:
- Listed in release notes
- Credited in documentation (if substantial contribution)
- Thanked in the community

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing to SwiftRigControl!**

**73!**
