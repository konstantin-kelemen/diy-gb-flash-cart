# Game Boy FPGA Flash Cartridge — BOM

**Last updated:** 2026-09-01

---

## 1. Основные компоненты

| Ref | Component | Part | Notes |
|---|---|---|---|
| FPGA | FPGA | `LCMXO2-1200HC-4TG100C` | Lattice MachXO2, TQFP-100 |
| ROM | Flash ROM | `MX29LV320E T/B` | 32 Mbit / 4 MB, x8 mode |
| FRAM | Save memory | `FM28V100-TG` | 1 Mbit / 128 KB |
| MCU | USB MCU/module | `RP2040-Zero` | USB / programming / save access |
| U1 | Level shifter | `SN74LVC8T245PWR` | Address A0-A7 |
| U2 | Level shifter | `SN74LVC8T245PWR` | Address A8-A15 |
| U3 | Level shifter | `SN74LVC8T245PWR` | Data D0-D7 |
| U4 | Level shifter | `SN74LVC8T245PWR` | Control signals |

---

# 2. FPGA

## Decoupling

| Ref | Value | Connection | Purpose |
|---|---|---|---|
| C_FPGA1 | 100 nF X7R | FPGA pin 50 VCC → GND | Core decoupling |
| C_FPGA2 | 100 nF X7R | FPGA pin 100 VCC → GND | Core decoupling |
| C_IO30 | 100 nF X7R | FPGA pin 5 VCCIO3 → GND | Bank 3 |
| C_IO31 | 100 nF X7R | FPGA pin 11 VCCIO3 → GND | Bank 3 |
| C_IO32 | 100 nF X7R | FPGA pin 23 VCCIO3 → GND | Bank 3 |
| C_IO20 | 100 nF X7R | FPGA pin 26 VCCIO2 → GND | Bank 2 |
| C_IO21 | 100 nF X7R | FPGA pin 46 VCCIO2 → GND | Bank 2 |
| C_IO10 | 100 nF X7R | FPGA pin 55 VCCIO1 → GND | Bank 1 |
| C_IO11 | 100 nF X7R | FPGA pin 73 VCCIO1 → GND | Bank 1 |
| C_IO00 | 100 nF X7R | FPGA pin 80 VCCIO0 → GND | Bank 0 |
| C_IO01 | 100 nF X7R | FPGA pin 93 VCCIO0 → GND | Bank 0 |

## Bulk capacitors

| Ref | Value | Connection | Purpose |
|---|---|---|---|
| C_CORE_B1 | 10 µF X5R/X7R | 3.3V VCC → GND возле FPGA | Bulk VCC |
| C_CORE_B2 | 10 µF X5R/X7R | 3.3V VCC → GND возле FPGA | Bulk VCC |
| C_B0 | 10 µF | VCCIO0 → GND | Bulk Bank 0 |
| C_B1 | 10 µF | VCCIO1 → GND | Bulk Bank 1 |
| C_B2 | 10 µF | VCCIO2 → GND | Bulk Bank 2 |
| C_B3 | 10 µF | VCCIO3 → GND | Bulk Bank 3 |

## Configuration / JTAG resistors

| Ref | Value | Connection | Purpose |
|---|---|---|---|
| R_TCK | 4.7 kΩ | FPGA pin 91 TCK → GND | Lattice recommended pull-down |
| R_PROGRAM | 4.7 kΩ | FPGA pin 81 PROGRAMN → 3.3V | Stable startup |
| R_INIT | 4.7 kΩ | FPGA pin 77 INITN → 3.3V | Config pull-up |
| R_DONE | 4.7 kΩ | FPGA pin 76 DONE → 3.3V | Config pull-up |
| R_JTAGEN | 10 kΩ | FPGA pin 82 JTAGENB → 3.3V | Keep JTAG mode enabled |

---

# 3. FRAM

**Part:** `FM28V100-TG`

## Capacitors

| Ref | Value | Connection | Purpose |
|---|---|---|---|
| C_FRAM | 100 nF | Pin 8 VDD → pin 24 VSS | Decoupling |
| C_FRAM_BULK | 1 µF | Pin 8 VDD → pin 24 VSS | Local bulk |

## Pull-ups

| Ref | Value | Connection | Purpose |
|---|---|---|---|
| R_FRAM_CE | 10 kΩ | Pin 30 CE1 → 3.3V | Deselect during startup |
| R_FRAM_WE | 10 kΩ | Pin 5 WE → 3.3V | Protect against accidental write |
| R_FRAM_OE | 10 kΩ DNP | Pin 32 OE → 3.3V | Optional footprint |

## Fixed connections

| Signal | Connection | Purpose |
|---|---|---|
| CE2 | FRAM pin 6 → 3.3V | CE2 permanently active |

---

# 4. ROM Flash

**Part:** `MX29LV320E T/B`

## Capacitors

| Ref | Value | Connection | Purpose |
|---|---|---|---|
| C_ROM | 100 nF | Pin 37 VCC → GND pins 27/46 | Decoupling |
| C_ROM_BULK | 1 µF | Pin 37 VCC → GND | Local bulk |

## Pull-ups

| Ref | Value | Connection | Purpose |
|---|---|---|---|
| R_ROM_CE | 10 kΩ | Pin 26 CE# → 3.3V | Flash deselected during startup |
| R_ROM_WE | 10 kΩ | Pin 11 WE# → 3.3V | Write inactive |
| R_ROM_RST | 10 kΩ | Pin 12 RESET# → 3.3V | Keep Flash in normal/read mode |
| R_ROM_RYBY | 10 kΩ | Pin 15 RY/BY# → 3.3V | Pull-up for open-drain output |
| R_ROM_OE | 10 kΩ DNP | Pin 28 OE# → 3.3V | Optional footprint |

