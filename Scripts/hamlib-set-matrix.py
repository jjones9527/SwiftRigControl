#!/usr/bin/env python3
"""Tabulate the set frames Hamlib sends, per model and command.

For each model, runs each rigctl command against a Hamlib simulator and
prints the frames Hamlib wrote that the radio didn't answer with data
(set frames; `ID;` verification is dropped). Set commands come out the
same whatever the simulator replies, so a generic simulator is enough to
read off each backend's wire format and scaling. Used to build the
per-model tables in SwiftRigControl (see Documentation/HAMLIB_COMMAND_AUDIT.md).

Uses the helpers in hamlib-diff-audit.py; same Hamlib build setup.

Usage:

    Scripts/hamlib-set-matrix.py --model "TS-590SG=2037:simts590" \\
        --model "TS-480=2028:simkenwood" -- "L AGC 2" "L ATT 12"
    Scripts/hamlib-set-matrix.py --models-file kenwood.txt --commands-file levels.txt --json out.json

    # Simulator "ack" is a built-in radio that ACKs every frame (best for
    # CI-V). A third field names our catalog radio and adds an "ours" row
    # per command, marked same / DIFF:
    Scripts/hamlib-set-matrix.py --framing civ \\
        --model "IC-705=3085:ack:Icom IC-705" -- "L RFPOWER 0.5"

The "ours" rows run Tools/SwiftRigControlTools HamlibDiffClient, which
`HamlibDiffClient --list --power` also uses to list each catalog radio's
protocol, maxPower and powerUnits.
"""

import argparse
import importlib.util
import json
import os
import pty
import select
import sys
import threading
import time
import tty

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("audit", os.path.join(HERE, "hamlib-diff-audit.py"))
audit = importlib.util.module_from_spec(spec)
sys.dont_write_bytecode = True
spec.loader.exec_module(audit)


class AckRadio(threading.Thread):
    """A fake radio that acknowledges every frame, for capturing set frames.

    CI-V frames get `FE FE E0 <radio> FB FD` (apart from a few reads
    Hamlib's open needs, see reply); text frames get nothing,
    except `ID;`, which gets `ID000;` so set verification succeeds.
    Exposes the Relay interface (port, set_label, traffic) so
    hamlib-diff-audit's SwiftClient can drive it.
    """

    def __init__(self, framing):
        super().__init__(daemon=True)
        self.framing = framing
        self.master, self.slave = pty.openpty()
        tty.setraw(self.slave)
        self.port = os.ttyname(self.slave)
        self.label, self.log, self.lock, self.running = "open", [], threading.Lock(), True
        self.buffer = b""

    def run(self):
        terminator = audit.TERMINATORS[self.framing]
        while self.running:
            ready, _, _ = select.select([self.master], [], [], 0.1)
            if not ready:
                continue
            try:
                data = os.read(self.master, 4096)
            except OSError:
                continue
            with self.lock:
                self.log.append((self.label, "TX", data))
            self.buffer += data
            while terminator in self.buffer:
                frame, _, self.buffer = self.buffer.partition(terminator)
                frame += terminator
                reply = self.reply(frame)
                if reply:
                    os.write(self.master, reply)
                    with self.lock:
                        self.log.append((self.label, "RX", reply))

    def reply(self, frame):
        if self.framing == "civ":
            start = frame.find(b"\xfe\xfe")
            if start < 0 or len(frame) < start + 5:
                return b""
            radio, body = frame[start + 2], frame[start + 4:-1]
            # Hamlib's Icom open reads the frequency (0x03, then 0x25) to
            # check for USB echo and gives up on a bare ACK, so answer the
            # reads it needs with 14.074 MHz USB; everything else is ACKed.
            freq = bytes([0x00, 0x40, 0x07, 0x14, 0x00])
            reads = {b"\x03": b"\x03" + freq, b"\x04": b"\x04\x01\x01",
                     b"\x25\x00": b"\x25\x00" + freq, b"\x25\x01": b"\x25\x01" + freq,
                     b"\x26\x00": b"\x26\x00\x01\x00\x01", b"\x26\x01": b"\x26\x01\x01\x00\x01",
                     b"\x19\x00": b"\x19\x00" + bytes([radio])}
            payload = reads.get(bytes(body), b"\xfb")
            return bytes([0xFE, 0xFE, 0xE0, radio]) + payload + b"\xfd"
        if frame == b"ID;":
            return b"ID000;"
        return b""

    def set_label(self, label):
        with self.lock:
            self.label = label

    def traffic(self, label):
        with self.lock:
            return [(d, b) for l, d, b in self.log if l == label]

    def stop(self):
        self.running = False
        self.join(1)
        for fd in (self.master, self.slave):
            try:
                os.close(fd)
            except OSError:
                pass


