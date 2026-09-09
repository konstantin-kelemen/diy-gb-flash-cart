#!/usr/bin/env python3
"""MX29LV320E programmer v3. Serial transport: pip install pyserial."""
import argparse
import binascii
import pathlib
import sys
import time

SIZE = 0x400000
BLOCK = 1024
ERRORS = {2: 'unknown command', 3: 'Flash timeout', 4: 'Flash Q5 failure',
          5: 'Flash readback mismatch', 6: 'controller fault', 7: 'SPI request CRC',
          8: 'address out of range', 9: 'programmer locked', 10: 'duplicate sequence'}


def packet(payload):
    return payload + binascii.crc_hqx(payload, 0xffff).to_bytes(2, 'big')


def status(raw):
    if len(raw) != 10 or raw[0] != 0x50 or packet(raw[:8]) != raw:
        raise RuntimeError('Invalid FPGA status or CRC')
    return raw


def sectors(device):
    """Return byte-addressed (start, size) pairs for the detected boot variant."""
    if device == 0xa8:
        return [(a, 0x2000) for a in range(0, 0x10000, 0x2000)] + [
            (a, 0x10000) for a in range(0x10000, SIZE, 0x10000)]
    if device == 0xa7:
        return [(a, 0x10000) for a in range(0, 0x3f0000, 0x10000)] + [
            (a, 0x2000) for a in range(0x3f0000, SIZE, 0x2000)]
    raise RuntimeError(f'Unsupported Flash device ID: {device:02X}')


class Programmer:
    def __init__(self, serial):
        self.serial = serial
        # Let a prior damaged/partial USB frame expire before handshaking.
        time.sleep(2.2)
        serial.reset_input_buffer()
        if self.exchange(b'\x01') != bytes.fromhex('4742464303000004'):
            raise RuntimeError('FPGA programmer v3 not found; update both firmware builds')
        raw = status(self.exchange(b'\x02'))
        if raw[2] == 1:
            raise RuntimeError('FPGA is busy; wait for the previous operation to finish')
        self.sequence = raw[1]

    def read_exact(self, length):
        result = bytearray()
        deadline = time.monotonic() + 10
        while len(result) < length:
            part = self.serial.read(length - len(result))
            if not part or time.monotonic() > deadline:
                raise RuntimeError('USB timeout/incomplete response; operation was not retried')
            result.extend(part)
        return bytes(result)

    def exchange(self, payload):
        frame = b'GB3Q' + packet(len(payload).to_bytes(2, 'big') + payload)
        if self.serial.write(frame) != len(frame):
            raise RuntimeError('Incomplete USB write; operation was not retried')
        header = self.read_exact(6)
        if header[:4] != b'GB3R':
            raise RuntimeError('Invalid USB framing; update RP2040 firmware to v3')
        length = int.from_bytes(header[4:6], 'big')
        if not 1 <= length <= BLOCK + 12:
            raise RuntimeError('Invalid USB response length')
        body = self.read_exact(length + 2)
        if packet(header[4:6] + body[:-2])[-2:] != body[-2:]:
            raise RuntimeError('USB response CRC mismatch')
        if length == 1:
            raise RuntimeError(f'RP2040 bridge error: 0x{body[0]:02X}; operation was not retried')
        return body[:-2]

    def request(self, op, address=0, length=0, data=0, payload=b''):
        if not 0 <= address < SIZE or not 0 <= data <= 255:
            raise ValueError('Address/data out of range')
        if op in (0x30, 0x31):
            if not 1 <= length <= BLOCK or address + length > SIZE:
                raise ValueError('Block range exceeds Flash capacity')
        elif length:
            raise ValueError('Control command cannot have a block length')
        if len(payload) != (length if op == 0x31 else 0):
            raise ValueError('Invalid write payload length')
        self.sequence = (self.sequence + 1) & 255
        request = packet(bytes([op, self.sequence]) + address.to_bytes(3, 'big') +
                         length.to_bytes(2, 'big') + bytes([data]) + payload)
        reply = self.exchange(request)
        raw = status(reply[:10])
        if raw[1] != self.sequence or raw[3] != op:
            raise RuntimeError('Stale or mismatched FPGA response')
        count = int.from_bytes(raw[6:8], 'little')
        if raw[2] != 0:
            raise RuntimeError(f'At 0x{address + count:06X}: '
                               f'{ERRORS.get(raw[2], "unexpected status")} ({raw[2]})')
        if op in (0x30, 0x31) and count != length:
            raise RuntimeError('Incomplete FPGA block')
        if op == 0x30:
            block = reply[10:]
            if len(block) != length + 2 or packet(block[:-2]) != block:
                raise RuntimeError('Invalid SPI block length or CRC')
            return block[:-2]
        if len(reply) != 10:
            raise RuntimeError('Unexpected response payload')
        return raw[4] | raw[5] << 8

    def operation(self, op, address=0, data=0):
        return self.request(op, address, data=data)

    def identify(self):
        self.operation(0x20, data=0xa5)
        self.operation(0x14)
        ident = self.operation(0x13)
        if ident & 255 != 0xc2:
            raise RuntimeError(f'Unexpected manufacturer ID: {ident & 255:02X}')
        sectors(ident >> 8)
        return ident >> 8

    def read_block(self, address, length):
        return self.request(0x30, address, length)

    def write_block(self, address, payload):
        self.request(0x31, address, len(payload), payload=payload)

    def read(self, address):
        return self.read_block(address, 1)[0]


