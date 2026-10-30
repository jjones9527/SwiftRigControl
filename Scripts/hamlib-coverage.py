#!/usr/bin/env python3
"""How much of each radio's Hamlib capability surface SwiftRigControl implements.

For every catalog radio mapped to a Hamlib model (MODEL_MAP below), reads
the model's capabilities from `rigctl -m <model> -u` (modes, settable
levels, get-only levels, functions, VFO and scan ops, and the "Can ..."
flags for the core operations), then runs the matching rigctl command
through SwiftRigControl (HamlibDiffClient → RigController →
RigctldCommandHandler) against a fake radio from hamlib-set-matrix.py
that ACKs everything.

Each item is classified:

  yes      RPRT 0: we accepted it and wrote to the radio
  attempt  we wrote to the radio, then failed waiting for a real reply
           (the fake radio only ACKs). Implemented, not wire-checked.
  no       RPRT -11 / -4, or an error before anything was written
  bridge   the library has no rigctld command for it at all

This measures coverage, not wire correctness: hamlib-diff-audit.py and
hamlib-set-matrix.py compare the bytes. SmartSDR slices are skipped
(TCP, not a serial port).

Usage:

    Scripts/hamlib-coverage.py --json /tmp/coverage.json --markdown /tmp/coverage.md
    Scripts/hamlib-coverage.py --radio "Icom IC-7300"
"""

import argparse
import concurrent.futures
import importlib.util
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("matrix", os.path.join(HERE, "hamlib-set-matrix.py"))
matrix = importlib.util.module_from_spec(spec)
spec.loader.exec_module(matrix)
audit = matrix.audit

