# GAME multi + PROGRAMMER с RP2040

FPGA: `LCMXO2-1200HC-4TG100C`, Diamond 3.14, реализация `game_programmer`,
стратегия `GameProgrammerArea`. RP2040 берёт на себя блоки USB и их CRC;
FPGA исполняет короткие SPI v4 операции и управляет шиной.

```powershell
powershell -ExecutionPolicy Bypass -File fpga/targets/game_programmer/build.ps1
```

Результат: `fpga/diamond/game_programmer/RomEmu_game_programmer.jed`.
Параметр `-MapOnly` выполняет только синтез и MAP. Полная сборка дополнительно
проверяет размещение и TRACE, не экспортируя новый JEDEC при ошибках тайминга.
В `RomEmu.ldf` указана стратегия `GameProgrammerArea`, но её файл
`RomEmu_game_programmer.sty` отсутствует. До восстановления стратегии
использовать скрипт выше: он самостоятельно задаёт параметры сборки.

Использовать с [новой прошивкой RP2040](../../../firmware/rp2040/programmer/README.md).
Старый UF2 для SPI v3 не подходит. [SPI v4 и переключение режимов](../../../docs/PROGRAMMER_SPI_V4.md).
[Готовая FPGA-прошивка](../../../releases/fpga/lsdj-working-2026-09-20/RomEmu_game_programmer.jed).

Проверки:

```powershell
powershell -ExecutionPolicy Bypass -File fpga/tests/run.ps1
```

Сохранённая рабочая база запускает LSDj после замены F-RAM; её внутренние
setup/hold пройдены. На новых прошивках аппаратно проверены передача F-RAM
через USB и полный цикл Flash — PASS; [журнал](../../../docs/TEST_PLAN.md#журнал-результатов).
Старый JEDEC по ссылке выше не содержит USB-команд F-RAM.
Полнота внешних временных ограничений требует отдельной проверки.
