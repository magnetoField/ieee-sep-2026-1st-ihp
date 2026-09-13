# Current verification status

Required local verification PASS. See [FINAL.md](FINAL.md) and
[FULL_VERIFICATION.md](FULL_VERIFICATION.md) for scope and reproducible commands.

The complete regression, all 65536 keypad masks, coverage, parameter checks,
formal checks, 7/7 mutation detection and IHP physical checks have executed.
The final model suite has15 tests, including two fail-closed release-gate tests.
All10 TT prechecks and the local action-compatible post-route gate smoke pass.

Gate smoke uses Icarus13 and unmodified library models without SDF. Full SDF
annotation experiments failed because of simulator limitations; they are not
a timing PASS. STA passes all3 corners;15 CTS max-fanout warnings remain,
with zero capacitance/slew violations. No hardware or remote CI run is claimed.
