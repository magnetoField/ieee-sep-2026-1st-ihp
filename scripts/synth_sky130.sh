#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
liberty=${SKY130_LIBERTY:-$root/.tools/sky130_fd_sc_hd/timing-generated/sky130_fd_sc_hd__tt_025C_1v80.lib}

if [ ! -f "$liberty" ]; then
    echo "BLOCKED: SKY130 Liberty file not found: $liberty" >&2
    echo "Set SKY130_LIBERTY to an installed sky130_fd_sc_hd .lib file." >&2
    exit 2
fi

case "$liberty" in
    *\"*|*\;*)
        echo "ERROR: unsupported quote or semicolon in SKY130_LIBERTY path" >&2
        exit 2
        ;;
esac

mkdir -p "$root/.build" "$root/reports/logs"

"$root/scripts/local_tool.sh" yosys -q \
    -l "$root/reports/logs/synth-sky130.log" \
    -p "read_liberty -lib -ignore_miss_func \"$liberty\"; \
        read_verilog $root/src/*.v; \
        hierarchy -check -top tt_um_rumcajs; \
        synth -top tt_um_rumcajs -flatten -noabc; \
        dfflibmap -liberty \"$liberty\"; \
        abc -liberty \"$liberty\" -dont_use sky130_fd_sc_hd__lpflow_*; \
        clean; \
        stat -liberty \"$liberty\"; \
        check; \
        write_verilog -noattr "$root/.build/tt_um_rumcajs.sky130.v""

