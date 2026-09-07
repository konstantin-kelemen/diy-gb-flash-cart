# RP2040 SPI bring-up

Minimal USB CDC + SPI0 firmware for the first RP2040-Zero <-> MachXO2 link test.

## Wiring

| Signal | RP2040-Zero | Direction |
|---|---:|---|
| SPI_MISO | GP0 | FPGA -> RP2040 |
| SPI_CS_N | GP1 | RP2040 -> FPGA |
| SPI_SCK | GP2 | RP2040 -> FPGA |
| SPI_MOSI | GP3 | RP2040 -> FPGA |
| GND | GND | common |

SPI mode 0, 8-bit, MSB first, 10 kHz. CS# is software controlled.

Do not connect the 3.3 V outputs of two independently powered boards together. Both
ends must be powered and share GND before starting the exchange.

## Build

Install the Raspberry Pi Pico SDK and export `PICO_SDK_PATH`, then:

```bash
cd firmware/rp2040
cmake -S . -B build -DPICO_BOARD=waveshare_rp2040_zero
cmake --build build -j
```

The UF2 file will be:

```text
build/gb_cart_rp2040.uf2
```

## Use

Flash the UF2, connect the RP2040-Zero over USB, and open its CDC serial port.

Commands:

```text
version
test 1000
help
```

Expected single transaction:

```text
TX: 01 00 00 00 00 00 00 00 00
RX: 00 47 42 46 43 01 00 00 00
OK: FPGA protocol 1.0, capabilities=0x0000
```

`test 1000` is the initial acceptance test: all 1000 frames should pass.