# Catalog name → Hamlib model. Built from `rigctl -l` by name; the
# non-obvious ones are commented.
MODEL_MAP = {
    "Icom IC ID-1": 3054, "Icom IC-2730": 3072, "Icom IC-7000": 3060, "Icom IC-703": 3055,
    "Icom IC-705": 3085, "Icom IC-706": 3009, "Icom IC-706MKII": 3010, "Icom IC-706MKIIG": 3011,
    "Icom IC-7100": 3070, "Icom IC-718": 3013, "Icom IC-7200": 3061, "Icom IC-7300": 3073,
    "Icom IC-7300MK2": 3094, "Icom IC-735": 3019,
    "Icom IC-7400": 3046,          # sold as the IC-746PRO outside Europe; Hamlib has no separate model
    "Icom IC-7410": 3067, "Icom IC-746": 3023, "Icom IC-746PRO": 3046, "Icom IC-751": 3024,
    "Icom IC-756": 3026, "Icom IC-756PRO": 3027, "Icom IC-756PROII": 3047, "Icom IC-756PROIII": 3057,
    "Icom IC-7600": 3063, "Icom IC-7610": 3078, "Icom IC-7700": 3062, "Icom IC-7760": 3092,
    "Icom IC-7800": 3056, "Icom IC-7850": 3075, "Icom IC-7851": 3075, "Icom IC-820H": 3032,
    "Icom IC-905": 3090, "Icom IC-9100": 3068, "Icom IC-910H": 3044, "Icom IC-92D": 3065,
    "Icom IC-970": 3035, "Icom IC-9700": 3081, "Icom IC-F8101": 3086, "Icom IC-R20": 3058,
    "Icom IC-R30": 3080, "Icom IC-R6": 3077, "Icom IC-R7100": 3041, "Icom IC-R75": 3039,
    "Icom IC-R8600": 3079, "Icom IC-R9500": 3066, "Icom IC-RX7": 3069, "Icom ID-31": 3083,
    "Icom ID-4100": 3082, "Icom ID-51": 3084,
    "Icom ID-5100": 3071,
    "Icom ID-52": 3093,            # Hamlib only has the PLUS (id52plus.c)
    "Icom ID-52 PLUS": 3093,
    "Yaesu FT-100": 1021, "Yaesu FT-1000MP": 1024, "Yaesu FT-1000MP MARK-V": 1004,
    "Yaesu FT-1000MP MARK-V Field": 1025, "Yaesu FT-2000": 1029, "Yaesu FT-450": 1027,
    "Yaesu FT-450D": 1046, "Yaesu FT-710": 1049, "Yaesu FT-817": 1020, "Yaesu FT-818": 1041,
    "Yaesu FT-847": 1001, "Yaesu FT-847UNI": 1038, "Yaesu FT-857": 1022, "Yaesu FT-857D": 1022,
    "Yaesu FT-891": 1036, "Yaesu FT-897": 1023, "Yaesu FT-897D": 1043, "Yaesu FT-920": 1014,
    "Yaesu FT-950": 1028, "Yaesu FT-991": 1035, "Yaesu FT-991A": 1035, "Yaesu FTDX-10": 1042,
    "Yaesu FTDX-101D": 1040, "Yaesu FTDX-101MP": 1044, "Yaesu FTDX-1200": 1034,
    "Yaesu FTDX-3000": 1037, "Yaesu FTDX-5000": 1032, "Yaesu FTDX-9000": 1030, "Yaesu FTX-1": 1051,
    "Yaesu mcHF QRP": 1045,
    "Kenwood TH-D72": 2033, "Kenwood TH-D72A": 2033, "Kenwood TH-D74": 2042, "Kenwood TH-D75": 2059,
    "Kenwood TH-F6A": 2019, "Kenwood TH-F7E": 2020, "Kenwood TM-D710(G)": 2034,
    "Kenwood TM-V71(A)": 2035, "Kenwood TS-2000": 2014, "Kenwood TS-450S": 2003,
    "Kenwood TS-480HX": 2028, "Kenwood TS-480SAT": 2028, "Kenwood TS-570D": 2004,
    "Kenwood TS-570S": 2016, "Kenwood TS-590S": 2031, "Kenwood TS-590SG": 2037,
    "Kenwood TS-690S": 2005, "Kenwood TS-850S": 2009, "Kenwood TS-870S": 2010,
    "Kenwood TS-890S": 2041, "Kenwood TS-940S": 2011, "Kenwood TS-950S": 2012,
    "Kenwood TS-950SDX": 2013, "Kenwood TS-990S": 2039,
    "Elecraft K2": 2021, "Elecraft K3": 2029, "Elecraft K3S": 2043, "Elecraft K4": 2047,
    "Elecraft KX2": 2044, "Elecraft KX3": 2045,
    "Xiegu G90": 3088, "Xiegu X6100": 3087, "Xiegu X6200": 3091,
    "FlexRadio 6000-series": 2036,  # Hamlib "6xxx" (flex6xxx.c), the Kenwood-style CAT bridge
    "FlexRadio PiHPSDR": 2040, "FlexRadio PowerSDR": 2048, "FlexRadio SDR-Console": 2056,
    "FlexRadio Thetis": 2054,
    "Ten-Tec Eagle": 16013,
    "Ten-Tec Jupiter (TT-538)": 16002,
    "Ten-Tec Orion (TT-565)": 16008, "Ten-Tec Orion II (TT-599)": 16008,  # TT-565/566 Orion I/II
    "Ten-Tec Pegasus (TT-550)": 16001, "Ten-Tec RX-320": 16003,
    "Lab599 TX-500": 2050, "QRP Labs QMX": 2057, "Hamgeek uSDX": 2058,
}

FRAMING = {
    "IcomCIVProtocol": "civ",
    "THD72Protocol": "cr", "THFamilyCAT": "cr", "TMFamilyCAT": "cr",
    "TenTecOrionProtocol": "cr", "TenTecLegacyProtocol": "cr",
}

