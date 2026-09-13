# Area and synthesis evidence

Current single-key result supersedes the historical comparisons below:
fast core8871.8868 µm², fast top19857.8520 µm²; physical synthesis20944.7154 µm²,
routed cells25996.7 µm² /89.8251% utilization. Local P&R and all10 TT prechecks
pass. See FINAL.md for timing and simulator qualifications.

Newest eight-idea comparison: retained Z3 simplification gives
**10713.4650 um2 core / 21668.4720 um2 top** with unchanged 9344 cycles.
See `EIGHT_IDEAS.md` for each idea, rejected combinations, tests and hashes.
This supersedes older fast-estimator figures below, not physical evidence.

Current Szymon checkpoint supersedes the historical estimator below:
isolated core **10922.0454 um2**, complete top **21817.0638 um2**,
9344 cipher cycles at 1 MHz (9.344 ms). See
`SZYMON_OPTIMIZATION_RESULTS.md` for current tests and hashes. Historical
physical results below are not new physical evidence for this candidate.

## Fast IHP target-library estimator

`make synth-ihp` maps the complete top with local Yosys 0.52 and the exact
IHP26b `sg13g2_stdcell_typ_1p20V_25C.lib` at PDK commit `e16d00b7...`.
The accepted ABC script uses `&nf -a -F 16 -A 8 -R 1000`.

| Metric | Result |
|---|---:|
| Yosys cells | 1588 (1576 SG13G2 + 12 zero-area metadata) |
| Sequential cells | 207 |
| Total cell area | 22708.0098 um2 |
| Sequential area | 10140.6816 um2 |
| Netlist SHA-256 | `d0d3ba7429d9c70811a7a3ecad851c8f8703a6ea7043eef244a6da5a743db9eb` |

This mapping passes Yosys `check` and the qualified gate-level functional
smoke. It is a fast estimator, not a production LibreLane netlist: it leaves
alias assignments which the LibreLane netlist checker rejects.

For quick isolated comparisons, run:

```sh
make area-module MODULE=szymon_fixed
```

The new target writes `reports/logs/area-<module>.log` and normally takes only
a few seconds. Its current `szymon_fixed` result is 897 Yosys cells and
11658.2382 um2, including 4017.0816 um2 sequential area. Cross-module
optimization means isolated measurements do not sum exactly to the top.

The earlier like-for-like isolated ranking was:

| Isolated block | Cells | Cell area | Sequential area |
|---|---:|---:|---:|
| `szymon_fixed` | 884 | 11547.5598 um2 | 4017.0816 um2 |
| `kb` | 215 | 3193.3062 um2 | 1567.6416 um2 |
| `serial_link` | 175 | 2857.6422 um2 | 1616.6304 um2 |
| `auth_ctrl` | 116 | 1772.6688 um2 | 881.7984 um2 |
| `regs` | 111 | 1739.9718 um2 | 979.7760 um2 |
| `timebase` | 39 | 841.8816 um2 | 587.8656 um2 |
| `buzzer` | 35 | 596.9376 um2 | 342.9216 um2 |

`szymon_fixed` is unambiguously the dominant block (roughly half of the
mapped top), followed by `kb` and `serial_link`. The cipher is still the full
SIMON64/128 computation: 44 rounds in 1408 cycles, or 1.408 ms at 1 MHz, well
inside the allowed 10 ms.

## Tile arithmetic and actual physical flow

The IHP 1x1 die is 202.08 x 154.98 = 31318.3584 um2. Its standard-cell rows
span approximately 196.32 x 147.42 = 28941.4944 um2. The fast mapped result is
130.77% of the 60% row-area budget (excess 5343.1132 um2). It is 98.08% of an
arithmetic 80% budget, leaving only 445.1857 um2 before physical overhead.

The official LibreLane 3.0.5 measurements are more decisive:

| Configuration | Synthesis / placement result |
|---|---:|
| official `AREA 3`, density 60% | 26880.7518 um2 synthesized; effective placement utilization 107.365%, FAIL |
| `AREA 0`, synthesis | 1679 cells, 23683.5522 um2 |
| `AREA 0`, density 80%, after repair + CTS | 25871.5 um2, 89.3925% real utilization |
| same, post-CTS hold repair margin 0.1 ns | 339 buffers requested, legalization FAIL |
| same, hold margin 0 ns | 234 buffers requested, 56 cells unlegalized, FAIL |

Therefore no production-ready 1x1 fit is claimed. No routed netlist, final
GDS, post-route STA, DRC, LVS or final antenna PASS exists. Full logs and the
meaning of density are summarized in `reports/PHYSICAL.md`.

## Historical SKY130 benchmark

SKY130 was used before the shuttle was named. The selected fixed-key
architecture reduced that one same-library benchmark by 21.92% versus the
runtime-key baseline. SKY130 numerical areas are not used to judge IHP26b.
