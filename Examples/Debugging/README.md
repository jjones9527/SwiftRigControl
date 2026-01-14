# Debugging Tools

This directory contains debugging and testing utilities used during development.

## K2 PTT Debug Tool

**K2PTTDebug** - Comprehensive PTT (Push-To-Talk) testing tool for Elecraft K2

Tests TX/RX commands and TQ query with 5-second observation windows. Useful for verifying CAT PTT functionality.

**Usage:**
```bash
K2_SERIAL_PORT="/dev/cu.usbserial-XXXX" swift run K2PTTDebug
```

## K2 Power Control Debug Tool

**K2PowerDebug** - Power control testing tool for Elecraft K2

Tests PC command (power control) for QRP settings (1W-15W). Verifies power setting and reading functionality.

**Usage:**
```bash
K2_SERIAL_PORT="/dev/cu.usbserial-XXXX" swift run K2PowerDebug
```

## K2 New Commands Test

**K2NewCommandsTest** - Tests newly implemented K2 commands

Tests TQ (transmit query), RC/RD/RU (RIT control) commands.

**Usage:**
```bash
K2_SERIAL_PORT="/dev/cu.usbserial-XXXX" swift run K2NewCommandsTest
```

## Notes

These tools were created during K2 implementation to isolate and debug specific functionality. They provide detailed output and timing information useful for troubleshooting CAT communication issues.

For comprehensive hardware validation, use the validators in `HardwareValidation/` directory.
