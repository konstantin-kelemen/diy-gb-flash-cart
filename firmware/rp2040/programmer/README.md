# RP2040 programmer

Прошивка Waveshare RP2040-Zero для [программатора Flash](../../../docs/PROGRAMMER.md).
USB CDC передаёт проверенные CRC команды FPGA; SPI0: GP0 MISO, GP1 CS,
GP2 SCK, GP3 MOSI, Mode 0, 10 кГц. UART отключён.

Сборка: Pico SDK, `-DPICO_BOARD=waveshare_rp2040_zero`.
Выход: `build/gb_cart_programmer.uf2`. Аппаратная приёмка не выполнена.
