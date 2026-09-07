// USB ASCII transport for CRC-protected FPGA protocol v2.
// v\n -> version hex; s\n -> status hex; x<16 hex digits>\n -> completed status hex.
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "pico/stdlib.h"
#include "hardware/spi.h"

static uint16_t crc16(const uint8_t *p, size_t n) {
    uint16_t c = 0xffff;
    while (n--) {
        c ^= (uint16_t)*p++ << 8;
        for (int i = 0; i < 8; ++i)
            c = (uint16_t)((c << 1) ^ ((c & 0x8000) ? 0x1021 : 0));
    }
    return c;
}
static void transfer(const uint8_t *tx, uint8_t *rx, size_t n) {
    gpio_put(1, 0); busy_wait_us_32(25);
    spi_write_read_blocking(spi0, tx, rx, n);
    busy_wait_us_32(25); gpio_put(1, 1); busy_wait_us_32(25);
}
static void query(uint8_t op, uint8_t out[8]) {
    uint8_t tx[9] = {0}, rx[9]; tx[0] = op;
    transfer(tx, rx, 9); memcpy(out, rx + 1, 8);
}
static bool valid(const uint8_t p[8]) {
    return p[0] == 0x50 && crc16(p, 6) == ((uint16_t)p[6] << 8 | p[7]);
}
static void reply(const uint8_t p[8]) {
    for (int i = 0; i < 8; ++i) printf("%02X", p[i]);
    printf("\n"); fflush(stdout);
}
static int hex(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}
static void execute(const char *line) {
    uint8_t p[8], rx[8];
    if (!strcmp(line, "v")) { query(1, p); reply(p); return; }
    if (!strcmp(line, "s")) { query(2, p); reply(p); return; }
    if (strlen(line) != 17 || line[0] != 'x') { puts("ERR syntax"); return; }
    for (int i = 0; i < 8; ++i) {
        int a = hex(line[1 + i * 2]), b = hex(line[2 + i * 2]);
        if (a < 0 || b < 0) { puts("ERR hex"); return; }
        p[i] = (uint8_t)(a * 16 + b);
    }
    if (crc16(p, 6) != ((uint16_t)p[6] << 8 | p[7])) { puts("ERR crc"); return; }
    if (!((p[0] >= 0x10 && p[0] <= 0x14) || p[0] == 0x20 || p[0] == 0x21)) {
        puts("ERR opcode"); return;
    }
    query(2, rx);
    if (!valid(rx) || rx[2] == 1 || rx[1] == p[1]) { puts("ERR state"); return; }
    transfer(p, rx, 8);
    absolute_time_t deadline = make_timeout_time_ms(5000);
    do {
        query(2, rx);
        if (!valid(rx)) { puts("ERR spi_crc"); return; }
        if (rx[1] == p[1] && rx[5] == p[0] && rx[2] != 1) { reply(rx); return; }
        sleep_ms(1);
    } while (!time_reached(deadline));
    // Never retry a destructive request after a transport timeout.
    puts("ERR timeout");
}
int main(void) {
    stdio_init_all();
    gpio_init(1); gpio_put(1, 1); gpio_set_dir(1, GPIO_OUT);
    spi_init(spi0, 10000);
    spi_set_format(spi0, 8, SPI_CPOL_0, SPI_CPHA_0, SPI_MSB_FIRST);
    gpio_set_function(0, GPIO_FUNC_SPI);
    gpio_set_function(2, GPIO_FUNC_SPI);
    gpio_set_function(3, GPIO_FUNC_SPI);
    sleep_ms(350);
    char line[32]; size_t used = 0; bool discard = false;
    absolute_time_t deadline = make_timeout_time_ms(2000);
    while (true) {
        int c = getchar_timeout_us(10000);
        if (c == PICO_ERROR_TIMEOUT) {
            if (used && time_reached(deadline)) { used = 0; discard = true; }
            continue;
        }
        if (c == '\r') continue;
        if (c == '\n') {
            if (discard) puts("ERR incomplete");
            else if (used) { line[used] = 0; execute(line); }
            used = 0; discard = false; fflush(stdout);
        } else if (!discard) {
            if (!used) deadline = make_timeout_time_ms(2000);
            if (used < sizeof(line) - 1) line[used++] = (char)c;
            else { used = 0; discard = true; }
        }
    }
}
