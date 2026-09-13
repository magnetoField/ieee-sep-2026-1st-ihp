#!/usr/bin/env python3
"""Emit the published KAT's independent word-level round trace for RTL."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from model.simon64_128 import encrypt_with_trace, expand_key  # noqa: E402

KEY = 0x1B1A1918131211100B0A090803020100
BLOCK = 0x656B696C20646E75


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: gen_simon_trace.py OUTPUT")
    target = Path(sys.argv[1])
    result, trace = encrypt_with_trace(BLOCK, KEY)
    keys = expand_key(KEY)
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("w", encoding="ascii") as handle:
        for round_index, (x, y) in enumerate(trace):
            next_key = keys[round_index + 1] if round_index < 43 else 0
            handle.write(f"{x:08x}{y:08x}{next_key:08x}\n")
    print(f"generated 44-round KAT trace ciphertext={result:016x}")


if __name__ == "__main__":
    main()
