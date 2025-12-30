#!/bin/bash
# IC-7100 PTT Test Runner
# This script runs only the PTT test with automatic confirmation

export IC7100_SERIAL_PORT="/dev/cu.usbserial-2110"

echo ""
echo "=========================================="
echo "IC-7100 PTT Test"
echo "=========================================="
echo ""
echo "✓ Dummy load connected"
echo "✓ Running PTT test with confirmation"
echo ""

# Run just the PTT test and automatically answer 'y'
swift test --filter IC7100HardwareTests/testPTTControl <<EOF
y
EOF
