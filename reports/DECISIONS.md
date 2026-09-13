# Decisions

## D-001 — working physical target

Date: 2026-09-12. Initially no shuttle or PDK was supplied, so per plan the
official SKY Verilog template was used as a temporary architecture benchmark.
This decision was superseded by D-009 when the user selected TTIHP26b; SKY
measurements remain historical and are not target fit evidence.

## D-002 — model organization

The SIMON oracle is full-word Python with an expanded 44-word key schedule. The
future RTL remains bit-serial and must not import expected DUT results. The keypad
oracle is an eight-node electrical connectivity graph, so rectangle ghosting is
included rather than approximated per selected row.

## D-003 — fail-closed Make targets

Required targets exist from P0 onward. Targets whose implementation/tool evidence
does not yet exist return non-zero and print BLOCKED. They will only be converted
to passing runners when the corresponding checks genuinely run.

## D-004 — one-copy transaction key context

`regs` retains the latched GOOD/BAD selection through `session_end`; `auth_ctrl`
therefore routes the selected constant without a second 128-bit register, and
`szymon` copies it only on `cmd_valid && cmd_ready`. Unit, integration and formal
tests guard stability/cardinality. This saves 128 generic DFFs without changing
the frozen interface or one-token semantics.

## D-005 — reproducible random integration

The E2E random suite uses Python's independent full-word oracle to emit packed
vectors, seed `0xe2e52517`. The RTL bench never reads DUT state to calculate an
expected response. It runs 256 physical-keypad sessions, preserving attempts
between sessions and cold-resetting only after lock or at sparse seeded points.

## D-006 — fixed two-key core in the ASIC top

The standalone `szymon` remains the arbitrary-runtime-key reference RTL and is
verified with 1024 key/plaintext pairs. The default ASIC top uses
`szymon_fixed`, whose two complete 44-word schedules are elaboration-time
constants derived from `KEY_GOOD` and `KEY_BAD`; it latches only the one-bit
selection. This is variant B explicitly permitted by the implementation plan,
not a shorter cipher: block/key sizes, 44 rounds, streaming protocol and
1408-cycle latency are unchanged. Default and alternate key parameter pairs,
256 independent-model E2E sessions, formal channel stability and mutations
guard the adapter. `FIXED_KEY_CORE=0` retains the runtime-key architecture for
experiments, but is not the area target.

## D-007 — selected variant C reset and ROM composition

The 64-bit shared cipher data register is synchronously cleared because it is
masked and unobservable during asynchronous reset; valid/ready control remains
asynchronously safe. The two fixed round-key tables use `BAD XOR select &
(GOOD XOR BAD)`, allowing synthesis to share their common bits. On the same
SKY130 mapping this reduces variant B from 13027.4944 to 12589.5744 um2. A
single 11-bit phase counter was also measured, but increased area to
12744.7232 um2 despite removing one DFF, so the separate counters were kept.

## D-008 — gate-level scope

`make test-gatelevel` uses the emitted target-library synthesis netlist, not
RTL. After D-009 it uses the exact pinned IHP26b standard-cell models. It covers
the mandatory public-pin smoke scenarios. This supports a qualified gate-level
PASS without SDF; physical-netlist simulation and timing closure remain blocked
with P&R.

## D-009 — retarget to Tiny Tapeout IHP26b

The user selected TTIHP26b on 2026-09-12. The package and workflows now use
`ttihp-verilog-template` commit `6598bef4...`, action tag `ttihp26b`, and PDK
name `ihp-sg13g2`. Preliminary synthesis uses the exact standard-cell Liberty
from the current shuttle's IHP-Open-PDK commit `e16d00b...`. No SKY area limit
or numerical area comparison is reused for IHP.

## D-010 — IHP area-first mapping and keypad counter sharing

The user explicitly allowed encryption latency up to 10 ms and made 1x1 fit the
priority. The selected cipher already completes its 44 full rounds in 1408
cycles, or 1.408 ms at the configured 1 MHz, so no cryptographic reduction was
needed. Two-bit rounds, a stateful round-key successor, alternate constant-ROM
coding, removing a serial-link flag, combinational timebase pulses, and an
eight-state keypad encoding were each synthesized against the same IHP Liberty
and rejected because they increased mapped area.

The accepted keypad change shares the mutually exclusive press/release counter,
uses one extra phase bit, reuses `key_id` as the latent candidate while no item
is valid, and derives the onehot row drive combinationally during non-blank
cycles. The accepted fast-estimator policy is area-first: local ABC uses
`&nf -a -F 16 -A 8 -R 1000`. Complete RTL/formal/gate regression passes.
The estimator reaches 22708.0098 um2, down 1422.2250 um2 / 5.89% from the
first IHP mapping. The later physical experiments are recorded in D-011.

## D-011 — stop after measured IHP 1x1 legalization failure

