"""Package an RP2040 XIP .bin at 0x10000000 using Pico SDK boot/uf2.h format."""
import argparse
from pathlib import Path
import struct


def convert(data: bytes) -> bytes:
    if not 256 <= len(data) <= 2 * 1024 * 1024:
        raise ValueError('Expected a boot2 + application image for the 2 MiB RP2040-Zero Flash')
    count = (len(data) + 255) // 256
    result = bytearray()
    for index in range(count):
        payload = data[index * 256:(index + 1) * 256].ljust(256, b'\x00')
        result += struct.pack('<8I', 0x0A324655, 0x9E5D5157, 0x2000,
                              0x10000000 + index * 256, 256, index, count, 0xE48BFF56)
        result += payload + bytes(220) + struct.pack('<I', 0x0AB16F30)
    return bytes(result)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.write_bytes(convert(args.binary.read_bytes()))
