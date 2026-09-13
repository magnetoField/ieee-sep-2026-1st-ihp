# Progress log

## Z3-optimized physical run — 2026-09-12

User authorized P&R. Ran pinned LibreLane 3.0.5/IHP26b 1x1, AREA 0,
density 80%, zero post-CTS hold margin in `runs/szymon_z_p80_h0`.
Synthesis 22523.0544 um2; CTS 24244.01 um2. Hold repair inserted 235
buffers and closed reported hold slack, but detailed placement failed on
9 instances (DPL-0036), exit 2. Routing/signoff not reached, no final GDS.
Exact evidence and comparison are in `reports/PHYSICAL.md`.

## Osiem pomysłów użytkownika — 2026-09-12

Nowa prośba użytkownika autoryzowała porównanie ośmiu konkretnych zmian.
Zmierzone osobno i na topie, z tym samym kontekstem źródeł/PDK/ABC;
szczegóły, komendy i logi w `reports/EIGHT_IDEAS.md`. Clock gate zatrzymany
na kontroli dopuszczalności (wykluczenia PDK). Serial wipe zmierzony i
przetestowany jako opcjonalny kontrakt 64 cykli, nie włączony do src.
Zachowano wyłącznie uproszczony Z3: 10713.4650 um2 rdzeń, 21668.4720 um2
top, 9344 cykle. Lint, sześć par kluczy, 256 sesji, safety induction i
gate smoke bez SDF PASS. Nowy P&R nie był uruchamiany; FIT niezaliczony.

## Resumed Szymon optimization — 2026-09-12

Terminal physical attempt: `runs/szymon_sparse_p80_h0`, pinned LibreLane
3.0.5/IHP, AREA 0/density 80/hold margin 0. Synthesis 22913.0748 um2,
CTS 24706.68 um2. Post-CTS inserted 227 hold buffers; DPL-0036 on 27
instances, exit 2. No routing/production output. Exact command and logs:
`reports/PHYSICAL.md`. Stopping further attempts per user instruction.
Additional four random key-pair parameter configurations (seed 0x53494D4F)
passed consumed-bit, latency, data-hold, abort and rearm tests; log
`reports/logs/szymon-sparse-keys.log`. RTL remains unchanged from the
verified sparse-key candidate.

New multilevel sparse-key candidate improves isolated area to 10922.0454
um2 and top to 21817.0638 um2, at a measured 9344-cycle crypt latency.
Unit tests now check consumed key bits, data hold and 28 abort positions.
Unit/default/alternate, lint and safety induction pass. Current architecture,
test configuration rationale, hashes and logs are in
`reports/SZYMON_OPTIMIZATION_RESULTS.md`. Physical fit remains unproven.

Follow-up: rejected registered one-hot rounds, three mapper-preprocessing
diagnostics and seven single-level sparse-key reconstruction variants.
No candidate beats the retained 11212.0848 um2. Restored RTL hash matches
the already-tested checkpoint exactly; quick area measurement reconfirmed.
Details and next architectural hypothesis are recorded in
`reports/SZYMON_OPTIMIZATION_RESULTS.md`. No physical run was started.

Retained MSB-first/shared-shift variant: isolated area 11658.2382 ->
11212.0848 um2; top 22708.0098 -> 22375.6722 um2. Same Yosys 0.52/IHP
mapping. Commands, tests, hashes and rejected trials are recorded in
`reports/SZYMON_OPTIMIZATION_RESULTS.md`. Unit/default/alternate KAT,
lint, integration (256 random sessions), F-11 SAT and fixed-core induction
pass. No physical fit claim; next step is a larger architectural reduction.

## P0 — environment and target discovery (2026-09-12)

Status: COMPLETE. The physical tool installation was completed later in P6.

- Verified original package: `sha256sum -c MANIFEST.sha256` — all entries OK.
- Initialized a new Git repository: `git init -b main`.
- Added official template remote: `git remote add template https://github.com/TinyTapeout/ttsky-verilog-template.git`.
- Inspected official template commit `60c39394fc4b67dd95e019ccd8849392eb00521d`.
- Inspected support tools commit `01d5d2814fa9dd61e9d211e0b235a4a592a9316a` and its `sky130A/tile_sizes.yaml` / `tt_block_1x1_pg.def`.
- Inspected `tt-gds-action@ttsky26c` commit `654423a5f8204bc7589457cce777c2d4619ebba8`; action declares LibreLane 3.0.14.
- Tool probe command covered Python, pytest, Icarus, Verilator, Yosys, SBY,
  Boolector, Z3, Docker, Git and Make; detailed state is in `TOOLCHAIN.md`.
