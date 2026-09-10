# Чтение и запись Flash с Mac

Стенд: Mac → USB → RP2040-Zero → SPI → FPGA → MX29LV320E, 4 МиБ
(4 194 304 байта), режим x8. FPGA — `game_programmer`, RP2040 — `programmer-v4`.
Внешний USB-протокол — 3.0, внутренний SPI — v4. Game Boy отключён. [Подключение и питание](SPI_BRINGUP.md).
[Текущее состояние проверок](STATUS.md), [этапы и критерии](ROADMAP.md).

## Подготовка FPGA в Windows

Использовать [JEDEC game_programmer](../releases/fpga/game_programmer/RomEmu_game_programmer.jed)
с [RP2040 programmer-v4](../releases/rp2040/programmer-v4/). Обновлять оба устройства
парой. Сборка и симуляции пройдены, аппаратное испытание этой пары ещё не выполнено.
[Сборка FPGA из исходников](../fpga/targets/game_programmer/README.md).

## Подготовка Mac

Все команды ниже выполнять из корня проекта в одном окне Terminal.

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install pyserial
```

Загрузить готовую прошивку RP2040: удерживая BOOTSEL, подключить плату к Mac
по USB. После появления диска `RPI-RP2` выполнить:

```sh
cp releases/rp2040/programmer-v4/gb_cart_programmer.uf2 /Volumes/RPI-RP2/
```

Плата перезапустится, диск исчезнет, появится USB CDC-порт.
[Выпуск UF2](../releases/rp2040/programmer-v4/).
Включить питание FPGA. Найти порт:

```sh
ls /dev/cu.usbmodem*
```

```sh
FLASH_PORT=/dev/cu.usbmodem1234561
python host/gbflash.py --port "$FLASH_PORT" info
```

Ожидается `MX29LV320E: C2 A8, Bottom Boot, PROGRAMMER` либо
`MX29LV320E: C2 A7, Top Boot, PROGRAMMER`. Команда `info` читает ID и
возвращает Flash в режим чтения; содержимое памяти не меняется.
При ошибке не переходить к следующим шагам.

Создать отдельный каталог для этого испытания:

```sh
FLASH_RUN="$PWD/flash-test-$(date +%Y%m%d-%H%M%S)"
mkdir "$FLASH_RUN"
```

Утилита Mac использует блочный USB-протокол 3.0. RP2040 выполняет обработку
блоков и обменивается короткими командами SPI v4 с FPGA.
[Описание протокола и переключения режимов](PROGRAMMER_SPI_V4.md).

## 1. Считать все 4 МиБ в файл

```sh
/usr/bin/time -p python host/gbflash.py --port "$FLASH_PORT" read "$FLASH_RUN/before.bin" --address 0 --length 0x400000
```

Дождаться `Read: 4194304 bytes` без ошибок. Проверить размер и сохранить SHA-256:

```sh
python -c 'import pathlib, sys; p = pathlib.Path(sys.argv[1]); n = p.stat().st_size; print(f"{p.name}: {n} bytes"); sys.exit(0 if n == 4194304 else 1)' "$FLASH_RUN/before.bin"
shasum -a 256 "$FLASH_RUN/before.bin" > "$FLASH_RUN/before.sha256"
```

`before.bin` — исходное содержимое всего чипа перед записью.
`read` не перезаписывает существующий файл. При ошибке остаётся неполный дамп;
такой файл не считается успешным результатом. Для повторного запуска создать
новый каталог испытания.

## 2. Записать файл .gb

Указать путь к нужному ROM. Принимаются непустые файлы до 4 МиБ
включительно — по ёмкости Flash. Ниже LSDj приведён как пример.
Сохранить его копию в каталоге испытания, чтобы последующее сравнение выполнялось
с теми же байтами:

```sh
FLASH_ROM="$PWD/roms/lsdj9_4_2.gb"
cp "$FLASH_ROM" "$FLASH_RUN/rom.gb"
```

После успешного полного чтения на шаге 1 выполнить запись с адреса 0.
Размер файла проверяется утилитой до обращения к устройству:

```sh
/usr/bin/time -p python host/gbflash.py --port "$FLASH_PORT" write "$FLASH_RUN/rom.gb" --erase
```

`--erase` стирает целиком секторы, пересекающие ROM, включая остаток последнего
сектора за концом файла. Другие секторы не меняются. Утилитой проверяется
стирание, записывается образ, затем выполняется встроенное чтение и сравнение.
Дождаться `Result: SUCCESS`. При ошибке остановить испытание.
Встроенная проверка не создаёт файл дампа; он сохраняется отдельным шагом ниже.

## 3. Считать все 4 МиБ повторно и сравнить с ROM

```sh
/usr/bin/time -p python host/gbflash.py --port "$FLASH_PORT" read "$FLASH_RUN/after.bin" --address 0 --length 0x400000
```

Дождаться `Read: 4194304 bytes` без ошибок. Проверить полный размер дампа и
побайтово сравнить диапазон от адреса 0 до конца ROM с сохранённым `.gb`:

```sh
python - "$FLASH_RUN/rom.gb" "$FLASH_RUN/after.bin" <<'PYCOMPARE'
from pathlib import Path
import sys
rom = Path(sys.argv[1]).read_bytes()
dump = Path(sys.argv[2]).read_bytes()
if not 0 < len(rom) <= 4194304:
    sys.exit("FAIL: размер ROM должен быть не больше 4 МиБ")
if len(dump) != 4194304:
    sys.exit(f"FAIL: размер дампа {len(dump)}, ожидалось 4194304")
for address, expected in enumerate(rom):
    actual = dump[address]
    if actual != expected:
        sys.exit(f"FAIL: адрес 0x{address:06X}, ROM={expected:02X}, Flash={actual:02X}")
print(f"PASS: побайтово проверено {len(rom)} байт ROM; полный дамп — {len(dump)} байт")
PYCOMPARE
shasum -a 256 "$FLASH_RUN/rom.gb" "$FLASH_RUN/after.bin" > "$FLASH_RUN/after.sha256"
```

Зафиксировать результат и контрольные суммы загруженных UF2/JEDEC в
[журнале испытаний](TEST_PLAN.md#журнал-результатов).
