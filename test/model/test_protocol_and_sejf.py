import random
import unittest

from model.protocol_model import AttemptScoreboard, FrameError, decode_shift64
from model.sejf_model import SejfModel, Verdict, classify_response
from model.simon64_128 import bits_msb, encrypt


GOOD = 0x1B1A1918131211100B0A090803020100
BAD = 0xF0E1D2C3B4A5968778695A4B3C2D1E0F


class ProtocolTests(unittest.TestCase):
    def test_shift64_exact_length_and_order(self) -> None:
        value = 0x656B696C20646E75
        self.assertEqual(decode_shift64(bits_msb(value, 64)), value)
        for length in (0, 1, 63, 65, 127, 128):
            with self.assertRaises(FrameError):
                decode_shift64([0] * length)

    def test_attempt_is_counted_before_token_and_never_rolled_back(self) -> None:
        board = AttemptScoreboard(max_fails=3)
        for expected in (1, 2, 3):
            token = board.submit(False)
            self.assertEqual(board.fail_count, expected)
            self.assertIsNone(token)
            self.assertIsNone(board.active_token)
            board.session_reset()
            self.assertEqual(board.fail_count, expected)
        with self.assertRaises(PermissionError):
            board.submit(True)
        board.cold_reset()
        self.assertEqual(board.fail_count, 0)

    def test_success_does_not_clear_failures(self) -> None:
        board = AttemptScoreboard()
        board.submit(False)
        board.end_session()
        board.submit(True)
        board.end_session()
        self.assertEqual(board.fail_count, 1)


class SejfTests(unittest.TestCase):
    def test_good_bad_reject_and_single_use(self) -> None:
        rng = random.Random(12345)
        safe = SejfModel(GOOD, rng.getrandbits)
        challenge = safe.issue_challenge(ready=True)
        self.assertEqual(safe.verify(encrypt(challenge, GOOD)), Verdict.GOOD)
        self.assertEqual(safe.verify(encrypt(challenge, GOOD)), Verdict.REJECT)
        challenge = safe.issue_challenge(ready=True)
        self.assertEqual(safe.verify(encrypt(challenge, BAD)), Verdict.REJECT)
        safe.issue_challenge(ready=True)
        self.assertEqual(safe.verify(0), Verdict.REJECT)

    def test_no_challenge_without_ready(self) -> None:
        safe = SejfModel(GOOD)
        with self.assertRaises(PermissionError):
            safe.issue_challenge(ready=False)
        self.assertEqual(classify_response(7, 8), Verdict.REJECT)

    def test_repeated_rng_candidates_are_not_reused(self) -> None:
        values = iter((9, 9, 10))
        safe = SejfModel(GOOD, lambda _: next(values))
        self.assertEqual(safe.issue_challenge(ready=True), 9)
        safe.cancel()
        self.assertEqual(safe.issue_challenge(ready=True), 10)


if __name__ == "__main__":
    unittest.main()
