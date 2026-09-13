# Verification status

| Scope | Command | Result |
|---|---|---|
| Python models | `make test-model` | PASS (13 tests, latest run 0.830 s) |
| Arithmetic plan | `python3 tools/verify_arithmetic_plan.py` | PASS for Python experiment only |
| Szymon RTL | `make test-unit MODULE=szymon` | PASS (KAT + 1024, seed `0x52554d43`) |
| Fixed-key Szymon RTL | `make test-unit MODULE=szymon_fixed` | PASS (default and alternate key pairs, exact latency and abort) |
| sync2 RTL | `make test-unit MODULE=sync2` | PASS |
| reset_release RTL | `make test-unit MODULE=reset_release` | PASS |
| timebase RTL | `make test-unit MODULE=timebase` | PASS |
| regs RTL | `make test-unit MODULE=regs` | PASS |
| buzzer RTL | `make test-unit MODULE=buzzer` | PASS |
| kb focused RTL | `make test-unit MODULE=kb` | PASS |
| kb exhaustive RTL | `make test-unit MODULE=kb_exhaustive` | PASS (65,536 masks) |
| keypad dynamic matrix | `make test-unit MODULE=kb_edges` | PASS (16 singles, 120 pairs, 180 rectangle masks, boundaries) |
| regs mapping/positions | `make test-unit MODULE=regs_matrix` | PASS |
| Szymon round trace/cancel | `make test-unit MODULE=szymon_trace_abort` | PASS (44/44 states and cancel points) |
| serial framing matrix | `make test-unit MODULE=serial_lengths` | PASS |
| timebase/buzzer edge parameters | selected `test-unit` modules | PASS |
| valid/invalid parameters | `make test-params` | PASS |
| controlled RTL mutations | `make test-mutations` | PASS, 7/7 killed |
| directed/fault integration | `make test-integration` | PASS |
| seeded E2E integration | same | PASS, 256 sessions, seed `0xe2e52517` |
| default wrapper timing/pins | same | PASS, GOOD and BAD full sessions |
| Formal F-11/F-12 | `make formal` | PASS, exhaustive SAT |
| Formal regs/kb/cipher safety | `make formal` | PASS by temporal induction; depths reached: regs 33, kb 2, both cipher variants 2 |
| Formal auth/serial/wrapper control | `make formal` | PASS only as BMC depth 20 (wrapper depth 2), complemented by deep simulation |
| Formal F-13 scaled harness | `make formal` | PASS only as BMC depth 12 with periodic tick assumption |
| Generic full-top synthesis | `make synth` | PASS/check 0; 2483 generic cells, 208 DFF-class |
| IHP SG13G2 fast mapping | `make synth-ihp` | PASS/check 0; 1588 cells (1576 SG13G2 + 12 metadata), 207 sequential, 22708.0098 um2 at typ/1.2 V/25 C |
| LibreLane/OpenROAD physical flow | see `reports/PHYSICAL.md` | FAIL 1x1 legalization after CTS; no production GDS/DRC/LVS PASS |
| IHP mapped gate-level smoke | `make test-gatelevel` | PASS without SDF: reset/ena, malformed 63-bit RX, GOOD, three BAD responses, lockout and pin safety |
| P&R / STA / DRC / LVS / physical-netlist timing | official LibreLane 3.0.5 flow | FAIL 1x1 legalization after CTS; routing/signoff not reached |

Every functional ID in `reports/TEST_MATRIX.csv` has executed evidence. Formal
PASS entries retain their explicit proof scope: no unbounded liveness or analog
CDC guarantee is claimed. The mapped gate simulation does not establish timing
closure; physical verification remains blocked.
