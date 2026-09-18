#!/usr/bin/env python3
"""Run deliberate RTL mutations and require the existing tests to kill them."""

from __future__ import annotations

import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / ".build" / "mutations"
LOCAL_TOOL = ROOT / "scripts" / "local_tool.sh"


@dataclass(frozen=True)
class Mutation:
    name: str
    source: str
    old: str
    new: str
    top: str
    companions: tuple[str, ...]
    bench: str
    plusargs: tuple[str, ...] = ()
    replace_all: bool = False


MUTATIONS = (
    Mutation(
        "authorize_bad_pin",
        "src/regs.v",
        "txn_valid    <= pin_matches;",
        "txn_valid    <= 1'b1;",
        "tb_regs",
        (),
        "test/unit/tb_regs.sv",
    ),
    Mutation(
        "remove_final_simon_round",
        "src/szymon.v",
        "if (round_count == 6'd43) begin",
        "if (round_count == 6'd42) begin",
        "tb_szymon",
        (),
        "test/unit/tb_szymon.sv",
        ("+VECTORS=.build/simon_vectors.mem", "+COUNT=1024"),
    ),
    Mutation(
        "shift_simon_output_bit",
        "src/szymon.v",
        "assign m_bit      = (state == ST_OUTPUT) ? a[31] : 1'b0;",
        "assign m_bit      = (state == ST_OUTPUT) ? a[30] : 1'b0;",
        "tb_szymon",
        (),
        "test/unit/tb_szymon.sv",
        ("+VECTORS=.build/simon_vectors.mem", "+COUNT=1024"),
    ),
    Mutation(
        "remove_final_fixed_simon_round",
        "src/szymon_fixed.v",
        "if (round_count == 6'd43) begin",
        "if (round_count == 6'd42) begin",
        "tb_szymon_fixed",
        (),
        "test/unit/tb_szymon_fixed.sv",
        ("+ROUND_KEYS=.build/fixed_round_keys_default.mem",),
    ),
    Mutation(
        "shift_fixed_simon_output_bit",
        "src/szymon_fixed.v",
        "assign m_bit      = (state == ST_OUTPUT) ? a[31] : 1'b0;",
        "assign m_bit      = (state == ST_OUTPUT) ? a[30] : 1'b0;",
        "tb_szymon_fixed",
        (),
        "test/unit/tb_szymon_fixed.sv",
        ("+ROUND_KEYS=.build/fixed_round_keys_default.mem",),
    ),
    Mutation(
        "erase_attempts_on_session_end",
        "src/regs.v",
        "        end else if (submit_event && !pin_matches) begin\n",
        "        end else if (session_end) begin\n"
        "            fail_count <= {FAIL_W{1'b0}};\n"
        "        end else if (submit_event && !pin_matches) begin\n",
        "tb_regs",
        (),
        "test/unit/tb_regs.sv",
    ),
    Mutation(
        "disable_keypad_poison",
        "src/kb.v",
        "gesture_poisoned <= 1'b1;",
        "gesture_poisoned <= 1'b0;",
        "tb_kb",
        ("src/sync2.v",),
        "test/unit/tb_kb.sv",
    ),
)


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )


def write_mutant(mutation: Mutation) -> Path:
    original = (ROOT / mutation.source).read_text(encoding="utf-8")
    count = original.count(mutation.old)
    expected = count if mutation.replace_all else 1
    if count < 1 or (not mutation.replace_all and count != 1):
        raise RuntimeError(
            f"{mutation.name}: mutation anchor count is {count}, expected {expected}"
        )
    changed = original.replace(mutation.old, mutation.new, -1 if mutation.replace_all else 1)
    target = BUILD / f"{mutation.name}.v"
    target.write_text(changed, encoding="utf-8")
    return target


def main() -> None:
    BUILD.mkdir(parents=True, exist_ok=True)
    vector_result = run([
        sys.executable,
        "scripts/gen_simon_vectors.py",
        ".build/simon_vectors.mem",
        "--count",
        "1024",
        "--seed",
        "0x52554d43",
    ])
    if vector_result.returncode:
        sys.stdout.write(vector_result.stdout)
        raise SystemExit("could not generate mutation-test vectors")
    fixed_result = run([
        sys.executable,
        "scripts/gen_fixed_round_keys.py",
        ".build/fixed_round_keys_default.mem",
        "0xba2a1918131211100b0a090803020100",
        "0xf0e1d2c3b4a5968778695a4b3c2d1e0f",
    ])
    if fixed_result.returncode:
        sys.stdout.write(fixed_result.stdout)
        raise SystemExit("could not generate fixed-key mutation schedule")

    killed = 0
    for mutation in MUTATIONS:
        mutant = write_mutant(mutation)
        executable = BUILD / f"{mutation.name}.vvp"
        compile_result = run([
            str(LOCAL_TOOL),
            "iverilog",
            "-g2012",
            "-Wall",
            "-s",
            mutation.top,
            "-o",
            str(executable),
            *mutation.companions,
            str(mutant.relative_to(ROOT)),
            mutation.bench,
        ])
        if compile_result.returncode:
            print(f"INVALID {mutation.name}: mutant did not compile")
            print(compile_result.stdout[-2000:])
            continue

        test_result = run([
            str(LOCAL_TOOL), "vvp", str(executable.relative_to(ROOT)), *mutation.plusargs
        ])
        if test_result.returncode == 0:
            print(f"SURVIVED {mutation.name}: test unexpectedly passed")
            print(test_result.stdout[-1000:])
        else:
            killed += 1
            diagnostic = next(
                (line.strip() for line in test_result.stdout.splitlines() if "FATAL" in line),
                "nonzero test exit",
            )
            print(f"KILLED {mutation.name}: {diagnostic}")

    if killed != len(MUTATIONS):
        raise SystemExit(f"FAIL mutation score {killed}/{len(MUTATIONS)}")
    print(f"PASS mutation score {killed}/{len(MUTATIONS)}")


if __name__ == "__main__":
    main()
