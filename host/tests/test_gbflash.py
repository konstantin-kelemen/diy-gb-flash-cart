import contextlib
import io
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import gbflash


class Memory:
    def __init__(self):
        self.memory = bytearray(b'\x00' * gbflash.SIZE)
        self.erased = []
        self.reads = []

    def operation(self, op, address=0, data=0):
        if op == 0x12:
            size = dict(gbflash.sectors(0xa8))[address]
            self.memory[address:address + size] = b'\xff' * size
            self.erased.append(address)
        elif op == 0x11:
            self.memory[address] &= data
        else:
            raise AssertionError(op)

    def read(self, address):
        self.reads.append(address)
        return self.memory[address]


class Tests(unittest.TestCase):
    def test_crc_standard_vector_and_corruption(self):
        self.assertEqual(gbflash.packet(b'123456789')[-2:], b'\x29\xb1')
        p = gbflash.packet(bytes.fromhex('500700a5a811'))
        self.assertEqual(gbflash.status(p), p)
        for i in range(64):
            bad = bytearray(p)
            bad[i // 8] ^= 1 << (i % 8)
            with self.assertRaises(RuntimeError):
                gbflash.status(bytes(bad))

    def test_sector_geometry_both_variants(self):
        for device in (0xa7, 0xa8):
            table = gbflash.sectors(device)
            self.assertEqual(len(table), 71)
            end = 0
            for a, size in table:
                self.assertEqual(a, end)
                end = a + size
            self.assertEqual(end, gbflash.SIZE)
        self.assertEqual(gbflash.sectors(0xa8)[0], (0, 8192))
        self.assertEqual(gbflash.sectors(0xa7)[-1], (0x3fe000, 8192))
        with self.assertRaises(RuntimeError):
            gbflash.sectors(0)

    def test_write_crosses_small_sector_and_reads_actual_memory(self):
        memory = Memory()
        image = bytes(range(256)) * 32 + b'\xa5\xff'
        with contextlib.redirect_stdout(io.StringIO()):
            gbflash.write_image(memory, image, 0xa8)
        self.assertEqual(memory.erased, [0, 8192])
        self.assertEqual(memory.memory[:len(image)], image)
        self.assertEqual(memory.memory[len(image):16384], b'\xff' * (16384 - len(image)))
        self.assertEqual(memory.memory[16384], 0)
        self.assertEqual(memory.reads[-len(image):], list(range(len(image))))
        memory.memory[8192] ^= 1
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(RuntimeError, '0x002000:.*A5.*A4'):
                gbflash.verify(memory, image)

    def test_stale_and_error_responses(self):
        programmer = object.__new__(gbflash.Programmer)
        programmer.sequence = 0
        programmer.exchange = lambda _: gbflash.packet(bytes.fromhex('500000000010'))
        with self.assertRaisesRegex(RuntimeError, 'Stale'):
            programmer.operation(0x10)
        programmer.sequence = 0
        programmer.exchange = lambda _: gbflash.packet(bytes.fromhex('500103000011'))
        with self.assertRaisesRegex(RuntimeError, 'timeout'):
            programmer.operation(0x11)


if __name__ == '__main__':
    unittest.main()
