#!/usr/bin/env python3
"""Регрессия game_multi и потребителей общих модулей на macOS (Icarus)."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
GAME = ["game_multi_core", "cart_header", "cart_mapper", "mbc_rtc"]
PROGRAMMER = ["mx29_bus", "mx29_programmer", "programmer_block"]
CASES = [
    ("cart_header", ["cart_header"], None, None),
    ("cart_mapper", ["cart_mapper"], None, None),
    ("mapper_race", ["cart_mapper", "mbc_rtc"], None, None),
    ("mbc_rtc", ["mbc_rtc"], None, None),
    ("rtc_priority", ["mbc_rtc"], None, None),
    ("game_multi", GAME, "game_multi", None),
    ("game_programmer", GAME + PROGRAMMER + ["cart_mode"], "game_programmer", 0),
    ("game_programmer", GAME + PROGRAMMER + ["cart_mode"], "game_programmer", 1),
]

with tempfile.TemporaryDirectory(prefix="game-multi-tests-") as directory:
    for index, (name, modules, target, host_blocks) in enumerate(CASES):
        output = str(Path(directory) / str(index))
        command = ["iverilog", "-g2012", "-s", name + "_tb", "-o", output]
        if host_blocks is not None:
            command += [f"-P{name}_tb.HOST_BLOCKS={host_blocks}"]
        command += [str(ROOT / "rtl" / (module + ".v")) for module in modules]
        if target:
            command += [str(ROOT / "targets" / target / "top.v")]
        command += [str(ROOT / "tests" / (name + "_tb.sv"))]
        subprocess.run(command, check=True)
        result = subprocess.run(["vvp", output], capture_output=True, text=True, timeout=180)
        print(result.stdout, end="", flush=True)
        if result.returncode or "PASS " not in result.stdout:
            raise RuntimeError(result.stderr or f"Тест {name} не пройден")
