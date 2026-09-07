# Прошивка RP2040

Конфигурация [rp2040/spi_bringup](rp2040/spi_bringup/README.md):
USB CDC-консоль и SPI0 для запроса версии FPGA и повторных тестов.
Команд памяти в ней нет.

[rp2040/programmer](rp2040/programmer/README.md) — USB/SPI-мост для записи Flash,
работающий с FPGA `programmer` и `host/gbflash.py`.
[Полная инструкция](../docs/PROGRAMMER.md). Аппаратная приёмка не выполнена.

Инструкции сборки находятся в README соответствующей конфигурации.
[Подключение стенда](../docs/SPI_BRINGUP.md) общее для обеих конфигураций;
[протокол программатора](../docs/PROGRAMMER_PROTOCOL.md) описан отдельно.