- Manifest and discovery output were observed directly; no synthesis, P&R or RTL
  simulation was run.

The original next actions were completed in P1-P6.

Target revision on the same date: the user later selected TTIHP26b. Inspected
the official IHP template commit `6598bef4...`, action tag commit `85a4c412...`,
support tools and current shuttle repository. `TARGET.md`, `src/config.json` and
the GDS/docs workflows now select `ihp-sg13g2`; the initial SKY work is retained
only as a historical architecture benchmark.

## P1 — independent models and interfaces (2026-09-12)

Status: COMPLETE.

- `make test-model`: PASS, 13 tests in 0.941 s, Python 3.14.4.
- Published SIMON64/128 KAT: PASS; demo BAD response: `9350e3713d63ad28`.
- Independent full-word model exercised 1024 deterministic vectors with seed
  `0x52554d43`; the attached arithmetic spike independently compares all 44
  round states against the proposed bit-serial organization.
- Graph keypad model passed all 65,536 masks and manual rectangle ghost cases.
- Safe/protocol model passed exact SHIFT64 length/order, one-use challenge,
  repeat suppression, GOOD/BAD/reject/ambiguous outcomes and attempt accounting.
- Interfaces and reset/cancel priorities frozen in `reports/INTERFACES.md`.
- Command: `python3 tools/verify_arithmetic_plan.py` — PASS for the documented
  arithmetic experiment.
- Evidence: `test/model/`, `model/`, `reports/logs/P1_models.log`.

Next: complete SIM-01..SIM-15 coverage and formal arithmetic harnesses.

## P2 — bit-serial Szymon core (2026-09-12)

Status: COMPLETE.

- Implemented Verilog-2005 `src/szymon.v`: shared A/B 64-bit RX/round/TX state,
  128-bit on-the-fly key schedule, 44 x 32 cycles, seal, abort and bit-stream
  ready-valid channels.
- `make test-unit MODULE=szymon`: PASS, 4.68 s wall time.
- Evidence includes published KAT; 1024 reference-generated vectors with 388
  directed edge/walking-bit cases and 636 seeded-random cases (seed
  `0x52554d43`); exact 1408-cycle latency; gaps at every input bit; backpressure
  at every output bit including last; command isolation; consecutive blocks;
  and clearing.
- `tb_szymon_trace_abort` checks all 44 RTL round states and next round keys
  against the independent full-word KAT trace, plus abort/session reset during
  every round and LOAD/WAIT_SEAL/OUTPUT.
- Generic core synthesis command: `make synth-core`; Yosys 0.52 PASS/check 0 problems.
  Result: 209 DFF-class cells and 1969 generic cells; no memories. This is an
  early architecture measurement, not SKY area/timing or 1x1 fit evidence.
- Evidence: `test/unit/tb_szymon.sv`, `reports/logs/synth-szymon.log`,
  `reports/AREA.md`.

Formal F-11/F-12 also pass exhaustive SAT for arbitrary round/key inputs.

## P3 — peripherals and PIN state (2026-09-12)

Status: COMPLETE.

- Implemented `sync2`, `reset_release`, `timebase`, `regs`, `buzzer`, `kb`.
- Standalone benches PASS for each currently implemented peripheral.
- `make test-unit MODULE=kb_exhaustive`: PASS for all 65,536 physical masks on
  RTL; 105.97 s user, 1:46.14 wall, 15,872 KiB max RSS.
- Keyboard evidence also covers release-only emission, no autorepeat, poisoned
  ONE/MULTI/ONE gesture, ready-valid stability, pending event through disable,
  onehot0 rows and break-before-make.
- `regs` evidence covers mapping, ignored specials, star, atomic fail accounting,
  GOOD/BAD selection, retained fail count across success/session reset, and the
  valid terminal third BAD token.
- Evidence: `test/unit/tb_*.sv`, `reports/logs/P1_P3_results.log`.

