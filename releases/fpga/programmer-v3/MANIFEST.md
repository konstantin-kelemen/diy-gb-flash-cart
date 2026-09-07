# FPGA programmer-v3 — проверенный выпуск 2026-09-07

Проверен полный цикл Flash: два дампа по 4 МиБ, стирание сектора,
запись ROM 32 КиБ и побайтовое сравнение — **PASS**.
Подробности испытания — в [журнале](../../../docs/TEST_PLAN.md#журнал-результатов).

## Сборка и совместимость

- FPGA: `LCMXO2-1200HC-4TG100C`, верхний модуль `top`.
- Конфигурация Diamond: `programmer`.
- Инструменты: Lattice Diamond 3.14.0.75.2.
- Время Bitgen по отчёту: 2026-09-07 23:10:05; часовой пояс не указан.
- Точный исходный коммит сборки в отчётах не зафиксирован.

Совместим с [RP2040 programmer-v3](../../rp2040/programmer-v3/MANIFEST.md)
и [host/gbflash.py](../../../host/gbflash.py), протокол 3.0,
блоки до 1 КиБ, SPI 4 МГц. Выпуски v2 несовместимы.
Снимок FPGA-исходников в старом выпуске RP2040 v3 предшествует исправлению
timing; для прошивки используется JEDEC из этого каталога.

## Результаты Diamond

- Map: 506/640 SLICE, 2/7 EBR, 0 ошибок, 1 предупреждение.
- TRACE: 0 setup / 0 hold ошибок при constraint 53,200001 МГц;
  минимальный setup slack +1,614 нс, hold +0,287 нс.
- Map отклонил FREQUENCY 64 МГц для OSCH и применил NOM_FREQ 53,20 МГц.
  Проверка timing до 64 МГц этим отчётом не подтверждена.
- Place & Route: все соединения разведены, 0 ошибок.
- Bitgen DRC: 0 ошибок, 0 предупреждений.

## Файлы

| Файл | Назначение |
| --- | --- |
| [RomEmu_programmer.jed](RomEmu_programmer.jed) | Готовая прошивка FPGA |
| [RomEmu_programmer.bgn](RomEmu_programmer.bgn) | Bitgen и DRC |
| [RomEmu_programmer.mrp](RomEmu_programmer.mrp) | Map, ресурсы и предупреждения |
| [RomEmu_programmer.par](RomEmu_programmer.par) | Place & Route |
| [RomEmu_programmer.twr](RomEmu_programmer.twr) | TRACE: setup и hold |
| [RomEmu_programmer.pad](RomEmu_programmer.pad) | Назначения выводов |
| [RomEmu_programmer.prf](RomEmu_programmer.prf) | Ограничения, применённые Diamond |

SHA-256 всех файлов выпуска, включая этот манифест, сохранены в
[SHA256SUMS.txt](SHA256SUMS.txt). Проверка на Mac из корня проекта:

```sh
(cd releases/fpga/programmer-v3 && shasum -a 256 -c SHA256SUMS.txt)
```
