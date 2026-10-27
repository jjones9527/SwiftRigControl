#!/usr/bin/env python3
"""Differential audit: SwiftRigControl vs Hamlib, command by command.

For each radio, the same rigctl command strings are run twice against a
fresh instance of the same Hamlib simulator (simulators/sim*.c):

  1. Hamlib: `rigctl -m <model>` with -vvvvv tracing. The bytes it writes
     and reads are taken from the trace (between command dispatch and
     rig shutdown, so rig_open / rig_close are left out).
  2. SwiftRigControl: Tools/SwiftRigControlTools HamlibDiffClient, which
     runs the commands through RigController + RigctldCommandHandler.
     Its serial port is a pty relayed to the simulator; the relay records
     every byte in both directions.

Each command's TX bytes are split into frames (`;`, CI-V 0xFD, or CR)
and compared, and so are the values each side printed. The simulator
answers both sides identically, so a difference is a difference in what
the two implementations send or how they read the same reply.

Setup (once): see Scripts/hamlib-wire-capture.py for building Hamlib in
~/Developer/hamlib-build, then build the simulators and the client:

    make -C ~/Developer/hamlib-build/simulators
    (cd Tools/SwiftRigControlTools && swift build --product HamlibDiffClient)

Usage:

    Scripts/hamlib-diff-audit.py                 # every radio in RADIOS
    Scripts/hamlib-diff-audit.py --radio "Elecraft KX3"
    Scripts/hamlib-diff-audit.py --json out.json --markdown out.md

Simulators return canned values and accept nearly anything, so a MATCH
means "sends the same bytes and reads the same reply the same way", not
"works on the radio".
"""

import argparse
import json
import os
import pty
import re
import select
import subprocess
import sys
import threading
import time
import tty

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.expanduser(os.environ.get("HAMLIB_BUILD", "~/Developer/hamlib-build"))
RIGCTL = os.path.join(BUILD, "tests", "rigctl")
CLIENT = os.path.join(ROOT, "Tools", "SwiftRigControlTools", ".build", "debug", "HamlibDiffClient")
HEX_LINE = re.compile(r"^0[0-9a-f]{3}\s+((?:[0-9a-f]{2} )+)")

# (catalog full name, Hamlib model, simulator, framing). Each side uses
# its own default baud rate; a pty ignores it.
#
# Tier 1: the hardware-verified radios plus the most-used ones. The TH-D72A
# is not here because Hamlib has no simulator for it.
RADIOS = [
    ("Icom IC-7100", 3070, "simic7100", "civ"),
    ("Icom IC-7600", 3063, "simic7600", "civ"),
    ("Icom IC-9700", 3081, "simic9700", "civ"),
    ("Icom IC-7300", 3073, "simic7300", "civ"),
    ("Icom IC-7300MK2", 3094, "simic7300", "civ"),
    ("Icom IC-705", 3085, "simic705", "civ"),
    ("Icom IC-7610", 3078, "simic7610", "civ"),
    ("Xiegu G90", 3088, "simxiegug90", "civ"),
    ("Yaesu FT-710", 1049, "simft710", "text"),
    ("Yaesu FT-991A", 1035, "simft991", "text"),
    ("Yaesu FT-891", 1036, "simyaesu", "text"),
    ("Yaesu FTDX-10", 1042, "simftdx101", "text"),
    ("Yaesu FTDX-101D", 1040, "simftdx101", "text"),
    ("Kenwood TS-590SG", 2037, "simts590", "text"),
    ("Kenwood TS-890S", 2041, "simts890", "text"),
    ("Elecraft K2", 2021, "simelecraft", "text"),
    ("Elecraft K3", 2029, "simelecraft", "text"),
    ("Elecraft KX3", 2045, "simelecraft", "text"),
    ("Elecraft K4", 2047, "simelecraftk4", "text"),
]

