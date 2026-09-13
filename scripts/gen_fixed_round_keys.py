#!/usr/bin/env python3
"""Emit two independent-model SIMON64/128 round-key schedules."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from model.simon64_128 import expand_key  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("good", type=lambda value: int(value, 0))
    parser.add_argument("bad", type=lambda value: int(value, 0))
    args = parser.parse_args()
    good = expand_key(args.good)
    bad = expand_key(args.bad)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="ascii") as handle:
        for good_word, bad_word in zip(good, bad, strict=True):
            handle.write(f"{good_word:08x}{bad_word:08x}\n")
    print(f"generated 44 fixed-key pairs: {args.output}")


if __name__ == "__main__":
    main()
