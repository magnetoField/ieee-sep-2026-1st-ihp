"""Independent word-oriented SIMON64/128 reference model.

This model deliberately does not mirror the bit-serial RTL microarchitecture.
Integers use the representation fixed by SPEC section 9.2: the block is
``{x[31:0], y[31:0]}`` and k0 is the least-significant key word.
"""

from __future__ import annotations

from collections.abc import Iterable

MASK32 = (1 << 32) - 1
ROUNDS = 44
Z3 = 0xFC2CE51207A635DB


def rol32(value: int, amount: int) -> int:
    value &= MASK32
    return ((value << amount) | (value >> (32 - amount))) & MASK32


def ror32(value: int, amount: int) -> int:
    value &= MASK32
    return ((value >> amount) | (value << (32 - amount))) & MASK32


def expand_key(key: int) -> tuple[int, ...]:
    """Return all 44 32-bit round keys for a 128-bit key."""
    if not 0 <= key < (1 << 128):
        raise ValueError("key must be an unsigned 128-bit integer")
    keys = [(key >> (32 * index)) & MASK32 for index in range(4)]
    for index in range(4, ROUNDS):
        tmp = ror32(keys[index - 1], 3) ^ keys[index - 3]
        keys.append(
            (
                0xFFFFFFFC
                ^ keys[index - 4]
                ^ tmp
                ^ ror32(tmp, 1)
                ^ ((Z3 >> (index - 4)) & 1)
            )
            & MASK32
        )
    return tuple(keys)


def encrypt_with_trace(block: int, key: int) -> tuple[int, tuple[tuple[int, int], ...]]:
    """Encrypt one block and return ciphertext plus states after every round."""
    if not 0 <= block < (1 << 64):
        raise ValueError("block must be an unsigned 64-bit integer")
    x = (block >> 32) & MASK32
    y = block & MASK32
    trace: list[tuple[int, int]] = []
    for round_key in expand_key(key):
        x, y = ((rol32(x, 1) & rol32(x, 8)) ^ rol32(x, 2) ^ y ^ round_key) & MASK32, x
        trace.append((x, y))
    return ((x << 32) | y), tuple(trace)


def encrypt(block: int, key: int) -> int:
    return encrypt_with_trace(block, key)[0]


def bits_msb(value: int, width: int) -> tuple[int, ...]:
    if width < 1 or not 0 <= value < (1 << width):
        raise ValueError("value does not fit requested positive width")
    return tuple((value >> index) & 1 for index in range(width - 1, -1, -1))


def bits_to_int(bits: Iterable[int]) -> int:
    value = 0
    count = 0
    for bit in bits:
        if bit not in (0, 1):
            raise ValueError("bits must contain only 0 and 1")
        value = (value << 1) | bit
        count += 1
    if count == 0:
        raise ValueError("at least one bit is required")
    return value