# rigctl level / function names to try, with a set value. Each set is
# followed by the matching get. Levels Hamlib can't set are read only.
SET_LEVELS = {
    "RFPOWER": "0.5", "AF": "0.5", "RF": "0.5", "SQL": "0.3", "MICGAIN": "0.5",
    "COMP": "0.5", "MONITOR_GAIN": "0.5", "VOXGAIN": "0.5", "VOXDELAY": "5",
    "IF": "100", "NR": "0.5", "KEYSPD": "20", "CWPITCH": "600", "AGC": "2",
}
READ_LEVELS = ["STRENGTH", "SWR", "ALC", "RFPOWER_METER", "COMP_METER", "VD_METER", "ID_METER"]
FUNCTIONS = ["NB", "NR", "ANF", "COMP", "VOX", "LOCK", "TUNER", "FBKIN", "TONE", "TSQL", "MN", "APF"]
MODES = ["USB", "LSB", "CW", "CWR", "AM", "FM", "RTTY", "PKTUSB", "PKTLSB", "PKTFM"]


# MARK: - Simulator and relay

class Simulator:
    """A Hamlib simulator on a pty."""

    def __init__(self, name):
        path = os.path.join(BUILD, "simulators", name)
        master, slave = pty.openpty()
        self.proc = subprocess.Popen([path], stdout=slave, stderr=slave, stdin=subprocess.DEVNULL)
        os.close(slave)
        buffer, deadline = b"", time.time() + 5
        while time.time() < deadline:
            ready, _, _ = select.select([master], [], [], 0.2)
            if ready:
                buffer += os.read(master, 4096)
                match = re.search(rb"name=(/dev/\S+)", buffer)
                if match:
                    self.port = match.group(1).decode()
                    self.drain = subprocess.Popen(["cat"], stdin=master, stdout=subprocess.DEVNULL)
                    return
        self.proc.kill()
        raise RuntimeError(f"simulator {name} did not report its pty")

    def stop(self):
        self.proc.kill()
        self.drain.kill()
        self.proc.wait()


class Relay(threading.Thread):
    """Forwards a client pty to the simulator and records the bytes."""

    def __init__(self, sim_port, civ=False):
        super().__init__(daemon=True)
        self.civ = civ
        self.rx_buffer = b""
        self.last_tx = b""
        self.sim = os.open(sim_port, os.O_RDWR | os.O_NOCTTY)
        tty.setraw(self.sim)
        self.master, self.slave = pty.openpty()
        tty.setraw(self.slave)
        self.port = os.ttyname(self.slave)
        self.label = "open"
        self.log = []          # (label, "TX"/"RX", bytes)
        self.lock = threading.Lock()
        self.running = True

    def run(self):
        while self.running:
            ready, _, _ = select.select([self.master, self.sim], [], [], 0.1)
            for fd in ready:
                try:
                    data = os.read(fd, 4096)
                except OSError:
                    continue
                if not data:
                    continue
                target, direction = (self.sim, "TX") if fd == self.master else (self.master, "RX")
                if direction == "TX":
                    self.last_tx = data
                elif self.civ:
                    data = self.fix_civ_addresses(data)
                    if not data:
                        continue
                os.write(target, data)
                with self.lock:
                    self.log.append((self.label, direction, data))

    def fix_civ_addresses(self, data):
        """Swap to/from on simulator replies that come back unswapped.

        Some Hamlib Icom simulators (simic7100, simic7600, ...) answer
        `FE FE <radio> E0 ...` instead of the real radio's
        `FE FE E0 <radio> ...`. Hamlib ignores the addresses, so it
        doesn't notice; SwiftRigControl reads such a frame as its own
        echo and skips it. Frames identical to what was just sent are
        real echoes and are left alone.
        """
        self.rx_buffer += data
        out = b""
        while b"\xfd" in self.rx_buffer:
            frame, _, self.rx_buffer = self.rx_buffer.partition(b"\xfd")
            frame += b"\xfd"
            start = frame.find(b"\xfe\xfe")
            if start >= 0 and len(frame) >= start + 6:
                body = frame[start:]
                is_echo = body in self.last_tx
                if not is_echo and body[3] == 0xE0 and body[2] != 0xE0:
                    body = body[:2] + bytes([0xE0, body[2]]) + body[4:]
                frame = frame[:start] + body
            out += frame
        return out

    def set_label(self, label):
        with self.lock:
            self.label = label

    def traffic(self, label):
        with self.lock:
            return [(d, b) for l, d, b in self.log if l == label]

    def stop(self):
        self.running = False
        self.join(1)
        for fd in (self.sim, self.master, self.slave):
            try:
                os.close(fd)
            except OSError:
                pass


