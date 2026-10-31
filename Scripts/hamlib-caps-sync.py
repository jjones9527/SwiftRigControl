#!/usr/bin/env python3
"""Compare catalog capability records with Hamlib's caps, and optionally sync them.

For each catalog radio of the chosen protocols, derives from
`rigctl -m <model> -u` (Hamlib model from hamlib-coverage.py MODEL_MAP):

  supportsRIT / supportsXIT     "Can set RIT" / "Can set XIT"
  supportsCWKeyer               KEYSPD is a settable level
  supportsSendCW                "Can send Morse"
  TX meter flags                SWR, ALC, RFPOWER_METER, COMP_METER,
                                VD_METER (voltage), ID_METER (current)
  scan flags                    Scan Ops VFO / MEM / SLCT / PRIO / PROG / DELTA
  supportedVFOOperations        VFO Ops, mapped like rigctld `G`
  supportedFunctions            Set functions, mapped like rigctld `U`
  preampLevels                  Preamp list

antennaCount is not synced: Hamlib's per-range antenna lists name the
connector each band uses (the IC-7100 lists ANT1-ANT5), not antennas
the radio can switch between.

and prints what differs from our records (`HamlibDiffClient --list --caps`).

With --apply, rewrites each record's `RigCapabilities(...)` call in the
capability database: derived fields are set, every other argument and its
comments are kept, and arguments are re-emitted in the init's declared
order. By default only additions are applied (a feature Hamlib has that
we don't advertise); --allow-removals also drops what Hamlib doesn't
list, except on hardware-verified radios. A record shared by several
radios takes the union of their Hamlib caps.

Our current values come from the HamlibDiffClient binary, so rebuild it
after any capability change (`swift build --product HamlibDiffClient` in
Tools/SwiftRigControlTools) or the report compares against stale records.

Usage:

    Scripts/hamlib-caps-sync.py --protocol IcomCIVProtocol            # report
    Scripts/hamlib-caps-sync.py --protocol IcomCIVProtocol --apply
"""

import argparse
import glob
import importlib.util
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("coverage", os.path.join(HERE, "hamlib-coverage.py"))
coverage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(coverage)
audit = coverage.audit

FUNCS = {
    "COMP": "compressor", "VOX": "vox", "TONE": "ctcssTone", "TSQL": "ctcssSquelch",
    "LOCK": "lock", "TUNER": "tuner", "ANF": "autoNotch", "MN": "manualNotch",
    "SATMODE": "satelliteMode", "MON": "monitor", "AFC": "autoFrequencyControl",
    "BC": "beatCancel", "NB2": "noiseBlanker2", "APF": "audioPeakFilter", "REV": "reverseSplit",
    "DUAL_WATCH": "dualWatch", "DIVERSITY": "diversity", "MUTE": "mute", "SCOPE": "scope",
    "RESUME": "scanResume", "VSC": "voiceSquelch",
}
VFO_OPS = {
    "CPY": "copyVFO", "XCHG": "exchange", "TOGGLE": "toggle", "FROM_VFO": "vfoToMemory",
    "TO_VFO": "memoryToVFO", "MCL": "memoryClear", "UP": "stepUp", "DOWN": "stepDown",
    "BAND_UP": "bandUp", "BAND_DOWN": "bandDown", "TUNE": "tune",
}
SCANS = {"VFO": "supportsVFOScan", "MEM": "supportsMemoryScan", "SLCT": "supportsSelectedMemoryScan",
         "PRIO": "supportsPriorityScan", "PROG": "supportsProgrammedScan", "DELTA": "supportsDeltaFScan"}
METERS = {"RFPOWER_METER": "supportsRFPowerMeter", "SWR": "supportsSWRMeter", "ALC": "supportsALCMeter",
          "COMP_METER": "supportsCompMeter", "VD_METER": "supportsVoltageMeter",
          "ID_METER": "supportsCurrentMeter"}
BOOLS = ["supportsRIT", "supportsXIT", "supportsCWKeyer", "supportsSendCW",
         *METERS.values(), *SCANS.values()]
SETS = {"supportedVFOOperations": "VFOOperation", "supportedFunctions": "RigFunction"}

INIT_FILE = os.path.join(ROOT, "Sources/RigControl/Models/RigCapabilities.swift")

