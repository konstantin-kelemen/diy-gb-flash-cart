import contextlib
import io
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import gbflash


class Bridge:
    """Binary USB/FPGA protocol model, deliberately returns fragmented reads."""
    def __init__(self):
        self.memory = bytearray(b'\xff' * gbflash.SIZE)
        self.device = 0xa8
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
        assert frame[:4] == b'GB5Q'
        assert gbflash.packet(frame[4:-4]) == frame[4:]
        size = int.from_bytes(frame[4:6], 'big')
        request = frame[6:-4]
        assert len(request) == size
        if request == b'\x01':
            response = bytes.fromhex('4742464305000040')
        elif request == b'\x02':
            response = bytes([0, self.sequence, 0, 0, 0, 0, 0, 0])
        else:
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
                result = (self.device << 8) | 0xc2
            elif op == 0x14:
                pass
            elif op == 0x30:
                count = length
                payload = bytes(self.memory[address:address + length])
                if self.corrupt == 'block_length':
                    payload = payload[:-1]
            elif op == 0x31:
                assert len(request) == 8 + length
                for offset, value in enumerate(request[8:]):
                    self.memory[address + offset] &= value
                count = length
            elif op == 0x12:
                size = dict(gbflash.sectors(self.device))[address]
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
            response = bytes([op, seq, code, result & 255, result >> 8,
                              count & 255, count >> 8, 0]) + payload
        self.output = b'GB5R' + gbflash.packet(len(response).to_bytes(2, 'big') + response)
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

    def test_cli_image_capacity(self):
        for command in ('write', 'verify'):
            for size in (0, 1, 32769, 1048576, gbflash.SIZE, gbflash.SIZE + 1):
                with self.subTest(command=command, size=size):
                    image = b'\x55' * size
                    argv = ['gbflash', '--port', 'test-port', command, 'test.gb']
                    if command == 'write':
                        argv.append('--erase')
                    serial = MagicMock()
                    with patch.object(sys, 'argv', argv), \
                         patch.object(Path, 'read_bytes', return_value=image), \
                         patch.dict(sys.modules, {'serial': serial}), \
                         patch('gbflash.Programmer') as programmer, \
                         patch('gbflash.write_image') as write, \
                         patch('gbflash.verify') as verify, \
                         contextlib.redirect_stdout(io.StringIO()), \
                         contextlib.redirect_stderr(io.StringIO()):
                        programmer.return_value.identify.return_value = 0xa8
                        result = gbflash.main()
                        if 0 < size <= gbflash.SIZE:
                            self.assertEqual(result, 0)
                            serial.Serial.assert_called_once()
                            operation = write if command == 'write' else verify
                            expected = [programmer.return_value, image]
                            if command == 'write':
                                expected.append(0xa8)
                            operation.assert_called_once_with(*expected)
                            programmer.return_value.operation.assert_called_once_with(0x21)
                        else:
                            self.assertEqual(result, 1)
                            serial.Serial.assert_not_called()
                            write.assert_not_called()
                            verify.assert_not_called()

    def test_crc_standard_vector_and_status(self):
        self.assertEqual(gbflash.packet(b'123456789')[-4:], bytes.fromhex('2639f4cb'))
        self.assertEqual(gbflash.status(bytes(8)), bytes(8))
        for raw in (bytes(7), bytes(9), bytes(7)+b'\x01'):
            with self.assertRaises(RuntimeError):
                gbflash.status(raw)

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
        for address, length in [(0, 0), (0, gbflash.BLOCK + 1), (-1, 1), (gbflash.SIZE - 1, 2)]:
            with self.assertRaises(ValueError):
                programmer.read_block(address, length)
        self.assertEqual(len(bridge.operations), 1)

    def test_transport_faults_stop_without_retry(self):
        for fault in ('usb_crc', 'block_length', 'truncated', 'sequence', 'count'):
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
        self.assertEqual(writes, [(0, 8194)])
        bridge.memory[8192] ^= 1
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(RuntimeError, '0x002000: expected A5, read A4'):
                gbflash.verify(programmer, image)

    def test_lsdj_full_cycle_both_boot_variants(self):
        rom_path = Path(__file__).resolve().parents[2] / 'roms/lsdj9_4_2.gb'
        if rom_path.exists():
            image = rom_path.read_bytes()
        else:
            # ROM не распространяется с репозиторием.
            data = bytearray((i ^ (i >> 14)) & 255 for i in range(1048576))
            data[0x147:0x14a] = bytes.fromhex('1b0504')
            image = bytes(data)
        self.assertEqual(len(image), 1048576)
        self.assertEqual(image[0x147:0x14a], bytes.fromhex('1b0504'))
        for device in (0xa7, 0xa8):
            with self.subTest(device=device):
                programmer, bridge = self.make_programmer()
                bridge.device = device
                bridge.memory[:] = b'\x55' * gbflash.SIZE
                before = b''.join(programmer.read_block(a, gbflash.BLOCK)
                                  for a in range(0, gbflash.SIZE, gbflash.BLOCK))
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(programmer.identify(), device)
                    gbflash.write_image(programmer, image, device)
                after = b''.join(programmer.read_block(a, gbflash.BLOCK)
                                 for a in range(0, gbflash.SIZE, gbflash.BLOCK))
                self.assertEqual(len(before), gbflash.SIZE)
                self.assertEqual(len(after), gbflash.SIZE)
                self.assertEqual(after[:len(image)], image)
                self.assertEqual(after[len(image):], before[len(image):])
                self.assertEqual(bridge.erased, [a for a, n in gbflash.sectors(device)
                                                if a < len(image)])
                self.assertTrue(all(n in (8192, gbflash.BLOCK) for op, a, n in bridge.operations
                                    if op in (0x30, 0x31)))

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

    def test_full_dump_uses_256_requests(self):
        programmer, bridge = self.make_programmer()
        for address in range(0, gbflash.SIZE, gbflash.BLOCK):
            self.assertEqual(len(programmer.read_block(address, gbflash.BLOCK)), gbflash.BLOCK)
        self.assertEqual(len(bridge.operations), 256)


if __name__ == '__main__':
    unittest.main()
