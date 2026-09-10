# Исходники FPGA

## Конфигурации

Новая совмещённая конфигурация: [game_programmer](targets/game_programmer/README.md).
Блоки программирования обрабатывает RP2040; FPGA использует короткий SPI v4.

| Каталог target | Реализация Diamond | Ограничения / инструкция |
|---|---|---|
| `targets/internal_rom/` | `v1_0` | `constraints/internal_rom.lpf`; сборка ниже |
| `targets/flash_bringup/` | `flash_bringup` (активна по умолчанию) | Общий `internal_rom.lpf`; [инструкция](targets/flash_bringup/README.md) |
| `targets/spi_bringup/` | `spi_bringup` | `constraints/spi_bringup.lpf`; [сборка и симуляция](targets/spi_bringup/README.md) |
| `targets/game_rom/` | `game_rom` | `constraints/game_rom.lpf`; [запуск ROM из Flash](targets/game_rom/README.md) |
| `targets/game_mbc5/` | `game_mbc5` | `constraints/game_mbc5.lpf`; [LSDj и F-RAM](targets/game_mbc5/README.md) |
| `targets/programmer/` | `programmer` | `constraints/programmer.lpf`; [запись Flash](targets/programmer/README.md) |

Добавлена GAME-конфигурация MBC5 для LSDj 1 МиБ / RAM 128 КиБ.
RTL и адаптация PROGRAMMER к F-RAM проверены в симуляции; новые JEDEC
ещё не собраны. Старые выпуски PROGRAMMER с диагностикой на 82–83
несовместимы с подключённой F-RAM. Назначения — в
[схеме KiCad](../hardware/cartridge/cartridge.kicad_sch).

Каждая конфигурация содержит собственный `top` и собирается независимо.
Общие модули — в `rtl/`, тесты — в `tests/`, проект — в `diamond/`.

`examples/hello_world.v` — минимальный пример выхода FPGA,
`examples/fram_test.v` — ранний автономный тест F-RAM. Они не подключены
к проекту Diamond. Перед использованием нужны отдельная конфигурация,
проверенный LPF и испытания.

## Работа в Lattice Diamond

Открывать нужно проект `diamond/RomEmu.ldf`, сохраняя рядом всю структуру
каталога `fpga/`: пути к исходникам и ограничениям в проекте относительные.
Копировать один каталог `diamond/` в другое место не следует.

Для обычной сборки `internal_rom`:

1. Выберите в Diamond `File -> Open -> Project` и откройте
   `diamond/RomEmu.ldf`.
2. Убедитесь, что активна реализация `v1_0`. В ней должны быть подключены
   `targets/internal_rom/top.v` и `constraints/internal_rom.lpf`, а модулем
   верхнего уровня должен быть `top`.
3. В окне `Process` последовательно запустите `Synthesize Design`,
   `Map Design`, `Place & Route Design` и `Export Files -> JEDEC File`.
4. Полученный файл находится по пути
   `diamond/v1_0/RomEmu_v1_0.jed`.

Каталог `diamond/v1_0/` содержит только результаты сборки. Он исключён из Git,
может быть удалён и будет создан Diamond заново. Исходный Verilog нужно
редактировать в `targets/` и `rtl/`, ограничения — в `constraints/`, а не в
сгенерированных копиях внутри каталога реализации.

Если Diamond сообщает об отсутствующих исходниках, удалите устаревшие ссылки
из реализации и добавьте нужные файлы через `Add -> Existing File`. Параметр
`Copy source to implementation directory` при этом должен быть отключён, чтобы
в проекте не появлялись отдельные копии исходников.

### Добавление другой конфигурации

Для новой конфигурации следует создавать отдельную реализацию Diamond, не
заменяя файлы в `v1_0`. Реализацию можно добавить через
`Add -> New Implementation`, после чего подключить её `top.v`, общие модули из
`rtl/` и отдельный LPF из `constraints/`. Одновременно активна только одна
реализация; перед сборкой нужно выбрать её через `Set as Active Implementation`
и установить модуль `top` верхним уровнем.

Особенности общего LPF и предупреждения `flash_bringup` описаны в
[README конфигурации](targets/flash_bringup/README.md).

После сохранения проекта через интерфейс Diamond следует проверить, какие
файлы проекта были изменены:

```sh
git diff -- fpga/diamond/RomEmu.ldf fpga/diamond/RomEmu1.sty
git status --short
```

## Проверка назначений выводов

Перед программированием реального устройства нужно выполнить
[процедуру сверки LPF](../docs/TEST_PLAN.md#сверка-lpf). Расхождения нельзя
скрывать изменением текстовой документации.

Состояние аппаратных проверок — в [STATUS.md](../docs/STATUS.md),
сохранённые сборки — в [releases/](../releases/README.md).
