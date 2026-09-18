# Target P0 — revised for TTIHP26b

Current result: local1x1 P&R plus all10 official prechecks PASS. The precheck
action pins CIEL c4b8b4e5, distinct from raw e16d00b7 used for hardening.
Both identities and executed scopes are recorded in FULL_VERIFICATION.md.
Older physical-failure descriptions below are superseded by FINAL.md.

- Status: approved target supplied by the user on 2026-09-12: Tiny Tapeout
  IHP 26b (`TTIHP26b`).
- Template: `https://github.com/TinyTapeout/ttihp-verilog-template`
- Template commit inspected: `6598bef4d3159f19fe471a2a2225df52e6f5ad25`
  (commit message `chore: update tags for TTIHP26b`).
- GDS action: `TinyTapeout/tt-gds-action@ttihp26b`; annotated tag resolves
  to commit `85a4c4128c10aa024ea8a02c7b3828d11c14ed90` and declares
  LibreLane 3.0.5.
- PDK: `ihp-sg13g2` (IHP SG13G2), not SKY130A.
- Current shuttle repository observed at commit
  `10425d0de9a117da1aaa9221fc1f6df4d1f10535`; its pinned PDK submodule is
  IHP-Open-PDK commit `e16d00b7b26a93956563c373b782f54dd4d77a7f` and its
  pinned LibreLane submodule is
  `e91e3b4b0d2a6a310226f89f5780fd2b81ba569f`.
- Standard-cell library/corner used for preliminary mapping:
  `sg13g2_stdcell_typ_1p20V_25C.lib` from that exact PDK commit.
- Support tools commit: `01d5d2814fa9dd61e9d211e0b235a4a592a9316a`.
- Authoritative IHP 1x1 DIEAREA from the support tools:
  `0 0 202.08 154.98` micrometres. The standard-cell row rectangle spans
  approximately 196.32 x 147.42 um, or 28941.4944 um2, before placement
  blockages and routing needs.
- Tile configuration: `1x1`; official default `PL_TARGET_DENSITY_PCT=60`.
  The checked-in config requests `AREA 3`; measured experiments also use
  `AREA 0` and density 80% because LibreLane 3.0.5's special `AREA 3` script
  does not consume the `SYNTH_ABC_AREA_USE_NF` branch.
- Clock: `1_000_000 Hz`; `CLOCK_PERIOD=1000 ns`.
- Active MVP parameters: SIMON64/128, 44 rounds, PIN_LEN=4, PIN=1234,
  MAX_FAILS=3, SCAN_HZ=4000, PRESS_FRAMES=20, RELEASE_FRAMES=20,
  AUTH_TIMEOUT_MS=5000, passive buzzer tone 2 kHz, BEEP_TICKS_MS=50.

The earlier SKY130 work remains useful as an architecture comparison only. It
is not fit evidence for TTIHP26b. The complete exact PDK and official
LibreLane 3.0.5 environment are installed; measured IHP physical-flow results
and the terminal 1x1 legalization failure are in `reports/PHYSICAL.md`.
