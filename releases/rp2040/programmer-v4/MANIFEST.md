# RP2040 programmer v4

Дата сборки: 2026-09-10. Плата: `waveshare_rp2040_zero`, RP2040, Release.
Прошивка: [gb_cart_programmer.uf2](gb_cart_programmer.uf2).
Использовать с [FPGA game_programmer SPI v4](../../fpga/game_programmer/MANIFEST.md),
обновляя оба устройства. Эта прошивка отклоняет FPGA с прежним SPI v3.

Внешний USB CDC остаётся GB3Q/GB3R v3, блоки до 1024 байт; внутренний SPI — v4,
Mode 0, 4 МГц. RP2040 хранит блоки, проверяет CRC, выполняет последовательность
однобайтовых команд и пропускает запись FF. Ошибка подтверждения записи не вызывает
автоматического повтора разрушительной команды. FPGA сохраняет тайминги Flash и
управление общей шиной; удержание режима действует на весь блок.

## Сборка и проверки

- Pico SDK **2.2.0**, commit `a1438dff1d38bd9c65dbd693f0e5db4b9ae91779`.
- TinyUSB commit `86ad6e56c1700e85f1c5678607a762cfe3aa2f47`.
- ARM GNU Toolchain **14.3.Rel1**, CMake **3.31.8**, Ninja, Python **3.12.10**.
- ARM Release: PASS с `-Wall -Wextra -Werror`; text 31456, data 0, bss 8192 байт.
- UF2: 54784 байта, RP2040 family ID `E48BFF56`, начало XIP `0x10000000`.
  SDK формирует boot2 и BIN; `tools/bin_to_uf2.py` упаковывает BIN при
  `PICO_NO_PICOTOOL=1`. Сохранены также ELF и BIN.
- Три теста Python unittest: PASS. Реальный `src/main.c` компилируется TinyCC 0.9.27
  с моделью SPI и SDK; проверены блоки 1024 байта, CRC, границы, блокировка,
  частичное выполнение, несовместимость версии, смена GAME-питания, потерянные ACK
  и отсутствие повторной записи. Два теста проверяют упаковку UF2 и неверные размеры.
- Дополнительно проверены заголовки всех блоков итогового UF2 и побайтовое
  восстановление исходного BIN из него; результат в `artifact_check.txt`.
- **Аппаратного испытания этой пары ещё нет.** Пропускная способность USB/SPI
  и работа на реальной Flash требуют измерения на плате.

## Воспроизведение

Базовый коммит `122ff897a08f96814daeb0b47291b8ad3d7ae0bb` с незакоммиченными
изменениями. Точный снимок общих исходников и его SHA-256 находится в
[комплекте FPGA](../../fpga/game_programmer/source/).
Контрольные суммы файлов этого выпуска — `SHA256SUMS.txt`.

С установленным ARM GCC, Ninja, Python и SDK с TinyUSB, из корня исходников:

```sh
cmake -S firmware/rp2040/programmer -B firmware/rp2040/programmer/build-offload -G Ninja -DPICO_BOARD=waveshare_rp2040_zero -DPICO_NO_PICOTOOL=1 -DCMAKE_BUILD_TYPE=Release -DPICO_SDK_PATH=/path/to/pico-sdk
cmake --build firmware/rp2040/programmer/build-offload -j4
python -m unittest discover -s firmware/rp2040/programmer/tests -v
```

Для последней команды нужен нативный C-компилятор; путь задаётся переменной `CC`.
Полные инструкции и формат SPI включены в снимок исходников.
