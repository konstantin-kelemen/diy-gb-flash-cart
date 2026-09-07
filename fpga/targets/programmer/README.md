# FPGA programmer

Отдельная конфигурация PROGRAMMER, без интерфейса Game Boy. Состав:
`top.v`, `rtl/programmer_spi.v`, `rtl/mx29_programmer.v`, `rtl/mx29_bus.v`.
Назначения выводов — `constraints/spi_bringup.lpf`.

[Сборка, протокол, стенд и ограничения](../../../docs/PROGRAMMER.md).
Результат Diamond: `fpga/diamond/programmer/RomEmu_programmer.jed`.
JEDEC пока не собран; RTL проверяется `tests/programmer_tb.sv`.
