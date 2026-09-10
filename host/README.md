# Программа для компьютера

`gbflash.py` — утилита macOS для работы с Flash через USB CDC прошивки RP2040
`programmer` v5. USB-блоки до 16 КиБ, CRC-32; требуется FPGA SPI v5.
С прежними выпусками v3/v4 утилита несовместима. [Подготовка и полный цикл чтения, записи и сравнения](../docs/PROGRAMMER.md).

Проверка утилиты из корня проекта:

```sh
python3 -m unittest discover -s host/tests -v
```

Дополнительные команды доступны через `python3 host/gbflash.py --help`.
