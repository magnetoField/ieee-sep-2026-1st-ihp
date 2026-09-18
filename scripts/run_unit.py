#!/usr/bin/env python3
"""Compile and execute standalone RTL unit benches."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / ".build"
LOCAL_TOOL = ROOT / "scripts/local_tool.sh"
SIMON_SEED = "0x52554d43"


def run(command: list[str]) -> None:
    print("+", " ".join(command), flush=True)
    subprocess.run(command, cwd=ROOT, check=True)


def run_szymon() -> None:
    BUILD.mkdir(exist_ok=True)
    vectors = BUILD / "simon_vectors.mem"
    output = BUILD / "tb_szymon.vvp"
    run([sys.executable, "scripts/gen_simon_vectors.py", str(vectors), "--count", "1024", "--seed", SIMON_SEED])
    run([
        str(LOCAL_TOOL), "iverilog", "-g2012", "-Wall", "-s", "tb_szymon",
        "-o", str(output), "src/szymon.v", "test/unit/tb_szymon.sv",
    ])
    run([str(LOCAL_TOOL), "vvp", str(output), f"+VECTORS={vectors}", "+COUNT=1024"])


def run_szymon_trace_abort() -> None:
    BUILD.mkdir(exist_ok=True)
    trace = BUILD / "simon_trace.mem"
    output = BUILD / "tb_szymon_trace_abort.vvp"
    run([sys.executable, "scripts/gen_simon_trace.py", str(trace)])
    run([
        str(LOCAL_TOOL), "iverilog", "-g2012", "-Wall", "-s", "tb_szymon_trace_abort",
        "-o", str(output), "src/szymon.v", "test/unit/tb_szymon_trace_abort.sv",
    ])
    run([str(LOCAL_TOOL), "vvp", str(output), f"+TRACE={trace}"])


def run_szymon_fixed() -> None:
    import random

    sys.path.insert(0, str(ROOT))
    from model.simon64_128 import encrypt

    BUILD.mkdir(exist_ok=True)
    rng = random.Random(0x53494D4F)
    keys = [0xBA2A1918131211100B0A090803020100, 0, (1 << 128) - 1]
    keys.extend(rng.getrandbits(128) for _ in range(4))
    for index, key in enumerate(keys):
        round_keys = BUILD / f"single_round_keys_{index}.mem"
        # Existing generator emits two columns; use the same key in both.
        run([sys.executable, "scripts/gen_fixed_round_keys.py", str(round_keys), hex(key), hex(key)])
        expected = encrypt(0x656B696C20646E75, key)
        output = BUILD / f"tb_szymon_single_{index}.vvp"
        run([
            str(LOCAL_TOOL), "iverilog", "-g2012", "-Wall", "-s", "tb_szymon_fixed",
            f"-Ptb_szymon_fixed.TEST_KEY=128'h{key:032x}",
            f"-Ptb_szymon_fixed.EXPECT=64'h{expected:016x}",
            "-o", str(output), "src/szymon_fixed.v", "test/unit/tb_szymon_fixed.sv",
        ])
        run([str(LOCAL_TOOL), "vvp", str(output), f"+ROUND_KEYS={round_keys}"])


def run_simple(module: str, sources: list[str]) -> None:
    BUILD.mkdir(exist_ok=True)
    output = BUILD / f"tb_{module}.vvp"
    run([str(LOCAL_TOOL), "iverilog", "-g2012", "-Wall", "-s", f"tb_{module}", "-o", str(output), *sources])
    run([str(LOCAL_TOOL), "vvp", str(output)])


RUNNERS = {
    "sync2": lambda: run_simple("sync2", ["src/sync2.v", "test/unit/tb_sync2.sv"]),
    "reset_release": lambda: run_simple("reset_release", ["src/reset_release.v", "test/unit/tb_reset_release.sv"]),
    "timebase": lambda: run_simple("timebase", ["src/timebase.v", "test/unit/tb_timebase.sv"]),
    "timebase_params": lambda: run_simple(
        "timebase_params", ["src/timebase.v", "test/unit/tb_timebase_params.sv"]
    ),
    "regs": lambda: run_simple("regs", ["src/regs.v", "test/unit/tb_regs.sv"]),
    "regs_matrix": lambda: run_simple(
        "regs_matrix", ["src/regs.v", "test/unit/tb_regs_matrix.sv"]
    ),
    "buzzer": lambda: run_simple("buzzer", ["src/buzzer.v", "test/unit/tb_buzzer.sv"]),
    "buzzer_params": lambda: run_simple(
        "buzzer_params", ["src/buzzer.v", "test/unit/tb_buzzer_params.sv"]
    ),
    "buzzer_symmetry": lambda: run_simple(
        "buzzer_symmetry", ["src/regs.v", "src/buzzer.v", "test/unit/tb_buzzer_symmetry.sv"]
    ),
    "kb": lambda: run_simple("kb", ["src/sync2.v", "src/kb.v", "test/unit/tb_kb.sv"]),
    "kb_edges": lambda: run_simple(
        "kb_edges", ["src/sync2.v", "src/kb.v", "test/unit/tb_kb_edges.sv"]
    ),
    "kb_exhaustive": lambda: run_simple(
        "kb_exhaustive", ["src/sync2.v", "src/kb.v", "test/unit/tb_kb_exhaustive.sv"]
    ),
    "serial_link": lambda: run_simple(
        "serial_link", ["src/sync2.v", "src/serial_link.v", "test/unit/tb_serial_link.sv"]
    ),
    "serial_lengths": lambda: run_simple(
        "serial_lengths", ["src/sync2.v", "src/serial_link.v", "test/unit/tb_serial_lengths.sv"]
    ),
    "auth_ctrl": lambda: run_simple(
        "auth_ctrl", ["src/auth_ctrl.v", "test/unit/tb_auth_ctrl.sv"]
    ),
    "auth_states": lambda: run_simple(
        "auth_states", ["src/auth_ctrl.v", "test/unit/tb_auth_states.sv"]
    ),
    "szymon": run_szymon,
    "szymon_trace_abort": run_szymon_trace_abort,
    "szymon_fixed": run_szymon_fixed,
}

DEFAULT_MODULES = [name for name in RUNNERS if name != "kb_exhaustive"]


def run_integration() -> None:
    sources = [
        "src/sync2.v", "src/reset_release.v", "src/timebase.v", "src/kb.v",
        "src/regs.v", "src/szymon.v", "src/szymon_fixed.v", "src/serial_link.v", "src/auth_ctrl.v",
        "src/buzzer.v", "src/rumcajs.v", "test/integration/tb_rumcajs.sv",
    ]
    run_simple("rumcajs", sources)


def run_wrapper() -> None:
    sources = [
        "src/sync2.v", "src/reset_release.v", "src/timebase.v", "src/kb.v",
        "src/regs.v", "src/szymon.v", "src/szymon_fixed.v", "src/serial_link.v", "src/auth_ctrl.v",
        "src/buzzer.v", "src/rumcajs.v", "src/project.v",
        "test/integration/tb_tt_um_rumcajs.sv",
    ]
    run_simple("tt_um_rumcajs", sources)


def run_random_sessions() -> None:
    BUILD.mkdir(exist_ok=True)
    vectors = BUILD / "session_vectors.mem"
    output = BUILD / "tb_random_sessions.vvp"
    run([
        sys.executable, "scripts/gen_session_vectors.py", str(vectors),
        "--count", "256", "--seed", "0xE2E52517",
    ])
    sources = [
        "src/sync2.v", "src/reset_release.v", "src/timebase.v", "src/kb.v",
        "src/regs.v", "src/szymon.v", "src/szymon_fixed.v", "src/serial_link.v", "src/auth_ctrl.v",
        "src/buzzer.v", "src/rumcajs.v", "test/integration/tb_random_sessions.sv",
    ]
    run([
        str(LOCAL_TOOL), "iverilog", "-g2012", "-Wall", "-s", "tb_random_sessions",
        "-o", str(output), *sources,
    ])
    run([
        str(LOCAL_TOOL), "vvp", str(output), f"+VECTORS={vectors}", "+COUNT=256",
    ])


def run_fault_sessions() -> None:
    sources = [
        "src/sync2.v", "src/reset_release.v", "src/timebase.v", "src/kb.v",
        "src/regs.v", "src/szymon.v", "src/szymon_fixed.v", "src/serial_link.v", "src/auth_ctrl.v",
        "src/buzzer.v", "src/rumcajs.v", "test/integration/tb_fault_sessions.sv",
    ]
    run_simple("fault_sessions", sources)


def main() -> None:
    global SIMON_SEED
    parser = argparse.ArgumentParser()
    parser.add_argument("--module", choices=sorted(RUNNERS), action="append")
    parser.add_argument("--seed", default=SIMON_SEED, help="SIMON random-vector seed (Python integer syntax)")
    args = parser.parse_args()
    # Validate eagerly so CI logs a malformed seed before compiling RTL.
    int(args.seed, 0)
    SIMON_SEED = args.seed
    modules = args.module or DEFAULT_MODULES
    for module in modules:
        print(f"== unit:{module} ==", flush=True)
        RUNNERS[module]()


if __name__ == "__main__":
    main()
