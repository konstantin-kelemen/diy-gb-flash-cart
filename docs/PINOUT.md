# Game Boy FPGA Cartridge — PINOUT

## U1 — Address bus A0–A7

| GB contact | GB signal | U1 B pin | U1 A pin | MachXO2 pin | FPGA signal |
|---:|---|---|---|---:|---|
| — | — | — | VCCA / 1 | 26 | `3V3` |
| 6 | A0 | B1 / 21 | A1 / 3 | 27 | `gb_a0` |
| 7 | A1 | B2 / 20 | A2 / 4 | 28 | `gb_a1` |
| 8 | A2 | B3 / 19 | A3 / 5 | 29 | `gb_a2` |
| 9 | A3 | B4 / 18 | A4 / 6 | 30 | `gb_a3` |
| 10 | A4 | B5 / 17 | A5 / 7 | 31 | `gb_a4` |
| 11 | A5 | B6 / 16 | A6 / 8 | 32 | `gb_a5` |
| 12 | A6 | B7 / 15 | A7 / 9 | 34 | `gb_a6` |
| 13 | A7 | B8 / 14 | A8 / 10 | 35 | `gb_a7` |
| — | — | — | GND / 11 | 33 | `GND` |

---

## U2 — Address bus A8–A15

| GB contact | GB signal | U2 B pin | U2 A pin | MachXO2 pin | FPGA signal |
|---:|---|---|---|---:|---|
| — | — | — | VCCA / 1 | 46 | `3V3` |
| 14 | A8 | 21 | 3 | 36 | `gb_a8` |
| 15 | A9 | 20 | 4 | 37 | `gb_a9` |
| 16 | A10 | 19 | 5 | 38 | `gb_a10` |
| 17 | A11 | 18 | 6 | 39 | `gb_a11` |
| 18 | A12 | 17 | 7 | 40 | `gb_a12` |
| 19 | A13 | 16 | 8 | 41 | `gb_a13` |
| 20 | A14 | 15 | 9 | 42 | `gb_a14` |
| 21 | A15 | 14 | 10 | 43 | `gb_a15` |
| — | — | — | GND / 11 | 44 | `GND` |

---

## U3 — Data bus D0–D7

| GB contact | GB signal | U3 B pin | U3 A pin | MachXO2 pin | FPGA signal |
|---:|---|---|---|---:|---|
| — | — | — | VCCA / 1 | 55 | `3V3` |
| — | — | — | DIR / 2 | 57 | `data_dir` |
| 22 | D0 | 21 | 3 | 45 | `gb_d0` |
| 23 | D1 | 20 | 4 | 47 | `gb_d1` |
| 24 | D2 | 19 | 5 | 48 | `gb_d2` |
| 25 | D3 | 18 | 6 | 49 | `gb_d3` |
| 26 | D4 | 17 | 7 | 51 | `gb_d4` |
| 27 | D5 | 16 | 8 | 52 | `gb_d5` |
| 28 | D6 | 15 | 9 | 53 | `gb_d6` |
| 29 | D7 | 14 | 10 | 54 | `gb_d7` |
| — | — | — | GND / 11 | 56 | `GND` |
| — | — | — | OE / 22 | 58 | `data_oe_n` |

---

## U4 — Control signals

| GB contact | GB signal | U4 B pin | U4 A pin | MachXO2 pin | FPGA signal |
|---:|---|---|---|---:|---|
| — | — | — | VCCA / 1 | 73 | `3V3` |
| 3 | /WR | B1 / 21 | A1 / 3 | 59 | `gb_wr_n` |
| 4 | /RD | B2 / 20 | A2 / 4 | 60 | `gb_rd_n` |
| 5 | /CS | B3 / 19 | A3 / 5 | 61 | `gb_cs_n` |
| 30 | /RES | B4 / 18 | A4 / 6 | 62 | `gb_res_n` |
| — | — | — | GND / 11 | 72 | `GND` |