# What each protocol's code implements, so the sync never advertises a
# feature that would just throw unsupportedOperation. None = everything.
# Read from the protocols' setFunction / performVFOOperation switches and
# trait conformances; update these when a protocol gains a feature. The
# text protocols' keyers (KS / KP / PT / EX / BI / SD) are in
# *+CWKeyer.swift.
ALL_OPS = set(VFO_OPS.values())
SUPPORTED = {
    "IcomCIVProtocol": None,
    "KenwoodProtocol": {
        "functions": {"compressor", "vox", "ctcssTone", "ctcssSquelch", "lock", "tuner",
                      "autoNotch", "beatCancel", "noiseBlanker2"},
        "vfoOps": {"stepUp", "stepDown", "bandUp", "bandDown", "memoryClear", "memoryToVFO", "tune"},
        "bools": {"supportsRIT", "supportsXIT", "supportsCWKeyer", "supportsSendCW"},
    },
    "YaesuCATProtocol": {
        "functions": {"compressor", "vox", "ctcssTone", "ctcssSquelch", "lock", "tuner",
                      "autoNotch", "manualNotch", "monitor", "noiseBlanker2"},
        "vfoOps": ALL_OPS - {"memoryClear"},   # MC: throws, needs a memory rewrite
        "bools": {"supportsRIT", "supportsXIT", "supportsCWKeyer", "supportsSendCW",
                  *METERS.values()},   # YaesuCATProtocol+TXMeters.swift
    },
    "ElecraftProtocol": {
        "functions": {"compressor", "vox", "ctcssTone", "ctcssSquelch", "lock",
                      "audioPeakFilter", "dualWatch", "diversity"},
        "vfoOps": {"stepUp", "stepDown", "bandUp", "bandDown", "memoryToVFO"},
        "bools": {"supportsRIT", "supportsXIT", "supportsCWKeyer", "supportsSendCW"},
    },
}


# Radios whose Hamlib backend lists a capability that it then refuses or
# handles with model-specific commands the shared protocol doesn't send.
EXCLUDE = {
    # sdrconsole: caps list functions, but set_func returns ENAVAIL.
    "FlexRadio SDR-Console": {"functions": "all", "vfoOps": "all"},
    # ftx1_vfo_op rejects UP/DOWN; TUNE and the tuner go through
    # ftx1-specific EX/AC1 commands; tone uses CT0 + PS reads.
    "Yaesu FTX-1": {"functions": {"tuner", "ctcssTone", "ctcssSquelch"},
                    "vfoOps": {"stepUp", "stepDown", "tune", "memoryClear"}},
    # Listed in caps, but kenwood_set_func returns ENAVAIL for TONE.
    "Kenwood TS-450S": {"functions": {"ctcssTone"}},
    "Kenwood TS-690S": {"functions": {"ctcssTone"}},
}


def exclude(derived, name):
    rules = EXCLUDE.get(name)
    if not rules:
        return derived
    out = dict(derived)
    for key, field in (("functions", "supportedFunctions"), ("vfoOps", "supportedVFOOperations")):
        drop = rules.get(key, set())
        out[field] = [] if drop == "all" else sorted(set(out[field]) - drop)
    return out


def restrict(derived, protocol):
    """Drop what the protocol can't do from Hamlib-derived values."""
    allowed = SUPPORTED.get(protocol, {"functions": set(), "vfoOps": set(), "bools": set()})
    if allowed is None:
        return derived
    out = dict(derived)
    out["supportedFunctions"] = sorted(set(derived["supportedFunctions"]) & allowed["functions"])
    out["supportedVFOOperations"] = sorted(set(derived["supportedVFOOperations"]) & allowed["vfoOps"])
    for field in BOOLS:
        if field not in allowed["bools"]:
            out[field] = False
    return out


def hamlib_derived(model):
    caps = coverage.hamlib_caps(model)
    raw = subprocess.run([audit.RIGCTL, "-m", str(model), "-u"], capture_output=True,
                         text=True, errors="replace", timeout=30).stdout
    antennas = [int(n) for n in re.findall(r"Antenna list:.*?ANT(\d)", raw)]
    antennas += [int(n) for line in re.findall(r"Antenna list:(.*)", raw)
                 for n in re.findall(r"ANT(\d)", line)]
    d = {
        "supportsRIT": caps["can"].get("Can set RIT", False),
        "supportsXIT": caps["can"].get("Can set XIT", False),
        # KEYSPD, not just CWPITCH: receivers such as the IC-R75 list only
        # a pitch, set through a model-specific menu command.
        "supportsCWKeyer": "KEYSPD" in caps["set_levels"],
        "supportsSendCW": caps["can"].get("Can send Morse", False),
        "antennaCount": max(antennas) if antennas and caps["can"].get("Can set Ant") else 1,
        "preampLevels": caps["preamp"],
        "supportedVFOOperations": sorted({VFO_OPS[o] for o in caps["vfo_ops"] if o in VFO_OPS}),
        # RigFunction.scope is the 27 10 scope switch, which goes with
        # Hamlib's SPECTRUM support; older radios' SCOPE is another command.
        # Hamlib's SPECTRUM func is the 27 10 scope switch.
        "supportedFunctions": sorted({FUNCS[f] for f in caps["set_funcs"]
                                      if f in FUNCS and (f != "SCOPE" or "SPECTRUM" in caps["set_funcs"])}
                                     | ({"scope"} if "SPECTRUM" in caps["set_funcs"] else set())),
    }
    for level, flag in METERS.items():
        d[flag] = level in caps["get_levels"]
    for op, flag in SCANS.items():
        d[flag] = op in caps["scan_ops"]
    return d


