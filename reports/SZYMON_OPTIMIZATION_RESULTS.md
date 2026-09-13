# Szymon optimization checkpoint — 2026-09-12

Superseded by the user's new eight-idea comparison: `EIGHT_IDEAS.md`.
Current core/top are 10713.4650 / 21668.4720 um2, with the Z3-only change
retained and targeted regression PASS. No new P&R. Stop statements below
refer to the earlier physical attempt, not the newly authorized screening.

## Final result of this optimization attempt

Physical FAIL after CTS: 227 inserted hold buffers, 27 instances cannot
be legalized (DPL-0036), `runs/szymon_sparse_p80_h0`, exit code 2.
Complete LibreLane synthesis is 22913.0748 um2, after CTS 24706.68 um2.
No production-ready GDS or post-route verification. See `PHYSICAL.md`.
Further attempts are stopped per user instruction; the next-step proposals
below are historical and are not authorization for continued work.

The retained sparse-key RTL also passes four additional random key-pair
configurations, seed 0x53494D4F, in `make test-unit MODULE=szymon_fixed`.
Each checks every consumed round-key bit, exact 9344-cycle latency, data
hold during reconstruction, 28 abort positions and rearm. Six total
configurations now run reproducibly; log `reports/logs/szymon-sparse-keys.log`.

## Current candidate: multilevel sparse reconstruction

This section supersedes the retained-checkpoint metrics below. The ASIC
core stores odd round words plus even checkpoints 0, 2, 32, 34, and
reconstructs omitted even words via the SIMON recurrence. Each recursion
level consumes four odd-word bits through one shared ROM lookup, then
continues at r-4 until a stored checkpoint. A 1-bit accumulator, 2-bit phase
and 3-bit depth counter replace part of the original lookup logic.

- Checkpoints every 16 rounds: 10943.7426 um2, calculated 5248 cycles.
  Area-screened only, superseded by the 32-round candidate.
- Checkpoints every 32 rounds: **10922.0454 um2**, 821 cells,
  4311.0144 um2 sequential area. Original baseline 11658.2382 um2;
  reduction 736.1928 um2 (6.31%).
- Whole top: **21817.0638 um2**, versus original 22708.0098 um2
  (3.92% reduction), previous retained variant 22375.6722 um2.
- Exact measured latency: **9344 cycles**, 9.344 ms at 1 MHz.
  Full 44 rounds and all 1408 data updates retained, both independent keys.
- RTL SHA-256:
  `309d8fc5f7316ee6fd847dfd9289c5021765769ecfe01359d823e91b5196934e`.

`make test-unit MODULE=szymon_fixed` passes both key pairs, every consumed
key bit against the independent model, exact latency, data holding during
key-only cycles, 28 reconstruction abort positions and successful rearm.
Log: `reports/logs/szymon-deep-unit.log`. `make lint` passes, log
`reports/logs/szymon-deep-lint.log`. Fixed-core safety induction passes
(`reports/logs/formal-induct-F06_szymon_fixed.log`); this is not complete
functional equivalence of the new reconstruction engine.

SPEC, unit latency assertions and integration response bounds now distinguish
runtime-key 1408 cycles from fixed-key 9344 cycles. Fault-session harness
uses 300 ms instead of 200 ms at its scaled 64 kHz: 9344 cipher cycles plus
6144 RX/TX cycles already exceed its old 12800-cycle absolute deadline.
Its timeout fault still executes; production AUTH_TIMEOUT_MS is unchanged.
The initial scaled test failed during TX as expected from this arithmetic;
see `reports/logs/szymon-deep-regression.log`, not a ciphertext PASS.

Physical acceptance remains unproven. No new full P&R was started in this
checkpoint. Integration and gate-level logs for the new candidate are
`reports/logs/szymon-deep-integration.log` and
`reports/logs/szymon-deep-gatelevel.log`.

Both completed with exit code 0: integration PASS (directed, wrapper,
faults, 256 random sessions seed 0xE2E52517) and mapped IHP gate-level
PASS (reset/ena, malformed RX, GOOD/BAD and attempt limit). Gate-level is
without SDF; library timing-check warnings remain, so this is not STA.
Next: audit the new key reconstruction across broader parameter/reset
coverage and then test this candidate in the pinned physical flow. The
previous physical failure must not be silently converted into FIT=PASS.

## Follow-up architecture screening

All following candidates were rejected by area screening; no functional
PASS is claimed for rejected candidates. Retained RTL was restored exactly
to SHA-256 908d94842b7b534a4fd51bd5f0d264faf901d7a1d723d871d0b30b1fcd67e70f
and remeasured at 11212.0848 um2 / 899 cells.

- Registered one-hot 44-round lookup: 14221.6074 um2 (120 sequential
  cells); storage overhead outweighs simpler addressing.