Additional completed evidence: every key ID and PIN mismatch position; valid
PIN_LEN/MAX_FAILS matrix; invalid elaborations; BEEP=1 and passive half-periods
1/2/3; serial frame lengths 0/1/63/64/65/127/128; all 16 keys, all 120 pairs,
all rectangle ghost classes, exact debounce boundaries and pending/flush cases.

All peripheral rows are closed in `reports/TEST_MATRIX.csv`; measured coverage
is recorded separately in `reports/COVERAGE.md`.

## P4 — integration and wrapper (2026-09-12)

Status: COMPLETE for the functional E2E matrix.

- Directed full-top sessions cover GOOD KAT, BAD, accumulated failures
  0/1/1/2/3, valid terminal BAD response, LOCKED, cold demo reset and `ena` with
  a stopped clock.
- Fault sessions cover traffic without a PIN, chords, held digit/star, absolute
  timeout, 63-bit RX, a new frame during CRYPT, attempted token replay, and a
  torn terminal attempt that remains LOCKED.
- Reproducible random suite: 256 sessions, seed `0xe2e52517`, 129 GOOD, 127 BAD,
  50 vector-requested cold resets plus initial reset, and exactly 256 txn/cmd/
  seal/session_end events. All responses come from the independent Python model.
- Wrapper test uses default 1 MHz/debounce timing for full GOOD and BAD sessions,
  continuously toggles every unused input, and checks OE/constants/safe masking.
- Controlled mutations: 7/7 killed by specific RTL tests; no mutant is written
  to final RTL.

Evidence: `test/integration/`, `scripts/gen_session_vectors.py`,
`scripts/test_mutations.py`.

## P5 — formal safety (2026-09-12)

Status: COMPLETE WITH EXPLICIT BOUNDED QUALIFICATIONS.

- F-11 and F-12: exhaustive Yosys SAT proofs over arbitrary inputs, PASS.
- Regs F-01/F-02/F-03/F-06/F-10, kb F-06/F-08/F-09 and both cipher F-06
  invariants pass temporal induction. Auth/serial controls pass BMC depth 20
  and wrapper constants pass BMC depth 2 under arbitrary defined inputs.
- F-13: scaled `AUTH_TIMEOUT_MS=3`, periodic `ms_tick`, arbitrary handshake/error
  environment, BMC depth 12 proves an admitted session has ended by the bound.
- Formal analysis found and caused repair of an IDLE framing/error priority bug
  that could acknowledge but drop a simultaneous transaction.
- Reachability SAT reaches GOOD, terminal BAD, cmd, seal and successful cleanup.
- `make coverage`: all 12 cases PASS; Verilator reports 1417/1729 aggregate
  points (81%) and 884/993 unique RTL source lines (89.0%).
- `reports/TEST_MATRIX.csv` contains exactly all 119 IDs from TEST_PLAN. Each
  formal row states whether its evidence is exhaustive SAT, induction or BMC.

No unbounded liveness, analog CDC or physical-security proof is claimed.

## P6 — area optimization and 1x1 physical target (2026-09-12)

Status: PHYSICAL 1x1 FIT FAILED.

- SKY variants A/B/C first established that the fixed-key core and shared ROM
  composition reduce the same architecture benchmark by 21.92%. Those figures
  are retained only as architecture history after the target change.
- The keypad now shares its mutually exclusive press/release counter and drives
  rows combinationally during non-blank cycles. Full keypad regression, all
  65536 masks, formal induction and E2E integration pass after the change.
- Area-first local mapping reaches 22708.0098 um2, 1588 Yosys cells and 207
  sequential cells. The dominant isolated block is `szymon_fixed` at about
  11.55k um2, followed by `kb` and `serial_link`.
- Installed and verified the official LibreLane 3.0.5 AppImage, full exact IHP
  PDK and pinned support tools (about 8.3 GB total).
- Default LibreLane `AREA 3` / density 60% stops at global placement with
  107.365% effective utilization.
- LibreLane `AREA 0` reduces synthesis to 23683.5522 um2. A density-80% run
  passes initial/detailed placement and CTS, reaching 25871.5 um2 / 89.3925%
  after repair and CTS, but 339 post-CTS hold buffers cannot be legalized.
