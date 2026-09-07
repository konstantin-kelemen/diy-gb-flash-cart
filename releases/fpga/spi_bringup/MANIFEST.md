# FPGA spi_bringup — проверенный выпуск 2026-09-07

Проверены ответ версии 1.0, capabilities `0x0000` и 1000/1000 обменов — **PASS**.
Подробности испытания — в [журнале](../../../docs/TEST_PLAN.md#журнал-результатов).

## Сборка и совместимость

- FPGA: `LCMXO2-1200HC-4TG100C`, верхний модуль `top`.
- Конфигурация Diamond: `spi_bringup`.
- Инструменты: Lattice Diamond 3.14.0.75.2.
- Время Bitgen по отчёту: 2026-09-07 19:50:18; часовой пояс не указан.
- Точный исходный коммит сборки в отчётах не зафиксирован.

Совместим с [RP2040 spi_bringup](../../rp2040/spi_bringup/MANIFEST.md);
управление через USB CDC-команды `version` и `test 1000`.
Команды Flash не поддерживаются.

## Результаты Diamond

- Map: 43/640 SLICE, 0 ошибок, 0 предупреждений.
- TRACE: 0 setup / 0 hold ошибок при constraint 2,08 МГц;
  минимальный setup slack +472,723 нс, hold +0,304 нс.
- Place & Route: все соединения разведены, 0 ошибок.
- Bitgen DRC: 0 ошибок, 0 предупреждений.

## Файлы

| Файл | Назначение |
| --- | --- |
| [RomEmu_spi_bringup.jed](RomEmu_spi_bringup.jed) | Готовая прошивка FPGA |
| [RomEmu_spi_bringup.bgn](RomEmu_spi_bringup.bgn) | Bitgen и DRC |
| [RomEmu_spi_bringup.mrp](RomEmu_spi_bringup.mrp) | Map, ресурсы и предупреждения |
| [RomEmu_spi_bringup.par](RomEmu_spi_bringup.par) | Place & Route |
| [RomEmu_spi_bringup.twr](RomEmu_spi_bringup.twr) | TRACE: setup и hold |
| [RomEmu_spi_bringup.pad](RomEmu_spi_bringup.pad) | Назначения выводов |
| [RomEmu_spi_bringup.prf](RomEmu_spi_bringup.prf) | Ограничения, применённые Diamond |

SHA-256 всех файлов выпуска, включая этот манифест, сохранены в
[SHA256SUMS.txt](SHA256SUMS.txt). Проверка на Mac из корня проекта:

```sh
(cd releases/fpga/spi_bringup && shasum -a 256 -c SHA256SUMS.txt)
```