def tx_frames(exchanges, framing):
    """Every distinct frame written, in order, whatever the reply. For
    reads and read-modify-write sets, which fail against the ACK radio
    after writing."""
    seen = []
    for frame in audit.frames(exchanges, framing):
        if frame not in seen and frame != "ID;":
            seen.append(frame)
    return seen


def cell(result, framing, tx):
    if tx:
        return tx_frames(result["exchanges"], framing) or [f"ERROR {(result['error'] or '')[:40]}"]
    sets, _, _ = audit.classify(result["exchanges"], framing)
    return sets if not result["error"] else [f"ERROR {result['error'][:40]}"]


def ours(name, commands, framing, tx=False):
    """Set frames SwiftRigControl sends for each command, against AckRadio."""
    radio = AckRadio(framing)
    radio.start()
    row = {}
    try:
        client = audit.SwiftClient(name, radio.port, radio)
        try:
            for index, command in enumerate(commands):
                result = client.run(command, f"{index}:{command}")
                row[command] = cell(result, framing, tx)
        finally:
            client.stop()
    finally:
        radio.stop()
    return row


def parse_model(text):
    """LABEL=HAMLIB_MODEL:SIMULATOR[:OUR CATALOG NAME]"""
    label, _, rest = text.partition("=")
    parts = rest.split(":")
    model = int(parts[0])
    sim = parts[1].strip() if len(parts) > 1 and parts[1].strip() else "simkenwood"
    catalog = parts[2].strip() if len(parts) > 2 else None
    return label.strip(), model, sim, catalog


def lines(path):
    with open(path) as f:
        return [l.strip() for l in f if l.strip() and not l.startswith("#")]


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--model", action="append", default=[],
                        help="LABEL=HAMLIB_MODEL:SIMULATOR[:CATALOG NAME] (catalog name also captures ours)")
    parser.add_argument("--models-file")
    parser.add_argument("--commands-file")
    parser.add_argument("--framing", default="text", choices=["text", "civ", "cr"])
    parser.add_argument("--json", help="write {label: {command: [frames]}}")
    parser.add_argument("--tx", action="store_true",
                        help="compare every frame written, not just set frames (for reads)")
    parser.add_argument("commands", nargs="*")
    args = parser.parse_args()

    models = [parse_model(m) for m in args.model + (lines(args.models_file) if args.models_file else [])]
    commands = args.commands + (lines(args.commands_file) if args.commands_file else [])
    table = {}
    for label, model, sim_name, catalog in models:
        if sim_name == "ack":
            # Hamlib against the ACK radio: set frames don't depend on the
            # reply, and some simulators stall Hamlib's Icom open.
            sim = None
            relay = AckRadio(args.framing)
            relay.start()
        else:
            try:
                sim = audit.Simulator(sim_name)
            except RuntimeError as error:
                print(f"{label:<12} SKIPPED: {error}", flush=True)
                continue
            relay = audit.Relay(sim.port, civ=(args.framing == "civ"))
            relay.start()
        row = {}
        try:
            for command in commands:
                result = audit.run_hamlib(model, relay.port, command)
                row[command] = cell(result, args.framing, args.tx)
                print(f"{label:<12} {command:<22} {' '.join(row[command])}", flush=True)
        finally:
            relay.stop()
            if sim:
                sim.stop()
        table[label] = row
        if catalog:
            mine = ours(catalog, commands, args.framing, args.tx)
            table[label + " (ours)"] = mine
            for command in commands:
                verdict = "same" if mine[command] == row[command] else "DIFF"
                print(f"{label:<12} {command:<22} ours={' '.join(mine[command])}   [{verdict}]", flush=True)
    if args.json:
        with open(args.json, "w") as f:
            json.dump(table, f, indent=1)


if __name__ == "__main__":
    main()
