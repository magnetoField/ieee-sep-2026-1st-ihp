# IEEE DOORSH — final local Tiny Tapeout report

Date: 2026-09-18. Target: Tiny Tapeout IHP26b, IHP SG13G2, one 1×1 tile.

```text
RTL_DEMO=PASS
VERIFICATION=PASS
FIT_1_TILE=PASS
PHYSICAL_CHECKS=PASS
TT_PRECHECK=PASS
GATE_LEVEL=PASS
SDF_SIMULATION=UNSUPPORTED
SUBMISSION=NOT_PERFORMED
PRODUCTION_PERSISTENCE=NOT_IMPLEMENTED
```

## Final configuration

- Public title: **IEEE DOORSH**.
- Internal physical top: `tt_um_rumcajs`.
- Clock: 1 MHz.
- PIN: `1234`.
- One SIMON64/128 demonstration key:
  `BA2A1918131211100B0A090803020100`.
- Full 44-round SIMON64/128, 9344 cipher cycles.
- One challenge after a correct PIN; wrong PIN produces no READY and no
  response; third wrong PIN blocks until cold reset.
- Reset/abort data erasure: 64 clock cycles.
- One fixed buzzer implementation: nominal 2 kHz tone for a passive buzzer,
  50 ms duration. There is no final buzzer-mode parameter.
- Public reference transaction:
  `F15654A8D25FFA1C → BA2A5234DEADBEEF`.

## Verification

The final source passed:

- 15 independent Python model tests;
- all standalone RTL module tests;
- published SIMON64/128 KAT and exact 44-round trace;
- 1024 seeded runtime-key vectors and seven fixed-key configurations;
- directed wrapper/fault tests and 256 random authorization sessions;
- all 65,536 physical keypad masks;
- invalid-parameter rejection;
- bounded formal checks, temporal induction and reachability;
- mutation score 7/7;
- IHP synthesis and no-SDF gate-level simulation.

The readable public challenge/response pair is checked in RTL wrapper,
fault-session and post-route gate-level benches. The published SIMON KAT
remains an independent algorithm test.

## Physical result

Run: `runs/final_ieee_doorsh_ba2a_passive`.

- LibreLane 3.0.5 with IHP-Open-PDK commit
  `e16d00b7b26a93956563c373b782f54dd4d77a7f`.
- Official 1×1 outline: 202.08 × 154.98 µm.
- Synthesis area: 21,086.163 µm².
- Routed standard-cell area excluding filler: 26,203.6 µm².
- Final utilization: 90.5398%; 1703 standard cells, 213 sequential cells.
- Routing DRC: 0; Magic DRC: 0; LVS errors: 0; antenna violations: 0.
- Setup, hold, max-slew and max-cap violations: 0 in all reported corners.
- Worst setup slack: +598.210 ns; worst hold slack: +0.0106 ns.
- Tiny Tapeout precheck: PASS, including KLayout SG13G2 DRC, pins, boundary,
  layers, cell name, zero-area and Verilog syntax.
- Post-route pin-level no-SDF simulation: PASS.

The flow reports 15 max-fanout warnings against its generic fanout limit. The
flow does not gate on this metric; max capacitance, max slew and timing checks
are clean. The generic SDC and IR-drop source-location qualifications remain
tool-flow limitations and are not hidden.

## Deliverables and limits

Verified GDS, LEF and post-route netlist are in
[`artifacts/verified_single_key`](../artifacts/verified_single_key/README.md).
SHA-256 identities are recorded in `MANIFEST.sha256`.

Full SDF simulation is unsupported by the available Icarus/IHP model
combination; STA is the timing evidence, while gate-level simulation is
functional and no-SDF. The key and PIN are public. The failure counter is
volatile and clears on cold reset. There is no secure provisioning, NVM,
tamper resistance or production-persistence claim.

No Tiny Tapeout submission, fabrication order or payment was performed.
