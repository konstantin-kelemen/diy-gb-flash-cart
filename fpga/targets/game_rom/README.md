# Game Boy: ROM 32 КиБ из Flash

`game_rom` выдаёт первые 32 КиБ MX29LV320E в адресах Game Boy `0000–7FFF`.
Поддерживается ROM ONLY без RAM и маппера: заголовок `0147–0149 = 00 00 00`
([формат заголовка](https://gbdev.io/pandocs/The_Cartridge_Header.html)).
У записанного `flash-test-20260907-232422/rom.gb` этот формат подтверждён.

## Реализация

Асинхронный путь: `gb_a[14:0] → flash_a[14:0]`, `flash_d → gb_d`.
Старшие семь бит адреса Flash равны нулю. Сохранена байтовая адресация
программатора: `flash_a[0]` подключён к A−1 (DQ15), BYTE# — LOW.
Назначения выводов Game Boy и направление `data_dir = 1` перенесены
из проверенной конфигурации `internal_rom`, выводы Flash — из `programmer`.

Flash CE#/OE# и преобразователь данных включаются только при `A15 = 0`
и `RD# = 0`. В остальных случаях шина данных Game Boy освобождена.
WE# Flash постоянно HIGH; FPGA не управляет входной шиной `flash_d`.
Записи Game Boy игнорируются. CS# не используется: здесь нет внешней RAM.

Это отдельный режим GAME: SPI, маппер, F-RAM и переключение в PROGRAMMER
в этой конфигурации не реализованы. Для новой записи ROM используется
[программатор](../../../docs/PROGRAMMER.md), затем снова загружается `game_rom`.
Flash должна находиться в режиме чтения массива; программатор возвращает её
в этот режим после операций. Содержимое Flash при прошивке FPGA не меняется.

## Сборка и запуск

1. В Windows открыть `fpga/diamond/RomEmu.ldf`, выбрать **game_rom** через
   `Set as Active Implementation`. Верхний модуль — `top`.
2. Выполнить `Synthesize Design`, `Map Design`, `Place & Route Design`,
   анализ TRACE и `Export Files → JEDEC File`.
3. Сверить `.pad` с `fpga/constraints/game_rom.lpf` по
   [процедуре LPF](../../../docs/TEST_PLAN.md#сверка-lpf).
4. При отключённом Game Boy прошить
   `fpga/diamond/game_rom/RomEmu_game_rom.jed` через Diamond Programmer.
5. Подключить стенд к Game Boy с согласованным питанием по
   [архитектуре](../../../docs/ARCHITECTURE.md#питание), отключив USB RP2040.
   Включить Game Boy. Ожидается запуск записанного ROM после заставки.

Ранее выполненное сравнение `after.bin` с `rom.gb` подтверждает содержимое
Flash; повторно записывать тот же ROM для этого запуска не требуется.
Критерий аппаратной проверки — характерный экран и работа записанной программы,
а не только логотип Nintendo. Результат сохраняется в
[журнале](../../../docs/TEST_PLAN.md#журнал-результатов).

## Временные параметры

В схеме нет тактового генератора и синхронного контроллера Flash.
В LPF намеренно нет FREQUENCY и BLOCK ASYNCPATHS. Отсутствие setup/hold ошибок
само по себе не подтверждает скорость асинхронного тракта.
После размещения проверить задержки `gb_a → flash_a`,
`gb_a[15]/gb_rd_n → CE#/OE#/data_oe_n` и `flash_d → gb_d`.
Полный бюджет чтения включает преобразователи уровней, FPGA, время доступа
Flash и разводку стенда; его нужно сопоставить с моментом выборки Game Boy.

RTL-тест использует задержки Flash 70 нс и преобразователя данных 10 нс,
проверяет данные через 100 нс после изменения входов. Это параметры модели,
а не измерение стенда или результат post-route анализа. Diamond и аппаратный
запуск этой конфигурации пока не проверены.

## RTL-проверка на Mac

Из корня проекта с установленным Icarus Verilog:

```sh
iverilog -g2012 -Wall -s game_rom_tb -o /tmp/game-rom.vvp fpga/targets/game_rom/top.v fpga/tests/game_rom_tb.sv
vvp /tmp/game-rom.vvp
```

Тест перебирает весь ROM, всё пространство вне ROM, случайные адреса,
изменение адреса при удержании RD#, отдельные импульсы RD# и записи CPU.
Ожидается `PASS game_rom`.

Для проверки с конкретным ROM вместо случайных данных:

```sh
python3 - /полный/путь/к/rom.gb /tmp/game-rom.hex <<'PY'
from pathlib import Path
import sys
rom = Path(sys.argv[1]).read_bytes()
if len(rom) != 32768 or rom[0x147:0x14a] != bytes(3):
    sys.exit("Ожидается ROM ONLY 32 КиБ без RAM")
Path(sys.argv[2]).write_text("".join(f"{b:02x}\n" for b in rom))
PY
vvp /tmp/game-rom.vvp +ROM=/tmp/game-rom.hex
```
