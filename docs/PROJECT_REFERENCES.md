# IEEE DOORSH — public-project references

Checked: 2026-09-18. These are primary public pages or repositories. They were
used to decide how to present IEEE DOORSH; no RTL, diagrams or prose were copied.

## Documentation pattern used

Tiny Tapeout project pages consistently make the observable design easy to
evaluate by separating:

1. a short `About this project` statement with author and context;
2. `How it works`, limited to behavior a user needs to understand;
3. a reproducible `How to test` sequence with concrete expected outputs;
4. `External hardware` and electrical assumptions;
5. a complete pin table and clock value;
6. limitations that prevent a demo from being mistaken for a production part.

IEEE DOORSH applies that pattern in `docs/info.md`, then keeps deeper verification,
physical metrics and security qualifications in the linked reports.

## Comparable published projects

| Project | Why it is relevant | Documentation lesson applied |
|---|---|---|
| [IEEE Open-silicon 2026 x NITHUB: Fluid Level Detector and Controller](https://tinytapeout.com/chips/ttsky26b/tt_um_oreoluwa_water_level) | An official Tiny Tapeout page for an IEEE Open Silicon project | State programme context separately from behavior; give a numbered physical-pin test. |
| [Tiny Tapeout: Lock system v2 (IEEE)](https://tinytapeout.com/chips/ttsky26b/tt_um_wokwi_461622504612675585) | Password/lock behavior with visual and audible outputs | Spell out the accepted code, wrong-code behavior and external buzzer/LED hardware. |
| [Shiftregister Challenge 40 Bit](https://tinytapeout.com/chips/ttsky26b/tt_um_thorsten_shiftregister) | A serialized challenge-like input with a deterministic result | State bit order, reset procedure, exact number of clocks and the output to inspect. |
| [Acoustic drone detector — Tiny Tapeout IHP 1×1](https://github.com/magnetoField/ieee-sep-2026-2nd-ihp) | A detailed sibling IHP project with measured verification and physical results | Keep measured metrics, commands and limitations distinct from the short user-facing explanation. |

## Programme and platform sources

- [IEEE HART — Chip Fabrication](https://hart.ieee.org/projects/chip-fabrication/)
  identifies the IEEE Open Silicon Initiative, its IEEE funding partners and
  Tiny Tapeout as an external partner.
- [Tiny Tapeout documentation guide](https://tinytapeout.com/guides/documentation/)
  confirms that `info.yaml` and `docs/info.md` provide the public project
  metadata and datasheet content.
- [Pinned IHP Verilog wrapper](https://github.com/TinyTapeout/ttihp-verilog-template/blob/6598bef4d3159f19fe471a2a2225df52e6f5ad25/src/project.v)
  is the authoritative wrapper interface used for the pin audit.
- [Tiny Tapeout GPIO specification](https://tinytapeout.com/specs/gpio/) and
  [clock specification](https://tinytapeout.com/specs/clock/) define the
  platform-level pins and externally supplied project clock.

## IEEE DOORSH-specific distinction

The related lock and shift-register projects are presentation references, not
security baselines. IEEE DOORSH additionally uses a matrix keypad with filtered
gestures, one-use authorization, framed 64-bit challenge/response traffic and
full 44-round SIMON64/128. Its public key, resettable lockout and unverified
physical-attack resistance remain explicit demo limitations.
