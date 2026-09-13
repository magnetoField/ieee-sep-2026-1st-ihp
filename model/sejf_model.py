"""Independent safe-side challenge/response model for demonstrations/tests."""

from __future__ import annotations

import secrets
from collections.abc import Callable
from enum import Enum

from model.simon64_128 import encrypt


class Verdict(Enum):
    GOOD = "GOOD"
    REJECT = "REJECT"


class SejfModel:
    def __init__(
        self,
        key: int,
        randbits: Callable[[int], int] = secrets.randbits,
    ) -> None:
        if not 0 <= key < (1 << 128):
            raise ValueError("key must be 128-bit")
        self.key = key
        self._randbits = randbits
        self._used: set[int] = set()
        self._challenge: int | None = None

    def issue_challenge(self, ready: bool, retry_limit: int = 1024) -> int:
        if not ready:
            raise PermissionError("CHALLENGE_READY must be high")
        if self._challenge is not None:
            raise RuntimeError("an outstanding challenge already exists")
        for _ in range(retry_limit):
            challenge = self._randbits(64)
            if not 0 <= challenge < (1 << 64):
                raise ValueError("challenge source returned a value outside 64 bits")
            if challenge not in self._used:
                self._used.add(challenge)
                self._challenge = challenge
                return challenge
        raise RuntimeError("challenge source repeated too many used values")

    def cancel(self) -> None:
        self._challenge = None

    def verify(self, response: int) -> Verdict:
        if self._challenge is None or not 0 <= response < (1 << 64):
            return Verdict.REJECT
        challenge = self._challenge
        self._challenge = None
        return classify_response(
            response,
            encrypt(challenge, self.key),
        )


def classify_response(response: int, expected: int) -> Verdict:
    return Verdict.GOOD if response == expected else Verdict.REJECT
