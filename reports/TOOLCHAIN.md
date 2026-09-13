# Toolchain inventory

Full-verification additions: Icarus13.0 from TinyTapeout/iverilog v13.0 for
unmodified-model gate smoke; managed Python3.12.14 with pinned tt/precheck
requirements; official CIEL precheck PDK c4b8b4e5 (779MB). CLI KLayout0.30.7
from the existing AppImage successfully ran that package's original DRC deck.
KLayout Python bindings are0.30.8. A downloaded0.30.8 CLI was not executed.
No rules modified. Full SDF annotation remains unsupported by Icarus13;
setup/hold evidence comes from OpenSTA. See FULL_VERIFICATION.md.

Observed/installed locally on 2026-09-12 in WSL2:

| Tool | Version / source |
|---|---|
| Python | system 3.14.4; LibreLane environment 3.13.9 |
| Icarus Verilog | 12.0, local `.tools/root` |
| Verilator | 5.032 local; AppImage flow uses 5.044 |
| Yosys | 0.52 local; AppImage flow uses 0.62 |
| LibreLane | official 3.0.5 x86_64 AppImage, verified SHA-256 `d6a349ec...` |
| OpenROAD | AppImage build `dcf36133...` |
| KLayout | 0.30.7 in AppImage |
| Magic | 8.3.623 in AppImage |
| Netgen | 1.5.316 in AppImage |
| IHP PDK | complete IHP-Open-PDK commit `e16d00b7b26a93956563c373b782f54dd4d77a7f` |
| tt-support-tools | commit `01d5d2814fa9dd61e9d211e0b235a4a592a9316a` |
| Docker | absent; LibreLane runs locally through AppImage |

The official AppImage is stored under `.tools/librelane-3.0.5`; its extracted
runtime is under `/var/tmp/rumcajs-appimage`. Together with the complete PDK,
support tools and small Python environment, the installation is about 8.3 GB,
well below the user-approved 50 GB ceiling.

The AppImage's built-in SKY130 smoke test was not used as target evidence: its
automatic PDK download timed out. Direct version probes pass, and real
IHP-specific synthesis/floorplan/placement/CTS steps executed successfully up
to the measured legalization failure. LibreLane was given the exact raw PDK
through `--manual-pdk`.
