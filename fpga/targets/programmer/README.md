# FPGA programmer

Отдельная конфигурация PROGRAMMER без интерфейса Game Boy.
`top.v` объединяет `programmer_block.v`, `mx29_programmer.v` и `mx29_bus.v`.
Входной и выходной блоки по 1 КиБ хранятся в синхронной памяти для вывода в EBR.
LPF: `constraints/programmer.lpf`; выводы сохранены.

Готовая рабочая сборка: [JEDEC, отчёты и манифест](../../../releases/fpga/programmer-v3/MANIFEST.md).
[Прошивка и стенд](../../../docs/PROGRAMMER.md),
[протокол и временные параметры](../../../docs/PROGRAMMER_PROTOCOL.md).
Результат Diamond: `fpga/diamond/programmer/RomEmu_programmer.jed`.
После исправления RTL повторный TRACE пройден на 53,2 МГц;
[результат и ограничение проверки](../../../docs/TEST_PLAN.md#журнал-результатов).
Map отклонил FREQUENCY 64 МГц для OSCH и применил NOM_FREQ 53,20 МГц.
Проверка timing с запасом на разброс частоты остаётся отдельной задачей.

## Сборка в Diamond

При изменении исходников в Windows открыть `fpga/diamond/RomEmu.ldf`,
выбрать **programmer**, выполнить синтез, Map, Place & Route, TRACE
и экспорт JEDEC. Проверить ресурсы, timing и выводы по
[плану испытаний](../../../docs/TEST_PLAN.md).

## RTL-проверка

Из корня проекта на Mac с Icarus Verilog:

```sh
iverilog -g2012 -s programmer_block_tb -o /tmp/programmer-block.vvp fpga/rtl/mx29_bus.v fpga/rtl/mx29_programmer.v fpga/rtl/programmer_block.v fpga/tests/programmer_block_tb.sv
vvp /tmp/programmer-block.vvp
```

Проверены SPI 4 МГц, блоки, CRC, границы, ID/стирание/запись, LOCK,
повреждённые/неполные/лишние кадры, дублирование sequence, кадр во время busy,
Q5 и тайм-аут. Модель задерживает данные Flash на 70 нс и контролирует
момент чтения и длительность WE#. Это не post-route и не аппаратная проверка.
`programmer_spi.v` и `programmer_tb.sv` оставлены для регрессии прежнего v2;
актуальная FPGA-конфигурация их не использует.
