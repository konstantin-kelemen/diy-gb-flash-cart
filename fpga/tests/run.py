#!/usr/bin/env python3
"""RTL-регрессии на Mac с Icarus Verilog; результаты не заменяют Diamond TRACE."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
GAME = ['rtl/game_multi_core.v', 'rtl/cart_header.v', 'rtl/cart_mapper.v', 'rtl/mbc_rtc.v']
FLASH = ['rtl/mx29_bus.v', 'rtl/mx29_programmer.v']
COMBINED = ['targets/game_programmer/top.v'] + GAME + FLASH + ['rtl/programmer_v5.v', 'rtl/cart_mode.v']
CASES = {
    'cart_header': ('cart_header_tb', ['rtl/cart_header.v'], []),
    'cart_mapper': ('cart_mapper_tb', ['rtl/cart_mapper.v'], []),
    'mbc_rtc': ('mbc_rtc_tb', ['rtl/mbc_rtc.v'], []),
    'cart_mode': ('cart_mode_tb', ['rtl/cart_mode.v'], []),
    'game_multi': ('game_multi_tb', ['targets/game_multi/top.v'] + GAME, []),
    'programmer': ('programmer_tb', FLASH + ['rtl/programmer_spi.v'], []),
    'programmer_block': ('programmer_block_tb', FLASH + ['rtl/programmer_block.v'], []),
    'programmer_top': ('programmer_top_tb', ['targets/programmer/top.v'] + FLASH + ['rtl/programmer_block.v'], []),
    'game_programmer': ('game_programmer_tb', COMBINED, []),
    'v5_slow': ('game_programmer_tb', COMBINED, ['-Pgame_programmer_tb.CLOCK_HALF=11.75']),
    'v5_fast': ('game_programmer_tb', COMBINED, ['-Pgame_programmer_tb.CLOCK_HALF=7.8125']),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', action='append', choices=CASES)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='gb-rtl-') as tmp:
        for name in args.case or CASES:
            top, sources, flags = CASES[name]
            executable = str(Path(tmp) / name)
            subprocess.run(['iverilog', '-g2012', '-s', top, '-o', executable] + flags +
                           [str(ROOT / p) for p in sources] +
                           [str(ROOT / 'tests' / (top + '.sv'))], check=True)
            result = subprocess.run(['vvp', executable], capture_output=True, text=True, timeout=120)
            lines = result.stdout + result.stderr
            if result.returncode or 'PASS ' not in lines:
                raise RuntimeError(f'{name}: {lines}')
            print(f'{name}: ' + '\n'.join(line for line in lines.splitlines() if 'PASS ' in line), flush=True)


if __name__ == '__main__':
    main()
