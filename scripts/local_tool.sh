#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tool_root="$root/.tools/root"
tool=${1:?usage: local_tool.sh TOOL [ARGS...]}
shift

case "$tool" in
    iverilog)
        if [ -x "$tool_root/usr/bin/iverilog" ]; then
            exec "$tool_root/usr/bin/iverilog" \
                -B "$tool_root/usr/lib/x86_64-linux-gnu/ivl" "$@"
        fi
        exec iverilog "$@"
        ;;
    vvp)
        if [ -x "$tool_root/usr/bin/vvp" ]; then
            exec "$tool_root/usr/bin/vvp" \
                -M "$tool_root/usr/lib/x86_64-linux-gnu/ivl" "$@"
        fi
        exec vvp "$@"
        ;;
    yosys)
        if [ -x "$tool_root/usr/bin/yosys" ]; then
            export LD_LIBRARY_PATH="$tool_root/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            export YOSYS_DATDIR="$tool_root/usr/share/yosys"
            exec "$tool_root/usr/bin/yosys" "$@"
        fi
        exec yosys "$@"
        ;;
    verilator)
        if [ -x "$tool_root/usr/bin/verilator_bin" ]; then
            export PATH="$tool_root/usr/bin:$PATH"
            export VERILATOR_ROOT="$tool_root/usr/share/verilator"
            export CC="$tool_root/usr/bin/x86_64-linux-gnu-gcc-15"
            export CXX="$tool_root/usr/bin/x86_64-linux-gnu-g++-15"
            export LIBRARY_PATH="$tool_root/usr/lib/x86_64-linux-gnu:$tool_root/usr/lib/gcc/x86_64-linux-gnu/15${LIBRARY_PATH:+:$LIBRARY_PATH}"
            export MAKEFLAGS="${MAKEFLAGS:+$MAKEFLAGS }CC=$CC CXX=$CXX LINK=$CXX"
            exec "$tool_root/usr/bin/verilator" \
                -CFLAGS "-idirafter $tool_root/usr/include -idirafter $tool_root/usr/include/x86_64-linux-gnu" "$@"
        fi
        exec verilator "$@"
        ;;
    verilator_coverage)
        if [ -x "$tool_root/usr/bin/verilator_coverage" ]; then
            export VERILATOR_ROOT="$tool_root/usr/share/verilator"
            exec "$tool_root/usr/bin/verilator_coverage" "$@"
        fi
        exec verilator_coverage "$@"
        ;;
    *)
        echo "unsupported local tool: $tool" >&2
        exit 2
        ;;
esac
