#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tt_tool="$root/tt/tt_tool.py"

if [ ! -f "$tt_tool" ]; then
    echo "BLOCKED: pinned tt-support-tools must be cloned at $root/tt" >&2
    echo "Required commit: 01d5d2814fa9dd61e9d211e0b235a4a592a9316a" >&2
    exit 2
fi

if [ -z "${PDK_ROOT:-}" ] || [ ! -d "$PDK_ROOT/ihp-sg13g2" ]; then
    echo "BLOCKED: set PDK_ROOT to the complete pinned IHP26b PDK root" >&2
    echo "Required IHP-Open-PDK commit: e16d00b7b26a93956563c373b782f54dd4d77a7f" >&2
    exit 2
fi

no_docker=
if [ "${TT_HARDEN_NO_DOCKER:-0}" = 1 ]; then
    if ! python3 -c 'import librelane' >/dev/null 2>&1; then
        echo "BLOCKED: TT_HARDEN_NO_DOCKER=1 requires local LibreLane 3.0.5" >&2
        exit 2
    fi
    no_docker=--no-docker
else
    if ! command -v docker >/dev/null 2>&1; then
        echo "BLOCKED: Docker is required, or use a local LibreLane 3.0.5 with TT_HARDEN_NO_DOCKER=1" >&2
        exit 2
    fi
fi

python3 "$tt_tool" --ihp --project-dir "$root" --create-user-config
python3 "$tt_tool" --ihp --project-dir "$root" $no_docker --harden
python3 "$tt_tool" --ihp --project-dir "$root" --print-warnings
