#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
mkdir -p reports/logs
scripts/local_tool.sh yosys -q -l reports/logs/formal-F11.log \
  -p 'read_verilog -formal -sv formal/round_equiv.sv; chformal -lower; prep -top round_equiv; sat -verify -prove-asserts -show-all'
scripts/local_tool.sh yosys -q -l reports/logs/formal-F12.log \
  -p 'read_verilog -formal -sv formal/key_schedule_equiv.sv; chformal -lower; prep -top key_schedule_equiv; sat -verify -prove-asserts -show-all'
echo 'PASS formal F-11 and F-12: exhaustive SAT over arbitrary inputs'

prove_seq() {
  name=$1
  top=$2
  sources=$3
  scripts/local_tool.sh yosys -q -l "reports/logs/formal-$name.log" \
    -p "read_verilog -formal -D FORMAL $sources; chformal -lower; prep -top $top; flatten; async2sync; formalff -clk2ff; memory_map; opt_clean; sat -verify -prove-asserts -set-init-zero -set-def-formal -set-def-inputs -seq 20"
}

prove_seq F01_F03_F06_F10_regs regs 'src/regs.v'
prove_seq F06_szymon szymon 'src/szymon.v'
prove_seq F06_szymon_fixed szymon_fixed 'src/szymon_fixed.v'
prove_seq F06_F08_F09_kb kb 'src/sync2.v src/kb.v'
prove_seq F05_F07_serial serial_link 'src/sync2.v src/serial_link.v'
prove_seq F04_F05_F13_auth auth_ctrl 'src/auth_ctrl.v'

prove_induct() {
  name=$1
  top=$2
  sources=$3
  scripts/local_tool.sh yosys -q -l "reports/logs/formal-induct-$name.log" \
    -p "read_verilog -formal -D FORMAL $sources; chformal -lower; prep -top $top; flatten; async2sync; formalff -clk2ff; memory_map; opt_clean; sat -verify -prove-asserts -set-init-zero -set-def-formal -set-def-inputs -seq 5 -tempinduct"
}

prove_induct F01_F02_F03_F06_F10_regs regs 'src/regs.v'
prove_induct F06_F08_F09_kb kb 'src/sync2.v src/kb.v'
prove_induct F06_szymon szymon 'src/szymon.v'
prove_induct F06_szymon_fixed szymon_fixed 'src/szymon_fixed.v'

scripts/local_tool.sh yosys -q -l reports/logs/formal-F13-liveness.log \
  -p 'read_verilog -formal -sv src/auth_ctrl.v formal/auth_liveness.sv; chformal -lower; prep -top auth_liveness; flatten; async2sync; formalff -clk2ff; memory_map; opt_clean; sat -verify -prove-asserts -set-init-zero -set-def-formal -set-def-inputs -seq 12'

scripts/local_tool.sh yosys -q -l reports/logs/formal-cover-reachability.log \
  -p 'read_verilog -sv src/regs.v src/auth_ctrl.v formal/reachability.sv; prep -top reachability; flatten; async2sync; formalff -clk2ff; memory_map; opt_clean; sat -seq 20 -set-init-zero -set-def-inputs -set-at 20 cover_goal 1 -show cover_goal'
if ! grep -q 'SAT solving finished - model found:' reports/logs/formal-cover-reachability.log; then
  echo 'FAIL formal reachability cover was not reached' >&2
  exit 1
fi

scripts/local_tool.sh yosys -q -l reports/logs/formal-F08-wrapper.log \
  -p 'read_verilog -formal -D FORMAL src/*.v; prep -top tt_um_rumcajs; async2sync; clk2fflogic; chformal -lower; memory_map; flatten; sat -verify -prove-asserts -set-init-zero -seq 2'

echo 'PASS bounded formal control checks: depth 20; F-13 scaled periodic-tick harness depth 12 (not induction)'
echo 'PASS temporal induction: regs, kb, szymon and szymon_fixed safety invariants'
echo 'PASS formal reachability: authorized GOOD, rejected terminal BAD, cmd, seal and successful cleanup'
