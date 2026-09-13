# IHP26b physical-flow result

Full verification update: all10 TT prechecks now PASS with the official
precheck PDK package; no layout/rule edits. Routed GDS is unchanged.
Current report: FINAL.md. The precheck blocker mentioned below is historical.

Current single-key run supersedes the historical fit failures below:
`runs/single_key_wipe_p80_h0` completed with exit0. Routed cell area
25996.7 µm², utilization 89.8251%; STA, Magic DRC, LVS and antenna pass.
TT precheck remains blocked by its KLayout/PDK environment, not by placement.
Current qualifications and artifact paths: [FINAL.md](FINAL.md),
[SINGLE_KEY.md](SINGLE_KEY.md). Older metrics below remain historical.

Date: 2026-09-12. Terminal result: **no production-ready 1x1 output**.

## Latest Z3-optimized P&R — terminal FAIL

The user authorized a new P&R check of RTL SHA-256
`b1458d9a66f202704693c1882a0acaeee4573bcfd996734c2b9f33100d61b229`.
Run `runs/szymon_z_p80_h0` used the same pinned LibreLane 3.0.5/IHP
environment, AREA 0, density 80%, and zero extra post-CTS hold margin.

- Complete LibreLane synthesis: **22523.0544 um2**.
- Global-placement original/final area: **25538.28 um2**.
- After CTS: **24244.01 um2**, 1747 cells, including 213 sequential cells,
  155 pre-CTS timing-repair buffers and 30 clock buffers/inverters.
- Setup: no violations at the post-CTS repair entry.
- Hold: 180 violating endpoints initially; repair inserted **235 buffers**
  (+15.8% area) and reached reported WNS/TNS 0.
- The repaired design could not be legalized: **9 instances** failed
  detailed placement, DPL-0036. LibreLane exited with code 2.

This is closer than the previous sparse-key run (22913.0748 um2 synthesis,
24706.68 um2 after CTS, 27 unlegalized instances), but still does not fit.
Routing, post-route STA, antenna, DRC and LVS were not reached. No final GDS
or production package exists. The run is terminal; no density/constraint
waiver is treated as a substitute for physical acceptance.

Evidence: `reports/logs/szymon-z-physical.log`,
`runs/szymon_z_p80_h0/06-yosys-synthesis/`,
`runs/szymon_z_p80_h0/35-openroad-cts/openroad-cts.log`, and
`runs/szymon_z_p80_h0/37-openroad-resizertimingpostcts/openroad-resizertimingpostcts.log`.
Resolved configuration: `runs/szymon_z_p80_h0/resolved.json`.

## Latest optimized Szymon attempt — terminal FAIL

`runs/szymon_sparse_p80_h0` uses RTL SHA-256
`309d8fc5f7316ee6fd847dfd9289c5021765769ecfe01359d823e91b5196934e`.
Same pinned environment as below; `AREA 0`, density 80%, post-CTS extra
hold margin 0 ns. Complete synthesis: **22913.0748 um2** (previous
23683.5522). After CTS: **24706.68 um2**, 1780 cells, 213 sequential cells.
Post-CTS repair inserted **227 hold buffers**; detailed placement failed
on **27 instances**, error DPL-0036, process exit code 2.

Routing and final STA/DRC/LVS/antenna checks were not reached. No production
GDS was produced. Per the user's stop-on-production-failure instruction,
no further physical retries or RTL optimization are launched after this run.
Continuing optimization would require renewed user direction.

Command (AppRun from the pinned LibreLane 3.0.5 extraction):

```sh
AppRun python -m librelane --manual-pdk \
  --pdk-root /mnt/c/Users/user/Desktop/HACKATHON/.tools/IHP-Open-PDK-partial \
  --pdk ihp-sg13g2 --force-run-dir runs/szymon_sparse_p80_h0 \
  --condensed -j 4 -c 'SYNTH_STRATEGY=AREA 0' \
  -c 'PL_TARGET_DENSITY_PCT=80' -c 'PL_RESIZER_HOLD_SLACK_MARGIN=0' \
  src/config_merged.json
```

