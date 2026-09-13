import unittest

from model.keypad_network import ScanKind, classify_scan, low_columns


class KeypadNetworkTests(unittest.TestCase):
    def test_manual_electrical_cases(self) -> None:
        self.assertEqual(low_columns(0, 0), 0)
        self.assertEqual(low_columns(1 << 6, 1), 1 << 2)
        self.assertEqual(low_columns((1 << 4) | (1 << 5), 1), 0b0011)
        self.assertEqual(low_columns((1 << 1) | (1 << 5), 0), 0b0010)
        three_corners = (1 << 0) | (1 << 1) | (1 << 4)
        self.assertEqual(low_columns(three_corners, 1), 0b0011)
        self.assertEqual(low_columns(0xFFFF, 3), 0b1111)

    def test_single_key_classification(self) -> None:
        for key_id in range(16):
            result = classify_scan(1 << key_id)
            self.assertEqual(result.kind, ScanKind.ONE)
            self.assertEqual(result.key_id, key_id)

    def test_all_static_masks(self) -> None:
        for mask in range(1 << 16):
            result = classify_scan(mask)
            if mask == 0:
                self.assertEqual(result.kind, ScanKind.NONE)
            elif mask & (mask - 1) == 0:
                self.assertEqual(result.kind, ScanKind.ONE)
                self.assertEqual(result.key_id, mask.bit_length() - 1)
            else:
                self.assertEqual(result.kind, ScanKind.MULTI, f"mask={mask:04x}")


if __name__ == "__main__":
    unittest.main()

