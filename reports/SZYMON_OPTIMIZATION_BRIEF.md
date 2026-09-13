# Brief for the next `szymon_fixed` optimization pass

## Objective and baseline

Update: a measured partial improvement is now retained. See
`SZYMON_OPTIMIZATION_RESULTS.md` for current metrics and rejected trials;
the baseline figures below remain the original comparison point.

Reduce the IHP SG13G2 area of `src/szymon_fixed.v` enough for the complete
Tiny Tapeout IHP26b 1x1 design to survive placement, CTS, hold repair and
routing. Do not optimize frequency: encryption may take up to 10 ms at the
1 MHz project clock (up to about 10000 cycles). The current core takes 1408
cycles.

Reproducible isolated baseline:

```text
make area-module MODULE=szymon_fixed
897 Yosys cells
11658.2382 um2 total
4017.0816 um2 sequential
```

The earlier identical-comparison ranking measured about 11.55k um2; small
differences come from synthesis cleanup/context. Always compare candidate and
baseline with the same command and tool checkout.

The complete LibreLane `AREA 0` top is 23683.5522 um2 before physical repair.
A useful engineering target is at least 3.5-4.5k um2 reduction in the cipher
and a top synthesis result below roughly 20k um2. This target is not a fit
guarantee; the official 60% row budget is only 17364.8966 um2.

## Non-negotiable behavior

- Full SIMON64/128: 64-bit block, 128-bit keys, 44 rounds.
- Both independently parameterized demonstration keys and exact published KAT.
- Existing ready-valid command, input, seal and output interfaces.
- Stable `m_bit`/`m_last` under backpressure; exact one-token behavior.
- Abort/reset clearing and safe re-arm behavior.
- One shared 64-bit `a`/`b` data store across load, crypt and output.
- No separate 64-bit RX/TX buffers, shortened output, reduced rounds or
  hard-wired test-only answer.
- Verilog-2005 synthesizable RTL and alternate-key parameter test.

Latency may increase, but record its new exact cycle count in RTL tests, spec
and reports. Do not weaken a test merely to accept changed behavior.

## Fast staged loop

1. For every RTL candidate, run only:

   ```sh
   make area-module MODULE=szymon_fixed
   ```

   Reject an area regression immediately. This takes about two seconds.

2. Only after a measurable area improvement, run:

   ```sh
   make test-unit MODULE=szymon_fixed
   ```

   This covers both default and alternate key pairs, exact KAT, framing,
   latency and abort.

3. Only for the best surviving candidate, run:

   ```sh
   make synth-ihp
   make test-gatelevel
   ```

4. Run the complete model/unit/integration/formal/mutation suite once after a
   candidate is selected. Repeat LibreLane P&R only after a substantial
   complete-top reduction, preferably toward the sub-20k target.

## Already measured dead ends

Do not repeat these exact transformations without a materially different
architecture: two cipher bits per cycle, the previously tried stateful
round-key successor, alternate constant-ROM coding, and a single phase-counter
rewrite all increased same-library area and were reverted. The current
constant schedules are elaboration-time data, but their 2-to-1 selected
1408-bit lookup logic is the principal combinational cost. A new approach
should exploit the available extra cycles rather than duplicate datapaths or
store all round keys.

## Physical acceptance gate

Synthesis improvement alone is not final evidence. Acceptance still requires
the pinned LibreLane 3.0.5 / IHP PDK flow to produce a legal routed 1x1 result
with post-route STA, antenna, DRC and LVS evidence. Current failure details
are in `reports/PHYSICAL.md`.
