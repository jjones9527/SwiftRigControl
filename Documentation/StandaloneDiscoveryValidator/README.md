# Standalone Discovery Validator

Two files. No repo clone required on the target machine.

## On the dev machine (already done)

These files are checked in at `Documentation/StandaloneDiscoveryValidator/`.

## On the machine with the radios

1. Copy `Package.swift` and `main.swift` to a fresh directory:

   ```bash
   mkdir ~/swiftrig-validate && cd ~/swiftrig-validate
   curl -O https://raw.githubusercontent.com/jjones9527/SwiftRigControl/main/Documentation/StandaloneDiscoveryValidator/Package.swift
   curl -O https://raw.githubusercontent.com/jjones9527/SwiftRigControl/main/Documentation/StandaloneDiscoveryValidator/main.swift
   ```

2. Identify each radio's serial port and export it:

   ```bash
   ls /dev/cu.* | grep -v Bluetooth          # find the paths
   export IC7100_SERIAL_PORT="/dev/cu.usbserial-XXXX"
   export IC7600_SERIAL_PORT="/dev/cu.SLAB_USBtoUART"
   export IC9700_SERIAL_PORT="/dev/cu.usbmodem14101"
   export K2_SERIAL_PORT="/dev/cu.usbserial-FT8XYZWY"
   ```

   Only export the env vars for radios you actually have connected.

3. Run:

   ```bash
   swift run --package-path .
   ```

   First run takes 1–2 minutes while SPM fetches the package. Repeat
   runs are fast.

## What it does

- Drives the production `RadioDiscovery` actor (the same code path
  any third-party app would use).
- For each radio whose `*_SERIAL_PORT` is set: confirms the radio
  was found, and that it was found *on the expected port*.
- If two or more radios are connected, also exercises the
  multi-radio overload and verifies port-exclusivity.

## Pinning to a release tag

The `Package.swift` currently tracks `main`. After v1.1.0 is
tagged, change the dependency to:

```swift
.package(
    url: "https://github.com/jjones9527/SwiftRigControl.git",
    .exact("1.1.0")
)
```

…so the validator runs against the released artifact rather than
whatever is on `main` at run time.

## Cleanup

```bash
rm -rf ~/swiftrig-validate
```
