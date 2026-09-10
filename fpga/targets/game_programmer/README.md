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
В GUI Diamond следует заново загрузить изменённый `RomEmu.ldf` и выбрать
реализацию `game_programmer`; остальные реализации используют прежние стратегии.

Использовать с [новой прошивкой RP2040](../../../firmware/rp2040/programmer/README.md).
Старый UF2 для SPI v3 не подходит. [SPI v4 и переключение режимов](../../../docs/PROGRAMMER_SPI_V4.md).
[Готовая FPGA-прошивка](../../../releases/fpga/game_programmer/RomEmu_game_programmer.jed).

Проверки:

```powershell
powershell -ExecutionPolicy Bypass -File fpga/tests/run.ps1
```

Функциональные симуляции и внутренние setup/hold пройдены. Проверки на реальной
плате, включая внешнюю шину Game Boy и скорость нового программатора, ещё нужны.
