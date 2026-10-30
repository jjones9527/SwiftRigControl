#!/usr/bin/env python3
"""Capture the exact bytes Hamlib sends for rigctl commands.

Runs one of Hamlib's radio simulators (simulators/sim*.c) on a pty so
Hamlib's rig_open handshake succeeds, drives `rigctl -m <model>` against
it with full tracing, and prints each write_block() payload. Used by the
command-by-command audit (Documentation/HAMLIB_COMMAND_AUDIT.md) to compare
Hamlib's wire bytes with SwiftRigControl's MockTransport captures.

Needs a local Hamlib build (not installed; nothing outside the build dir):

    cd ~/Developer/hamlib && LIBTOOLIZE=glibtoolize ./bootstrap
    mkdir -p ~/Developer/hamlib-build && cd ~/Developer/hamlib-build
    ../hamlib/configure --disable-shared --enable-static \
        --without-cxx-binding --without-libusb --without-readline \
        --without-xml-support --without-python-binding
    make -j8 && make -C simulators

Usage:

    Scripts/hamlib-wire-capture.py --sim simelecraft --model 2045 \
        -- "L AGC 2" "l STRENGTH"

Each rigctl command runs in its own rigctl session. Only the traffic
between command dispatch and rig shutdown is printed, so the rig_open /
rig_close handshakes are left out. --replies adds the simulator's answers.
Simulator replies are canned, so gets show Hamlib's request bytes and
parsing path, not real radio values.
"""

import argparse
import os
import pty
import re
import select
import subprocess
import sys
import time

BUILD = os.path.expanduser(os.environ.get("HAMLIB_BUILD", "~/Developer/hamlib-build"))
RIGCTL = os.path.join(BUILD, "tests", "rigctl")
HEX_LINE = re.compile(r"^0[0-9a-f]{3}\s+((?:[0-9a-f]{2} )+)")


def start_simulator(name):
    """Start simulators/<name> with stdout on a pty and return (proc, slave path)."""
    path = os.path.join(BUILD, "simulators", name)
    master, slave = pty.openpty()
    proc = subprocess.Popen([path], stdout=slave, stderr=slave, stdin=subprocess.DEVNULL)
    os.close(slave)
    buffer = b""
    deadline = time.time() + 5
    while time.time() < deadline:
        ready, _, _ = select.select([master], [], [], 0.2)
        if ready:
            buffer += os.read(master, 4096)
            match = re.search(rb"name=(/dev/\S+)", buffer)
            if match:
                # Keep draining the simulator's chatter so it never blocks.
                drain = subprocess.Popen(["cat"], stdin=master, stdout=subprocess.DEVNULL)
                return proc, drain, match.group(1).decode()
    proc.kill()
    sys.exit(f"simulator {name} did not report its pty: {buffer!r}")


COMMAND_START = "rigctl_parse: called"
COMMAND_END = ("Stopping rig poll routine", "rig_close(")


def exchanges(trace):
    """Return [(direction, bytes)] for the command part of a rigctl -vvvvv trace.

    Only traffic between rigctl's command dispatch and rig shutdown is kept,
    so rig_open / rig_close handshakes are left out. direction is "TX" for
    write_block() and "RX" for read_*() hex dumps.
    """
    found, current, direction, active = [], b"", None, False

    def flush():
        nonlocal current
        if current and direction:
            found.append((direction, current))
        current = b""

    for line in trace.splitlines():
        if COMMAND_START in line:
            active = True
            continue
        if active and any(marker in line for marker in COMMAND_END):
            break
        if not active:
            continue
        if "write_block()" in line or re.search(r"read_\w+\(\): RX", line):
            flush()
            direction = "TX" if "write_block()" in line else "RX"
            continue
        match = HEX_LINE.match(line)
        if direction and match:
            current += bytes.fromhex(match.group(1).replace(" ", ""))
            continue
        flush()
        direction = None
    flush()
    return found


def show(data):
    printable = all(32 <= b < 127 for b in data)
    return data.decode("ascii") if printable else data.hex(" ").upper()


def run(model, port, commands, extra):
    cmd = [RIGCTL, "-m", str(model), "-r", port, "-vvvvv", *extra, *commands]
    try:
        done = subprocess.run(cmd, capture_output=True, text=True, timeout=60, stdin=subprocess.DEVNULL)
        return done.stdout + done.stderr
    except subprocess.TimeoutExpired as error:
        return (error.stdout or "") + (error.stderr or "") if isinstance(error.stdout, str) else ""


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sim", required=True, help="simulator binary name, e.g. simelecraft")
    parser.add_argument("--model", required=True, help="Hamlib model number (rigctl -l)")
    parser.add_argument("--conf", action="append", default=[], help="rigctl --set-conf value")
    parser.add_argument("--replies", action="store_true", help="also print what the simulator answered")
    parser.add_argument("commands", nargs="+", help="rigctl commands, one per argument")
    args = parser.parse_args()

    extra = [f"--set-conf={c}" for c in args.conf]
    proc, drain, port = start_simulator(args.sim)
    try:
        for command in args.commands:
            trace = run(args.model, port, command.split(), extra)
            parts = [f"{d} {show(b)}" for d, b in exchanges(trace)]
            if not args.replies:
                parts = [p[3:] for p in parts if p.startswith("TX")]
            print(f"{command}: " + (" | ".join(parts) or "(nothing)"))
    finally:
        proc.kill()
        drain.kill()


if __name__ == "__main__":
    main()
