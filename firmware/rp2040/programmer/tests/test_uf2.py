"""Check the portable RP2040 UF2 fallback independently of the firmware build."""
from pathlib import Path
import runpy
import struct
import unittest

convert = runpy.run_path(str(Path(__file__).parents[1] / 'tools/bin_to_uf2.py'))['convert']


class UF2Tests(unittest.TestCase):
    def test_headers_addresses_and_payload_roundtrip(self):
        original = bytes(range(256)) * 9 + b'last page'
        output = convert(original)
        self.assertEqual(len(output), 10 * 512)
        reconstructed = bytearray()
        for index in range(10):
            block = output[index * 512:(index + 1) * 512]
            self.assertEqual(struct.unpack('<8I', block[:32]),
                             (0x0A324655, 0x9E5D5157, 0x2000, 0x10000000 + index * 256,
                              256, index, 10, 0xE48BFF56))
            self.assertEqual(struct.unpack('<I', block[-4:])[0], 0x0AB16F30)
            reconstructed += block[32:288]
        self.assertEqual(reconstructed[:len(original)], original)
        self.assertEqual(reconstructed[len(original):], bytes(256 - len(b'last page')))

    def test_invalid_image_sizes(self):
        for size in (0, 255, 2 * 1024 * 1024 + 1):
            with self.assertRaises(ValueError):
                convert(bytes(size))


if __name__ == '__main__':
    unittest.main()
