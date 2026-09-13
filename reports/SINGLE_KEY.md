# Single-key implementation and verification — 2026-09-12

Superseded status: the user reopened full verification. All required local
checks now pass, including exhaustive keypad, coverage and all10 prechecks.
Current evidence: FULL_VERIFICATION.md and FINAL.md. The blocker discussion
below is historical; SDF limitations remain explicitly qualified in FINAL.md.

Current contract: docs/SINGLE_KEY.md. No git commit exists (unborn main);
all work is local. No submission or remote CI was performed.

## Requirement evidence

| Requirement | Implementation / evidence |
|---|---|
| Exactly one key | rumcajs.KEY -> szymon_fixed.KEY; no GOOD/BAD constants or key-selection ports in src; parameterized round-key table tested for seven keys |
| READY only after correct complete PIN | regs txn_valid<=pin_matches; auth req=WAIT_RX&&!rx_active; wrapper uo0 mapping; directed and randomized pin-level tests |
| One external readiness output | uo1 tied low; uo2 retains serial ciphertext; wrapper checks reserved output throughout protocol |
| Wrong PIN never opens challenge | 127 rejected random trials including unauthorized frames; wrong attempts increment and third locks without a terminal response |
| One challenge per PIN | auth token checks, replay/fault integration, full 64-bit framing |
| Full cipher within 10 ms | independent KAT and consumed round-key-bit checks; 44 rounds, 9344 cycles; host waits 10000 clocks at 1 MHz |
| Approved 64-cycle wipe | reset with nonzero data and pending command; LOAD abort and 28 crypt phase/depth aborts per key; zero data and safe outputs at completion |

## Commands and measured results

All logs below are under reports/logs. Tool versions: reports/TOOLCHAIN.md.

| Command | Result | Log |
|---|---|---|
| make lint | PASS | single-key-lint.log |
| make test-model | PASS, 13 tests | single-key-model.log |
| make test-unit | PASS, every default module; 1024 runtime-key vectors and seven fixed-key configurations | single-key-unit.log |
| make test-integration | PASS, directed/default wrapper/faults/256 trials | single-key-integration.log |
| make test-params | PASS, valid configurations and invalid elaborations | single-key-params.log |
| make test-mutations | PASS, 7/7 mutations killed | single-key-mutations.log |
| make formal | PASS: combinational SAT, safety induction, control BMC20 / wrapper BMC2, scaled timeout BMC12 | single-key-formal.log |
| make test-gatelevel | PASS, synthesis netlist without SDF | single-key-gatelevel.log |
| scripts/test_gatelevel_ihp.sh with IHP_NETLIST pointing to final/nl/tt_um_rumcajs.nl.v and IHP_GL_LOG pointing to the report | PASS, post-route netlist without SDF | single-key-postroute-gl.log |
| make area-module MODULE=szymon_fixed | 8871.8868 µm² / 521 cells | synth-ihp-szymon_fixed.log |
| make synth-ihp | 19857.8520 µm² | synth-ihp.log |

The 65536-mask exhaustive keypad and instrumented coverage reports belong to
an earlier revision; they were not rerun here. Focused keypad tests did rerun.
No unbounded end-to-end proof, analog CDC proof or physical security is claimed.
The test-model constructor and three peripheral benches were migrated to the
new interfaces; initial failures were stale two-key expectations. Buzzer event
comparison now samples at the consuming edge, while comparing registered
outputs after the edge. No RTL was changed to satisfy those stale expectations.

## Physical run

From repository root, the command actually used was:

```sh
mkdir runs/single_key_wipe_p80_h0
/var/tmp/rumcajs-appimage/appimage_extracted_7ee003e414b503dafc1ee3684d415174/AppRun python -m librelane --manual-pdk --pdk-root /mnt/c/Users/user/Desktop/HACKATHON/.tools/IHP-Open-PDK-partial --pdk ihp-sg13g2 --force-run-dir runs/single_key_wipe_p80_h0 --condensed -j 4 -c 'SYNTH_STRATEGY=AREA 0' -c 'PL_TARGET_DENSITY_PCT=80' -c 'PL_RESIZER_HOLD_SLACK_MARGIN=0' src/config_merged.json
```

Use a fresh run directory when reproducing; retain the existing evidence.
Log: single-key-physical.log. Exit 0. Metrics and report:

- runs/single_key_wipe_p80_h0/final/metrics.json
- runs/single_key_wipe_p80_h0/72-misc-reportmanufacturability/manufacturability.rpt
- runs/single_key_wipe_p80_h0/55-openroad-stapostpnr
- runs/single_key_wipe_p80_h0/66-netgen-lvs

Official synthesis 20944.7154 µm²; routed standard-cell area 25996.7 µm²,
89.8251% utilization excluding fillers. Routing/Magic DRC/LVS/antenna pass.
All three timing corners pass setup/hold under the generated generic SDC.
Worst hold slack is only +0.0079368 ns. No extra hold safety margin is claimed.
Checked-in config now matches successful AREA 0 / density80 / hold-margin0.

## Remaining precheck environment blocker

Pinned tt/precheck ran unchanged with its pinned Python dependencies in a
local Python3.12 environment; AppImage supplied CLI tools. Nine checks passed,
SG13G2 DRC failed to open ihp-sg13g2.drc. See single-key-precheck.log and
reports/single-key-precheck.xml. Direct sg13g2_maximal.lydrc execution then
failed with KLayout0.30.7's with_angle argument-count error; see
single-key-klayout-maximal.log. Neither report establishes KLayout DRC PASS.

Further read-only inspection of tt-gds-action tag ttihp26b shows its precheck
installs CIEL PDK c4b8b4e5e7a05f375cca3815d51b3a37721fbf5c and a separate Nix
tool environment. That differs from the raw e16d00b7 PDK used for this local
run. Reproduce that official precheck environment; do not alias filenames,
edit rules or waive checks. The CI gate-level action additionally expects
test/Makefile and results.xml, which this repository does not yet provide.
Local functional gate simulation is not evidence that this remote job works.

User requested stopping if production checks cannot be completed. Current
candidate files are retained in artifacts/single_key, explicitly not approved.
No additional RTL tuning is justified by these environment failures.
