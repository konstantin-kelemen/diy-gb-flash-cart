import contextlib
import io
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import gbflash


class Bridge:
    """Binary USB/FPGA protocol model, deliberately returns fragmented reads."""
    def __init__(self):
        self.memory = bytearray(b'\xff' * gbflash.SIZE)
        self.sequence = 254
        self.armed = False
        self.output = b''
        self.operations = []
        self.erased = []
        self.corrupt = None
        self.fragment = 17

    def reset_input_buffer(self):
        self.output = b''

    def read(self, length):
        result = self.output[:min(length, self.fragment)]
        self.output = self.output[len(result):]
        return result

    def write(self, frame):
        assert frame[:4] == b'GB3Q'
        assert gbflash.packet(frame[4:-2]) == frame[4:]
        size = int.from_bytes(frame[4:6], 'big')
        request = frame[6:-2]
        assert len(request) == size
        if request == b'\x01':
            response = bytes.fromhex('4742464303000004')
        elif request == b'\x02':
            response = gbflash.packet(bytes([0x50, self.sequence, 0, 0, 0, 0, 0, 0]))
        else:
            assert gbflash.packet(request[:-2]) == request
            op, seq = request[:2]
            assert seq == (self.sequence + 1) % 256
            self.sequence = seq
            address = int.from_bytes(request[2:5], 'big')
            length = int.from_bytes(request[5:7], 'big')
            self.operations.append((op, address, length))
            code, result, count, payload = 0, 0, 0, b''
            if op == 0x20:
                assert request[7] == 0xa5
                self.armed = True
            elif op == 0x21:
                self.armed = False
            elif op != 0x30 and not self.armed:
                code = 9
            elif op == 0x13:
                result = 0xa8c2
            elif op == 0x14:
                pass
            elif op == 0x30:
                count = length
                payload = gbflash.packet(bytes(self.memory[address:address + length]))
                if self.corrupt == 'block_crc':
                    payload = payload[:-1] + bytes([payload[-1] ^ 1])
            elif op == 0x31:
                assert len(request) == 10 + length
                for offset, value in enumerate(request[8:-2]):
                    self.memory[address + offset] &= value
                count = length
            elif op == 0x12:
                size = dict(gbflash.sectors(0xa8))[address]
                self.memory[address:address + size] = b'\xff' * size
                self.erased.append(address)
            else:
                raise AssertionError(op)
            if self.corrupt == 'sequence':
                seq = (seq + 1) % 256
            if self.corrupt == 'count':
                count -= 1
            if self.corrupt == 'timeout':
                code, count = 3, 13
            response = gbflash.packet(bytes([0x50, seq, code, op, result & 255,
                                             result >> 8, count & 255, count >> 8])) + payload
        self.output = b'GB3R' + gbflash.packet(len(response).to_bytes(2, 'big') + response)
        if self.corrupt == 'usb_crc':
            self.output = self.output[:-1] + bytes([self.output[-1] ^ 1])
        if self.corrupt == 'truncated':
            self.output = self.output[:9]
        return len(frame)


class Tests(unittest.TestCase):
    def make_programmer(self):
        bridge = Bridge()
        with patch('gbflash.time.sleep'):
            programmer = gbflash.Programmer(bridge)
        return programmer, bridge

    def test_crc_standard_vector_and_corruption(self):
        self.assertEqual(gbflash.packet(b'123456789')[-2:], b'\x29\xb1')
        raw = gbflash.packet(bytes.fromhex('50070030a5000004'))
        self.assertEqual(gbflash.status(raw), raw)
        for i in range(80):
            bad = bytearray(raw)
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

    def test_binary_read_all_byte_values_and_sequence_wrap(self):
        programmer, bridge = self.make_programmer()
        data = bytes(range(256)) * 4
        bridge.memory[123:1147] = data
        for _ in range(3):
            self.assertEqual(programmer.read_block(123, 1024), data)
        self.assertEqual(programmer.sequence, 1)
        self.assertEqual(bridge.operations, [(0x30, 123, 1024)] * 3)

    def test_last_byte_and_invalid_ranges(self):
        programmer, bridge = self.make_programmer()
        self.assertEqual(programmer.read_block(gbflash.SIZE - 1, 1), b'\xff')
        for address, length in [(0, 0), (0, 1025), (-1, 1), (gbflash.SIZE - 1, 2)]:
            with self.assertRaises(ValueError):
                programmer.read_block(address, length)
        self.assertEqual(len(bridge.operations), 1)

    def test_transport_faults_stop_without_retry(self):
        for fault in ('usb_crc', 'block_crc', 'truncated', 'sequence', 'count'):
            with self.subTest(fault=fault):
                programmer, bridge = self.make_programmer()
                bridge.corrupt = fault
                with self.assertRaises(RuntimeError):
                    programmer.read_block(0, 1024)
                self.assertEqual(len(bridge.operations), 1)

    def test_partial_program_error_reports_failing_address(self):
        programmer, bridge = self.make_programmer()
        programmer.operation(0x20, data=0xa5)
        bridge.corrupt = 'timeout'
        with self.assertRaisesRegex(RuntimeError, '0x00100D: Flash timeout'):
            programmer.write_block(0x1000, b'\x55' * 31)
        self.assertEqual(len(bridge.operations), 2)

    def test_write_crosses_sector_and_partial_block_tail(self):
        programmer, bridge = self.make_programmer()
        bridge.memory[:] = b'\x00' * gbflash.SIZE
        image = bytes(range(256)) * 32 + b'\xa5\xff'
        with contextlib.redirect_stdout(io.StringIO()):
            device = programmer.identify()
            gbflash.write_image(programmer, image, device)
        self.assertEqual(bridge.erased, [0, 8192])
        self.assertEqual(bridge.memory[:len(image)], image)
        self.assertEqual(bridge.memory[len(image):16384], b'\xff' * (16384 - len(image)))
        self.assertEqual(bridge.memory[16384], 0)
        writes = [(a, n) for op, a, n in bridge.operations if op == 0x31]
        self.assertEqual(writes, [(i * 1024, 1024) for i in range(8)] + [(8192, 2)])
        bridge.memory[8192] ^= 1
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(RuntimeError, '0x002000: expected A5, read A4'):
                gbflash.verify(programmer, image)

    def test_ff_blocks_are_skipped_only_after_erase_check(self):
        programmer, bridge = self.make_programmer()
        programmer.operation(0x20, data=0xa5)
        with contextlib.redirect_stdout(io.StringIO()):
            gbflash.write_image(programmer, b'\xff' * 2048, 0xa8)
        self.assertFalse(any(op == 0x31 for op, _, _ in bridge.operations))
        self.assertEqual(sum(n for op, _, n in bridge.operations if op == 0x30), 8192 + 2048)

    def test_locked_block_write_is_rejected(self):
        programmer, bridge = self.make_programmer()
        with self.assertRaisesRegex(RuntimeError, 'locked'):
            programmer.write_block(0, b'\x00')
        self.assertEqual(bridge.memory[0], 255)

    def test_full_dump_uses_4096_requests(self):
        programmer, bridge = self.make_programmer()
        for address in range(0, gbflash.SIZE, gbflash.BLOCK):
            self.assertEqual(len(programmer.read_block(address, gbflash.BLOCK)), 1024)
        self.assertEqual(len(bridge.operations), 4096)


if __name__ == '__main__':
    unittest.main()