# "Can ..." flag → rigctl command(s) to try. None: no rigctld command in
# SwiftRigControl, so the item is "bridge".
CORE = [
    ("Can set Frequency", "set_freq", ["F 14074000", "F 145500000", "F 446000000", "F 7074000"]),
    ("Can set VFO", "set_vfo", ["V VFOB"]),
    ("Can set PTT", "set_ptt", ["T 1"]),
    ("Can set Split VFO", "set_split_vfo", ["S 1 VFOB"]),
    ("Can set Split Freq", "set_split_freq", ["I 14075000", "I 145510000"]),
    ("Can set Split Mode", "set_split_mode", ["X USB 0", "X FM 0"]),
    ("Can set RIT", "set_rit", ["J 100"]),
    ("Can set XIT", "set_xit", ["Z 100"]),
    ("Can set Ant", "set_ant", ["Y 1"]),
    ("Can send Morse", "send_morse", ["b CQ"]),
    ("Can set Power Stat", "set_powerstat", ["\\set_powerstat 1"]),
    ("Can set Tuning Step", "set_ts", None),
    ("Can set CTCSS", "set_ctcss_tone", None),
    ("Can set CTCSS Squelch", "set_ctcss_sql", None),
    ("Can set DCS", "set_dcs_code", None),
    ("Can set DCS Squelch", "set_dcs_sql", None),
    ("Can set Repeater Duplex", "set_rptr_shift", None),
    ("Can set Repeater Offset", "set_rptr_offs", None),
    ("Can set Mem", "set_mem", None),
    ("Can set Channel", "set_channel", None),
    ("Can get DCD", "get_dcd", None),
    ("Can send DTMF", "send_dtmf", None),
    ("Can send Voice", "send_voice_mem", None),
]

SCOPE_ITEMS = re.compile(r"^(SPECTRUM|SCOPE|USB_AF|TRANSCEIVE|OVF_STATUS)")


class Radio(matrix.AckRadio):
    """AckRadio that also echoes CR-terminated commands, which is how the
    Kenwood TH/TM and Ten-Tec text protocols acknowledge a set."""

    def reply(self, frame):
        if self.framing == "cr":
            return frame
        return super().reply(frame)


def hamlib_caps(model):
    out = subprocess.run([audit.RIGCTL, "-m", str(model), "-u"], capture_output=True,
                         text=True, errors="replace", timeout=30).stdout
    caps = {"can": {}, "modes": [], "set_levels": {}, "get_levels": [], "set_funcs": [],
            "vfo_ops": [], "scan_ops": [], "att": [], "preamp": []}
    for line in out.splitlines():
        key, _, value = line.partition(":")
        value = value.strip()
        if key.startswith("Can "):
            caps["can"][key.strip()] = value.startswith(("Y", "E"))
        elif key == "Mode list" and not caps["modes"]:
            caps["modes"] = value.split()
        elif key == "Set level":
            for name, low, high in re.findall(r"(\w+)\(([-\d.]+)\.\.([-\d.]+)/", value):
                caps["set_levels"][name] = (float(low), float(high))
        elif key == "Get level":
            caps["get_levels"] = re.findall(r"(\w+)\(", value)
        elif key == "Set functions":
            caps["set_funcs"] = value.split()
        elif key == "VFO Ops":
            caps["vfo_ops"] = value.split()
        elif key == "Scan Ops":
            caps["scan_ops"] = value.split()
        elif key == "Attenuator":
            caps["att"] = [int(v) for v in re.findall(r"(\d+)dB", value)]
        elif key == "Preamp":
            caps["preamp"] = [int(v) for v in re.findall(r"(\d+)dB", value)]
    return caps


def level_value(name, low, high, caps):
    if name == "ATT":
        return str(caps["att"][0]) if caps["att"] else "0"
    if name == "PREAMP":
        return str(caps["preamp"][0]) if caps["preamp"] else "0"
    if name == "AGC":
        return "2"
    if high <= 1.0 and low >= 0.0:
        return "0.5"
    middle = (low + high) / 2
    return str(int(middle)) if float(int(low)) == low and float(int(high)) == high else f"{middle:.3f}"


def items(caps):
    """[(category, item, [command alternatives] or None)] for one model."""
    out = []
    for flag, name, commands in CORE:
        if caps["can"].get(flag):
            out.append(("core", name, commands))
    for mode in caps["modes"]:
        out.append(("mode", mode, [f"M {mode} 0"]))
    for name, (low, high) in caps["set_levels"].items():
        out.append(("level", name, [f"L {name} {level_value(name, low, high, caps)}"]))
    for name in caps["get_levels"]:
        if name not in caps["set_levels"]:
            out.append(("meter", name, [f"l {name}"]))
    for name in caps["set_funcs"]:
        out.append(("func", name, [f"U {name} 1"]))
    for op in caps["vfo_ops"]:
        out.append(("vfo_op", op, [f"G {op}"]))
    for op in caps["scan_ops"]:
        if op != "STOP":
            out.append(("scan", op, [f"g {op} 0"]))
    return out


