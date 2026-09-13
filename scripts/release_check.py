#!/usr/bin/env python3
"""Validate actual local evidence; never infer PASS from a prefix or missing file."""
from pathlib import Path
import hashlib
import json
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = ("RTL_DEMO", "VERIFICATION", "FIT_1_TILE", "PHYSICAL_CHECKS",
            "TT_PRECHECK", "GATE_LEVEL")

def check_statuses(text):
    for name in REQUIRED:
        if re.findall(rf"^{name}=(\S+)\s*$", text, re.MULTILINE) != ["PASS"]:
            raise ValueError(f"missing or non-PASS status: {name}")
    if not re.search(r"^PRODUCTION_PERSISTENCE=NOT_IMPLEMENTED\s*$", text, re.MULTILINE):
        raise ValueError("missing mandatory volatile-demo limitation")

def check_xml(path, minimum):
    tree = ET.parse(path)
    cases = list(tree.iter("testcase"))
    if len(cases) < minimum or any(list(tree.iter(tag)) for tag in ("failure", "error", "skipped")):
        raise ValueError(f"incomplete/failing XML evidence: {path}")

def check_manifest(root):
    records = (root / "MANIFEST.sha256").read_text().splitlines()
    seen = set()
    for line in records:
        digest, name = line.split("  ", 1)
        path = (root / name).resolve()
        if not path.is_relative_to(root.resolve()):
            raise ValueError("manifest path escapes repository")
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ValueError(f"changed evidence/source: {name}")
        seen.add(name)
    required = {str(p.relative_to(root)) for p in (root / "src").glob("*.v")}
    required |= {"src/config.json", "reports/full-precheck.xml",
                 "reports/full-physical-metrics.json", "reports/full-gatelevel.xml",
                 "artifacts/verified_single_key/tt_um_rumcajs.gds",
                 "artifacts/verified_single_key/tt_um_rumcajs.lef",
                 "artifacts/verified_single_key/tt_um_rumcajs.v"}
    if not required <= seen:
        raise ValueError("manifest misses required source or evidence")

def main():
    try:
        check_statuses((ROOT / "reports/FINAL.md").read_text())
        check_manifest(ROOT)
        check_xml(ROOT / "reports/full-precheck.xml", 10)
        check_xml(ROOT / "reports/full-gatelevel.xml", 1)
        metrics = json.loads((ROOT / "reports/full-physical-metrics.json").read_text())
        for key in ("route__drc_errors", "magic__drc_error__count",
                    "design__lvs_error__count", "antenna__violating__nets",
                    "design__critical_disconnected_pin__count",
                    "design__max_slew_violation__count", "design__max_cap_violation__count",
                    "timing__unannotated_net_filtered__count"):
            if metrics.get(key) != 0:
                raise ValueError(f"missing or failing physical metric: {key}")
        for corner in ("nom_fast_1p32V_m40C", "nom_typ_1p20V_25C", "nom_slow_1p08V_125C"):
            for kind in ("setup", "hold"):
                if metrics[f"timing__{kind}__ws__corner:{corner}"] < 0:
                    raise ValueError(f"negative {kind} slack at {corner}")
                if metrics[f"timing__{kind}__tns__corner:{corner}"] != 0:
                    raise ValueError(f"nonzero {kind} TNS at {corner}")
        log = (ROOT / "reports/logs/full-verification-regression.log").read_text()
        for marker in ("PASS tb_kb_exhaustive all 65536", "PASS mutation score 7/7",
                       "PASS tb_random_sessions count=256", "PASS tb_szymon: KAT + 1024",
                       "PASS temporal induction", "PASS formal reachability"):
            if marker not in log:
                raise ValueError(f"missing regression evidence: {marker}")
        coverage = (ROOT / "reports/logs/full-verification-coverage.log").read_text()
        if coverage.count("PASS coverage case ") != 12 or "RTL unique line coverage" not in coverage:
            raise ValueError("coverage regression incomplete")
    except (OSError, ValueError, KeyError, ET.ParseError) as exc:
        raise SystemExit(f"BLOCKED: {exc}")
    print("release-check: PASS for required local checks; SDF unsupported, no remote submission")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
