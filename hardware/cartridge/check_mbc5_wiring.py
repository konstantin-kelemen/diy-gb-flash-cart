#!/usr/bin/env python3
"""Сверка экспортированной KiCad XML-сетки с назначениями MBC5."""
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[2]
nets = ET.parse(sys.argv[1]).getroot().findall('./nets/net')
by_pin = {}
for net in nets:
    for node in net.findall('node'):
        key = (node.get('ref'), int(node.get('pin'))) if node.get('ref') != 'U8' else None
        if key:
            by_pin[key] = net.get('name').lstrip('/')

def check(ref, pin, name):
    actual = by_pin.get((ref, pin))
    assert actual == name, f'{ref}.{pin}: {actual!r} != {name!r}'

lpf = (root / 'fpga/constraints/game_mbc5.lpf').read_text()
ports = re.findall(r'LOCATE COMP "([^"]+)" SITE "(\d+)"', lpf)
assert len(ports) == len({name for name, _ in ports}) == len({pin for _, pin in ports}) == 66
for name, pin in ports:
    check('U5', int(pin), name.replace('[', '').replace(']', ''))
    assert f'IOBUF PORT "{name}" IO_TYPE=LVCMOS33' in lpf

addr_pins = [20, 19, 18, 17, 16, 15, 14, 13, 3, 2, 31, 1, 12, 4, 11, 7, 10]
data_pins = [21, 22, 23, 25, 26, 27, 28, 29]
flash_addr_pins = [45, 25, 24, 23, 22, 21, 20, 19, 18, 8, 7, 6, 5, 4, 3, 2, 1]
flash_data_pins = [29, 31, 33, 35, 38, 40, 42, 44]
for i, pin in enumerate(addr_pins):
    check('U7', pin, f'flash_a{i}')
    check('U6', flash_addr_pins[i], f'flash_a{i}')
for i, pin in enumerate(data_pins):
    check('U7', pin, f'flash_d{i}')
    check('U6', flash_data_pins[i], f'flash_d{i}')
for pin, name in [(30, 'fram_ce_n'), (32, 'fram_oe_n'), (5, 'fram_we_n'),
                  (6, '+3.3V'), (8, '+3.3V'), (24, 'GND')]:
    check('U7', pin, name)
assert by_pin['U7', 9].startswith('unconnected-')
for i, name in enumerate(['fram_ce_n', 'fram_oe_n', 'fram_we_n',
                          'flash_ce_n', 'flash_oe_n', 'flash_we_n'], 5):
    assert {by_pin[f'R{i}', 1], by_pin[f'R{i}', 2]} == {name, '+3.3V'}
for ref, offset in [('U1', 0), ('U2', 8)]:
    for i in range(8):
        check(ref, i + 3, f'gb_a{i + offset}')
for pin, name in [(2, 'GND'), (22, 'GND'), (3, 'gb_wr_n'), (4, 'gb_rd_n'),
                  (5, 'gb_cs_n'), (6, 'gb_res_n')]:
    check('U4', pin, name)
check('U3', 2, 'data_dir')
check('U3', 22, 'data_oe_n')
check('C10', 1, '+3.3V')
check('C10', 2, 'GND')
print('PASS: 66 назначений FPGA, все выводы F-RAM, общие шины, U1/U2/U3/U4 и подтяжки')