# MARK: - Hamlib side

COMMAND_START = "rigctl_parse: called"
COMMAND_END = ("Stopping rig poll routine", "rig_close(")


def hamlib_exchanges(trace):
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


def run_hamlib(model, port, command):
    # One retry and a short timeout: simulators ignore commands they don't
    # implement, and Hamlib's default 5 x 1 s retries make that very slow.
    cmd = [RIGCTL, "-m", str(model), "-r", port, "-vvvvv",
           "--set-conf=retry=1,timeout=400", *command.split()]
    try:
        done = subprocess.run(cmd, capture_output=True, text=True, errors="replace", timeout=30,
                              stdin=subprocess.DEVNULL)
        stdout, stderr = done.stdout, done.stderr
    except subprocess.TimeoutExpired as error:
        stdout = error.stdout.decode() if isinstance(error.stdout, bytes) else (error.stdout or "")
        stderr = error.stderr.decode() if isinstance(error.stderr, bytes) else (error.stderr or "")
    values, error = [], None
    for line in stdout.splitlines():
        line = line.strip()
        if not line or line.startswith("Opened rig model"):
            continue
        if "error = " in line:
            # rigctl prints "<cmd>: error = <rigerror>"; rigerror appends
            # recent debug lines, and the last line is the error text.
            error = stdout.strip().splitlines()[-1].strip()
            break
        values.append(line)
    return {"exchanges": hamlib_exchanges(stderr), "values": values, "error": error}


def hamlib_caps(model):
    out = subprocess.run([RIGCTL, "-m", str(model), "-u"], capture_output=True, text=True, timeout=30).stdout
    caps = {"set_levels": set(), "get_levels": set(), "set_funcs": set(), "get_funcs": set(),
            "modes": set(), "att": [], "preamp": [], "ranges": {}}
    for line in out.splitlines():
        line = line.strip()
        if line.startswith("Set level:"):
            for name, low, high in re.findall(r"(\w+)\(([-\d.]+)\.\.([-\d.]+)/", line):
                caps["set_levels"].add(name)
                caps["ranges"][name] = (float(low), float(high))
        elif line.startswith("Get level:"):
            caps["get_levels"].update(re.findall(r"(\w+)\(", line))
        elif line.startswith("Set functions:"):
            caps["set_funcs"].update(line.split(":", 1)[1].split())
        elif line.startswith("Get functions:"):
            caps["get_funcs"].update(line.split(":", 1)[1].split())
        elif line.startswith("Mode list:") and not caps["modes"]:
            caps["modes"].update(line.split(":", 1)[1].split())
        elif line.startswith("Attenuator:"):
            caps["att"] = [int(v) for v in re.findall(r"(\d+)dB", line)]
        elif line.startswith("Preamp:"):
            caps["preamp"] = [int(v) for v in re.findall(r"(\d+)dB", line)]
    return caps


# MARK: - SwiftRigControl side

