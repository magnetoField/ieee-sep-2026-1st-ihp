# Blockers and limitations

## Full verification update — current

The final IEEE DOORSH configuration is locally complete: fixed passive buzzer,
key `BA2A1918131211100B0A090803020100`, 1×1 P&R, Tiny Tapeout precheck and
post-route gate-level test all PASS. Author metadata is present.

Remaining limitations are scope qualifications, not upload blockers: public
demo key/PIN, volatile lockout, no post-fabrication silicon measurement and
unsupported full SDF annotation in the available simulator. STA covers all
three reported corners. The flow retains 15 non-gating max-fanout warnings;
max capacitance, slew and timing violations are zero. Remote CI for the new
revision remains NOT_RUN until the revision is pushed. No Tiny Tapeout
submission, order or payment has been performed.

`FINAL.md` supersedes earlier current-status wording below; older sections are
retained as historical evidence.

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
extracted-source tests PASS. The user redirected publication to public target
magnetoField/ieee-sep-2026-1st-ihp; WRITE permission is confirmed. Its existing
main history through dde98d17fe0eef79c5d05db6fbf471b7aeebed0e is integrated
without force-push. Commit 591f96d was pushed. Its docs and wiki jobs PASS; RTL
FAIL is localized to missing executable Git mode on shell scripts, not an RTL
failure. Commit bc292cd fixes the modes; its next RTL run found Icarus 13
forward-reference elaboration errors in kb.v. Declaration order is corrected and
the complete local regression PASS. Commit ff4b316 carries that correction; its
remote lint reaches Verilator 5.053, which promotes the intentional
asynchronous-assert/synchronous-release reset warning to an error. A narrow
`-Wno-SYNCASYNCNET` waiver is prepared; all other `-Wall` checks remain enabled
and a fresh remote run is required. For
591f96d the official gds, precheck and gl_test jobs PASS; viewer alone FAIL because
Pages is disabled. The authenticated account has WRITE rather than ADMIN, and
both Pages GET and create API calls return 404. A repository admin must enable
Settings -> Pages -> GitHub Actions. Shuttle availability must also be confirmed
before submission. See GITHUB_UPLOAD.md.

## GitHub Pages viewer rerun status (2026-09-13)

The earlier Pages-disabled condition is resolved: workflow-dispatch run
34764740699 successfully completed `viewer`. The remaining branch summary 6/7
comes from push run 34762738865 attempt 2, where `deploy-pages@v5` found two
artifacts named `github-pages` retained across attempts. A local workflow fix
uses an artifact name unique to `github.run_id` and `github.run_attempt` and is
covered by the upload-structure validator. Remote verification remains NOT_RUN
until an explicitly authorized push; do not mark the historical check PASS.
