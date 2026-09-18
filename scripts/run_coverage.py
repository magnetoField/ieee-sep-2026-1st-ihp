#!/usr/bin/env python3
"""Run a cross-module Verilator line/toggle coverage regression."""

from __future__ import annotations

import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / ".build" / "coverage"
LOGS = ROOT / "reports" / "logs"
TOOL = ROOT / "scripts" / "local_tool.sh"
COMMON = (
    "src/sync2.v", "src/reset_release.v", "src/timebase.v", "src/kb.v",
    "src/regs.v", "src/szymon.v", "src/szymon_fixed.v", "src/serial_link.v", "src/auth_ctrl.v",
    "src/buzzer.v", "src/rumcajs.v",
)


@dataclass(frozen=True)
class Case:
    name: str
    top: str
    sources: tuple[str, ...]
    plusargs: tuple[str, ...] = ()


CASES = (
    Case("directed", "tb_rumcajs", COMMON + ("test/integration/tb_rumcajs.sv",)),
    Case("faults", "tb_fault_sessions", COMMON + ("test/integration/tb_fault_sessions.sv",)),
    Case("wrapper", "tb_tt_um_rumcajs", COMMON + ("src/project.v", "test/integration/tb_tt_um_rumcajs.sv")),
    Case("kb_edges", "tb_kb_edges", ("src/sync2.v", "src/kb.v", "test/unit/tb_kb_edges.sv")),
    Case("serial_lengths", "tb_serial_lengths", ("src/sync2.v", "src/serial_link.v", "test/unit/tb_serial_lengths.sv")),
    Case("serial_unit", "tb_serial_link", ("src/sync2.v", "src/serial_link.v", "test/unit/tb_serial_link.sv")),
    Case("auth_states", "tb_auth_states", ("src/auth_ctrl.v", "test/unit/tb_auth_states.sv")),
    Case(
        "szymon_trace", "tb_szymon_trace_abort",
        ("src/szymon.v", "test/unit/tb_szymon_trace_abort.sv"),
        ("+TRACE=.build/simon_trace.mem",),
    ),
    Case(
        "szymon_fixed", "tb_szymon_fixed",
        ("src/szymon_fixed.v", "test/unit/tb_szymon_fixed.sv"),
        ("+ROUND_KEYS=.build/fixed_round_keys_default.mem",),
    ),
    Case("regs_matrix", "tb_regs_matrix", ("src/regs.v", "test/unit/tb_regs_matrix.sv")),
    Case("buzzer_params", "tb_buzzer_params", ("src/buzzer.v", "test/unit/tb_buzzer_params.sv")),
    Case("timebase_params", "tb_timebase_params", ("src/timebase.v", "test/unit/tb_timebase_params.sv")),
)


def checked(command: list[str], log: Path | None = None) -> str:
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if log is not None:
        log.write_text(result.stdout, encoding="utf-8")
    if result.returncode:
        sys.stdout.write(result.stdout[-5000:])
        raise SystemExit(f"coverage command failed: {' '.join(command)}")
    return result.stdout


def main() -> None:
    BUILD.mkdir(parents=True, exist_ok=True)
    LOGS.mkdir(parents=True, exist_ok=True)
    checked([sys.executable, "scripts/gen_simon_trace.py", ".build/simon_trace.mem"])
    checked([
        sys.executable, "scripts/gen_fixed_round_keys.py",
        ".build/fixed_round_keys_default.mem",
        "0xba2a1918131211100b0a090803020100",
        "0xf0e1d2c3b4a5968778695a4b3c2d1e0f",
    ])
    data_files: list[str] = []
    for case in CASES:
        objdir = BUILD / case.name
        compile_log = LOGS / f"coverage-build-{case.name}.log"
        command = [
            str(TOOL), "verilator", "--binary", "--timing", "--coverage-line",
            "--coverage-toggle", "--coverage-underscore", "-Wno-fatal",
            "-j", "0", "--top-module", case.top, "--Mdir", str(objdir), *case.sources,
        ]
        checked(command, compile_log)
        coverage_data = BUILD / f"{case.name}.dat"
        run_output = checked([
            str(objdir / f"V{case.top}"),
            f"+verilator+coverage+file+{coverage_data}",
            *case.plusargs,
        ])
        (LOGS / f"coverage-run-{case.name}.log").write_text(run_output, encoding="utf-8")
        print(f"PASS coverage case {case.name}", flush=True)
        data_files.append(str(coverage_data))

    annotation = ROOT / "reports" / "coverage"
    info = ROOT / "reports" / "coverage.info"
    output = checked([
        str(TOOL), "verilator_coverage", "--annotate", str(annotation),
        "--annotate-all", "--annotate-min", "1", "--write-info", str(info), *data_files,
    ])
    current_source = ""
    line_hits = line_total = 0
    for line in info.read_text(encoding="utf-8").splitlines():
        if line.startswith("SF:"):
            current_source = line[3:]
        elif current_source.startswith("src/") and line.startswith("DA:"):
            count = int(line[3:].split(",", 1)[1])
            line_total += 1
            line_hits += count > 0
    summary = f"RTL unique line coverage ({line_hits}/{line_total}) {100*line_hits/line_total:.1f}%"
    (LOGS / "coverage.log").write_text(output + summary + "\n", encoding="utf-8")
    print(output.strip())
    print(summary)


if __name__ == "__main__":
    main()
