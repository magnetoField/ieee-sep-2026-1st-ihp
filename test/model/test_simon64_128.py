import json
import random
import unittest
from pathlib import Path

from model.simon64_128 import bits_msb, bits_to_int, encrypt, encrypt_with_trace, expand_key


ROOT = Path(__file__).resolve().parents[2]


class SimonReferenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.kat = json.loads((ROOT / "vectors/simon64_128_kat.json").read_text())

    def test_published_kat_and_landmarks(self) -> None:
        key = int(self.kat["key_hex"], 16)
        block = int(self.kat["plaintext_hex"], 16)
        expected = int(self.kat["ciphertext_hex"], 16)
        ciphertext, trace = encrypt_with_trace(block, key)
        keys = expand_key(key)
        self.assertEqual(ciphertext, expected)
        self.assertEqual((trace[0][0] << 32) | trace[0][1], int(self.kat["round_1_state_hex"], 16))
        self.assertEqual(keys[4], int(self.kat["round_key_4_hex"], 16))
        self.assertEqual(keys[43], int(self.kat["round_key_43_hex"], 16))

    def test_demo_bad_key_response(self) -> None:
        self.assertEqual(
            encrypt(int(self.kat["plaintext_hex"], 16), int(self.kat["demo_bad_key_hex"], 16)),
            int(self.kat["computed_demo_bad_response_hex"], 16),
        )

    def test_wire_serialization_round_trip(self) -> None:
        value = int(self.kat["plaintext_hex"], 16)
        self.assertEqual(bits_to_int(bits_msb(value, 64)), value)
        self.assertEqual(bits_msb(value, 64)[:8], tuple(int(bit) for bit in "01100101"))

    def test_1024_seeded_vectors_have_full_traces(self) -> None:
        rng = random.Random(0x52554D43)
        for _ in range(1024):
            block = rng.getrandbits(64)
            key = rng.getrandbits(128)
            ciphertext, trace = encrypt_with_trace(block, key)
            self.assertEqual(len(trace), 44)
            self.assertEqual(ciphertext, (trace[-1][0] << 32) | trace[-1][1])


if __name__ == "__main__":
    unittest.main()

