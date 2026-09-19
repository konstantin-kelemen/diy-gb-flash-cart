# Программа для компьютера

`gbflash.py` — утилита macOS для работы с Flash через USB CDC прошивки RP2040
`programmer`. [Подготовка и полный цикл чтения, записи и сравнения](../docs/PROGRAMMER.md).

Проверка утилиты из корня проекта:

```sh
python3 -m unittest discover -s host/tests -v
```

Дополнительные команды доступны через `python3 host/gbflash.py --help`.
## FRAM (сохранения)

Требуются обновлённые прошивки FPGA `game_programmer` и RP2040; готовые старые
файлы из `releases/` FRAM-команды не поддерживают.

```sh
python host/gbflash.py --port "$FLASH_PORT" fram-read save.sav
python host/gbflash.py --port "$FLASH_PORT" fram-write save.sav
python host/gbflash.py --port "$FLASH_PORT" fram-clear --value 0xff
```

Ёмкость FRAM — 128 КиБ. Чтение и очистка по умолчанию охватывают всю память.
Доступны `--address` и, для чтения/очистки, `--length`; запись меняет только
диапазон файла и не требует `--erase`. Запись и очистка завершаются проверкой
чтением. [Подробности](../docs/PROGRAMMER.md#чтение-и-запись-fram).