class SwiftClient:
    def __init__(self, name, port, relay):
        self.name, self.port, self.relay = name, port, relay
        self.start()

    def start(self):
        self.stderr = open(f"/tmp/hamlib-diff-client-{os.getpid()}.err", "w+")
        self.proc = subprocess.Popen([CLIENT, "--radio", self.name, "--port", self.port],
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self.stderr,
                                     text=True, bufsize=1)
        first = self.proc.stdout.readline().strip()
        if first != "READY":
            self.stderr.seek(0)
            raise RuntimeError(f"client failed to connect: {first} {self.stderr.read()}")
        time.sleep(0.2)

    def run(self, command, label):
        self.relay.set_label(label)
        lines, crashed = [], False
        try:
            self.proc.stdin.write(command + "\n")
            self.proc.stdin.flush()
            while True:
                line = self.proc.stdout.readline()
                if not line:
                    crashed = True
                    break
                if line.strip() == "@@END":
                    break
                lines.append(line.strip())
        except BrokenPipeError:
            crashed = True
        if crashed:
            self.proc.wait(5)
            self.stderr.seek(0)
            detail = self.stderr.read().strip().splitlines()[-3:]
            time.sleep(0.2)
            self.relay.set_label("idle")
            result = {"exchanges": self.relay.traffic(label), "values": [],
                      "error": f"CLIENT-CRASH exit={self.proc.returncode} {' / '.join(detail)}"}
            self.start()   # carry on with a fresh session
            return result
        time.sleep(0.15)  # let trailing bytes reach the relay
        self.relay.set_label("idle")
        values = [l for l in lines if not l.startswith("RPRT")]
        rprt = next((l for l in lines if l.startswith("RPRT")), "RPRT 0")
        code = int(rprt.split()[1])
        return {"exchanges": self.relay.traffic(label), "values": values,
                "error": None if code == 0 else rprt}

    def stop(self):
        try:
            self.proc.stdin.close()
            self.proc.wait(5)
        except Exception:
            self.proc.kill()


# MARK: - Comparison

def frames(exchanges, framing, direction="TX"):
    stream = b"".join(b for d, b in exchanges if d == direction)
    terminator = TERMINATORS.get(framing)
    if terminator is None:
        return [stream.hex(" ").upper()] if stream else []
    parts, out = stream.split(terminator), []
    for index, part in enumerate(parts):
        if index == len(parts) - 1 and not part:
            break
        frame = part + (terminator if index < len(parts) - 1 else b"")
        out.append(show(frame, framing))
    return out


TERMINATORS = {"text": b";", "civ": b"\xfd", "cr": b"\r"}


def ordered_frames(exchanges, framing):
    """[(direction, frame bytes)] in wire order, reassembled across chunks."""
    terminator = TERMINATORS[framing]
    buffers, out = {"TX": b"", "RX": b""}, []
    for direction, chunk in exchanges:
        buffers[direction] += chunk
        while terminator in buffers[direction]:
            frame, _, rest = buffers[direction].partition(terminator)
            buffers[direction] = rest
            out.append((direction, frame + terminator))
    return out


def classify(exchanges, framing):
    """Split TX frames into sets, queries and set-verification probes.

    A TX frame is a query if the radio answered it with data, a set if it
    was answered with an ACK/NAK (CI-V) or not answered (text protocols).
    Text `ID;` after a set is Hamlib-style set verification.
    """
    frames = ordered_frames(exchanges, framing)
    sets, queries, verify = [], [], []
    for index, (direction, frame) in enumerate(frames):
        if direction != "TX":
            continue
        replies = []
        for later_direction, later in frames[index + 1:]:
            if later_direction == "TX":
                break
            replies.append(later)
        shown = show(frame, framing)
        if framing == "civ":
            body = frame[frame.find(b"\xfe\xfe"):] if b"\xfe\xfe" in frame else frame
            answers = [r for r in replies if r != frame]   # drop echoes
            acked = any(r.endswith(b"\xfb\xfd") or r.endswith(b"\xfa\xfd") for r in answers)
            data = any(len(r) > 6 and not r.endswith(b"\xfb\xfd") for r in answers)
            (queries if data and not acked else sets).append(shown)
        else:
            text = frame.decode("ascii", "replace")
            if text == "ID;":
                verify.append(shown)
                continue
            prefix = text[:2]
            answered = any(r.decode("ascii", "replace").startswith(prefix) for r in replies)
            (queries if answered else sets).append(shown)
    return sets, queries, verify