def verify(programmer, expected, start=0, label='Verified'):
    for offset in range(0, len(expected), BLOCK):
        block = expected[offset:offset + BLOCK]
        actual = programmer.read_block(start + offset, len(block))
        if len(actual) != len(block):
            raise RuntimeError('Incomplete read block')
        if actual != block:
            i = next(i for i, (a, b) in enumerate(zip(block, actual)) if a != b)
            raise RuntimeError(f'0x{start + offset + i:06X}: expected {block[i]:02X}, read {actual[i]:02X}')
        print(f'{label}: {offset + len(block)}/{len(expected)}', flush=True)


def write_image(programmer, image, device):
    if not 0 < len(image) <= SIZE:
        raise ValueError('Image must contain 1..4194304 bytes')
    affected = [(a, n) for a, n in sectors(device) if a < len(image)]
    print('Erasing sectors: ' + ', '.join(f'{a:06X}+{n:X}' for a, n in affected), flush=True)
    for address, size in affected:
        programmer.operation(0x12, address)
        # Check the entire erased sector, including any tail beyond the image.
        verify(programmer, b'\xff' * size, address, 'Erase verified')
    for address in range(0, len(image), BLOCK):
        block = image[address:address + BLOCK]
        if block != b'\xff' * len(block):
            programmer.write_block(address, block)
        print(f'Written: {address + len(block)}/{len(image)}', flush=True)
    verify(programmer, image)
    print(f'Written: {len(image)} bytes\nVerified: {len(image)} bytes\nResult: SUCCESS')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', required=True, help='e.g. /dev/cu.usbmodem123')
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('info')
    for name in ('write', 'verify'):
        p = sub.add_parser(name)
        p.add_argument('file', type=pathlib.Path)
        if name == 'write':
            p.add_argument('--erase', action='store_true', required=True,
                           help='erase complete overlapping sectors, including their unused tails')
    p = sub.add_parser('read')
    p.add_argument('file', type=pathlib.Path)
    p.add_argument('--length', type=lambda s: int(s, 0), required=True)
    p.add_argument('--address', type=lambda s: int(s, 0), default=0)
    args = parser.parse_args()
    try:
        image = None
        if args.command in ('write', 'verify'):
            image = args.file.read_bytes()
            if not 0 < len(image) <= SIZE:
                raise ValueError('Image size must be between 1 byte and 4 MiB')
        if args.command == 'read' and not (0 <= args.address < SIZE and 0 < args.length <= SIZE - args.address):
            raise ValueError('Read range exceeds Flash capacity')
        import serial
        with serial.Serial(args.port, 115200, timeout=10, write_timeout=2) as port:
            programmer = Programmer(port)
            try:
                if args.command in ('info', 'write'):
                    device = programmer.identify()
                    print(f'MX29LV320E: C2 {device:02X}, {"Bottom" if device == 0xa8 else "Top"} Boot, PROGRAMMER')
                if args.command == 'write':
                    write_image(programmer, image, device)
                elif args.command == 'verify':
                    verify(programmer, image)
                    print(f'Verified: {len(image)} bytes; SUCCESS')
                elif args.command == 'read':
                    # Exclusive creation prevents accidentally replacing an existing dump.
                    with args.file.open('xb') as output:
                        started = time.monotonic()
                        for offset in range(0, args.length, BLOCK):
                            size = min(BLOCK, args.length - offset)
                            output.write(programmer.read_block(args.address + offset, size))
                            if (offset + size) % 65536 == 0 or offset + size == args.length:
                                elapsed = max(time.monotonic() - started, 0.001)
                                print(f'Read: {offset + size}/{args.length} bytes; '
                                      f'{(offset + size) / elapsed / 1024:.1f} KiB/s', flush=True)
                    print(f'Read: {args.length} bytes')
            finally:
                failed = sys.exc_info()[0] is not None
                try:
                    programmer.operation(0x21)
                except (OSError, RuntimeError) as exc:
                    if not failed:
                        raise
                    print(f'Could not confirm programmer lock: {exc}', file=sys.stderr)
    except (OSError, RuntimeError, ValueError, ImportError) as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