- Reducing the hold margin from 0.1 ns to zero still needs 234 buffers and
  leaves 56 instances unlegalized. No routed GDS/DRC/LVS result is generated.
- Added `make area-module MODULE=<name>` as a few-second isolated area estimator
  for the next focused optimization pass.

Evidence: `reports/AREA.md`, `reports/PHYSICAL.md`, LibreLane run directories
under `runs/`, and synthesis logs under `reports/logs/`.

## P7 — Tiny Tapeout package and gate-level (2026-09-12)

Status: PACKAGE COMPLETE; SYNTHESIS-NETLIST GATE SMOKE PASS WITHOUT SDF.

- Added the official-template-derived `info.yaml`, `src/config.json`, docs and
  pinned GDS/docs/test workflows.
- `make lint`, complete RTL regression and synthesis run locally.
- `make test-gatelevel`: PASS on the actual IHP-mapped synthesis netlist for
  reset/ena, malformed RX, GOOD, three BAD responses, lockout and pin safety.
  It uses no SDF and is not a replacement for the physical-flow GL job.
- The pinned support tools, complete PDK and LibreLane 3.0.5 were provisioned.
- Physical experiments reached CTS but failed legalization before routing;
  partial runs are retained as evidence and are not reported as production PASS.
- Shuttle and submitter identity remain unknown; no push/submission was made.

## P8 — final audit (2026-09-12)

Status: NOT PRODUCTION READY — P6 measured 1x1 legalization failure.

The code/docs/security review and functional matrix are complete. `FINAL.md`
records the measured terminal failure. FIT is FAIL and downstream physical
checks were not reached; the synthesis-netlist gate smoke is qualified PASS
without SDF. The project is
not declared release-complete.

## Approved serial wipe — targeted verification (2026-09-12)

Confirmed existing ST_WIPE implementation against explicit user approval.
Extended the fixed-core test with reset during a nonzero load, a pending
command throughout wipe, and checking m_bit=0 during erasure. Existing
checks cover abort during load and all 28 reconstruction phase/depth pairs,
64-cycle completion, zero data and successful rearm.

- Command: `make test-unit MODULE=szymon_fixed > reports/logs/serial-wipe-approved.log 2>&1`
- Tool: Icarus Verilog 12.0 (stable), via scripts/local_tool.sh.
- Result: PASS, exit 0, all seven key configurations.
- Log: `reports/logs/serial-wipe-approved.log`.
- Scope: targeted RTL verification only; no new P&R or production-file claim.
- Next physical milestone remains a successful full flow for current RTL.

## Single-key goal — implementation and successful local P&R (2026-09-12)

Previous goal turn: progress (reset/wipe test extended and executed).
This turn migrated remaining unit/model callers, corrected pin/protocol
documentation, reran all default unit and integration tests, formal,
parameters and mutations. All passed; exact commands/logs in SINGLE_KEY.md.
No functional RTL changed during the physical run.

P&R command in SINGLE_KEY.md completed with exit0. Synthesis20944.7154 µm²;
routed stdcell25996.7 µm² / 89.8251%, STA/Magic DRC/LVS/antenna PASS.
Post-route gate simulation PASS without SDF, log single-key-postroute-gl.log.
Copied exact final GDS/LEF/powered netlist into artifacts/single_key.

Pinned precheck dependencies installed locally (Python3.12, KLayout Python
0.30.8, CLI from AppImage0.30.7); about 300 MB added plus managed Python/cache,
remaining comfortably below the approved50GB environment limit.
Unmodified TT precheck: 9 checks PASS, SG13G2 DRC FAIL_ENVIRONMENT due to
missing ihp-sg13g2.drc. Direct original maximal.lydrc: tool API error.
Read-only inspection identified official ttihp26b precheck CIEL c4b8b4e5
and separate Nix environment, different from raw-PDK local invocation.
No production-pass claim, remote jobs, push or submission. Per requested
stop-on-production-check-failure, retained evidence and report; no speculative
RTL changes. Remaining steps require compatible official precheck environment,
remote-GL Makefile integration and signoff review, not another area sweep.

## Full verification resumed at user request — 2026-09-12

- Read current source/requirements; no RTL changes made. Archived failures
  remain visible but are superseded by full-precheck.xml and FINAL.md.
