# D00RSH publication and interface audit

Date: 2026-09-18. Scope: public metadata/documentation, Tiny Tapeout wrapper,
clock use, comparable project pages, programme acknowledgement and current
local regression. This audit does not submit, order or pay for fabrication.

## Result

```text
PUBLIC_NAME_D00RSH=PASS
AUTHOR_AFFILIATION=PASS
TT_PIN_MAPPING=PASS
CLOCK_DISCIPLINE=PASS
IEEE_ACKNOWLEDGEMENT=PASS
REFERENCE_PROJECT_REVIEW=PASS
LOCAL_REGRESSION=PASS
REMOTE_CI_FOR_THIS_CHANGE=NOT_RUN
```

The public product name is D00RSH. The verified physical implementation keeps
the internal identifier `tt_um_rumcajs` and matching artifact filenames; this
is an implementation/provenance exception, not the public product identity.
Renaming it would require a new GDS/netlist identity and sign-off.

## Tiny Tapeout pins and clocks

The wrapper was compared with the official IHP Verilog template at commit
`6598bef4d3159f19fe471a2a2225df52e6f5ad25`. Both expose `ui_in[7:0]`,
`uo_out[7:0]`, `uio_in[7:0]`, `uio_out[7:0]`, active-high `uio_oe[7:0]`,
`ena`, `clk` and active-low `rst_n`.

| Pins | D00RSH use | Audit result |
|---|---|---|
| `ui_in[3:0]` | active-low keypad columns | PASS; input path only |
| `ui_in[4]` | SHIFT64 SDI | PASS; synchronized into `clk` domain |
| `ui_in[5]` | SHIFT64 SCLK | PASS; synchronized data/strobe input, never an RTL clock |
| `ui_in[6]` | SHIFT64 CS_n | PASS; synchronized framing input |
| `ui_in[7]` | unused | PASS; cannot affect function |
| `uo_out[0]` | CHALLENGE_READY | PASS; correct-PIN authorization only |
| `uo_out[1]` | reserved low | PASS |
| `uo_out[2]` | SHIFT64 SDO | PASS |
| `uo_out[3]` | buzzer | PASS |
| `uo_out[7:4]` | reserved low | PASS |
| `uio[3:0]` | keypad rows | PASS; `uio_out=0`, `uio_oe` performs open-drain low/Z behavior |
| `uio[7:4]` | unused | PASS; high impedance |

`info.yaml` declares `clock_hz: 1000000`, matching `CLOCK_PERIOD=1000 ns` in
the physical configuration and the user protocol. Repository-wide static
search found no `posedge sclk` or `posedge serial_sclk`. Unit and integration
tests exercise asynchronous SCLK phases and the wrapper pin map.

## Public identity and programme acknowledgement

`info.yaml`, README, datasheet and wiki identify the author as:

> Koło Naukowe BAZA, Politechnika Warszawska — ZT, PN, MK, JT, KK

The public documents acknowledge the IEEE Open Silicon Initiative. The wording
is based on the official IEEE HART programme page, which lists IEEE EDS, SSCS,
CASS, CEDA and the IEEE Nanotechnology Council as funding partners and Tiny
Tapeout as an external partner. Tiny Tapeout's official credits separately
identify SwissChips as the funder of its IHP 130 nm work.

Primary sources:

- `https://hart.ieee.org/projects/chip-fabrication/`
- `https://tinytapeout.com/credits/`

## Comparable projects and page organization

The review used four primary public sources: the IEEE Open Silicon water-level
controller, Lock system v2 (IEEE), Shiftregister Challenge 40 Bit, and the
sibling IHP acoustic drone detector. The applied pattern is `About`, `How it
works`, `How to test`, `External hardware`, complete IO/clock information and
explicit limitations. Full links and the lesson taken from each source are in
`docs/PROJECT_REFERENCES.md`. No third-party RTL, images or prose were copied.

## Buzzer evidence boundary

The hardened ASIC candidate remains `ACTIVE_BUZZER=1`, for an active buzzer.
The RTL independently implements and tests `ACTIVE_BUZZER=0` for a passive
buzzer. The project team reports that the passive mode passed on its FPGA with
a buzzer without a built-in generator. This user-supplied hardware observation
is recorded but not presented as a repository-reproduced ASIC measurement.
Changing the hardened ASIC default would alter the synthesized design and
requires a new physical flow and sign-off, so it was not done silently here.

## Commands and results

Tools: Python 3.14.4, Git 2.53.0, Icarus Verilog 12.0, Verilator 5.032.

```text
make upload-check
  PASS: metadata, exact 24-pin mapping, full author affiliation, source list,
        IHP jobs, wrapper ports and no SCLK-derived RTL clock

make lint
  PASS: Python compile, Icarus, Yosys check and Verilator lint

make wiki-build
python3 scripts/check_wiki.py
  PASS: 12 HTML pages, 398 local references/anchors, 56 search entries,
        no legacy public product name

make test-model test-unit test-integration test-exhaustive test-params formal test-mutations synth
  PASS: 15 model tests; all unit tests; 1024 SIMON vectors; 44-round trace;
        seven fixed-key configurations; active/passive buzzer; full wrapper;
        256 random sessions; all 65536 keypad masks; parameter rejection;
        formal SAT/BMC/induction/reachability; mutation score 7/7; synthesis

make test-gatelevel
  PASS: fresh IHP standard-cell netlist smoke for reset/ena, malformed RX,
        authorized response, wrong-PIN rejection and attempt limit; no SDF

git diff --check
  PASS
```

Formal, synthesis and gate-level tools write their detailed outputs under
`reports/logs/`.
The prior full physical, precheck and gate-level evidence remains applicable
because no RTL or physical configuration was changed in this publication
audit. A new remote CI run is required after publication of these changes.
