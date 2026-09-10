# RP2040 programmer

Прошивка Waveshare RP2040-Zero для [программатора Flash](../../../docs/PROGRAMMER.md).
Бинарный USB CDC, протокол 3.0 с CRC; SPI0 Mode 0, 4 МГц, внутренний протокол 4.
RP2040 обрабатывает блоки по 1024 байта, FPGA выполняет однобайтовые операции.
Требуется новая FPGA-конфигурация `game_programmer`; старая SPI v3 отклоняется.
[Формат обмена и удержание режима](../../../docs/PROGRAMMER_SPI_V4.md). UART отключён.
Подключение — по [схеме KiCad](../../../hardware/cartridge/cartridge.kicad_sch).

## Сборка на macOS при изменении прошивки

Требуются Pico SDK с инициализированным TinyUSB, ARM GCC и CMake.
`PICO_SDK_PATH` должен указывать на каталог SDK. Из корня проекта:

```sh
cmake -S firmware/rp2040/programmer -B firmware/rp2040/programmer/build-v3 -DPICO_BOARD=waveshare_rp2040_zero
cmake --build firmware/rp2040/programmer/build-v3 -j4
```

Выход: `firmware/rp2040/programmer/build-v3/gb_cart_programmer.uf2`.
Для стендового опыта с готовым UF2 использовать общую инструкцию выше.

Проверенная новая сборка использует Pico SDK 2.2.0, ARM GNU 14.3.Rel1,
плату `waveshare_rp2040_zero` и Release. Можно выбрать каталог `build-offload`
вместо `build-v3`. На Windows доступны те же команды с генератором `-G Ninja`.
Если нет picotool/нативного C++ компилятора, добавьте `-DPICO_NO_PICOTOOL=1`:
SDK соберёт `.bin`, а скрипт `tools/bin_to_uf2.py` сформирует RP2040 UF2.

Проверка кода моста с моделью SPI на Mac:

```sh
python3 -m unittest discover -s firmware/rp2040/programmer/tests -v
```

Переменная `CC` позволяет выбрать C-компилятор (по умолчанию `cc`), в том числе
переносимый TinyCC на Windows. Проверяется настоящий `src/main.c` с моделью
коротких SPI-команд, а не отдельная реализация алгоритма моста.
