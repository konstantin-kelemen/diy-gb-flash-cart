# RP2040 programmer

Прошивка Waveshare RP2040-Zero для [программатора Flash](../../../docs/PROGRAMMER.md).
Бинарный USB CDC передаёт блоки протокола 3.0 с CRC; SPI0: GP0 MISO, GP1 CS,
GP2 SCK, GP3 MOSI, Mode 0, 4 МГц. UART отключён.

## Сборка на macOS при изменении прошивки

Требуются Pico SDK с инициализированным TinyUSB, ARM GCC и CMake.
`PICO_SDK_PATH` должен указывать на каталог SDK. Из корня проекта:

```sh
cmake -S firmware/rp2040/programmer -B firmware/rp2040/programmer/build-v3 -DPICO_BOARD=waveshare_rp2040_zero
cmake --build firmware/rp2040/programmer/build-v3 -j4
```

Выход: `firmware/rp2040/programmer/build-v3/gb_cart_programmer.uf2`.
Для стендового опыта с готовым UF2 использовать общую инструкцию выше.

Проверка кода моста с моделью SPI на Mac:

```sh
python3 -m unittest discover -s firmware/rp2040/programmer/tests -v
```