- Logic rewriting / LUT4 / LUT6 preprocessing before the same area mapper:
  11435.0292 / 12497.0958 / 11906.4330 um2. Diagnostic only; mapping
  scripts unchanged. Logs: `reports/logs/szymon-map-{resyn,lut4,lut6}.log`.
- Sparse round-key ROM: omit round indices r>=4 with residues {o,o+2}
  modulo 7. None of their r-1/r-3/r-4 dependencies is omitted. Reconstruct
  each omitted bit using five sequential ROM accesses and an XOR
  accumulator, retaining full cipher rounds. Offsets o=0..6 measured:
  11609.1738, 11569.6728, 11562.3396, 11515.1652, 11582.3358,
  11422.2528, 11424.5208 um2. Even the best regresses by 210.1680 um2.
  The design trades table gates for address/control logic and four extra
  registers. No latency/test changes were accepted. A rejected source
  checkpoint is in `.build/szymon-opt/sparse-rejected.v` (offset 6).

Sparse screening command: `make area-module MODULE=szymon_fixed` for each
candidate; same Yosys/PDK/mapping as the retained baseline. These results
rule out this single-level reconstruction, not every time/area tradeoff.
Potential next experiment: deeper reconstruction with periodic stored
checkpoints, only if its calculated cycle count remains below 10000.

## Retained checkpoint

Status: measured RTL improvement; 1x1 physical fit still unproven.
No new production files or physical PASS are claimed.

Same-library estimates: Yosys 0.52, IHP SG13G2 typical Liberty,
existing area-first ABC script.

| Variant | Isolated core area, um2 |
|---|---:|
| Original baseline | 11658.2382 |
| MSB-first rounds | 11430.0018 |
| MSB-first + shared shift/clear control, retained | 11212.0848 |
| Ternary key selection, rejected | 11323.7082 |
| 128-bit / 256-bit ROM banks, rejected | 11442.0978 / 11469.7296 |
| Interleaved key address, positions 0/1/2 | 11289.8016 / 11282.6196 / 11250.0360 |
| Interleaved key address, positions 3/4/5/8 | 11425.7304 / 11331.3438 / 11356.7832 / 11221.0056 |

All ROM trials were rejected. Retained core: 899 mapped cells,
4017.0816 um2 sequential area. Core reduction: 446.1534 um2 (3.83%).
Complete-top estimate: 22708.0098 -> 22375.6722 um2 (1.46% reduction).
These estimates exclude physical repair/CTS/routing overhead.

MSB-first rounds share the left shift direction with RX/TX. Both keys,
44 rounds, the 64-bit shared data register, clearing and interfaces remain.
Latency: 1408 cycles (1.408 ms at 1 MHz). Runtime-key `szymon.v` unchanged.

Executed verification for the retained candidate:

- `make area-module MODULE=szymon_fixed`: PASS;
  `reports/logs/area-szymon_fixed.log`.
- `make synth-ihp`: PASS; `reports/logs/synth-ihp.log`.
- `make test-gatelevel`: PASS on mapped IHP cells for reset/ena, malformed
  RX, GOOD/BAD and attempt limit; `reports/logs/szymon-opt-gatelevel.log`.
  No SDF; Icarus does not execute library timing checks. Not timing closure.
- `make test-unit MODULE=szymon_fixed`: PASS for default/alternate key
  pairs, 44 elaborated round keys, KAT, latency, framing and abort.
- `make lint`: PASS, including Verilator 5.032 and Verilog-2005 compile.
- `make test-integration`: PASS for directed sessions, wrapper/default
  timing, faults and 256 random sessions, seed 0xE2E52517.
- F-11 SAT: PASS for arbitrary words/key, LSB-first and MSB-first rounds;
  `reports/logs/formal-F11.log`. Separate arithmetic harness, not whole-DUT
  equivalence. Reproduce with the F-11 invocation in `scripts/run_formal.sh`.
- Fixed-core safety induction: PASS;
  `reports/logs/formal-induct-F06_szymon_fixed.log`. Reproduce with the
  F06_szymon_fixed induction invocation in `scripts/run_formal.sh`.

Unrelated exhaustive keypad tests and full mutation/coverage suites were
not rerun. Prior full-project reports describe the earlier baseline, not
complete verification of this checkpoint.

No git commit exists (unborn main). Retained RTL SHA-256:
`908d94842b7b534a4fd51bd5f0d264faf901d7a1d723d871d0b30b1fcd67e70f`.
Backups: `.build/szymon-opt/baseline.v` and `.build/szymon-opt/factored.v`.

Next: investigate using extra cycles to reduce key-generation area materially.
Do not repeat equivalent ROM-address experiments. Physical flow deferred
until substantial top reduction; prior legalization failure is historical
evidence, not a new physical run of this candidate.