## Fixed connections

| Signal | Connection | Purpose |
|---|---|---|
| BYTE# | Pin 47 → GND | Select x8 mode |
| WP#/ACC | Pin 14 → 3.3V | Normal mode, ACC disabled |

---

# 5. Level shifters

**Part:** `SN74LVC8T245PWR`

---

## U1 — Address A0-A7

| Ref | Value | Connection | Purpose |
|---|---|---|---|
| C_U1_A | 100 nF | U1 pin 1 VCCA → GND | 3.3V side decoupling |
| C_U1_B | 100 nF | U1 pins 23+24 VCCB → GND | 5V side decoupling |

Fixed:

```text
U1 pin 2 DIR → GND
```

Direction: permanent `B → A`.

---

## U2 — Address A8-A15

| Ref | Value | Connection | Purpose |
|---|---|---|---|
| C_U2_A | 100 nF | U2 pin 1 VCCA → GND | 3.3V side decoupling |
| C_U2_B | 100 nF | U2 pins 23+24 VCCB → GND | 5V side decoupling |

Fixed:

```text
U2 pin 2 DIR → GND
```

Direction: permanent `B → A`.

---

## U3 — Data D0-D7

| Ref | Value | Connection | Purpose |
|---|---|---|---|
| C_U3_A | 100 nF | U3 pin 1 VCCA → GND | Data shifter, 3.3V side |
| C_U3_B | 100 nF | U3 pins 23+24 VCCB → GND | Data shifter, 5V side |
| R_U3_OE | 10 kΩ | U3 pin 22 OE → 3.3V | Data bus Hi-Z during startup |
| R_U3_DIR | 10 kΩ | U3 pin 2 DIR → GND | Default Game Boy → FPGA |

`DIR` is later actively controlled by FPGA through `data_dir`.

---

## U4 — Control signals

| Ref | Value | Connection | Purpose |
|---|---|---|---|
| C_U4_A | 100 nF | U4 pin 1 VCCA → GND | 3.3V side decoupling |
| C_U4_B | 100 nF | U4 pins 23+24 VCCB → GND | 5V side decoupling |

Fixed:

```text
U4 pin 2 DIR → GND
```

Direction: permanent `B → A`.

---

# 6. Общие power capacitors

| Ref | Value | Connection | Purpose |
|---|---|---|---|
| C_5V_BULK | 10 µF | 5V_GB → GND возле level shifters | Main 5V bulk |
| C_3V3_BULK | 10 µF | 3V3 → GND возле memory/shifters | Main 3.3V bulk |

---

# 7. RP2040 / FPGA interface

| Ref | Value | Connection | Purpose |
|---|---|---|---|
| R_RP_CS | 10 kΩ | RP2040 → FPGA CS# → 3.3V | SPI inactive during reset |

Финальный интерфейс RP2040 ↔ FPGA ещё должен быть зафиксирован.

---

# 8. Optional LEDs

| Ref | Value | Connection | Purpose |
|---|---|---|---|
| R_LED_OK | 1 kΩ | FPGA GPIO → LED → GND | Optional status LED |
| R_LED_ERR | 1 kΩ | FPGA GPIO → LED → GND | Optional error LED |

---

# 9. DNP components

`DNP` = footprint установить на PCB, но компонент по умолчанию не запаивать.

| Ref | Value | Purpose |
|---|---|---|
| R_FRAM_OE | 10 kΩ | Optional FRAM OE pull-up |
| R_ROM_OE | 10 kΩ | Optional Flash OE pull-up |

---

# 10. Сводка пассивных компонентов

## 100 nF

- FPGA: 11 × 100 nF X7R
- FRAM: 1 × 100 nF
- ROM: 1 × 100 nF
- Level shifters: 8 × 100 nF

**Всего: 21 × 100 nF**

## 1 µF

- FRAM: 1
- ROM: 1

**Всего: 2 × 1 µF**

## 10 µF

- FPGA core bulk: 2
- FPGA VCCIO banks: 4
- 5V rail: 1
- 3.3V rail: 1

**Всего: 8 × 10 µF**

## 4.7 kΩ

- R_TCK
- R_PROGRAM
- R_INIT
- R_DONE

**Всего: 4 × 4.7 kΩ**

## 10 kΩ populated

- R_JTAGEN
- R_FRAM_CE
- R_FRAM_WE
- R_ROM_CE
- R_ROM_WE
- R_ROM_RST
- R_ROM_RYBY
- R_U3_OE
- R_U3_DIR
- R_RP_CS

**Всего: 10 × 10 kΩ**

## 10 kΩ DNP

- R_FRAM_OE
- R_ROM_OE

**Всего: 2 footprints**

## 1 kΩ optional

- R_LED_OK
- R_LED_ERR

**Всего: 2 × 1 kΩ optional**

---

# 11. Notes

- Decoupling capacitors размещать максимально близко к соответствующим power pins.
- DNP-компоненты оставить как footprints на PCB.
- `BYTE#` Flash подключён к GND для x8 mode.
- FRAM `CE2` постоянно подключён к 3.3V.
- `DIR` U1/U2/U4 постоянно подключён к GND.
- U3 имеет управляемые FPGA сигналы `DIR` и `OE`.
- Точные signal-to-pin соединения FPGA и Game Boy находятся в `PINOUT.md`.
- Перед финальной PCB электрические подключения необходимо ещё раз сверить с datasheets выбранных корпусов микросхем.