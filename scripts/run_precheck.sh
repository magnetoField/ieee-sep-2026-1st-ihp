#!/usr/bin/env bash
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
runner=${LIBRELANE_RUNNER:-/var/tmp/rumcajs-appimage/appimage_extracted_7ee003e414b503dafc1ee3684d415174/AppRun}
precheck_pdk=${PRECHECK_PDK_ROOT:-$root/.tools/ciel-precheck/ciel/ihp-sg13g2/versions/c4b8b4e5e7a05f375cca3815d51b3a37721fbf5c}
precheck_python=${PRECHECK_PYTHON:-$root/.tools/precheck-py312/bin/python}
gds=${1:-$root/artifacts/verified_single_key/tt_um_rumcajs.gds}
test -f "$precheck_pdk/ihp-sg13g2/libs.tech/klayout/tech/drc/ihp-sg13g2.drc"
test -f "$gds"
test -x "$runner"
test -x "$precheck_python"
exec "$runner" bash -c '
    export PATH="$(dirname "$1"):$PATH"
    export PDK_ROOT="$2" PDK=ihp-sg13g2
    cd "$3"
    exec "$1" precheck.py --tech ihp-sg13g2 --gds "$4"
' _ "$precheck_python" "$precheck_pdk" "$root/tt/precheck" "$gds"
