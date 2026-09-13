# Full local verification — single-key IHP26b revision

Date: 2026-09-12. Required local functional and Tiny Tapeout checks PASS.
This is a verified demonstrator candidate, not a claim of silicon testing or
production security. No commit exists (unborn main); source/artifact identity
is recorded by SHA-256 in MANIFEST.sha256.

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

## Implemented and tested

One 128-bit KEY, full SIMON64/128 with 44 rounds. Only a correct complete PIN
raises CHALLENGE_READY on uo_out[0]; uo_out[1] stays zero. Ciphertext remains
on uo_out[2]. Wrong PINs never open a session; the third wrong PIN locks
without a final BAD response. Success does not clear failed-attempt history.
Reset/abort clears the shared data register over 64 clocks with its interface
blocked. Encryption is 9344 clocks; the host waits 10000 clocks (10 ms at
1 MHz) after RX before reading TX.

The complete required regression was rerun: models, all default unit modules,
1024 runtime-key vectors, seven fixed-key configurations, directed/default-pin
and fault integration, 256 random authorization trials, all 65536 keypad
masks, parameter checks, formal checks, 7/7 killed mutations and synthesis.
Formal results distinguish SAT/induction from control BMC20, wrapper BMC2
and scaled timeout BMC12; no unbounded end-to-end proof is claimed.
Coverage: 876/986 unique RTL lines (88.8%), aggregate 1463/1764 (82% as reported
by Verilator). Coverage is measured, not a proof that all bugs are absent.

## Physical and gate-level results

Run runs/single_key_wipe_p80_h0, LibreLane3.0.5, raw IHP PDK e16d00b7,
official 1x1 outline 202.08 × 154.98 µm, AREA0, placement target80%,
extra post-CTS hold margin0. No functional RTL changed during this verification.

- Official synthesis: 20944.7154 µm², 1318 cells.
- Routed standard-cell area excluding filler: 25996.7 µm²; utilization89.8251%.
- Worst setup slack +598.4245 ns, worst hold slack +0.0079368 ns.
- Setup/hold TNS zero in fast, typical and slow corners.
- Routing DRC, Magic DRC, LVS differences, antenna violations: zero.
- Unmodified Tiny Tapeout precheck: all10 checks PASS, including KLayout
  SG13G2 DRC, pin geometry, boundary, layers and Verilog syntax.
- Post-route pin-level simulation PASS with Icarus13 and unmodified original
  cell models, no SDF. The TT action's GATES=yes make entry and results.xml
  checks also pass locally.

The precheck failure is resolved: the official precheck uses CIEL PDK
c4b8b4e5, not the raw PDK used for P&R. The correct package supplies
ihp-sg13g2.drc; no rules or layout were changed. CLI KLayout0.30.7 executed
this deck successfully; the Python bindings are0.30.8. A separately downloaded
0.30.8 CLI was not needed and is not claimed as the executed version.

## Timing qualifications and remaining limitations

STA uses the official flow's generic SDC: 1000 ns clock, 200 ns input/output
delays, propagated clock, 0.25 ns uncertainty. check_setup reports no missing
clocks, unconstrained endpoints or combinational loops. No timing paths were
newly disabled. Of21 unannotated drivers,9 are unused inputs and12 are
unloaded CTS balancing-cell outputs; filtered unannotated count is0.

There are15 max-fanout warnings, all CTS leaf outputs driving10–17 sinks
against a generic limit8. Max capacitance and slew violations are0. The
official flow does not gate max fanout. This warning is retained, not waived
or silently reported as zero. Hold margin is small and only the analyzed
corners/constraints are covered.

Additional SDF experiments on all three corners did NOT pass: Icarus13
cannot fully annotate these SDF files (constant-output interconnects and COND
syntax); setup/hold timing checks are also unsupported by this simulator.
These failed experiments are not evidence of a silicon bug or timing PASS.
No SDF was edited to manufacture a successful result. Timing signoff evidence
is STA, independently of the passing no-SDF functional gate smoke, as allowed
by TEST_PLAN section8.

No remote CI, hardware/analog measurements, secure provisioning or permanent
lockout. Demo key is public; cold reset clears failures; READY intentionally
reveals PIN correctness. Author metadata is still empty and must be supplied
before submission. No push, order, purchase or submission was performed.

## Deliverables and reproduction

[Verified candidate files](../artifacts/verified_single_key/README.md):
GDS, LEF, unpowered IHP gate-level netlist and provenance. The older
artifacts/single_key directory is a historical candidate, not the current bundle.

Detailed commands, evidence and limitations: [FULL_VERIFICATION.md](FULL_VERIFICATION.md).
`make release-check` checks exact status labels, hashes, XML results, physical
metrics and required regression evidence; it does not submit anything.

## GitHub publication update (2026-09-13)

The user selected public repository
https://github.com/magnetoField/ieee-sep-2026-1st-ihp as the publication target.
Authenticated WRITE permission is confirmed. Its existing `main` history
through dde98d17fe0eef79c5d05db6fbf471b7aeebed0e is merged without force-push;
commit 591f96d58bc990ff2b4ac7c46b12b4208281c7a2 was pushed to `main`.
Docs and wiki PASS remotely. The first RTL job FAIL is a packaging portability
issue (shell scripts tracked as 100644); the staged correction changes them to
100755 and adds an upload guard. The official 591f96d run later reports gds,
precheck and gl_test PASS; viewer FAIL is only disabled repository Pages. The
bc292cd RTL rerun found Icarus 13 declaration-order incompatibility in kb.v;
moving existing declarations before their uses leaves logic unchanged and the
complete local regression PASS. Commit ff4b316 confirms the parser fix remotely,
then stops only because Verilator 5.053 promotes the intentional reset-release
SYNCASYNCNET warning. The prepared lint change waives only that named rule and
retains `-Wall`; RTL is unchanged. Fresh remote CI is still required. This step
does not perform a Tiny Tapeout import, production
submission, order or payment.