def show(data, framing):
    if framing in ("text", "cr") and all(32 <= b < 127 or b in (13,) for b in data):
        return data.decode("ascii").replace("\r", "\\r")
    return data.hex(" ").upper()


def normalize_value(value):
    try:
        number = float(value)
        return f"{number:.6g}"
    except ValueError:
        return value


def plan(caps):
    """The rigctl commands to run for one radio, in order."""
    commands = ["F 7074100", "f", "F 14074000", "f"]
    for mode in MODES:
        if mode in caps["modes"]:
            commands += [f"M {mode} 0", "m"]
    commands += ["M USB 0", "T 1", "t", "T 0", "t", "S 1 VFOB", "s", "S 0 VFOA", "s"]
    commands += ["J 500", "j", "J 0", "Z 300", "z", "Z 0"]
    for level, value in SET_LEVELS.items():
        if level in caps["set_levels"]:
            low, high = caps["ranges"].get(level, (0, 1))
            if level not in ("AGC",) and not (low <= float(value) <= high):
                value = str(high if float(value) > high else low)
            commands += [f"L {level} {value}", f"l {level}"]
    if caps["att"]:
        commands += [f"L ATT {caps['att'][0]}", "l ATT", "L ATT 0"]
    if caps["preamp"]:
        commands += [f"L PREAMP {caps['preamp'][0]}", "l PREAMP", "L PREAMP 0"]
    for level in READ_LEVELS:
        if level in caps["get_levels"]:
            commands.append(f"l {level}")
    for function in FUNCTIONS:
        if function in caps["set_funcs"]:
            commands += [f"U {function} 1", f"u {function}", f"U {function} 0"]
    commands.append("\\get_powerstat")
    return commands


def is_get(command):
    head = command.split()[0]
    return head[0].islower() or head.startswith("\\get_")


def compare(command, hamlib, ours, framing):
    h_tx, o_tx = frames(hamlib["exchanges"], framing), frames(ours["exchanges"], framing)
    h_set, h_query, h_verify = classify(hamlib["exchanges"], framing)
    o_set, o_query, o_verify = classify(ours["exchanges"], framing)
    h_vals = [normalize_value(v) for v in hamlib["values"]]
    o_vals = [normalize_value(v) for v in ours["values"]]
    timeout = lambda e: e and ("timed out" in e.lower() or "-5" in e or "-8" in e)
    if ours["error"] and ours["error"].startswith("CLIENT-CRASH"):
        status = "CLIENT-CRASH"
    elif hamlib["error"] and timeout(hamlib["error"]) and (not ours["error"] or timeout(ours["error"])):
        status = "SIM-NO-REPLY"
    elif ours["error"] and ("-11" in ours["error"] or "-4" in ours["error"]):
        status = "BOTH-UNSUPPORTED" if hamlib["error"] else "OURS-UNSUPPORTED"
    elif hamlib["error"] and ours["error"]:
        status = "BOTH-ERROR"
    elif hamlib["error"]:
        status = "HAMLIB-ERROR"
    elif ours["error"]:
        status = "OURS-ERROR"
    elif is_get(command):
        if h_vals != o_vals:
            status = "VALUE-DIFF"
        elif h_query and h_query != o_query:
            status = "MATCH-OTHER-QUERY"
        else:
            status = "MATCH"
    else:
        if h_set != o_set:
            status = "SET-DIFF"
        elif h_verify and not o_verify:
            status = "MATCH-NO-VERIFY"
        else:
            status = "MATCH"
    return {"command": command, "status": status, "hamlib_tx": h_tx, "ours_tx": o_tx,
            "hamlib_set": h_set, "ours_set": o_set, "hamlib_query": h_query, "ours_query": o_query,
            "hamlib_verify": h_verify, "ours_verify": o_verify,
            "hamlib_values": hamlib["values"], "ours_values": ours["values"],
            "hamlib_error": hamlib["error"], "ours_error": ours["error"],
            "hamlib_rx": frames(hamlib["exchanges"], framing, "RX"),
            "ours_rx": frames(ours["exchanges"], framing, "RX")}


