"""Actual host + firmware USB parser/codec/bridge, with a deterministic SPI model."""
import binascii
import contextlib
import ctypes
import io
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'host'))
import gbflash


class BridgeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.tmp.cleanup)
        path = Path(cls.tmp.name)
        source = (ROOT / 'firmware/rp2040/programmer/src/main.c').read_text()
        source = source.replace('#include "pico/stdlib.h"', '#include "sdk_stubs.h"')
        source = source.replace('#include "hardware/spi.h"', '')
        source = source.replace('int main(void)', 'int firmware_main(void)')
        source += Path(__file__).with_name('bridge_model.c').read_text()
        (path / 'bridge.c').write_text(source)
        library = path / 'bridge.so'
        subprocess.run(shlex.split(os.environ.get('CC', 'cc')) + [
            '-std=c11', '-Wall', '-Wextra', '-Werror', '-shared', '-fPIC',
            '-I', str(Path(__file__).parent), str(path / 'bridge.c'), '-o', str(library)], check=True)
        cls.lib = ctypes.CDLL(str(library))
        cls.lib.model_exchange.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p]
        cls.lib.model_exchange.restype = ctypes.c_size_t
        cls.lib.model_memory.restype = ctypes.POINTER(ctypes.c_uint8)

    def setUp(self):
        self.lib.model_reset()
        self.output = b''
        self.written_frames = []
        self.fragment = 17
        self.mutate = None
        with patch('gbflash.time.sleep'):
            self.host = gbflash.Programmer(self)

    def reset_input_buffer(self):
        self.output = b''

    def raw_exchange(self, frame):
        out = ctypes.create_string_buffer(gbflash.BLOCK + 18)
        n = self.lib.model_exchange(frame, len(frame), out)
        return out.raw[:n]

    def write(self, frame):
        self.written_frames.append(frame)
        if self.mutate:
            frame = self.mutate(frame)
        self.output = self.raw_exchange(frame)
        return len(frame)

    def read(self, length):
        part = self.output[:min(length, self.fragment)]
        self.output = self.output[len(part):]
        return part

    def test_sizes_binary_and_end_address(self):
        self.assertEqual(self.host.identify(), 0xa8)
        for size in (1, 255, 256, 257, 16384):
            with self.subTest(size=size):
                address = gbflash.SIZE-size
                self.host.operation(0x12, address)
                data = bytes(i % 256 for i in range(size))
                before = self.lib.model_count(2)
                self.host.write_block(address, data)
                self.assertEqual(self.lib.model_count(2)-before, (size+255)//256)
                self.assertEqual(self.host.read_block(address, size), data)
        for _ in range(260):
            self.assertEqual(self.host.read_block(0, 1), b'\xff')

    def test_full_cycle_with_two_dumps(self):
        image = bytes(range(256))*33+b'\xa5'
        before = b''.join(self.host.read_block(a, gbflash.BLOCK)
                          for a in range(0, gbflash.SIZE, gbflash.BLOCK))
        with contextlib.redirect_stdout(io.StringIO()):
            gbflash.write_image(self.host, image, self.host.identify())
        after = b''.join(self.host.read_block(a, gbflash.BLOCK)
                         for a in range(0, gbflash.SIZE, gbflash.BLOCK))
        self.assertEqual(len(before), gbflash.SIZE)
        self.assertEqual(len(after), gbflash.SIZE)
        self.assertEqual(after[:len(image)], image)
        self.assertEqual(after[len(image):], before[len(image):])

    def test_spi_version_rejected_before_mutation(self):
        self.lib.model_fault(1, 1)
        before = self.lib.model_count(0)
        with patch('gbflash.time.sleep'), self.assertRaises(RuntimeError):
            gbflash.Programmer(self)
        self.assertEqual(self.lib.model_count(0), before)

    def test_usb_crc_precedes_flash_and_embedded_frames_are_not_executed(self):
        self.host.identify()
        embedded = b'GB5Q'+gbflash.packet(b'\x00\x01\x01')
        data = embedded+b'\x55'*257
        self.mutate = lambda frame: frame[:-1]+bytes([frame[-1]^1])
        before = self.lib.model_count(0)
        with self.assertRaises(RuntimeError):
            self.host.write_block(0, data)
        self.assertEqual(self.lib.model_count(0), before)
        self.assertEqual(bytes(self.lib.model_memory()[:len(data)]), b'\xff'*len(data))

    def test_partial_failure_reports_absolute_address(self):
        self.host.identify()
        self.lib.model_fault(6, 0x1000+256+13)
        with self.assertRaisesRegex(RuntimeError, '0x00110D: Flash readback mismatch'):
            self.host.write_block(0x1000, b'\x55'*1024)
        self.assertEqual(self.lib.model_count(2), 2)
        self.assertEqual(self.lib.model_count(5), 269)
        self.assertEqual(self.lib.model_memory()[0x110d], 0xff)

    def test_link_faults_and_timeouts_never_repeat_writes(self):
        for fault in (3, 4, 5):
            with self.subTest(fault=fault):
                self.setUp()
                self.host.identify()
                self.lib.model_fault(fault, 1)
                with self.assertRaises(RuntimeError):
                    self.host.write_block(0, b'\x55'*257)
                self.assertEqual(self.lib.model_count(2), 1)
                if fault == 4:
                    self.assertLess(self.lib.model_count(6), 12000)

    def test_bad_spi_data_crc_or_completed_count(self):
        for fault in (2, 7):
            with self.subTest(fault=fault):
                self.setUp()
                self.lib.model_fault(fault, 1)
                with self.assertRaises(RuntimeError):
                    self.host.read_block(0, 256)
                self.assertEqual(self.lib.model_count(1), 1)

    def test_bad_ranges_and_duplicate_do_not_reach_spi(self):
        before = self.lib.model_count(0)
        for address, length in ((0, 0), (0, 16385), (0x3fffff, 2), (0x400000, 1)):
            self.host.sequence = (self.host.sequence+1) & 255
            payload = bytes([0x30, self.host.sequence])+address.to_bytes(3,'big')+length.to_bytes(2,'big')+b'\0'
            response = self.host.exchange(payload)
            self.assertNotEqual(response[2], 0)
        self.assertEqual(self.lib.model_count(0), before)
        self.host.read_block(0, 1)
        before = self.lib.model_count(0)
        response = self.raw_exchange(self.written_frames[-1])
        self.assertEqual(response[6], 0xe3)
        self.assertEqual(self.lib.model_count(0), before)

    def test_receive_deadline_even_with_continuous_bytes(self):
        self.host.identify()
        self.lib.model_fault(9, 1000)
        with self.assertRaises(RuntimeError):
            self.host.write_block(0, b'\x55'*16384)
        self.assertEqual(self.lib.model_count(2), 0)

    def test_overall_deadline_limits_completed_portions(self):
        self.host.identify()
        self.lib.model_fault(8, 2000000)
        with self.assertRaisesRegex(RuntimeError, 'deadline'):
            self.host.write_block(0, b'\x55'*16384)
        self.assertLess(self.lib.model_count(2), 64)
        self.assertLess(self.lib.model_count(6), 94000)


if __name__ == '__main__':
    unittest.main()
