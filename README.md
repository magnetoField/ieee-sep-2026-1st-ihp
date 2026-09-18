# IEEE DOORSH

**Koło Naukowe BAZA, Politechnika Warszawska — ZT, PN, MK, JT, KK**

IEEE DOORSH is a one-tile Tiny Tapeout challenge-response authenticator. A
4×4 keypad accepts the PIN, and a correct PIN authorizes exactly one 64-bit
challenge. The response is calculated with the full 44-round SIMON64/128
cipher and returned over the SHIFT64 serial interface.

The project targets Tiny Tapeout IHP26b, uses synthesizable Verilog-2005 and
runs from a 1 MHz project clock. The submitted hardware has one fixed
configuration: a single demonstration key and a 2 kHz output for a passive
buzzer.

## How it works

1. Enter `1234` on the matrix keypad.
2. `CHALLENGE_READY` rises after the complete correct PIN.
3. Send one 64-bit challenge, MSB first, using `SDI`, `SCLK` and `CS_n`.
4. Wait 10,000 project-clock cycles (10 ms at 1 MHz).
5. Read the 64-bit encrypted response from `SDO` in a second frame.

A wrong PIN never raises `CHALLENGE_READY` and never produces a response.
After three wrong PINs, new attempts remain blocked until cold reset.

## Reference transaction

```text
PIN:       1234
KEY:       BA2A1918131211100B0A090803020100
CHALLENGE: F15654A8D25FFA1C
RESPONSE:  BA2A5234DEADBEEF
```

## External hardware

- passive 4×4 matrix keypad with pull-ups on the column inputs;
- host or microcontroller for the SHIFT64 interface;
- passive buzzer connected through a suitable output driver;
- 1 MHz project clock.

The ASIC output generates the buzzer tone; a buzzer with a built-in oscillator
is not required.

## Tiny Tapeout files

- [Project datasheet](docs/info.md)
- [Pin assignment](info.yaml)
- [Current functional contract](docs/SINGLE_KEY.md)
- [Verification report](reports/FINAL.md)

The Tiny Tapeout top module remains `tt_um_rumcajs` because it is the verified
physical identifier. The public project name is **IEEE DOORSH**.

The fixed key and PIN are public demonstration values. This project is an
educational ASIC demonstrator, not a production security device.