With user approval, the official LibreLane 3.0.5 AppImage, complete exact PDK
and pinned support tools were installed under the 50 GB ceiling. The default
`AREA 3` / 60% run failed global placement at 107.365% effective utilization.
`AREA 0` reduced synthesis to 23683.5522 um2. At density 80%, placement and
CTS succeeded, but utilization reached 89.3925% before post-CTS hold repair;
339 buffers at the template margin, or 234 at zero margin, could not be
legalized. The user requested stopping if Tiny Tapeout production outputs
could not be generated. No GDS/DRC/LVS/antenna PASS is claimed.

The exact PDK SRAM macros were also ruled out as a simple shortcut: the
smallest relevant macro dimensions inspected exceed the 202.08 um tile width.
The next focused architecture target is therefore `szymon_fixed`.

## D-012 — retain measured MSB-first/shared-shift improvement

Resumed cipher optimization retains full 44-round SIMON64/128 and 1408-cycle
latency. Sharing the RX/round/TX shift direction and data control reduces
isolated area by 3.83%, complete-top area by 1.46%. ROM banking and tested
key-address interleavings regress and were reverted. Relevant unit,
integration and formal checks pass; details and exact metrics are in
`reports/SZYMON_OPTIMIZATION_RESULTS.md`. This is not enough evidence for
physical fit, so another full P&R run is deferred pending larger reduction.

## D-013 — multilevel sparse-key reconstruction within 10 ms

Store odd round keys and even checkpoints every 32 rounds. Reconstruct
omitted even words using the full SIMON recurrence and one shared lookup,
not a runtime 128-bit key register. This reduces the complete-top estimate
to 21817.0638 um2 while extending fixed-core latency to exactly 9344 cycles.
The user permits up to 10 ms at 1 MHz. Both independent keys and full
44 rounds remain. New key-bit/data-hold/abort checks pass for both key pairs.
The scaled fault-session test deadline had to account for the additional
cycles; production timeout logic was not changed. Current evidence and
limitations: `reports/SZYMON_OPTIMIZATION_RESULTS.md`.

## D-014 — stop after optimized candidate's physical failure

The optimized RTL was passed through the pinned IHP flow (AREA 0, 80%
density, zero extra post-CTS hold margin). Synthesis and CTS improved, but
hold repair inserted 227 buffers and detailed placement could not legalize
27 instances. This is a measured terminal failure, not a missing tool.
User explicitly requested stopping when production files cannot be
generated, so no further retries or architectural experiments are started.
Retain the tested optimized RTL and evidence; do not claim FIT or physical
verification PASS. See `reports/PHYSICAL.md` for the exact run.

## D-015 — compare eight user proposals; retain only Z3 simplification

The user explicitly reopened work for eight bounded proposals. All legal
RTL candidates were synthesized in the same full-source context, isolated
and whole-top. Scan/group/delta can improve isolated area yet regress the
whole top. ROM reorderings and full/16/24-round checkpoints also regress.
Clock gating is blocked by both pinned PDK exclusion lists. Serial wipe
saves area but changes first-edge erasure to 64 cycles; it is tested only
as an experiment and requires an explicit contract decision before use.
Only Z3 simplification is retained: top 21668.4720 um2, same 9344 cycles.
Targeted regression and no-SDF gate smoke pass; no new physical-fit claim.
Full table, qualifications and commands: `reports/EIGHT_IDEAS.md`.

## D-016 — serial wipe explicitly approved (2026-09-12)

User: "Dopuść 64 cykle czyszczenia". The fixed-key core may erase its
shared 64-bit data register serially after reset/abort. All core ready/valid
signals remain low and m_bit is zero until wipe completes. Count 64 rising
clock edges after reset/abort release; a repeated abort restarts the count.
With the clock stopped, interface masking remains effective but physical
erasure waits for clock edges. This supersedes D-015's pending approval
for serial wipe only. No physical-fit PASS is implied.

## D-017 — one key and authorized-only external READY

User explicitly replaced the two-key architecture with one key and one READY
status output after the correct PIN. No BAD challenge/response remains;
third wrong PIN locks immediately without token. Preserve SDO and buzzer;
uo0=CHALLENGE_READY, uo1=0, uo2=SDO. With no response-ready pin the host waits
10000 clocks before reading output. Full cipher and keypad filtering remain.
The new source passed default units, integration, parameters, mutations,
formal and post-route no-SDF gate simulation. Local P&R exits0 at 89.8251%
cell utilization. Adopt its AREA0/density80/extra post-CTS hold margin0 settings
in config.json; no DRC/timing gate was disabled for this change.

Production acceptance is still unproven: TT precheck environment fails in
KLayout DRC. Preserve candidate GDS/LEF/netlist and report this explicitly,
without treating rule failure-to-run as rule PASS. See SINGLE_KEY.md.

