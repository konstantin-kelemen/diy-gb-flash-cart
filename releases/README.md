# Выпуски

В FPGA-релизах хранятся JEDEC, основные отчёты Diamond и SHA-256;
в RP2040-релизах — UF2 и SHA-256. Исходники, тесты, документация и скрипты
остаются в основных каталогах проекта.

## FPGA

- [lsdj-working-2026-09-20](fpga/lsdj-working-2026-09-20/) — свежая база GAME + PROGRAMMER:
  сохранённый JEDEC, отчёты и снимок исходников; после замены FRAM
  ошибка устранена, LSDj запускается. 582/640 SLICE, setup/hold PASS.
- [game_programmer](fpga/game_programmer/) — GAME + PROGRAMMER, SPI v4; 581/640 SLICE,
  setup/hold PASS. На плате ещё не проверен; использовать с RP2040 programmer-v4.
- [game_rom](fpga/game_rom/) — ROM ONLY 32 КиБ.
- [game_mbc5](fpga/game_mbc5/) — MBC5 с F-RAM.
- [game_multi](fpga/game_multi/) — несколько мапперов, F-RAM и RTC.
  Эти три сборки предшествуют оптимизации game_programmer; аппаратный PASS
  для сохранённых JEDEC не зафиксирован. Внешние тайминги покрыты не полностью.
- [spi_bringup](fpga/spi_bringup/) — SPI 1.0, аппаратный PASS 1000/1000.
- [flash-bringup-pass](fpga/flash-bringup-pass/) — аппаратный PASS после прошивки
  и перезапуска питания.
- [internal-rom-baseline](fpga/internal-rom-baseline/) — проверенная база с внутренним ПЗУ.

Успешные MAP/TRACE не заменяют испытание внешней шины на плате.

## RP2040

- [programmer-v4](rp2040/programmer-v4/) — для FPGA game_programmer с SPI v4;
  совместимость зафиксирована в рабочей базе LSDj от 2026-09-20.
  Команды передачи F-RAM из текущих исходников требуют новой пары сборок.
- [spi_bringup](rp2040/spi_bringup/) — аппаратный PASS 1000/1000 с FPGA spi_bringup.

## Плата

[breakout/v1.0.zip](breakout/v1.0.zip) — производственный архив отладочной платы.

## Контрольные суммы

Из каталога конкретного выпуска: `shasum -a 256 -c SHA256SUMS.txt` на macOS.
Файлы релизов сохраняются побайтово, без преобразования переводов строк.
