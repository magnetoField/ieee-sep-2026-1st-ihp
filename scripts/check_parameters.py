#!/usr/bin/env python3
"""Run valid parameter behavior and require invalid elaborations to fail."""

from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / ".build" / "params"
TOOL = ROOT / "scripts" / "local_tool.sh"


def run(command: list[str], expect_success: bool = True) -> None:
    completed = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    if (completed.returncode == 0) != expect_success:
        print(completed.stdout, end="")
        print(completed.stderr, end="")
        expectation = "success" if expect_success else "failure"
        raise SystemExit(f"expected {expectation}: {' '.join(command)}")


def valid_regs() -> None:
    for pin_len, max_fails in ((1, 1), (4, 3), (6, 4), (8, 7)):
        output = BUILD / f"regs_{pin_len}_{max_fails}.vvp"
        compile_command = [
            str(TOOL), "iverilog", "-g2012", "-s", "tb_regs_params",
            f"-Ptb_regs_params.PIN_LEN={pin_len}",
            f"-Ptb_regs_params.MAX_FAILS={max_fails}",
            "-o", str(output), "src/regs.v", "test/unit/tb_regs_params.sv",
        ]
        run(compile_command)
        completed = subprocess.run([str(TOOL), "vvp", str(output)], cwd=ROOT, check=True, text=True, capture_output=True)
        print(completed.stdout.strip())


def invalid_elaboration() -> None:
    cases = {
        "sync_width": ("src/sync2.v", "sync2 #(.WIDTH(0)) d(.clk(c),.rst_n(r),.async_in(),.sync_out());"),
        "time_div": ("src/timebase.v", "timebase #(.CLK_HZ(64000),.SCAN_HZ(3000)) d(.clk(c),.rst_n(r),.scan_tick(),.ms_tick());"),
        "time_small_div": ("src/timebase.v", "timebase #(.CLK_HZ(16000),.SCAN_HZ(2000)) d(.clk(c),.rst_n(r),.scan_tick(),.ms_tick());"),
        "kb_zero": ("src/sync2.v src/kb.v", "kb #(.PRESS_FRAMES(0)) d(.clk(c),.rst_n(r),.enable(1'b0),.flush(1'b0),.scan_tick(1'b0),.col_n(4'hf),.row_oe(),.key_valid(),.key_ready(1'b0),.key_id());"),
        "regs_pin_zero": ("src/regs.v", "regs #(.PIN_LEN(0)) d();"),
        "regs_bad_bcd": ("src/regs.v", "regs #(.PIN_VALUE(32'h0000123a)) d();"),
        "regs_pin_long": ("src/regs.v", "regs #(.PIN_LEN(9)) d();"),
        "regs_fail_zero": ("src/regs.v", "regs #(.MAX_FAILS(0)) d();"),
        "buzzer_zero": ("src/buzzer.v", "buzzer #(.BEEP_TICKS_MS(0)) d();"),
        "buzzer_half_zero": ("src/buzzer.v", "buzzer #(.TONE_HALF_TICKS(0)) d();"),
        "auth_zero": ("src/auth_ctrl.v", "auth_ctrl #(.AUTH_TIMEOUT_MS(0)) d();"),
        "core_mode": (
            "src/sync2.v src/reset_release.v src/timebase.v src/kb.v src/regs.v "
            "src/szymon.v src/szymon_fixed.v src/serial_link.v src/auth_ctrl.v "
            "src/buzzer.v src/rumcajs.v",
            "rumcajs #(.FIXED_KEY_CORE(2)) d();",
        ),
    }
    for name, (sources, instance) in cases.items():
        harness = BUILD / f"invalid_{name}.sv"
        harness.write_text(f"module invalid_{name}; reg c=0,r=0; {instance} endmodule\n")
        command = [str(TOOL), "iverilog", "-g2012", "-s", f"invalid_{name}", "-o", str(BUILD / name)]
        command.extend(sources.split())
        command.append(str(harness))
        run(command, expect_success=False)
        print(f"PASS invalid configuration rejected: {name}")


def main() -> None:
    BUILD.mkdir(parents=True, exist_ok=True)
    valid_regs()
    invalid_elaboration()


if __name__ == "__main__":
    main()