## D-018 — full verification explicitly resumed and completed locally

User: "zrób już do końca weryfikację pełną" overrides the earlier stop.
Fetched the precheck action's exact CIEL c4b8b4e5 PDK. All10 unchanged
prechecks pass on the existing GDS; no RTL/layout/rule changes were needed.
Full required regression and coverage rerun, original-model GL with Icarus13
passes, and the local TT GATES=yes Makefile/XML interface is verified.
Use unpowered nl netlist for IHP, per tt/tech.py, not the powered LVS netlist.

Do not turn failed SDF experiments into timing PASS: Icarus cannot fully
parse/annotate this output. STA is the required timing evidence under
TEST_PLAN section8. Preserve15 non-gating CTS fanout warnings,0 slew/cap
violations and worst hold slack7.94ps. Exact PASS status fields refer to
required local checks only; no remote run or submission is implied.

## D-019 — external product name and user-document scope

The new user-facing HTML documentation uses `Chip D6` exclusively. Existing
RTL top names, physical artifact names, run directories and historical reports
are not renamed: they are implementation/evidence identifiers whose mutation
would break flow compatibility, provenance and recorded hashes. The wiki
describes only observable behavior and external integration. Its block diagram
is a product-level functional diagram, not an RTL hierarchy. The physical image
is the final routed-layout render already produced by the verified run, with an
explicit non-micrograph qualification.

## D-020 — MkDocs framework for Chip D6 wiki/manual

User requested a complete rebuild in the style of stm32world.com using an
existing documentation framework. Adopt MkDocs 1.6.1 with bundled Read the
Docs theme and local classic-wiki CSS. Navigation, page generation, search
index and search runtime come from the framework. This provides a static
manual without requiring a database or account system. It does not claim
MediaWiki editing/history features. No third-party articles or branding copied.
Keep ten source articles separate from generated HTML; preserve the prior
page in an archive. Add wiki-build/wiki-serve Make targets. All product
content remains named Chip D6 and describes user-visible behavior.

## D-021 — public D00RSH identity and upload scope

User supplied the new public product name D00RSH, author Koło Naukowe BAZA,
creator initials ZT PN MK JT KK, and will create the repository personally.
Apply identity to info.yaml, README, datasheet and wiki. Keep verified RTL/GDS
identifiers and historical reports unchanged. Prepare public source ZIP and
GitHub Actions configuration, without creating a remote, committing, pushing
or submitting to production. Preserve original manifest before refreshing
only changed documentation/packaging metadata records; no re-verification
claim for changed RTL is involved because RTL and physical config are unchanged.

## D-022 — pin the public RTL CI tool bundle

Do not rely on the Ubuntu repository's unspecified Yosys version for formal
commands used by this project. The public regression selects OSS CAD Suite
release 2026-09-12 and pins the setup action to commit
853bb54f52246aa8fb4fab963f104cfb6676197a. This is additional CI; the official
IHP26b GDS, precheck, gate-level and viewer jobs remain the submission path.

## D-023 — publish into the assigned holder repository without force-push

Publish only to magnetoField/ieee-sep-2026-1st-ihp. The target already contains
four placeholder/template commits and the authenticated account has WRITE
permission. Merge the unrelated histories and keep the verified D00RSH tree as
the result, instead of force-pushing or rewriting the owner's history. The
remote placeholder commit dde98d17fe0eef79c5d05db6fbf471b7aeebed0e remains an
ancestor of the publication commit. Do not submit, order or pay for tapeout.

## D-024 — enforce executable modes required by the Linux template runner

The first remote RTL workflow reached the pinned tool installation, then failed
before lint because Git had stored `scripts/local_tool.sh` as mode 100644. Local
NTFS execution did not reveal this packaging defect. Track every shell script as
100755 and make `upload-check` inspect Git index modes. This is a repository and
CI portability correction; script contents and RTL behavior are unchanged.

## D-025 — use strict declaration-before-reference ordering for Icarus 13

The template-compatible pinned CI bundle supplies Icarus 13, which rejects
continuous assignments in kb.v that refer to module variables declared later.
Move the existing row/frame register declarations above those assignments.
Do not change expressions, state, widths or timing. Re-run the entire functional,
exhaustive, formal, mutation and synthesis suite because the edited file is RTL.
Treat the prior physical artifacts as evidence for the logic-equivalent source;
the official remote GDS/precheck/gl_test run for the published correction is the
required current publication evidence.

## D-026 — narrow Verilator waiver for reset-release synchronizers

Verilator 5.053 reports SYNCASYNCNET when a register is asynchronously cleared
and then synchronously shifted. That is the deliberate architecture of both
`reset_release` instances and is covered by a standalone testbench and formal
checks. Keep `-Wall`, disable only SYNCASYNCNET for the lint invocation, and do
not alter the reset circuit merely to satisfy this structural heuristic.
