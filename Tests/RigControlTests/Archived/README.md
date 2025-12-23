# Archived Tests and Debug Tools

This directory contains legacy test code and debugging tools that have been superseded by the comprehensive hardware test suites.

## Directory Structure

### LegacyTests/
Contains older integration tests that have been replaced by radio-specific hardware test suites:
- `IcomIntegrationTests.swift` - Legacy generic Icom integration tests (replaced by IC7600/IC7100/IC9700HardwareTests)

### DebugTools/
Contains debugging and diagnostic tools that were used during development. These are preserved for historical reference and potential future debugging needs.

## Current Test Organization

For current tests, see:
- `Tests/RigControlTests/UnitTests/` - Unit tests for core functionality
- `Tests/RigControlTests/ProtocolTests/` - Protocol-level tests with mocks
- `Tests/RigControlTests/HardwareTests/` - Comprehensive hardware test suites
- `Tests/RigControlTests/Support/` - Test infrastructure and helpers

## Running Current Tests

```bash
# Run all unit tests
swift test --filter UnitTests

# Run all protocol tests
swift test --filter ProtocolTests

# Run specific hardware test suite
export IC7600_SERIAL_PORT="/dev/cu.IC7600"
swift test --filter IC7600HardwareTests

# Run all hardware tests
swift test --filter HardwareTests
```

## Note

The files in this directory are not actively maintained and may not compile with the current codebase. They are preserved for historical reference only.
