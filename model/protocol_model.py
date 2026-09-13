"""Pure model helpers for SHIFT64 framing and PIN-attempt accounting."""

from __future__ import annotations

from dataclasses import dataclass


class FrameError(ValueError):
    pass


def decode_shift64(bits: list[int] | tuple[int, ...]) -> int:
    if len(bits) != 64:
        raise FrameError(f"SHIFT64 frame must contain exactly 64 bits, got {len(bits)}")
    value = 0
    for bit in bits:
        if bit not in (0, 1):
            raise FrameError("SHIFT64 frame contains a non-bit value")
        value = (value << 1) | bit
    return value


@dataclass
class AttemptScoreboard:
    max_fails: int = 3
    fail_count: int = 0
    active_token: bool | None = None

    def __post_init__(self) -> None:
        if self.max_fails < 1:
            raise ValueError("max_fails must be positive")

    @property
    def locked(self) -> bool:
        return self.fail_count >= self.max_fails

    def submit(self, pin_matches: bool) -> bool | None:
        """Only a correct PIN creates a single-use token; bad PINs consume attempts."""
        if self.active_token is not None:
            raise RuntimeError("a transaction is already active")
        if self.locked:
            raise PermissionError("lockout prevents a new attempt")
        if not pin_matches:
            self.fail_count = min(self.max_fails, self.fail_count + 1)
            return None
        self.active_token = True
        return True

    def end_session(self) -> None:
        self.active_token = None

    def session_reset(self) -> None:
        self.active_token = None

    def cold_reset(self) -> None:
        self.active_token = None
        self.fail_count = 0
