#!/usr/bin/env python3
"""MX29LV320E programmer v2. Serial transport: pip install pyserial."""
import argparse
import binascii
import pathlib
import sys
import time

SIZE = 0x400000
ERRORS = {2: 'unknown command', 3: 'Flash timeout', 4: 'Flash Q5 failure',
          5: 'Flash readback mismatch', 6: 'controller fault', 7: 'SPI request CRC',
          8: 'address out of range', 9: 'programmer locked'}


def packet(payload):
    return payload + binascii.crc_hqx(payload, 0xffff).to_bytes(2, 'big')


def status(raw):
    if len(raw) != 8 or raw[0] != 0x50 or packet(raw[:6]) != raw:
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
        # Terminate any abandoned partial USB line before the handshake.
        serial.write(b'\n')
        time.sleep(0.1)
        serial.reset_input_buffer()
        if self.exchange('v') != bytes.fromhex('4742464302000100'):
            raise RuntimeError('FPGA programmer v2 not found; check both firmware builds')
        raw = status(self.exchange('s'))
        if raw[2] == 1:
            raise RuntimeError('FPGA is busy; wait for the previous operation to finish')
        self.sequence = raw[1]

    def exchange(self, line):
        self.serial.write(line.encode('ascii') + b'\n')
        raw = self.serial.read_until(b'\n', 96)
        if not raw.endswith(b'\n'):
            raise RuntimeError('USB timeout/incomplete response; operation was not retried')
        try:
            return bytes.fromhex(raw.decode('ascii').strip())
        except (ValueError, UnicodeError) as exc:
            raise RuntimeError(f'RP2040: {raw!r}') from exc

    def operation(self, op, address=0, data=0):
        if not 0 <= address < SIZE or not 0 <= data <= 255:
            raise ValueError('Address/data out of range')
        self.sequence = (self.sequence + 1) & 255
        request = packet(bytes([op, self.sequence]) + address.to_bytes(3, 'big') + bytes([data]))
        raw = status(self.exchange('x' + request.hex()))
        if raw[1] != self.sequence or raw[5] != op:
            raise RuntimeError('Stale or mismatched FPGA response')
        if raw[2] != 0:
            raise RuntimeError(f'At 0x{address:06X}: {ERRORS.get(raw[2], "unexpected status")} ({raw[2]})')
        return raw[3] | raw[4] << 8

    def identify(self):
        self.operation(0x20, data=0xa5)
        self.operation(0x14)
        ident = self.operation(0x13)
        if ident & 255 != 0xc2:
            raise RuntimeError(f'Unexpected manufacturer ID: {ident & 255:02X}')
        sectors(ident >> 8)
        return ident >> 8

    def read(self, address):
        return self.operation(0x10, address) & 255


def verify(programmer, expected, start=0, label='Verified'):
    for offset, value in enumerate(expected):
        actual = programmer.read(start + offset)
        if actual != value:
            raise RuntimeError(f'0x{start + offset:06X}: expected {value:02X}, read {actual:02X}')
        if (offset + 1) % 1024 == 0:
            print(f'{label}: {offset + 1}/{len(expected)}', flush=True)


def write_image(programmer, image, device):
    if not 0 < len(image) <= SIZE:
        raise ValueError('Image must contain 1..4194304 bytes')
    affected = [(a, n) for a, n in sectors(device) if a < len(image)]
    print('Erasing sectors: ' + ', '.join(f'{a:06X}+{n:X}' for a, n in affected), flush=True)
    for address, size in affected:
        programmer.operation(0x12, address)
        # Check the entire erased sector, including any tail beyond the image.
        verify(programmer, b'\xff' * size, address, 'Erase verified')
    for address, value in enumerate(image):
        if value != 0xff:
            programmer.operation(0x11, address, value)
        if (address + 1) % 1024 == 0:
            print(f'Written: {address + 1}/{len(image)}', flush=True)
    verify(programmer, image)
    print(f'Written: {len(image)} bytes\nVerified: {len(image)} bytes\nResult: SUCCESS')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', required=True, help='e.g. /dev/cu.usbmodem123 or COM5')
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('info')
    for name in ('write', 'verify'):
        p = sub.add_parser(name)
        p.add_argument('file', type=pathlib.Path)
        if name == 'write':
            p.add_argument('--erase', action='store_true', required=True,
                           help='erase complete overlapping sectors, including their unused tails')
            p.add_argument('--allow-large', action='store_true', help='allow images over 32 KiB after bench acceptance')
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
            if args.command == 'write' and len(image) > 32768 and not args.allow_large:
                raise ValueError('Initial bring-up is limited to 32 KiB; use --allow-large after bench acceptance')
        if args.command == 'read' and not (0 <= args.address < SIZE and 0 < args.length <= SIZE - args.address):
            raise ValueError('Read range exceeds Flash capacity')
        import serial
        with serial.Serial(args.port, 115200, timeout=7, write_timeout=2) as port:
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
                        for address in range(args.address, args.address + args.length):
                            output.write(bytes([programmer.read(address)]))
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
