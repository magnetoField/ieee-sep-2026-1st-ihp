#!/usr/bin/env python3
"""Generate deterministic RTL oracle vectors from the independent word model."""

from __future__ import annotations

import argparse
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from model.simon64_128 import encrypt


def corner_cases() -> list[tuple[int, int]]:
    """Explicit zero/one/alternating/walking-bit cases before seeded randoms."""
    cases = [
        (0, 0),
        ((1 << 64) - 1, (1 << 128) - 1),
        (0xAAAAAAAAAAAAAAAA, 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA),
        (0x5555555555555555, 0x55555555555555555555555555555555),
    ]
    fixed_key = 0x1B1A1918131211100B0A090803020100
    fixed_data = 0x656B696C20646E75
    for bit in range(64):
        cases.append((1 << bit, fixed_key))
        cases.append((((1 << 64) - 1) ^ (1 << bit), fixed_key))
    for bit in range(128):
        cases.append((fixed_data, 1 << bit))
        cases.append((fixed_data, ((1 << 128) - 1) ^ (1 << bit)))
    return cases


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--count", type=int, default=1024)
    parser.add_argument("--seed", type=lambda text: int(text, 0), default=0x52554D43)
    args = parser.parse_args()
    if args.count < 1:
        parser.error("--count must be positive")
    rng = random.Random(args.seed)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="ascii") as handle:
        directed = corner_cases()
        for index in range(args.count):
            if index < len(directed):
                plaintext, key = directed[index]
            else:
                plaintext = rng.getrandbits(64)
                key = rng.getrandbits(128)
            ciphertext = encrypt(plaintext, key)
            handle.write(f"{key:032x}{plaintext:016x}{ciphertext:016x}\n")
    print(
        f"generated {args.count} SIMON vectors: "
        f"directed={min(args.count, len(directed))} random={max(0, args.count-len(directed))} "
        f"seed=0x{args.seed:x}"
    )


if __name__ == "__main__":
    main()
