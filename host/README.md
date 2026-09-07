# Программа для компьютера

`gbflash.py` реализует `info`, `read`, `write --erase` и `verify` через USB CDC
прошивки RP2040 `programmer`. Запись включает полное чтение Flash обратно.

Требуются Python 3 и pyserial. [Инструкция и ограничения](../docs/PROGRAMMER.md).
Аппаратная приёмка ещё не выполнена.

Для прежнего теста `spi_bringup` достаточно USB CDC-терминала и
[команд прошивки RP2040](../firmware/rp2040/spi_bringup/README.md#запуск).
SPI-команда версии bring-up описана в [спецификации 1.0](../docs/SPI_BRINGUP.md).
