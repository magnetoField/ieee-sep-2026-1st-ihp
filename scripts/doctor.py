#!/usr/bin/env python3
"""Report the actual local tool status without converting absence into PASS."""

from __future__ import annotations

import platform
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LOCAL_TOOL = ROOT / "scripts" / "local_tool.sh"

TOOLS = {
    "python3": [sys.executable, "--version"],
    "git": ["git", "--version"],
    "make": ["make", "--version"],
    "iverilog (local/system fallback)": [str(LOCAL_TOOL), "iverilog", "-V"],
    "verilator (local/system fallback)": [str(LOCAL_TOOL), "verilator", "--version"],
    "yosys (local/system fallback)": [str(LOCAL_TOOL), "yosys", "-V"],
}


def first_line(command: list[str]) -> str:
    try:
        completed = subprocess.run(command, text=True, capture_output=True, timeout=10, check=False)
    except (OSError, subprocess.SubprocessError) as error:
        return f"BROKEN ({error})"
    output = (completed.stdout + completed.stderr).strip().splitlines()
    text = output[0] if output else "no version output"
    return f"FOUND rc={completed.returncode}: {text}"


def main() -> int:
    print(f"platform: {platform.platform()}")
    missing = False
    for name, command in TOOLS.items():
        executable = command[0]
        if not Path(executable).is_absolute() and shutil.which(executable) is None:
            print(f"{name}: MISSING")
            missing = True
        else:
            result = first_line(command)
            print(f"{name}: {result}")
            missing |= "rc=0:" not in result
    # This project's formal runner uses Yosys' built-in SAT engine. Docker
    # is optional because the pinned LibreLane AppImage is supported locally.
    for optional in ("sby", "boolector", "z3", "docker"):
        print(f"optional {optional}: {'FOUND' if shutil.which(optional) else 'NOT_INSTALLED'}")
    pdk_root = Path(os.environ.get("PDK_ROOT", ROOT / ".tools/IHP-Open-PDK-partial"))
    print(f"local PDK: {'FOUND' if pdk_root.exists() else 'MISSING'} ({pdk_root.resolve()})")
    pdk_ready = (pdk_root / "ihp-sg13g2/libs.tech/librelane/config.tcl").is_file()
    print("RTL/formal preflight: BLOCKED" if missing else "RTL/formal preflight: READY")
    print(f"IHP PDK configuration: {'FOUND' if pdk_ready else 'MISSING'}")
    print("Physical tool versions and executed checks: reports/TOOLCHAIN.md and reports/FINAL.md")
    return 2 if missing or not pdk_ready else 0


if __name__ == "__main__":
    raise SystemExit(main())
