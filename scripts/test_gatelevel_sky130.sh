#!/usr/bin/env bash
set -euo pipefail

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
netlist="$root/.build/tt_um_rumcajs.sky130.v"
library="$root/.tools/sky130_fd_sc_hd"
output="$root/.build/tb_tt_um_rumcajs_gl.vvp"
log="$root/reports/logs/gatelevel-sky130.log"

if [[ ! -f "$netlist" ]]; then
    echo "BLOCKED: mapped SKY130 netlist not found: $netlist" >&2
    echo "Run 'make synth-sky130' first." >&2
    exit 2
fi
if [[ ! -d "$library/cells" ]]; then
    echo "BLOCKED: sky130_fd_sc_hd functional models not found: $library" >&2
    exit 2
fi

mkdir -p "$root/.build" "$root/reports/logs"
cell_args=()
while read -r cell; do
    short=${cell#sky130_fd_sc_hd__}
    group=${short%_[0-9]*}
    model="$library/cells/$group/$cell.v"
    if [[ ! -f "$model" ]]; then
        echo "BLOCKED: functional model wrapper not found: $model" >&2
        exit 2
    fi
    cell_args+=("-I$library/cells/$group" "$model")
done < <(rg -o 'sky130_fd_sc_hd__[A-Za-z0-9_]+' "$netlist" | sort -u)

{
    echo "netlist_sha256=$(sha256sum "$netlist" | awk '{print $1}')"
    echo "library_commit=$(git -C "$library" rev-parse HEAD)"
    "$root/scripts/local_tool.sh" iverilog -g2012 -DFUNCTIONAL \
        "${cell_args[@]}" -s tb_tt_um_rumcajs_gl -o "$output" \
        "$netlist" "$root/test/gatelevel/tb_tt_um_rumcajs_gl.sv"
    "$root/scripts/local_tool.sh" vvp "$output"
} 2>&1 | tee "$log"

