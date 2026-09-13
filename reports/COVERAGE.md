# Current single-key coverage

Command: make coverage. Exit0, Verilator5.032; all12 cases PASS.
Log: reports/logs/full-verification-coverage.log and reports/logs/coverage.log.
LCOV: reports/coverage.info; current annotated sources: reports/coverage/.

- Unique RTL lines hit:876/986 =88.8%.
- Aggregate tool points:1463/1764, displayed82% by Verilator.
- Cases: directed top, fault top, default wrapper, keypad dynamics, serial
  lengths/unit, auth states, runtime cipher trace, fixed cipher, regs matrix,
  buzzer parameters and timebase parameters.
- Constant/elaboration-only code and illegal-state recovery branches can
  remain unexecuted in normal simulation. No artificial 100% target or new
  exclusions were introduced.
- Coverage does not prove all behaviors correct or replace the independent
  algorithm oracle, protocol assertions, exhaustive keypad test or formal checks.

Historical percentages in old reports are superseded by these measurements.
