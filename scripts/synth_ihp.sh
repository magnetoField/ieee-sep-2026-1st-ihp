#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
relative=ihp-sg13g2/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib

if [ -n "${IHP_LIBERTY:-}" ]; then
    liberty=$IHP_LIBERTY
elif [ -n "${PDK_ROOT:-}" ] && [ -f "$PDK_ROOT/$relative" ]; then
    liberty=$PDK_ROOT/$relative
else
    liberty=$root/.tools/IHP-Open-PDK-partial/$relative
fi

if [ ! -f "$liberty" ]; then
    echo "BLOCKED: IHP SG13G2 Liberty file not found: $liberty" >&2
    echo "Set IHP_LIBERTY or PDK_ROOT to the pinned IHP26b PDK." >&2
    exit 2
fi

case "$liberty" in
    *\"*|*\;*)
        echo "ERROR: unsupported quote or semicolon in IHP Liberty path" >&2
        exit 2
        ;;
esac

mkdir -p "$root/.build" "$root/reports/logs"

"$root/scripts/local_tool.sh" yosys -q \
    -l "$root/reports/logs/synth-ihp.log" \
    -p "read_liberty -lib -ignore_miss_func \"$liberty\"; \
        read_verilog $root/src/*.v; \
        hierarchy -check -top tt_um_rumcajs; \
        synth -top tt_um_rumcajs -flatten -noabc; \
        dfflibmap -liberty \"$liberty\"; \
        abc -liberty \"$liberty\" \
            -script \"+strash; &get -n; &fraig -x; &put; scorr; dc2; \
                dretime; strash; &get -n; &dch -f; \
                &nf -a -F 16 -A 8 -R 1000; &put\"; \
        clean; \
        stat -liberty \"$liberty\"; \
        check; \
        write_verilog -noattr \"$root/.build/tt_um_rumcajs.ihp.v\""
