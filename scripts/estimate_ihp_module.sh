#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
module=${1:-}
relative=ihp-sg13g2/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib

case "$module" in
    ''|[0-9]*|*[!A-Za-z0-9_]*)
        echo "usage: $0 VERILOG_MODULE" >&2
        exit 2
        ;;
esac

if [ -n "${IHP_LIBERTY:-}" ]; then
    liberty=$IHP_LIBERTY
elif [ -n "${PDK_ROOT:-}" ] && [ -f "$PDK_ROOT/$relative" ]; then
    liberty=$PDK_ROOT/$relative
else
    liberty=$root/.tools/IHP-Open-PDK-partial/$relative
fi

if [ ! -f "$liberty" ]; then
    echo "BLOCKED: IHP SG13G2 Liberty file not found: $liberty" >&2
    exit 2
fi

log=$root/reports/logs/area-$module.log
mkdir -p "$root/reports/logs"

"$root/scripts/local_tool.sh" yosys -q -l "$log" -p "read_liberty -lib -ignore_miss_func \"$liberty\"; read_verilog $root/src/*.v; hierarchy -check -top $module; synth -top $module -flatten -noabc; dfflibmap -liberty \"$liberty\"; abc -liberty \"$liberty\" -script \"+strash; &get -n; &fraig -x; &put; scorr; dc2; dretime; strash; &get -n; &dch -f; &nf -a -F 16 -A 8 -R 1000; &put\"; clean; stat -liberty \"$liberty\"; check"

echo "Approximate isolated IHP area for $module:"
grep -E 'Number of cells:|Chip area for module|sequential elements' "$log" | tail -3
echo "Log: $log"
