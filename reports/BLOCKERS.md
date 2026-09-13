# Blockers and limitations

## Full verification update — current

B-008 RESOLVED: correct official CIEL c4b8b4e5 precheck PDK; all10 checks pass.
B-009 RESOLVED LOCALLY: test/Makefile and real results.xml implemented;
official GATES=yes make contract passes with the unpowered IHP netlist.
No remote CI execution is claimed. Existing local physical fit also passes.

Remaining limitations: author identity needed for submission, public demo key,
volatile lockout, no board measurements. Full SDF annotation is UNSUPPORTED
by Icarus13 (extra experiment, not required gate); STA covers all3 corners.
15 non-gating CTS fanout warnings and narrow hold margin remain disclosed.
FINAL.md and FULL_VERIFICATION.md supersede earlier blocker statuses below.

## Current single-key revision (supersedes B-005 below)

Local 1x1 P&R now PASSES: run single_key_wipe_p80_h0, exit0, routed cell
utilization 89.8251%, STA/Magic DRC/LVS/antenna pass. Old two-key fit failures
below are historical. No additional area reduction is currently required
to complete local placement and routing.

B-008: TT precheck environment mismatch. Missing ihp-sg13g2.drc in raw
e16d00b7 PDK; unchanged maximal.lydrc also fails with AppImage KLayout0.30.7
API mismatch. Official ttihp26b precheck installs CIEL c4b8b4e5 and a separate
Nix environment. Nine other prechecks pass. No rule waivers or edits made.
B-009: Official remote GL job requires test/Makefile/results.xml; not yet
provided. Local post-route no-SDF simulation passes but does not prove CI.
Submission author remains empty; fallback SDC needs shuttle-specific review.
See SINGLE_KEY.md and FINAL.md. Candidate files are NOT production approved.

## Historical two-key blockers

Newest B-005 evidence: Z3-optimized run `runs/szymon_z_p80_h0`.
Synthesis 22523.0544 um2, after CTS 24244.01 um2; 235 hold buffers cause
DPL-0036 with 9 unlegalized instances. This improves the prior count of
27 but remains a measured 1x1 fit failure. No final GDS/signoff results.

Latest B-005 evidence: optimized sparse-key variant, run
`runs/szymon_sparse_p80_h0`, failed DPL-0036 after 227 hold buffers;
27 instances could not be legalized, exit code 2. Synthesized area
22913.0748 um2, after-CTS area 24706.68 um2. No production output.
Per the user's stop condition, work is stopped pending renewed direction;
tools/PDK are available and are not the blocker. Older metrics below are
historical baselines. Broader full regression of the new RTL was not rerun;
targeted evidence is in `SZYMON_OPTIMIZATION_RESULTS.md`.

| ID | Scope | Status | Evidence / consequence |
|---|---|---|---|
| B-001 | Approved shuttle | RESOLVED | User selected TTIHP26b; package and measurements use `ihp-sg13g2`. |
| B-002 | RTL simulation | RESOLVED | Icarus and Verilator unit/integration/exhaustive regressions pass. |
| B-003 | Formal | RESOLVED WITH QUALIFICATIONS | Exhaustive SAT and induction cover the datapath/safety properties; control and liveness items explicitly marked BMC remain bounded. |
| B-004 | Target synthesis | RESOLVED | Fast IHP map: 22708.0098 um2. Complete LibreLane `AREA 0`: 23683.5522 um2 / 1679 cells. |
| B-005 | IHP 1x1 physical fit | FAIL | Default 60% placement reaches 107.365% effective utilization. The 80% run reaches CTS but post-CTS hold-buffer legalization fails even at zero extra hold margin. No production GDS/DRC/LVS/antenna result exists. |
| B-006 | Production persistence | ACCEPTED SCOPE LIMIT | Demo lockout is volatile; protected NVM/provisioning are not implemented. |
| B-007 | Submission metadata | OPEN | `info.yaml` author is empty; no identity is invented. |
| B-008 | Gate-level timing | PARTIAL | Functional IHP synthesis-netlist smoke passes without SDF. No routed netlist or post-route SDF exists because B-005 fails. |

The complete physical environment is now installed, so missing tooling is no
longer the blocker. The measured blocker is cell density/legalization. The
largest optimization target is `szymon_fixed`.

## User wiki validation (2026-09-13)

No blocker to delivering the static HTML documentation. Structural parsing,
fragment links and the local layout asset pass. Pixel-level browser regression
is NOT_RUN because no browser executable is installed in PATH; manual viewing
in the deployment browser remains a presentation check, not an ASIC signoff
requirement.

## MkDocs wiki rebuild (2026-09-13)

MkDocs build and local link/search-index checks PASS. Python system venv
creation lacked ensurepip; existing local uv provisioned a separate Python
3.12.14 environment instead. PyPI access and serving localhost required
normal sandbox approvals. Browser-rendering and interactive search UI checks
remain NOT_RUN (no browser executable in the Linux environment). This is a
presentation qualification, not a new blocker for the previously verified ASIC.

## D00RSH GitHub preparation (2026-09-13)

Submission author B-007 is resolved by user: Koło Naukowe BAZA — ZT PN MK JT KK.
Project name is D00RSH. Official metadata parser PASS. Local preparation and
extracted-source tests PASS. Public repository opelkus/D00RSH and local source
commit 60e40e9e213899b3100321591388d3e2c844380e exist; first push and actual
remote CI remain. Remote CI is NOT_RUN, not PASS. Shuttle availability must be
confirmed in Tiny Tapeout before submission. See GITHUB_UPLOAD.md.
