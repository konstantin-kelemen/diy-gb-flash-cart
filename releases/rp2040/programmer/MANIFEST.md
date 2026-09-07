# RP2040 programmer v2 — 2026-09-07

`gb_cart_programmer.uf2` собран для Waveshare RP2040-Zero. Аппаратно не проверен.
Совместим только с новой FPGA-конфигурацией `programmer`, протокол 2.0.
Старый JEDEC `flash-bringup-pass` команд программатора не поддерживает.

- Pico SDK 2.2.0: `a1438dff1d38bd9c65dbd693f0e5db4b9ae91779`.
- TinyUSB: `86ad6e56c1700e85f1c5678607a762cfe3aa2f47`.
- ARM GCC 9.2.1; Release; `-Wall -Wextra -Werror`.
- picotool 2.2.0: `a7eb3988f0645239185fadb4e25d8279478c2dbb`.
- Исходники прошивки сохранены в `source/`; суммы в `SHA256SUMS.txt`.

При локальной сборке SDK был в `/private/tmp/gb-cart-pico-sdk`.
Сначала CMake с `-DPICO_BOARD=waveshare_rp2040_zero -DPICO_NO_PICOTOOL=1`,
затем `cmake --build ... -j4` и преобразование ELF официальным picotool:

```sh
picotool uf2 convert gb_cart_programmer.elf gb_cart_programmer.uf2 --family rp2040
picotool info -a gb_cart_programmer.uf2
```

Метаданные UF2 подтверждают `gb_cart_programmer`, USB stdin/stdout, правильную
плату и SDK. Это не проверка реального USB или SPI.

[Инструкция запуска](../../../docs/PROGRAMMER.md). JEDEC программатора ещё
нужно собрать в Diamond и проверить timing/назначения выводов.