def ours():
    out = subprocess.run([audit.CLIENT, "--list", "--caps"], capture_output=True, text=True).stdout
    return {row["name"]: row for row in map(json.loads, out.splitlines())}


def protocols():
    out = subprocess.run([audit.CLIENT, "--list", "--power"], capture_output=True, text=True).stdout
    return {line.split("\t")[0]: line.split("\t")[1] for line in out.splitlines()}


def merge(rows, current, allow_removals):
    """Target value per field for one record, from the Hamlib caps of the
    radios sharing it."""
    target = {}
    for field in BOOLS:
        want = any(r[field] for r in rows)
        target[field] = want if allow_removals else (want or current[field])
    for field in SETS:
        want = set().union(*(r[field] for r in rows))
        target[field] = sorted(want if allow_removals else want | set(current[field]))
    preamps = [r["preampLevels"] for r in rows if r["preampLevels"]]
    target["preampLevels"] = preamps[0] if preamps else current["preampLevels"]
    return target


# MARK: - Source rewriting

def init_order():
    text = open(INIT_FILE).read()
    body = text[text.index("    public init(\n        hasVFOB"):]
    body = body[:body.index(") {")]
    return re.findall(r"^\s+(\w+):", body, re.M)


def record_locations():
    """{(namespace, identifier): (path, start offset of 'RigCapabilities(')}"""
    found = {}
    for path in glob.glob(os.path.join(ROOT, "Sources/RigControl/Models/RadioCapabilitiesDatabase+*.swift")):
        text = open(path).read()
        for m in re.finditer(r"static let (\w+) = RigCapabilities\(", text):
            namespace = enclosing_namespace(text, m.start())
            found[(namespace, m.group(1))] = (path, m.end() - 1)
    return found


def enclosing_namespace(text, offset):
    best = None
    for m in re.finditer(r"(?:extension RadioCapabilitiesDatabase\.(\w+)|enum (\w+))\s*\{", text[:offset]):
        best = m.group(1) or m.group(2)
    return best


def radio_records():
    """{radio full name: (namespace, identifier)} from the RadioDefinition factories."""
    mapping = {}
    enum = open(os.path.join(ROOT, "Sources/RigControl/Core/RadioDefinition.swift")).read()
    manufacturer_names = dict(re.findall(r'case (\w+) = "([^"]+)"', enum))
    for path in glob.glob(os.path.join(ROOT, "Sources/RigControl/Protocols/**/*.swift"), recursive=True):
        text = open(path).read()
        for m in re.finditer(r"RadioDefinition\(\s*manufacturer: \.(\w+),\s*model: \"([^\"]+)\"(.*?)"
                             r"capabilities: RadioCapabilitiesDatabase\.(\w+)\.(\w+)", text, re.S):
            if "RadioDefinition(" in m.group(3):
                continue
            maker = manufacturer_names.get(m.group(1), m.group(1).capitalize())
            mapping[f"{maker} {m.group(2)}"] = (m.group(4), m.group(5))
    return mapping


def split_args(text, open_index):
    """Top-level arguments of the call whose '(' is at open_index, as
    (label, source) with any comment that trails an argument on its own
    line moved onto that argument. Returns (args, close_index)."""
    depth, i, start, pieces = 0, open_index, open_index + 1, []
    in_string = in_comment = False
    while i < len(text):
        c = text[i]
        if in_comment:
            in_comment = c != "\n"
        elif in_string:
            if c == "\\":
                i += 1
            elif c == '"':
                in_string = False
        elif c == '"':
            in_string = True
        elif text.startswith("//", i):
            in_comment = True
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
            if depth == 0:
                pieces.append(text[start:i])
                break
        elif c == "," and depth == 1:
            pieces.append(text[start:i])
            start = i + 1
        i += 1
    else:
        raise ValueError("unbalanced call")
    args = []
    for piece in pieces:
        # "  // trailing note" up to the first newline belongs to the
        # previous argument.
        trail = re.match(r"[ \t]*//[^\n]*", piece)
        if trail and args:
            args[-1][2] = trail.group(0)
            piece = piece[trail.end():]
        if not piece.strip():
            continue
        label = re.match(r"\s*(?://[^\n]*\n\s*)*(\w+):", piece)
        args.append([label.group(1) if label else None, piece, ""])
    return args, i


