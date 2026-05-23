#!/usr/bin/env python3
"""Find public declarations in Sources/RigControl/ that lack a
triple-slash (`///`) doc comment.

Skip declarations whose identifier matches one of the CATProtocol /
SerialTransport / CIVCommandSet method names — DocC inherits
documentation from protocol requirements automatically, so an
implementation that omits a doc comment is fine.

Exit codes:
  0  — no undocumented public symbols (modulo the conformance list)
  N  — N undocumented symbols; each printed as "file:line: decl"

Run from the repo root:
  python3 Scripts/check-public-docs.py

Wired into CI by `.github/workflows/ci.yml` (Phase 3.2).
"""
import os, re, sys

CONFORMANCE = {
    "setFrequency","getFrequency","setMode","getMode","setPTT","getPTT",
    "selectVFO","setPower","getPower","setSplit","getSplit",
    "getSignalStrength","setRIT","getRIT","setXIT","getXIT",
    "setAGC","getAGC","setNoiseBlanker","getNoiseBlanker",
    "setNoiseReduction","getNoiseReduction","setIFFilter","getIFFilter",
    "setAFGain","getAFGain","setRFGain","getRFGain","setSquelch","getSquelch",
    "setPreamp","getPreamp","setAttenuator","getAttenuator",
    "setPowerState","getPowerState",
    "setMemoryChannel","getMemoryChannel","getMemoryChannelCount","clearMemoryChannel",
    "getRFPowerOut","getSWR","getALC","getComp","getVoltage","getCurrent",
    "connect","disconnect","open","close","write","read","readUntil","flush",
    "isOpen","transport","capabilities",
    "setModeCommand","setDataModeCommand","readModeCommand","parseModeResponse",
    "setPowerCommand","readPowerCommand","parsePowerResponse",
    "setPTTCommand","readPTTCommand","parsePTTResponse",
    "selectVFOCommand","setFrequencyCommand","readFrequencyCommand","parseFrequencyResponse",
    "civAddress","vfoModel","requiresModeFilter","echoesCommands","powerUnits",
    "errorDescription","recoverySuggestion","description",
}

DECL_RE = re.compile(
    r"^\s*public\s+(?:actor|class|struct|enum|protocol|func|var|let|"
    r"init|subscript|typealias|nonisolated|static)\b"
)
IDENT_RE = re.compile(
    r"\b(?:func|var|let|init|subscript|typealias|actor|class|struct|enum|protocol)"
    r"\s+([A-Za-z_][A-Za-z0-9_]*)"
)

def scan(path):
    with open(path) as f:
        lines = f.readlines()
    has_doc = False
    issues = []
    for i, raw in enumerate(lines, 1):
        line = raw.rstrip("\n")
        stripped = line.strip()
        if stripped.startswith("///"):
            has_doc = True
            continue
        if not stripped:
            continue
        if stripped.startswith("@"):
            continue
        if stripped.startswith("//") and not stripped.startswith("///"):
            has_doc = False
            continue
        if DECL_RE.match(line):
            if not has_doc:
                m = IDENT_RE.search(line)
                ident = m.group(1) if m else "?"
                if ident not in CONFORMANCE:
                    issues.append((path, i, line.strip()))
            has_doc = False
        else:
            has_doc = False
    return issues

root = "Sources/RigControl"
issue_count = 0
for dp, _, fs in os.walk(root):
    for fn in sorted(fs):
        if fn.endswith(".swift"):
            for p, n, l in scan(os.path.join(dp, fn)):
                print(f"{p}:{n}: {l}")
                issue_count += 1

sys.exit(min(issue_count, 1))

