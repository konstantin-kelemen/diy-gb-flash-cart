# RP2040 programmer v3 — 2026-09-07

Собран `gb_cart_programmer.uf2` для Waveshare RP2040-Zero, версия 3.0.
Бинарный USB, блоки до 1024 байт, SPI 4 МГц. Совместим только с FPGA
`programmer` протокола 3.0. Аппаратная приёмка не выполнена.

## Происхождение

- Базовый коммит: `6a8694a745d329f05bdbe1f1d615b8bdba3c4be7`.
- Сборка выполнена с незакоммиченными изменениями. Точные исходники прошивки,
  FPGA и утилиты Mac сохранены в `source/`; контрольные суммы всех файлов,
  включая UF2 и манифест, — в `SHA256SUMS.txt`.
- Pico SDK 2.3.1: `079c6f39023649b154152db30f1d781e884879bc`.
- TinyUSB: `86ad6e56c1700e85f1c5678607a762cfe3aa2f47`.
- picotool: `2041936441b48a3cc53ae3da9e805229fe8f4e18`.
- ARM GCC 9.2.1; Release; `-Wall -Wextra -Werror`.

Из корня проекта с SDK в `/Users/kkk/pico-sdk`:

```sh
PICO_SDK_PATH=/Users/kkk/pico-sdk cmake -S firmware/rp2040/programmer -B firmware/rp2040/programmer/build-v3 -DPICO_BOARD=waveshare_rp2040_zero -DCMAKE_BUILD_TYPE=Release
cmake --build firmware/rp2040/programmer/build-v3 -j4
```

## Проверка

- Сборка RP2040 завершена; picotool подтвердил версию 3.0, плату, SDK и USB stdio.
- 10 host-тестов и тест фактического C-кода моста с моделью SPI — PASS.
- RTL v3 при SPI 4 МГц и тактах FPGA около 42,55/53,19/64 МГц — PASS.
- Регрессия RTL v2 с общим контроллером шины — PASS.
- JEDEC в выпуск не входит. Map, EBR inference, timing и размещение в MachXO2
  ещё требуют проверки в Diamond. Полный дамп, запись ROM и аппаратная скорость
  не проверены. UF2 не является подтверждением работы стенда.

[Инструкция для Mac](../../../docs/PROGRAMMER.md).