def audit(radio):
    name, model, sim_name, framing = radio
    caps = hamlib_caps(model)
    commands = plan(caps)

    # Hamlib goes through the same relay so it also sees corrected CI-V
    # reply addressing; its bytes are still taken from its own trace.
    sim = Simulator(sim_name)
    relay = Relay(sim.port, civ=(framing == "civ"))
    relay.start()
    try:
        hamlib = [run_hamlib(model, relay.port, c) for c in commands]
    finally:
        relay.stop()
        sim.stop()

    sim = Simulator(sim_name)
    relay = Relay(sim.port, civ=(framing == "civ"))
    relay.start()
    try:
        client = SwiftClient(name, relay.port, relay)
        try:
            ours = [client.run(c, f"{i}:{c}") for i, c in enumerate(commands)]
        finally:
            client.stop()
        open_ours = frames(relay.traffic("open"), framing)
    finally:
        relay.stop()
        sim.stop()

    results = [compare(c, h, o, framing) for c, h, o in zip(commands, hamlib, ours)]
    return {"radio": name, "hamlib_model": model, "simulator": sim_name,
            "open_ours": open_ours, "results": results}


def markdown(reports):
    lines = []
    for report in reports:
        counts = {}
        for r in report["results"]:
            counts[r["status"]] = counts.get(r["status"], 0) + 1
        summary = ", ".join(f"{k} {v}" for k, v in sorted(counts.items()))
        lines += [f"## {report['radio']} (Hamlib {report['hamlib_model']}, {report['simulator']})", "",
                  summary, "",
                  "| Command | Status | Hamlib TX | Ours TX | Hamlib value | Our value |",
                  "| --- | --- | --- | --- | --- | --- |"]
        for r in report["results"]:
            cell = lambda xs: "<br>".join(f"`{x}`" for x in xs) or "—"
            h_val = r["hamlib_error"] or " ".join(r["hamlib_values"]) or "—"
            o_val = r["ours_error"] or " ".join(r["ours_values"]) or "—"
            lines.append(f"| `{r['command']}` | {r['status']} | {cell(r['hamlib_tx'])} | {cell(r['ours_tx'])} | {h_val} | {o_val} |")
        lines.append("")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--radio", action="append", help="only these catalog names")
    parser.add_argument("--json", help="write full results as JSON")
    parser.add_argument("--markdown", help="write a markdown report")
    parser.add_argument("--only-diffs", action="store_true", help="print only non-MATCH rows")
    args = parser.parse_args()

    radios = [r for r in RADIOS if not args.radio or r[0] in args.radio]
    reports = []
    for radio in radios:
        print(f"== {radio[0]}", file=sys.stderr)
        report = audit(radio)
        reports.append(report)
        for r in report["results"]:
            if args.only_diffs and r["status"] == "MATCH":
                continue
            print(f"{r['status']:<17} {r['command']:<20} hamlib={' '.join(r['hamlib_tx'])}  -> {r['hamlib_values'] or r['hamlib_error'] or ''}"
                  f"\n{'':<38} ours  ={' '.join(r['ours_tx'])}  -> {r['ours_values'] or r['ours_error'] or ''}")
    if args.json:
        with open(args.json, "w") as f:
            json.dump(reports, f, indent=1, default=list)
    if args.markdown:
        with open(args.markdown, "w") as f:
            f.write(markdown(reports))


if __name__ == "__main__":
    main()
