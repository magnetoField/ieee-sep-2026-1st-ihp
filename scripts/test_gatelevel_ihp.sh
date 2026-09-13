#!/usr/bin/env bash
set -euo pipefail

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
netlist="${IHP_NETLIST:-$root/.build/tt_um_rumcajs.ihp.v}"
relative=ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v

if [[ -n "${IHP_CELL_MODELS:-}" ]]; then
    models=$IHP_CELL_MODELS
elif [[ -n "${PDK_ROOT:-}" && -f "$PDK_ROOT/$relative" ]]; then
    models="$PDK_ROOT/$relative"
else
    models="$root/.tools/IHP-Open-PDK-partial/$relative"
fi

output="$root/.build/tb_tt_um_rumcajs_ihp_gl.vvp"
functional_models="$root/.build/sg13g2_stdcell.iverilog.v"
log="${IHP_GL_LOG:-$root/reports/logs/gatelevel-ihp.log}"
compile_flags=()
iverilog_cmd=("$root/scripts/local_tool.sh" iverilog)
vvp_cmd=("$root/scripts/local_tool.sh" vvp)
official_models=0
if [[ -x "$root/.tools/iverilog13/usr/bin/iverilog" ]]; then
    iverilog_cmd=("$root/.tools/iverilog13/usr/bin/iverilog" -B "$root/.tools/iverilog13/usr/lib/ivl")
    vvp_cmd=("$root/.tools/iverilog13/usr/bin/vvp" -M "$root/.tools/iverilog13/usr/lib/ivl")
    official_models=1
elif command -v iverilog >/dev/null && iverilog -V 2>/dev/null | grep -q 'Icarus Verilog version 13'; then
    iverilog_cmd=(iverilog)
    vvp_cmd=(vvp)
    official_models=1
fi
if [[ "${IHP_POWER_PINS:-0}" = 1 ]]; then
    compile_flags+=(-DIHP_POWER_PINS)
fi

if [[ ! -f "$netlist" ]]; then
    echo "BLOCKED: mapped IHP netlist not found: $netlist" >&2
    exit 2
fi
if [[ ! -f "$models" ]]; then
    echo "BLOCKED: IHP SG13G2 cell models not found: $models" >&2
    echo "Set IHP_CELL_MODELS or PDK_ROOT to the pinned IHP26b PDK." >&2
    exit 2
fi

mkdir -p "$root/.build" "$root/reports/logs"

# Icarus 12 does not drive the delayed_* signals created only by specify
# timing checks in the official dfrbpq model. Keep every official combinational
# model, remove that wrapper, and substitute the zero-delay DFF used by this
# no-SDF smoke. The physical flow's own GL job remains authoritative.
cell_sources=("$models")
if [[ "$official_models" = 1 ]]; then
    compile_flags+=(-gspecify)
else
awk '
    BEGIN { skip = 0 }
    /^module sg13g2_dfrbpq_1 / { skip = 1; next }
    skip && /^endmodule/ { skip = 0; next }
    !skip { print }
' "$models" > "$functional_models"
cell_sources=("$functional_models" "$root/test/gatelevel/sg13g2_dfrbpq_1.functional.v")
fi

{
    echo "netlist_sha256=$(sha256sum "$netlist" | awk '{print $1}')"
    echo "cell_models_sha256=$(sha256sum "$models" | awk '{print $1}')"
    echo "official_unmodified_models=$official_models; sdf=none"
    "${iverilog_cmd[@]}" -g2012 "${compile_flags[@]}" \
        -s tb_tt_um_rumcajs_gl -o "$output" \
        "${cell_sources[@]}" \
        "$netlist" "$root/test/gatelevel/tb_tt_um_rumcajs_gl.sv"
    "${vvp_cmd[@]}" "$output"
} >"$log" 2>&1

tail -n 3 "$log"
