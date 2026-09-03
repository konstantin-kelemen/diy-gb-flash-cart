# Game Boy FPGA Flash Cartridge — PROJECT_STATE

**Last updated:** 2026-09-02  
**Status:** External Flash bring-up and programming path  
**Revision:** 0.4

---

## 1. Цель

Создать flash-картридж для оригинального Game Boy с:

- FPGA для логики картриджа и MBC
- 4 MB Flash ROM
- 128 KB FRAM для сохранений
- RP2040-Zero для USB
- возможностью загружать ROM и читать/записывать saves через USB

Первый прототип собирается на проводах. Финальная цель — собственная PCB картриджа.

---

## 2. Компоненты

### FPGA

**Lattice `LCMXO2-1200HC-4TG100C`**

- MachXO2-1200HC
- TQFP-100
- 3.3 V

Задачи FPGA:

- интерфейс с cartridge bus Game Boy
- address decoding
- управление ROM и FRAM
- MBC / bank switching
- арбитраж доступа Game Boy ↔ RP2040
- управление параллельной Flash при чтении, стирании и записи

**Статус:** получен и протестирован 2026-08-31.

Проверено:

- питание 3.3 V
- programming adapter
- JTAG
- `HW-USBN-2B`
- определение FPGA в Lattice Diamond
- программирование
- запуск тестового design
- работа в составе прототипа `Game Boy connector → SN74LVC8T245 → FPGA`
- эмуляция минимального ROM на реальном Game Boy

Pins 48 и 49 разрешено использовать как PIO. Текущее назначение пинов проверено через Diamond `Check Pins`.

---

### ROM

**Macronix `MX29LV320E T/B`**

- 32 Mbit / 4 MB
- используется в режиме x8
- назначение: хранение ROM

Address mapping:

```text
FPGA MEM_A0  -> Flash A-1
FPGA MEM_A1  -> Flash A0
FPGA MEM_A2  -> Flash A1
...
FPGA MEM_A21 -> Flash A20
```

`BYTE#` используется для выбора x8 mode: Pin 47 → GND.

**Статус:** выбран; подключение и bring-up — следующий текущий этап.

---

### FRAM

**Infineon/Cypress `FM28V100-TG`**

- 1 Mbit / 128 KB
- 3.3 V
- назначение: энергонезависимые saves без батареи

На `WE` требуется pull-up:

```text
3.3V
 |
10 kΩ
 |
 +---- WE FRAM
 |
 +---- FPGA fram_we_n
```

Pull-up нужен для защиты от случайной записи во время включения питания и конфигурации FPGA.

**Статус:** ещё не реализовано; отложено до подтверждения работы внешней Flash.

---

### MCU / USB

**RP2040-Zero**

Задачи:

- USB-интерфейс
- передача ROM в FPGA для записи во Flash
- чтение данных Flash через FPGA для verify
- в дальнейшем — чтение/запись FRAM и служебное управление FPGA

Выбран постоянный интерфейс RP2040 ↔ FPGA: **SPI, 3.3 V**.

Логические сигналы:

```text
SCK
MOSI
MISO
CS#
GND
```

Точные физические выводы RP2040 и FPGA пока не зафиксированы и должны быть выбраны после проверки доступного pinout.

---

### Level shifters

**4 × `SN74LVC8T245PWR`**

Game Boy использует 5 V логику, FPGA и память — 3.3 V.

Level shifters располагаются между Game Boy и FPGA.

`D0-D7` — двунаправленная шина. Направлением соответствующего `SN74LVC8T245` управляет FPGA через сигнал:

```text
data_dir
```

**Статус:** прототип `Game Boy connector → SN74LVC8T245 → FPGA` собран и работает на реальном Game Boy.

---

## 3. Архитектура

```text
              +-------------+
              |  Game Boy   |
              +------+------+
                     |
                  5 V bus
                     |
            +--------+--------+
            | SN74LVC8T245 x4 |
            +--------+--------+
                     |
                  3.3 V bus
                     |
                +----+----+        SPI        +-------------+
                | MachXO2 |<----------------->| RP2040-Zero |
                |  FPGA   |                   | USB <-> PC  |
                +--+---+--+                   +-------------+
                   |   |
          +--------+   +---------+
          |                      |
      +---+---+              +---+---+
      | Flash |              | FRAM  |
      | 4 MB  |              |128 KB |
      +-------+              +-------+
```