Evidence: `reports/logs/szymon-sparse-physical.log`,
`runs/szymon_sparse_p80_h0/06-yosys-synthesis/`,
`runs/szymon_sparse_p80_h0/35-openroad-cts/openroad-cts.log`, and
`runs/szymon_sparse_p80_h0/37-openroad-resizertimingpostcts/openroad-resizertimingpostcts.log`.
Run settings are preserved in `runs/szymon_sparse_p80_h0/resolved.json`.

## Reproducible environment

The official LibreLane 3.0.5 x86_64 AppImage was downloaded and verified with
SHA-256 `d6a349ec65be11456e96c4981d35f63ca34d3c85daf79a51e1ccb907bb5d7466`.
It provides OpenROAD `dcf36133...`, Yosys 0.62, KLayout 0.30.7, Magic
8.3.623 and Netgen 1.5.316. The complete IHP-Open-PDK checkout is pinned at
`e16d00b7b26a93956563c373b782f54dd4d77a7f`; tt-support-tools is pinned at
`01d5d2814fa9dd61e9d211e0b235a4a592a9316a`. The installed and extracted
environment uses about 8.3 GB, below the user-approved 50 GB limit.

LibreLane was invoked with `--manual-pdk`, because the exact raw shuttle PDK
checkout is supplied directly. Automatic CIEL package downloads timed out and
were not used for the measurements below.

## Measured runs

| Run | Key settings | Last successful point | Measured result | Outcome |
|---|---|---|---|---|
| `runs/wokwi` | official `AREA 3`, density 60% | floorplan/PDN/DEF template | synthesis 26880.7518 um2; placement saw 26883.965 um2 actual and 31073.079 um2 after pin-density inflation | global placement stopped at 107.365% effective utilization |
| `runs/area0` | `AREA 0`, synthesis only | Yosys synthesis | 1679 cells, 23683.5522 um2 | best complete LibreLane synthesis tried |
| `runs/area0_p80` | `AREA 0`, density 80%, hold margin 0.1 ns | CTS and mid-PnR STA | 23687 um2 / 81.8444% after floorplan; 25298.2 um2 / 87.4114% after 222 repair buffers; 25871.5 um2 / 89.3925% after CTS | 339 hold buffers could not be legalized |
| `runs/area0_p80_h0` | continuation with hold margin 0 ns | post-CTS hold repair | 234 hold buffers requested; 56 instances remained unlegalized | detailed placement failed |

The mid-PnR timing report had very large setup margin at the 1 MHz clock. The
failure is area/legalization pressure, not insufficient encryption speed.
No detailed routing, post-route STA, production GDS, DRC, LVS or final antenna
PASS was reached. Partial run directories are evidence only.

A further experiment tried to inject the smaller locally mapped netlist
(`22708.0098 um2`) into the physical flow. LibreLane's fail-closed netlist
checker rejected its remaining alias `assign` statements before OpenROAD, so
it is not counted as a production result.

## Meaning of the 60% setting

`PL_TARGET_DENSITY_PCT=60` comes from the official Tiny Tapeout IHP project
configuration inherited by `src/config.json`. It is a placement target, not a
claim that only 60% of the die physically exists. The unused fraction reserves
space for clock-tree and repair buffers, tap/decap/filler cells, legalization
movement and routability. Raising the number is allowed as an experiment, but
does not create area; the 80% run demonstrated the consequence by reaching
about 89.4% real utilization after CTS and then failing hold-buffer
legalization.

## Fast area estimate

Use `make area-module MODULE=szymon_fixed` for an isolated target-library
estimate. It runs only synthesis and normally finishes in a few seconds. Use
`make synth-ihp` for the full top. These numbers are useful for ranking RTL
changes, but only LibreLane placement/routing can establish tile fit.
