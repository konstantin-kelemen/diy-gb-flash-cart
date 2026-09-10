# RP2040 programmer v5

Прошивка Waveshare RP2040-Zero для [программатора Flash](../../../docs/PROGRAMMER.md).
USB CDC v5: блоки до 16 КиБ с CRC-32. SPI0 Mode 0, 4 МГц, SPI v5:
порции до 256 байт с CRC-16. FPGA обрабатывает порции в одном буфере EBR.
UART отключён. [Протокол и тайм-ауты](../../../docs/PROGRAMMER_PROTOCOL.md).
Подключение — по [схеме KiCad](../../../hardware/cartridge/cartridge.kicad_sch).

Требуются FPGA `game_programmer` с SPI v5 и `host/gbflash.py` v5.
Прежние FPGA v3/v4 отклоняются до операций Flash. UF2 v5 собран;
совместимый JEDEC v5 пока не выпущен. [Артефакт и точные исходники](../../../releases/rp2040/programmer-v5/).

## Сборка на macOS

Требуются Pico SDK с TinyUSB, ARM GCC, CMake и Python 3.
`PICO_SDK_PATH` должен указывать на SDK. Из корня проекта:

```sh
cmake -S firmware/rp2040/programmer -B firmware/rp2040/programmer/build-v5 -DPICO_BOARD=waveshare_rp2040_zero -DCMAKE_BUILD_TYPE=Release -DPICO_NO_PICOTOOL=1
cmake --build firmware/rp2040/programmer/build-v5 -j4
```

Выход: `firmware/rp2040/programmer/build-v5/gb_cart_programmer.uf2`.
Без picotool SDK создаёт `.bin`, затем `tools/bin_to_uf2.py` формирует UF2.
Проверенные версии инструментов и контрольные суммы указаны в манифесте выпуска.

## Проверка на Mac

```sh
python3 -m unittest discover -s firmware/rp2040/programmer/tests -v
```

`CC` выбирает C-компилятор (по умолчанию `cc`). Настоящий `src/main.c`, включая
цикл приёма USB, собирается с детерминированными SDK/SPI-моделями и вызывается
настоящей утилитой `gbflash.py`. Проверяются версии, CRC, фрагментация ответов,
порции, диапазоны, частичная запись, переключение режима, тайм-ауты и отсутствие
повторов. Отдельно проверяется упаковка UF2. Модель не подтверждает USB-скорость
или электрические параметры реальной платы.
