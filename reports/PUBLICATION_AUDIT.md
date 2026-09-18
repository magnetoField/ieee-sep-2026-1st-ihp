# IEEE DOORSH Tiny Tapeout upload audit

Date: 2026-09-18.

## Upload-facing configuration

```text
PROJECT_TITLE=IEEE DOORSH
TOP_MODULE=tt_um_rumcajs
CLOCK_HZ=1000000
TILES=1x1
KEY=ba2a1918131211100b0a090803020100
BUZZER=PASSIVE_2_KHZ
```

The project exposes one fixed hardware configuration. There is no buzzer-mode
parameter in the final RTL. `uo_out[3]` generates the tone for a passive
buzzer. The fixed demonstration key starts with `BA2A` as requested.

The public test transaction uses challenge `F15654A8D25FFA1C` and the visually
distinctive hexadecimal response `BA2A5234DEADBEEF`; RTL and gate-level tests
check the same pair.

## Tiny Tapeout interface

The wrapper matches the official IHP Verilog template at commit
`6598bef4d3159f19fe471a2a2225df52e6f5ad25`: `ui_in[7:0]`, `uo_out[7:0]`,
`uio_in[7:0]`, `uio_out[7:0]`, active-high `uio_oe[7:0]`, `ena`, `clk` and
active-low `rst_n`.

| Pins | IEEE DOORSH use |
|---|---|
| `ui_in[3:0]` | active-low keypad columns |
| `ui_in[4]` | SHIFT64 SDI |
| `ui_in[5]` | synchronized SHIFT64 SCLK strobe |
| `ui_in[6]` | SHIFT64 CS_n |
| `ui_in[7]` | unused |
| `uo_out[0]` | CHALLENGE_READY |
| `uo_out[1]` | tied low |
| `uo_out[2]` | SHIFT64 SDO |
| `uo_out[3]` | 2 kHz passive-buzzer drive |
| `uo_out[7:4]` | tied low |
| `uio[3:0]` | open-drain keypad row enables |
| `uio[7:4]` | high impedance |

`SCLK` is synchronized into the project-clock domain and is never used as an
RTL clock.

## Public page review

The short public page follows the Tiny Tapeout pattern used by comparable
projects: title and description, How it works, How to test, external hardware,
pinout and one reference transaction. Research links are recorded separately
in `docs/PROJECT_REFERENCES.md`; they are not presented as project features or
acknowledgements.

## Verification

The final passive-buzzer and BA2A-key configuration passed the complete local
regression: 15 Python model tests, standalone RTL tests, 1024 seeded SIMON
vectors, seven fixed-key configurations, 256 randomized authorization
sessions, all 65,536 keypad masks, formal BMC/induction/reachability, mutation
score 7/7 and synthesis. Coverage ran 12 cases with 88.8% unique RTL line
coverage.

The final one-tile physical run completed with zero routing/Magic DRC, LVS,
antenna, setup, hold, maximum-slew and maximum-capacitance violations. The
official Tiny Tapeout precheck, including KLayout SG13G2 DRC, passed. The
post-route no-SDF gate-level test passed with the public hexadecimal pair.
Full SDF simulation remains unsupported and is not reported as PASS.

Exact commands, tool versions and log locations are recorded in
`reports/PROGRESS.md`; metrics and limitations are consolidated in
`reports/FINAL.md`.
