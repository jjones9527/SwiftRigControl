# Hardware check: v1.2.16 – v1.2.19 on the verified radios

v1.2.16 through v1.2.19 shipped mock-tested only. Four of the changes
run on radios we list as hardware-verified (IC-7100, IC-7600, IC-9700,
K2), so this check keeps that claim honest. Allow about 15 minutes per
radio. A dummy load is needed only for the optional PTT steps.

| Change | Release | Radios | Covered by |
|---|---|---|---|
| DATA flag set and read with `0x1A 0x06`; DATA cleared when leaving a DATA mode | 1.2.19 | IC-7100, IC-7600, IC-9700 | Part 1, Part 2 |
| `getMode` reads the radio's real DATA flag (was always plain USB/LSB/FM) | 1.2.19 | same | Part 1 (front-panel step), Part 2 |
| AGC wire bytes from each model's Hamlib `agc_levels` table | 1.2.17 | same | Part 1 |
| `TIOCEXCL`: a second program can't open the port while we hold it | 1.2.18 | all | Part 1, Part 3 |
| rigctld accepts `F 14074000.000000` (netrigctl `%lf`) | 1.2.17 | all | Part 2 |
| PTT ACK survives transceive broadcasts (async-frame skip) | 1.2.16 | IC-7100 especially | Part 1 (opt-in), Part 2 |
| K2 at 8-N-2 (ROADMAP 5.8.1) | 1.1.2 | K2 | Part 3 |

Before you start, turn **CI-V Transceive ON** on the Icoms (the
IC-7100 default). The PTT and mode checks are only meaningful with
broadcasts on the bus.

## Part 1 — `IcomReleaseValidator` (per Icom)

```bash
cd Tools/SwiftRigControlTools
swift run IcomReleaseValidator ic7100 /dev/cu.usbserial-XXXX
swift run IcomReleaseValidator ic7600 /dev/cu.usbserial-XXXX
swift run IcomReleaseValidator ic9700 /dev/cu.usbserial-XXXX
```

It saves the radio's frequency, mode and AGC, runs the checks below,
and restores them. `--no-prompt` skips the two interactive steps.

1. **Exclusive access.** Opens the port a second time while connected;
   the second open must fail.
2. **DATA modes.** Sets and reads back, in order, USB → DATA-USB → USB
   → LSB → DATA-LSB → LSB → DATA-USB → CW on the SSB frequency, then
   FM → DATA-FM → FM on the FM frequency (only the modes the radio
   supports). **Also watch the radio:** the `D` / `-D` indicator must
   come on and go off with each step. A readback can pass while the
   radio display is wrong only if both set and read are wrong in the
   same way, so the display is the independent check.
3. **Front-panel readback** (prompted). You switch DATA on, then off,
   from the front panel; the validator must read DATA-USB, then USB.
   This is the case that always read plain USB before v1.2.19.
4. **AGC.** FAST → MID → SLOW, read back each. Check the radio's AGC
   display matches each step (a wrong wire byte would show a different
   speed on the radio even if the readback agrees).
5. **Power-state probe.** Must report on.
6. **PTT** (prompted, keys the transmitter). Three 1-second key/unkey
   cycles with transceive on. Set low power and use a dummy load.

Expected: `Failed: 0`. Copy the summary block into the report.

## Part 2 — rigctld bridge with Hamlib's own client (one Icom is enough; IC-7100 preferred)

```bash
cd Tools/SwiftRigControlTools
swift run RigctldEmulator -r IC-7100 -s /dev/cu.usbserial-XXXX -b 19200   # -b = the radio's CI-V baud
# in a second terminal (Hamlib installed: brew install hamlib)
rigctl -m 2 -r localhost:4532 F 14074000.000000   # no error (was RPRT -1)
rigctl -m 2 -r localhost:4532 f                   # 14074000
rigctl -m 2 -r localhost:4532 M PKTUSB 0          # radio shows USB-D
rigctl -m 2 -r localhost:4532 m                   # PKTUSB
rigctl -m 2 -r localhost:4532 M USB 0             # D indicator off
rigctl -m 2 -r localhost:4532 m                   # USB
rigctl -m 2 -r localhost:4532 '\get_powerstat'    # 1
# PTT — keys TX, dummy load:
rigctl -m 2 -r localhost:4532 T 1 T 0 T 1 T 0      # no errors
```

If Direwolf or WSJT-X is set up, a short session through the bridge
(Direwolf `PTT RIG 2 localhost:4532`) is the field-realistic version
of the PTT step: the log should show no `RPRT` errors.

## Part 3 — Elecraft K2

```bash
cd Tools/SwiftRigControlTools
export K2_SERIAL_PORT=/dev/cu.usbserial-XXXX
swift run K2Validator
```

The K2 now opens at **8-N-2** (ROADMAP 5.8.1); it was verified at
8-N-1. A clean run here closes 5.8.1. While the validator is running,
`screen /dev/cu.usbserial-XXXX 4800` in another terminal should fail
with "resource busy" (`TIOCEXCL`).

## Reporting

For each radio: firmware version, the summary block, and any step where
the radio display disagreed with the readback. A failure in Part 1
step 2 or 3 is the one to report first: it would mean the v1.2.19
DATA-mode change is wrong on real radios.