def classify(result):
    sent = any(d == "TX" for d, _ in result["exchanges"])
    error = result["error"]
    if error is None:
        return "yes"
    code = error.split()[1] if error.startswith("RPRT") else ""
    if code in ("-11", "-4"):
        return "no"
    return "attempt" if sent else "no"


def probe(name, protocol, model):
    framing = FRAMING.get(protocol, "text")
    caps = hamlib_caps(model)
    plan = items(caps)
    radio = Radio(framing)
    radio.start()
    results = []
    try:
        try:
            client = audit.SwiftClient(name, radio.port, radio)
        except RuntimeError as error:
            return {"radio": name, "model": model, "protocol": protocol,
                    "connect_error": str(error)[:200], "items": []}
        try:
            for index, (category, item, commands) in enumerate(plan):
                if commands is None:
                    results.append((category, item, "bridge", ""))
                    continue
                verdict, detail = "no", ""
                for alternative, command in enumerate(commands):
                    result = client.run(command, f"{index}.{alternative}:{command}")
                    verdict = classify(result)
                    detail = result["error"] or ""
                    if verdict != "no":
                        break
                results.append((category, item, verdict, detail))
        finally:
            client.stop()
    finally:
        radio.stop()
    return {"radio": name, "model": model, "protocol": protocol, "items": results}


def summarize(row):
    counts = {}
    for category, item, verdict, _ in row["items"]:
        scope = "scope" if SCOPE_ITEMS.match(item) else category
        counts.setdefault(scope, {"total": 0, "covered": 0})
        counts[scope]["total"] += 1
        if verdict in ("yes", "attempt"):
            counts[scope]["covered"] += 1
    return counts


def markdown(rows):
    categories = ["core", "mode", "level", "meter", "func", "vfo_op", "scan"]
    lines = ["| Radio | Protocol | " + " | ".join(categories) + " | Overall (excl. scope) |",
             "| --- | --- | " + " | ".join("---:" for _ in categories) + " | ---: |"]
    for row in rows:
        if row.get("connect_error"):
            lines.append(f"| {row['radio']} | {row['protocol']} | connect failed: "
                         f"{row['connect_error'][:60]} |" + " |" * len(categories))
            continue
        counts = summarize(row)
        cells, total, covered = [], 0, 0
        for category in categories:
            c = counts.get(category)
            if not c:
                cells.append("–")
                continue
            cells.append(f"{c['covered']}/{c['total']}")
            total += c["total"]
            covered += c["covered"]
        overall = f"{100 * covered // total}%" if total else "–"
        lines.append(f"| {row['radio']} | {row['protocol']} | " + " | ".join(cells) + f" | {overall} |")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--radio", action="append", default=[])
    parser.add_argument("--jobs", type=int, default=8)
    parser.add_argument("--json")
    parser.add_argument("--markdown")
    args = parser.parse_args()

    listing = subprocess.run([audit.CLIENT, "--list", "--power"], capture_output=True, text=True).stdout
    catalog = [line.split("\t")[:2] for line in listing.splitlines()]
    todo = [(n, p) for n, p in catalog
            if (not args.radio or n in args.radio) and p != "FlexSmartSDRProtocol"]
    missing = [n for n, _ in todo if n not in MODEL_MAP]
    if missing:
        sys.exit(f"no Hamlib model mapped for: {missing}")

    rows = []
    with concurrent.futures.ThreadPoolExecutor(args.jobs) as pool:
        futures = {pool.submit(probe, n, p, MODEL_MAP[n]): n for n, p in todo}
        for future in concurrent.futures.as_completed(futures):
            row = future.result()
            rows.append(row)
            counts = summarize(row)
            total = sum(c["total"] for k, c in counts.items() if k != "scope")
            covered = sum(c["covered"] for k, c in counts.items() if k != "scope")
            print(f"{row['radio']:<32} {covered:>3}/{total:<3} {row.get('connect_error', '')[:60]}", flush=True)
    rows.sort(key=lambda r: r["radio"])
    if args.json:
        with open(args.json, "w") as f:
            json.dump(rows, f, indent=1)
    if args.markdown:
        with open(args.markdown, "w") as f:
            f.write(markdown(rows))


if __name__ == "__main__":
    main()
