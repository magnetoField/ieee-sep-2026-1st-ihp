#!/usr/bin/env python3
"""TT action-compatible no-SDF gate smoke; emit real JUnit results, fail closed."""
import os
from pathlib import Path
import subprocess
import time
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
netlist = root / "test/gate_level_netlist.v"
log = root / "reports/logs/tt-action-gatelevel.log"
env = os.environ.copy()
env.update(IHP_NETLIST=str(netlist), IHP_GL_LOG=str(log), IHP_POWER_PINS="0")
started = time.monotonic()
suite = ET.Element("testsuite", name="Rumcajs post-route pin-level smoke", tests="1")
case = ET.SubElement(suite, "testcase", name="single_key_pins_no_sdf")
try:
    result = subprocess.run(
        ["bash", str(root / "scripts/test_gatelevel_ihp.sh")],
        cwd=root, env=env, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, timeout=600,
    )
    print(result.stdout, end="")
    passed = result.returncode == 0 and "PASS gate-level mapped standard cells" in result.stdout
    detail = result.stdout
    if not passed and log.exists():
        detail += "\n" + log.read_text()[-8000:]
except (OSError, subprocess.TimeoutExpired) as exc:
    passed, detail = False, str(exc)
case.set("time", f"{time.monotonic()-started:.3f}")
if not passed:
    suite.set("failures", "1")
    ET.SubElement(case, "failure", message="Gate simulation failed or did not report PASS").text = detail
ET.SubElement(case, "system-out").text = detail
ET.ElementTree(suite).write(root / "test/results.xml", encoding="unicode")
raise SystemExit(0 if passed else 1)