def swift_value(field, value):
    if field in SETS or field == "preampLevels":
        items = [f".{v}" for v in value] if field in SETS else [str(v) for v in value]
        return "[" + ", ".join(items) + "]"
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def rewrite(path, open_index, target, current):
    """Set the changed fields in the RigCapabilities(...) call at
    open_index, keeping every other argument and its comments, and emit
    the arguments in the init's declared order."""
    text = open(path).read()
    args, close = split_args(text, open_index)
    order = init_order()
    unknown = [a[0] for a in args if a[0] not in order]
    if unknown:
        raise ValueError(f"{path}: unrecognised arguments {unknown}")
    indent = re.match(r"\n?([ \t]*)", args[0][1]).group(1)
    by_label = {a[0]: a for a in args}
    changed = []
    for field, value in target.items():
        if value == current[field]:
            continue
        changed.append(field)
        rendered = f"{field}: {swift_value(field, value)}"
        if field in by_label:
            piece = by_label[field][1]
            head = re.match(r"(\s*(?://[^\n]*\n\s*)*)", piece).group(1)
            by_label[field][1] = head + rendered
        else:
            by_label[field] = [field, f"\n{indent}{rendered}", ""]
    if not changed:
        return []
    ordered = [by_label[label] for label in order if label in by_label]
    out = ""
    for index, (_, piece, trail) in enumerate(ordered):
        comma = "," if index < len(ordered) - 1 else ""
        out += piece.rstrip() + comma + trail
    closing = text[open_index + 1:close]
    closing_ws = closing[len(closing.rstrip()):]
    text = text[:open_index + 1] + out + closing_ws + text[close:]
    open(path, "w").write(text)
    return changed


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--protocol", action="append", default=[])
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--allow-removals", action="store_true")
    parser.add_argument("--json")
    args = parser.parse_args()

    protos = protocols()
    current = ours()
    records = radio_records()
    radios = [n for n, p in protos.items() if p in args.protocol and n in coverage.MODEL_MAP]

    by_record = {}
    for name in radios:
        if name not in records:
            print(f"!! no capability record found for {name}")
            continue
        by_record.setdefault(records[name], []).append(name)

    report = {}
    for record, names in sorted(by_record.items()):
        derived = [exclude(restrict(hamlib_derived(coverage.MODEL_MAP[n]), protos[n]), n) for n in names]
        mine = current[names[0]]
        hardware = any(current[n]["verification"] == "hardware" for n in names)
        target = merge(derived, mine, args.allow_removals and not hardware)
        adds, removes = {}, {}
        for field, value in target.items():
            if field in SETS:
                plus = sorted(set(value) - set(mine[field]))
                minus = sorted(set(mine[field]) - set(value))
                if plus: adds[field] = plus
                if minus: removes[field] = minus
            elif value != mine[field]:
                (adds if value and not mine[field] or (isinstance(value, list) and value) or
                 (isinstance(value, int) and not isinstance(value, bool) and value > mine[field])
                 else removes)[field] = value
        # What Hamlib lacks that we claim, for review even when not removing.
        full = merge(derived, mine, True)
        overclaims = {f: sorted(set(mine[f]) - set(full[f])) for f in SETS if set(mine[f]) - set(full[f])}
        overclaims.update({f: True for f in BOOLS if mine[f] and not full[f]})
        report["/".join(record)] = {"radios": names, "add": adds, "remove": removes,
                                     "overclaims": overclaims, "hardware": hardware}
        print(f"{'/'.join(record):<28} {', '.join(names)}{'  [hardware]' if hardware else ''}")
        for field, value in adds.items():
            print(f"    + {field}: {value}")
        for field, value in removes.items():
            print(f"    - {field}: {value}")
        if overclaims and not args.allow_removals:
            print(f"    ? not in Hamlib: {overclaims}")
        if args.apply and (adds or removes):
            # Locate afresh: an earlier rewrite may have moved this record.
            path, open_index = record_locations()[record]
            rewrite(path, open_index, target, mine)
    if args.json:
        with open(args.json, "w") as f:
            json.dump(report, f, indent=1)


if __name__ == "__main__":
    main()
