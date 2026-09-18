# Verified local IEEE DOORSH IHP26b candidate

This directory contains the final GDS, LEF and unpowered post-route netlist
for the fixed Tiny Tapeout configuration:

- project: IEEE DOORSH;
- key: `BA2A1918131211100B0A090803020100`;
- buzzer: fixed passive-buzzer tone, nominally 2 kHz;
- run: `runs/final_ieee_doorsh_ba2a_passive`;
- tile: IHP SG13G2 1×1.

LibreLane 3.0.5 completed with routing DRC, Magic DRC, LVS, antenna and timing
violations at zero. The official Tiny Tapeout precheck, including KLayout
SG13G2 DRC, passed. Post-route no-SDF gate-level simulation passed with the
public transaction `F15654A8D25FFA1C → BA2A5234DEADBEEF`.

This bundle has not been submitted or ordered. The key and PIN are public
demonstration constants, and the lockout remains volatile.