FPGA является центральным контроллером и единственным устройством, которое непосредственно управляет параллельной Flash. RP2040 не подключается к полной address/data bus Flash: он передаёт команды и данные FPGA по SPI.

Основные внутренние шины:

```text
MEM_A0 ... MEM_A21
D0 ... D7
```

FRAM использует только необходимую младшую часть address bus.

FPGA отвечает за `CE#/OE#/WE#` и не должна допускать одновременного управления data bus несколькими устройствами.

### Режимы доступа к Flash

FPGA имеет два явно разделённых режима:

```text
GAME MODE
  Game Boy -> FPGA address/data interface -> Flash
  Flash WE# удерживается в неактивном состоянии

PROGRAMMER MODE
  PC -> USB -> RP2040 -> SPI -> FPGA programmer -> Flash
  Game Boy side не управляет Flash
```

Для первого прототипа допустимо ручное или иное простое переключение `GAME / PROGRAMMER`. Автоматический арбитраж одновременного доступа пока не требуется.

---

## 4. Подтверждённые milestones

### FPGA programming baseline — подтверждено

FPGA стабильно определяется, программируется через `HW-USBN-2B` и запускает тестовый design.

### Game Boy bus + internal ROM — подтверждено

Собран и проверен на реальном Game Boy прототип:

```text
Game Boy connector
        ↓
SN74LVC8T245
        ↓
FPGA
        ↓
minimal ROM inside FPGA
```

Наблюдаемый результат:

```text
Power on
   ↓
Nintendo logo
   ↓
black screen
```

Это подтверждает, что Game Boy способен читать минимальный ROM через собранную физическую цепочку и что FPGA отвечает на cartridge bus достаточно корректно для прохождения проверки логотипа. Чёрный экран сам по себе не используется как доказательство полноценного выполнения тестовой программы; при необходимости это отдельно проверяется diagnostic ROM с очевидным визуальным результатом.

### Следующий milestone

Записать тот же известный минимальный test ROM по пути:

```text
PC -> USB -> RP2040 -> SPI -> FPGA -> MX29LV320E
```

затем обязательно прочитать его обратно и сравнить с исходным файлом, переключить FPGA в `GAME MODE` и получить на реальном Game Boy тот же наблюдаемый результат: Nintendo logo, затем black screen.

---

## 5. Программирование FPGA

Используется:

**Lattice `HW-USBN-2B`**

На финальной PCB нужно вывести JTAG:

```text
TCK
TMS
TDI
TDO
GND
VTREF
```

FPGA можно программировать уже после пайки на картридж.

Во время программирования плата должна иметь собственное питание 3.3 V.

Эта схема уже проверена на реальном FPGA.

---

## 6. Программирование внешней Flash

MX29LV320E — параллельная NOR Flash, поэтому команды стирания и записи формирует FPGA на её address/data/control lines. RP2040 выполняет роль USB-контроллера и отправляет FPGA по SPI команды, адреса и данные.

Минимальный путь первой версии:

```text
test.gb
   ↓ USB
RP2040-Zero
   ↓ SPI: SCK/MOSI/MISO/CS#
MachXO2 programmer FSM
   ↓ parallel address/data/control bus
MX29LV320E
```

FPGA programmer должен как минимум поддержать:

- чтение Flash
- стирание
- программирование байтов или блоков, собранное поверх byte-program operations Flash
- ожидание завершения операции и сообщение об ошибке/тайм-ауте
- чтение записанного диапазона для verify

`WE#` должен оставаться неактивным по умолчанию и в `GAME MODE`. Стирание и запись разрешены только в явно выбранном `PROGRAMMER MODE`.

**Verify обязателен:** после записи весь записанный диапазон читается обратно через `Flash → FPGA → RP2040 → PC` и сравнивается байт-в-байт с исходным ROM. Переход к запуску на Game Boy разрешён только после `VERIFY OK`.

---

## 7. Питание

### От Game Boy

```text
Game Boy 5V
     |
3.3V regulator
     |
     +-- FPGA
     +-- Flash
     +-- FRAM
     +-- 3.3V logic
```

5 V Game Boy не подаются непосредственно на FPGA и память.

### От USB

RP2040-Zero получает питание от USB.

До проектирования PCB необходимо определить схему питания, исключающую back-powering:

```text
USB -> Game Boy
Game Boy -> USB VBUS
```

Также нужно определить поведение при одновременном подключении USB и Game Boy. Для первого прототипа режимы программирования и игры можно проверять раздельно.