- Full make regression through synthesis: exit0; full-verification-regression.log.
  Includes all65536 keypad masks, full units/integration, parameters, SAT/
  induction/BMC and7/7 killed mutations. make coverage: exit0,12 cases,
  876/986 RTL lines and1463/1764 aggregate tool points.
- CIEL c4b8b4e5 fetch: exit0; correct original ihp-sg13g2.drc fixes precheck
  environment. make precheck on delivered verified_single_key bundle: exit0,
  all10 applicable checks PASS. No rule changes/waivers.
- Local TT gate entry now emits real JUnit and fails closed. Final GATES=yes
  make uses Icarus13, unmodified original cell models and IHP unpowered
  post-route netlist: exit0; XML matches official action's no-failure check.
- Extra SDF experiments: all3 exit1 due unsupported interconnect/COND syntax;
  not a timing PASS. No source SDF edits. Extracted STA remains PASS on all3
  corners; check_setup has no listed violations. Clock-leaf fanout warnings
  retained (15); slew/cap violations0. See FULL_VERIFICATION.md.
- make doctor lint: exit0. After hardening the release checker, final model
  tests:15 PASS; lint PASS. Manifest records exact delivered source/evidence.
- Tool versions/commands in FULL_VERIFICATION.md and TOOLCHAIN.md. User identity
  not invented; no commit, push, remote CI, order, payment or submission.

## P8 — Chip D6 user wiki (2026-09-13)

- Added a standalone, responsive Polish user manual at `wiki/index.html`.
  It covers quick start, external block diagram, Tiny Tapeout pinout, keypad,
  SHIFT64 framing/timing, known-answer demo, physical metrics, security scope
  and troubleshooting without discussing RTL construction.
- Copied the actual final IHP SG13G2 place-and-route render to
  `wiki/assets/chip-d6-layout.png`; the caption explicitly distinguishes it
  from a silicon micrograph.
- Product naming in the wiki is exclusively `Chip D6`; implementation and
  evidence filenames elsewhere in the repository remain unchanged to preserve
  reproducibility and artifact hashes.
- Command: Python 3.14.4 stdlib `html.parser` check of duplicate IDs, local
  assets, fragment targets and forbidden legacy product name; followed by
  `sha256sum wiki/index.html wiki/assets/chip-d6-layout.png`.
- Result: PASS, 16 unique IDs, 12 links and one resolved local image asset.
  Exact output: `reports/logs/chip-d6-wiki-validation.log`.
- Browser visual regression: NOT_RUN because no browser executable was found
  in PATH. This does not affect the existing RTL/physical verification status.
- Next step: open `wiki/index.html` in the intended publication browser and,
  if desired, publish the `wiki/` directory as static hosting content.

## P8 — Chip D6 MkDocs wiki rebuild (2026-09-13)

- Rebuilt as a genuine MkDocs 1.6.1 / Read the Docs static manual, styled as
  a classic technical wiki inspired by STM32World: light sidebar, serif
  article headings, blue links, category portal and product infobox.
- Ten authored articles; generated search and 404 pages; built-in search,
  responsive navigation, local assets and print styles. Corrected serial
  timing details and reset guidance against docs/SINGLE_KEY.md and SPEC.md.
- Source: wiki/manual; generated HTML: wiki/site; wiki/index.html redirects
  to the new portal. Previous page/image preserved in wiki/archive.
- Local environment: Python 3.12.14, MkDocs 1.6.1; exact dependency versions
  in wiki/requirements-lock.txt. No system package installation.
- Commands: `make wiki-build` (strict MkDocs build),
  `.tools/wiki-env/bin/python scripts/check_wiki.py`, `make wiki-serve`.
- PASS: strict build, 12 HTML pages, 398 references/anchors, 56 indexed
  article/section entries, unchanged layout SHA-256 and product naming.
  Logs: reports/logs/chip-d6-mkdocs-build.log and
  reports/logs/chip-d6-mkdocs-validation.log.
- Initial link check found one Polish anchor mismatch; fixed with explicit
  anchor. Root-relative 404 URLs are resolved relative to the site root.
- Server runs on 127.0.0.1:8000. Browser rendering/interactive search UI
  NOT_RUN; static search index and assets checked. No new ASIC tests run.
