# D00RSH — Tiny Tapeout IHP26b

**Koło Naukowe BAZA, Politechnika Warszawska — ZT, PN, MK, JT, KK**

D00RSH is a deliberately small Tiny Tapeout challenge-response authenticator.
A 4×4 matrix keypad authorizes one challenge after the correct PIN. One fixed
demonstration key encrypts it over a custom 64-bit SHIFT64 link using full
SIMON64/128 with 44 rounds. Wrong PINs consume attempts but never authorize
a challenge or produce a response.
The design is written in synthesizable Verilog-2005 and targets one IHP SG13G2
Tiny Tapeout IHP26b tile at 1 MHz.

The ASIC top derives its round-key table from one `KEY` parameter at elaboration,
avoiding 128 runtime key-schedule flip-flops. `uo_out[0]` is CHALLENGE_READY;
`uo_out[1]` is tied low. Ciphertext remains on `uo_out[2]`. After sending a
challenge, wait 10000 clock cycles (10 ms at 1 MHz) before reading the response.
Reset/abort erases data serially over 64 cycles with the core interface blocked.
The arbitrary-runtime-key reference core remains independently testable.
The single-key candidate passes local P&R and all10 Tiny Tapeout prechecks.
Full regression and post-route no-SDF gate simulation pass. Full SDF annotation
is unsupported by the simulator; STA is the timing evidence. See
[the final report](reports/FINAL.md) for warnings and verification scope, and
[verified files](artifacts/verified_single_key/README.md) for GDS/LEF/netlist.

Start with [the project datasheet](docs/info.md). The normative behavior and
verification scope are amended by [docs/SINGLE_KEY.md](docs/SINGLE_KEY.md),
which takes precedence over the earlier two-key specification and test plan.
`make doctor` reports the available local
toolchain; the other Make targets run the model, RTL, formal, synthesis and
physical gates without silently treating missing tools as success.

This is an educational volatile-lockout profile. Its hard-coded demo key and
resettable attempt counter are not production authentication security.

## Programme and acknowledgements

D00RSH was developed by Koło Naukowe BAZA at Warsaw University of Technology
as part of the **IEEE Open Silicon Initiative**. We gratefully acknowledge the
programme funding provided by the IEEE Electron Devices Society (EDS), IEEE
Solid-State Circuits Society (SSCS), IEEE Circuits and Systems Society (CASS),
IEEE Council on Electronic Design Automation (CEDA), and IEEE Nanotechnology
Council, as listed by the [official IEEE programme page](https://hart.ieee.org/projects/chip-fabrication/).
Tiny Tapeout is an external programme partner. Tiny Tapeout separately credits
[SwissChips for funding its IHP 130 nm work](https://tinytapeout.com/credits/).

The public page follows Tiny Tapeout's established `About / How it works / How
to test / External hardware / IO` structure. The comparable projects and the
specific documentation lessons used here are recorded in
[docs/PROJECT_REFERENCES.md](docs/PROJECT_REFERENCES.md); no third-party RTL or
project text was copied.

The repository structure and ASIC workflow are based on the Apache-2.0-licensed
Tiny Tapeout Verilog template, pinned in `reports/TARGET.md`.

## Documentation and GitHub upload

- [User datasheet](docs/info.md) — pins, operation and hardware.
- [Wiki sources](wiki/manual/index.md) — build with `make wiki-build` or view locally with `make wiki-serve`.
- [GitHub / Tiny Tapeout upload guide](docs/GITHUB_UPLOAD.md).
- [Local evidence](reports/FINAL.md) — local PASS does not claim a remote CI run.

The physical top identifier remains `tt_um_rumcajs` to preserve the verified
GDS/netlist identity; the product name is D00RSH. Project authorship is recorded
in `info.yaml`; the Git commit author is set separately by the repository owner.

GitHub Actions builds the IHP GDS, precheck, gate-level tests and datasheet.
The wiki workflow builds a downloadable HTML artifact; the official Tiny
Tapeout viewer retains control of GitHub Pages.