---

## 8. Пассивные компоненты

Базово:

- `100 nF` ceramic decoupling у supply pins цифровых IC
- bulk capacitance на 3.3 V rail
- `10 kΩ` pull-up на `WE` FRAM

Полный список пассивных компонентов и конкретные подключения хранить отдельно в `BOM.md` / `PINOUT.md`.

---

## 9. Текущий статус

### Готово

- [x] выбрана архитектура картриджа
- [x] выбран `LCMXO2-1200HC-4TG100C`
- [x] FPGA получен и протестирован
- [x] programming adapter и JTAG работают
- [x] FPGA программируется через `HW-USBN-2B`
- [x] тестовый FPGA design работает
- [x] выбран Flash `MX29LV320E T/B`
- [x] выбрана FRAM `FM28V100-TG`
- [x] выбран `RP2040-Zero`
- [x] выбраны `4 × SN74LVC8T245PWR`
- [x] выбран управляемый `data_dir` для data bus
- [x] собран прототип `Game Boy connector → SN74LVC8T245 → FPGA`
- [x] минимальный ROM эмулируется FPGA на реальном Game Boy
- [x] подтверждён результат `Nintendo logo → black screen`
- [x] выбран SPI для интерфейса RP2040 ↔ FPGA
- [x] выбраны режимы FPGA `GAME / PROGRAMMER`
- [x] verify после записи принят как обязательное требование

### Сейчас

**Внешняя MX29LV320E и путь её программирования через RP2040 → FPGA → Flash.**

Текущая последовательность:

```text
подключить MX29LV320E к FPGA
        ↓
реализовать и проверить чтение Flash
        ↓
реализовать erase/program/status в FPGA
        ↓
поднять SPI между RP2040 и FPGA
        ↓
прочитать Flash через USB
        ↓
erase + небольшой test pattern + verify
        ↓
записать известный test ROM + полный verify
        ↓
переключить FPGA в GAME MODE
        ↓
загрузить ROM на реальном Game Boy
```

Подробный план вынесен в `NEXT_STEPS.md`.

---

## 10. Открытые вопросы

### Hardware

- [ ] окончательная схема 3.3 V питания
- [ ] USB / Game Boy power isolation
- [ ] окончательное подключение Flash `BYTE#` (Pin 47 → GND)
- [ ] состояние `WP#/ACC` Flash в обычном режиме и при программировании
- [ ] FRAM `WE` pull-up
- [ ] power-up состояния `DIR/OE` level shifters
- [ ] точные физические выводы SPI между RP2040 и FPGA
- [ ] способ простого переключения `GAME / PROGRAMMER` в первом прототипе
- [ ] автоматический арбитраж памяти между Game Boy и RP2040 для будущей версии
- [ ] полный финальный FPGA pinout
- [ ] JTAG header/test pads на PCB
- [ ] decoupling и остальные пассивные компоненты

### FPGA logic

- [x] минимальный Game Boy bus interface, достаточный для internal ROM milestone
- [x] minimal ROM response
- [ ] external Flash read interface
- [ ] Flash erase/program/status controller
- [ ] SPI slave для RP2040
- [ ] безопасное разделение `GAME / PROGRAMMER`
- [ ] MBC implementation
- [ ] FRAM interface

### RP2040 / PC

- [ ] минимальный SPI master protocol
- [ ] USB-команды read/erase/program/status
- [ ] загрузка `.gb`
- [ ] обязательный полный verify с адресом первой ошибки

### PCB

- [ ] cartridge edge pinout
- [ ] физические размеры PCB
- [ ] размещение компонентов в корпусе Game Boy cartridge

---

## 11. Файлы проекта

```text
PROJECT_STATE.md   # текущее состояние и принятые решения
NEXT_STEPS.md      # план ближайшего этапа для нового обсуждения
PINOUT.md          # все соединения и номера выводов
BOM.md             # компоненты и пассивные элементы

FPGA/
  cartridge.v
  gameboy_bus.v
  flash_controller.v
  spi_slave.v
  mbc.v
  memory.v
  constraints.lpf

RP2040/
  firmware/

DOCS/
  bringup.md
  test-plan.md
```

`PROJECT_STATE.md` — основной источник актуального состояния проекта.

Точные номера выводов и электрические соединения не дублируются здесь, если они уже находятся в `PINOUT.md`. Новые назначения выводов считаются принятыми только после отдельной проверки и фиксации.
