# Выпуски

В FPGA-релизах хранятся JEDEC, основные отчёты Diamond и SHA-256;
в RP2040-релизах — UF2 и SHA-256. Исходники, тесты, документация и скрипты
остаются в основных каталогах проекта.

## FPGA

- [game_programmer](fpga/game_programmer/) — GAME + PROGRAMMER, SPI v4; 581/640 SLICE,
  setup/hold PASS. На плате ещё не проверен; использовать с RP2040 programmer-v4.
- [game_rom](fpga/game_rom/) — ROM ONLY 32 КиБ.
- [game_mbc5](fpga/game_mbc5/) — MBC5 с F-RAM.
- [game_multi](fpga/game_multi/) — несколько мапперов, F-RAM и RTC.
  Эти три сборки предшествуют оптимизации game_programmer; аппаратный PASS
  для сохранённых JEDEC не зафиксирован. Внешние тайминги покрыты не полностью.
- [spi_bringup](fpga/spi_bringup/) — SPI 1.0, аппаратный PASS 1000/1000.
- [programmer-v3](fpga/programmer-v3/) — аппаратный PASS полного цикла Flash.
- [flash-bringup-pass](fpga/flash-bringup-pass/) — аппаратный PASS после прошивки
  и перезапуска питания.
- [flash-bringup-fail](fpga/flash-bringup-fail/) — историческая сборка с FAIL.
- [internal-rom-baseline](fpga/internal-rom-baseline/) — проверенная база с внутренним ПЗУ.

Успешные MAP/TRACE не заменяют испытание внешней шины на плате.

## RP2040

- [programmer-v4](rp2040/programmer-v4/) — для FPGA game_programmer с SPI v4;
  обновлять оба устройства парой. Аппаратного испытания ещё нет.
- [programmer-v3](rp2040/programmer-v3/) — для FPGA programmer-v3, аппаратный PASS.
- [programmer](rp2040/programmer/) — прежний несовместимый программатор v2.
- [spi_bringup](rp2040/spi_bringup/) — аппаратный PASS 1000/1000 с FPGA spi_bringup.

## Плата

[breakout/v1.0.zip](breakout/v1.0.zip) — производственный архив отладочной платы.

## Контрольные суммы

Из каталога конкретного выпуска: `sha256sum -c SHA256SUMS.txt`.
Файлы релизов сохраняются побайтово, без преобразования переводов строк.