- HTTP smoke: `curl --fail --silent --show-error --output /dev/null
  --write-out 'HTTP %{http_code}\n' http://127.0.0.1:8000/` returned HTTP 200.
- Next step: view the local portal; publication remains optional and was
  not performed. Existing ASIC statuses remain those in reports/FINAL.md.

## P7–P8 — D00RSH public repository preparation (2026-09-13)

User supplied product D00RSH, Koło Naukowe BAZA and initials ZT PN MK JT KK.
The user selected
https://github.com/magnetoField/ieee-sep-2026-1st-ihp. The target is
public and authenticated permission is WRITE. Its four-commit `main` history,
ending at dde98d17fe0eef79c5d05db6fbf471b7aeebed0e, was fetched and merged with
the D00RSH project commit without rewriting remote history. Metadata and public
documentation are updated, the IHP GDS flow is preserved/pinned, and wiki CI
artifact plus RTL log upload are present. First target push remains pending at
this report snapshot.
Original manifest retained; packaging/documentation hashes updated after
confirming zero changes to RTL, physical config and verified artifacts.

PASS: official YAML parser, upload selection/basic token scan, lint,15 model
tests, strict wiki build,398 references,56 search entries, release-check.
Fresh ZIP extraction also passes inventory/hash checks, release-check, wiki
build and actual RTL wrapper smoke. Commands/tool versions/logs and remaining
risks: reports/GITHUB_UPLOAD.md. Next: first push and remote CI. No remote PASS
or production submission is claimed.

## P8 — first target push and template compatibility repair (2026-09-13)

Pushed merge commit 591f96d58bc990ff2b4ac7c46b12b4208281c7a2 to
`magnetoField/ieee-sep-2026-1st-ihp:main` without force. GitHub Actions results
at inspection: docs PASS, wiki PASS, gds RUNNING, rtl-regression FAIL. Exact
failure from `gh run view 34761065837 --log-failed`: Linux could not execute
`scripts/local_tool.sh` because its tracked mode was 100644. Set all nine shell
scripts to Git mode 100755 and extended `scripts/prepare_upload.py` to reject
future non-executable shell scripts. Evidence:
`reports/logs/github-rtl-591f96d-failure.log`. Next: local upload/release checks,
push repair, then require fresh remote CI. No Tiny Tapeout submission performed.

## P8 — template parser compatibility and official remote jobs (2026-09-13)

Commit bc292cd89c310cac13115c4f5b4fd8e3235ee453 fixes Git executable modes.
Its remote docs and wiki jobs PASS. The RTL job reached Icarus 13 and FAILed
because kb.v used frame_hits/row_index before their declarations; the older
local Icarus 12 accepted the ordering. Moved existing declarations before the
continuous assignments, with no expression, width or sequential logic change.

Executed locally:
`make lint test-model test-unit test-integration test-exhaustive test-params formal test-mutations synth`.
PASS: 15 model tests, every unit/integration case, 256 seeded sessions, all
65536 keypad masks, parameter checks, formal properties, 7/7 killed mutations
and synthesis. Evidence summary: `reports/logs/template-compat-local.log`;
formal and synthesis logs were regenerated and hashed in MANIFEST.sha256.

Official run 34761065857 on 591f96d independently reports gds PASS, precheck
PASS and gl_test PASS. Viewer FAIL is repository configuration only: Pages is
disabled. `gh api .../pages` GET and create both returned HTTP 404 under WRITE
permission, so repository ADMIN must enable Pages with GitHub Actions source.
Next: publish declaration-order fix and require fresh RTL/GDS results. No
submission, order or payment performed.

## P8 — strict Verilator compatibility (2026-09-13)

Remote rtl-regression run 34762520248 for ff4b316 confirms that Icarus 13 now
passes elaboration. Verilator 5.053 then stops on two SYNCASYNCNET warnings for
the tested `reset_release` pattern. This module deliberately asserts reset
asynchronously and shifts its release synchronously; changing it to silence the
warning would weaken the specified reset behavior. Add only
`-Wno-SYNCASYNCNET` to the Verilator invocation while preserving `-Wall` and all
other warnings. Reproduction: `gh run view 34762520248 --log-failed`. Evidence:
`reports/logs/github-rtl-ff4b316-failure.log`. Next: lint locally, publish and
continue the exact remote regression. No RTL logic changed in this repair.
