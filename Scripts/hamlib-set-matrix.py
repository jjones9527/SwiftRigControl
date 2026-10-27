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
"""

import argparse
import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("audit", os.path.join(HERE, "hamlib-diff-audit.py"))
audit = importlib.util.module_from_spec(spec)
sys.dont_write_bytecode = True
spec.loader.exec_module(audit)


def parse_model(text):
    label, _, rest = text.partition("=")
    model, _, sim = rest.partition(":")
    return label.strip(), int(model), sim.strip() or "simkenwood"


def lines(path):
    with open(path) as f:
        return [l.strip() for l in f if l.strip() and not l.startswith("#")]


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--model", action="append", default=[], help="LABEL=HAMLIB_MODEL:SIMULATOR")
    parser.add_argument("--models-file")
    parser.add_argument("--commands-file")
    parser.add_argument("--framing", default="text", choices=["text", "civ", "cr"])
    parser.add_argument("--json", help="write {label: {command: [frames]}}")
    parser.add_argument("commands", nargs="*")
    args = parser.parse_args()

    models = [parse_model(m) for m in args.model + (lines(args.models_file) if args.models_file else [])]
    commands = args.commands + (lines(args.commands_file) if args.commands_file else [])
    table = {}
    for label, model, sim_name in models:
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
                sets, _, _ = audit.classify(result["exchanges"], args.framing)
                row[command] = sets if not result["error"] else [f"ERROR {result['error'][:40]}"]
                print(f"{label:<12} {command:<22} {' '.join(row[command])}", flush=True)
        finally:
            relay.stop()
            sim.stop()
        table[label] = row
    if args.json:
        with open(args.json, "w") as f:
            json.dump(table, f, indent=1)


if __name__ == "__main__":
    main()
