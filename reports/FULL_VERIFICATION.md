# Full verification execution record

User explicitly reopened verification after the earlier stop condition.
2026-09-12; no RTL changes. Current result and qualifications: FINAL.md.

## Executed commands

- `make lint test-model test-unit test-integration test-exhaustive test-params formal test-mutations synth`: exit0; reports/logs/full-verification-regression.log.
- `make coverage`: exit0; full-verification-coverage.log and coverage.log.
- `make doctor lint`: exit0; full-final-preflight.log. Doctor now recognizes the actual built-in Yosys SAT route and local raw IHP PDK; sby/Docker remain optional, not falsely labelled installed.
- `GATES=yes make -C test`: exit0 on final/nl netlist; full-tt-gl-entry.log and tt-action-gatelevel.log. test/results.xml passes the official action's presence/no-failure check.
- `make precheck`: exit0 on artifacts/verified_single_key; full-packaged-precheck.log; copied full-precheck.xml and full-precheck.md. No rule changes.
- The successful physical run is unchanged. Final metrics copied to full-physical-metrics.json. Full run and command remain in SINGLE_KEY.md.

Tool details: Icarus12 for main RTL regression; Icarus13 from the exact
TinyTapeout/iverilog v13.0 release for final GL; Verilator5.032; Yosys0.52
SAT/mapping; LibreLane3.0.5 AppImage with OpenROAD/Magic/Netgen/KLayout0.30.7.
The no-SDF GL script now uses original models with Icarus13; a documented
Icarus12 functional-model fallback remains for older environments.

## Precheck environment reproduction

The unchanged tt-support-tools commit is01d5d2814fa9dd61e9d211e0b235a4a592a9316a.
tt-gds-action ttihp26b resolves to85a4c4128c10aa024ea8a02c7b3828d11c14ed90.
Its precheck selects CIEL IHP c4b8b4e5e7a05f375cca3815d51b3a37721fbf5c.
That package was fetched with:

```sh
/var/tmp/rumcajs-appimage/appimage_extracted_7ee003e414b503dafc1ee3684d415174/AppRun ciel fetch --pdk-root /mnt/c/Users/user/Desktop/HACKATHON/.tools/ciel-precheck --pdk-family ihp-sg13g2 c4b8b4e5e7a05f375cca3815d51b3a37721fbf5c
```

Log: full-precheck-pdk-fetch.log; fetched package approximately779MB.
Pinned Python dependencies from tt/precheck/requirements.txt are installed
in .tools/precheck-py312. scripts/run_precheck.sh binds this environment
and the correct PDK. Overrides: PRECHECK_PDK_ROOT, PRECHECK_PYTHON,
LIBRELANE_RUNNER; optional GDS argument via `make precheck GDS=/absolute/path`.
The required rule deck is checked before invocation. This is a local execution,
not a claim that a GitHub workflow has run.

KLayout0.30.8 Ubuntu package was located at the [official download page](https://www.klayout.de/build.html)
and extracted locally but not used: the corrected CIEL rule deck runs under
the existing AppImage CLI. Do not report the downloaded binary as executed.
Total environment remains below the approved50GB; no global install or
permission changes were performed.

## Extra SDF experiments — not a required passing gate

Compiled original PDK cell models and the post-route netlist with Icarus13
`-g2012 -ginterconnect -gspecify -DSDF_RUN`, CLOCK_HALF_NS=500 and
IO_SETTLE_NS=100. Ran each original final/sdf corner using +SDF_FILE.
Logs: full-sdf-{fast_1p32V_m40C,typ_1p20V_25C,slow_1p08V_125C}.log.
All three exit1: unsupported intermodpaths and malformed-COND diagnostics,
followed by an invalid annotation and a functional
timeout. This is an unsuccessful simulator experiment, not a valid delayed
simulation. Original SDF/netlists were preserved; nothing was filtered out.
An earlier attempt omitted -ginterconnect and was terminated once the missing
net diagnostics established invalid annotation. No such result is marked PASS.

STA remains the timing evidence: all3 corners, extracted parasitics, no
setup/hold/slew/cap violations; retain15 CTS fanout warnings and the narrow
7.94ps worst hold slack. Analog metastability and physical attacks are outside
these digital checks.
