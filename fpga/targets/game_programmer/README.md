# GAME multi + PROGRAMMER v5

FPGA: `LCMXO2-1200HC-4TG100C`, Diamond 3.14, реализация `game_programmer`,
стратегия `GameProgrammerArea`. Сохранены мапперы, RTC и автовыбор режима.
RP2040 передаёт SPI-порции до 256 байт; `programmer_v5` использует один общий
буфер EBR и сам выполняет последовательные операции Flash.
[USB/SPI v5](../../../docs/PROGRAMMER_PROTOCOL.md).

## Сборка в Windows

```powershell
powershell -ExecutionPolicy Bypass -File fpga/targets/game_programmer/build.ps1
```

Результат: `fpga/diamond/game_programmer/RomEmu_game_programmer.jed`.
`-MapOnly` выполняет синтез и MAP. Скрипт проверяет наличие ровно одной EBR,
полная сборка дополнительно проверяет PAR и TRACE и не экспортирует новый
JEDEC при ошибках setup/hold. В GUI Diamond заново загрузить `RomEmu.ldf`
и выбрать `game_programmer`, чтобы подключился новый `programmer_v5.v`.

MAP/PAR/TRACE v5 пока не выполнены; размещение EBR и вместимость MachXO2-1200
не подтверждены. Старый [JEDEC](../../../releases/fpga/game_programmer/) содержит
SPI v4. С новой [прошивкой RP2040](../../../firmware/rp2040/programmer/README.md)
и утилитой v5 он несовместим. Аппаратная проверка v5 ещё нужна.

## Проверки

На Mac, с установленным Icarus Verilog:

```sh
python3 fpga/tests/run.py
```

В Windows с Questa из Diamond:

```powershell
powershell -ExecutionPolicy Bypass -File fpga/tests/run.ps1
```

Сценарии v5: чтение/запись и CRC, границы 4 МиБ, частичная ошибка Flash,
повреждённые и незавершённые кадры, sequence, удержание при переключении GAME,
частичные ответы и watchdog. Icarus дополнительно запускает регрессии отдельных
мапперов, RTC, арбитража и прежнего программатора. Проверяются модели задержек
Flash/F-RAM; они не заменяют post-route анализ внешних путей и испытание платы.
