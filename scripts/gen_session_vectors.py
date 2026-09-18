#!/usr/bin/env python3
"""Generate deterministic independent E2E session expectations."""

from __future__ import annotations

import argparse
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from model.simon64_128 import encrypt  # noqa: E402


KEY = 0xBA2A1918131211100B0A090803020100


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--count", type=int, default=256)
    parser.add_argument("--seed", type=lambda value: int(value, 0), default=0xE2E52517)
    args = parser.parse_args()
    if args.count < 1:
        raise SystemExit("count must be positive")

    rng = random.Random(args.seed)
    fail_count = 0
    seen: set[int] = set()
    rows: list[str] = []
    cold_resets = 0
    good_sessions = 0
    bad_sessions = 0
    for index in range(args.count):
        reset_before = fail_count == 3 or (index > 0 and rng.randrange(29) == 0)
        if reset_before:
            fail_count = 0
            cold_resets += 1

        # Draw independently, but force both classes into every short regression.
        good = bool(rng.getrandbits(1))
        if index == 0:
            good = True
        elif index == 1:
            good = False
        if good:
            good_sessions += 1
        else:
            bad_sessions += 1
            fail_count += 1

        challenge = rng.getrandbits(64)
        while challenge in seen:
            challenge = rng.getrandbits(64)
        seen.add(challenge)
        response = encrypt(challenge, KEY) if good else 0
        packed = (
            (int(reset_before) << 129)
            | (int(good) << 128)
            | (challenge << 64)
            | response
        )
        rows.append(f"{packed:033x}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        "// packed as {cold_reset_before, good_pin, challenge[63:0], response[63:0]}\n"
        + "\n".join(rows)
        + "\n",
        encoding="ascii",
    )
    print(
        f"generated {args.count} sessions seed=0x{args.seed:x} "
        f"good={good_sessions} bad={bad_sessions} cold_resets={cold_resets}"
    )


if __name__ == "__main__":
    main()
