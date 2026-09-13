# Final audit — TTIHP26b 1x1 does not yet fit

Date: 2026-09-12. Overall result: **NOT PRODUCTION READY**.

The latest explicitly authorized P&R of the Z3-optimized RTL also fails
1x1 legalization. LibreLane synthesis is 22523.0544 um2 and the design is
24244.01 um2 after CTS. Hold repair adds 235 buffers; 9 instances remain
unlegalized (DPL-0036). No routing/final GDS/signoff checks. This supersedes
the older physical attempt below; `FIT_1_TILE=FAIL` remains unchanged.

Latest user-requested eight-idea screening is recorded in `EIGHT_IDEAS.md`.
Only Z3 simplification was retained: core 10713.4650 um2, top 21668.4720
um2, unchanged 9344 cycles. Targeted lint/unit/integration/induction/gate
smoke pass. No new physical run: failures below belong to the previous
sparse-key checkpoint. Production readiness remains unproven.

Latest Szymon optimization supersedes the older baseline details below:
core 10922.0454 um2 (-6.31%), fast whole-top 21817.0638 um2 (-3.92%),
9344 cipher cycles = 9.344 ms at 1 MHz. Six key-pair configurations,
per-consumed-key-bit checks, 28 abort phases per configuration, directed
and 256 random E2E sessions, safety induction, lint and synthesis-netlist
gate smoke pass. Full mutation/coverage/exhaustive regressions below are
historical, not newly rerun on this candidate.

The new physical run synthesized to 22913.0748 um2 and reached CTS, but
227 hold buffers caused legalization failure on 27 instances. Exit code 2;
no routed GDS or post-route checks. Work stops as instructed. See
`PHYSICAL.md` and `SZYMON_OPTIMIZATION_RESULTS.md` for current evidence.

```text
RTL_DEMO=PASS
VERIFICATION=TARGETED_PASS_FULL_REGRESSION_NOT_RERUN
TARGET_LIBRARY_SYNTHESIS=PASS
FIT_1_TILE=FAIL
PHYSICAL_CHECKS=NOT_REACHED
GATE_LEVEL=PASS_WITHOUT_SDF
PRODUCTION_PERSISTENCE=NOT_IMPLEMENTED
```

## What is complete

The target is Tiny Tapeout IHP26b / `ihp-sg13g2`, not SKY130. The functional
RTL implements the complete SIMON64/128 44-round algorithm, keypad filtering,
transaction/attempt accounting, SHIFT64 framing, timeout, lockout, buzzer and
Tiny Tapeout wrapper behavior. Encryption takes 1408 cycles = 1.408 ms at
1 MHz, below the permitted 10 ms.

Functional evidence passes: 13 independent-model tests, published SIMON KAT,
1024 cipher vectors, all 44 KAT round states, 256 model-driven physical-keypad
E2E sessions, all 65536 keypad masks, parameter tests, 7/7 killed mutations,
formal SAT/induction/BMC checks, and an IHP synthesis-netlist gate smoke.
Coverage is 1417/1729 aggregate points (81%) and 884/993 unique RTL source
lines (89.0%). These results support functional confidence, but do not prove
analog CDC behavior, physical security, unbounded liveness or silicon behavior.

## Area ranking

The fast same-library estimator maps the top to 1588 Yosys cells, including
207 flops, and 22708.0098 um2. The dominant isolated blocks are:

| Block | Approximate isolated IHP area |
|---|---:|
| `szymon_fixed` | 11547.5598 um2 |
| `kb` | 3193.3062 um2 |
| `serial_link` | 2857.6422 um2 |
| `auth_ctrl` | 1772.6688 um2 |
| `regs` | 1739.9718 um2 |

The cipher is therefore the first optimization target. Use
`make area-module MODULE=szymon_fixed` for a quick, few-second isolated
measurement; use `make synth-ihp` for the complete top. A staged handoff for
the next model is in `reports/SZYMON_OPTIMIZATION_BRIEF.md`.

## Physical result

The official LibreLane 3.0.5 AppImage, full exact IHP PDK and pinned
tt-support-tools were installed locally (about 8.3 GB total, below the approved
50 GB). Real LibreLane/OpenROAD runs were executed:

- Default `AREA 3` / 60%: 26880.7518 um2 synthesis; global placement stopped
  at 107.365% effective utilization.
- `AREA 0` reduced synthesis to 23683.5522 um2 / 1679 cells.
- `AREA 0` / 80% passed initial placement, detailed placement and CTS, but
  reached 25871.5 um2 / 89.3925% after repair and CTS.
- Post-CTS hold repair needed 339 buffers at the template's 0.1 ns margin and
  could not legalize them. With margin reduced to 0 ns it still needed 234
  buffers and left 56 instances unlegalized.

Thus `FIT_1_TILE=FAIL`. The flow never reached detailed routing, post-route
STA, final antenna checks, GDS signoff, DRC or LVS. No production files that
pass Tiny Tapeout were generated. See `reports/PHYSICAL.md` and
`reports/AREA.md` for measured details.

## Why 60%

The 60% value is the official template's placement-density target, not a
cryptographic limit and not the fraction of the die that exists. Its remaining
whitespace is needed for clock/repair buffers, tap/decap/filler cells,
legalization and routing. The 80% experiment shows why an arithmetic
synthesis-only fit is insufficient: physical repair pushed real utilization
to about 89.4% before hold buffers, then legalization failed.

## Remaining scope and metadata

The demo keys are public constants and failed-attempt state is volatile;
power/cold reset clears lockout. Secure provisioning and persistent production
lockout are not implemented. `info.yaml` intentionally leaves the author
empty because no submitter identity was supplied. No push, submission,
purchase or tapeout order was performed.
