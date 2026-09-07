#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "pico/stdlib.h"
#include "hardware/spi.h"

#define FPGA_SPI                spi0
#define FPGA_SPI_BAUD_HZ        10000u

#define PIN_SPI_MISO            0u
#define PIN_SPI_CS_N            1u
#define PIN_SPI_SCK             2u
#define PIN_SPI_MOSI            3u

#define SPI_FRAME_GUARD_US      25u
#define GET_VERSION_CMD         0x01u
#define GET_VERSION_FRAME_LEN   9u

static const uint8_t get_version_tx[GET_VERSION_FRAME_LEN] = {
    GET_VERSION_CMD, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00
};

static void print_bytes(const char *label, const uint8_t *data, size_t len) {
    printf("%s", label);
    for (size_t i = 0; i < len; ++i) {
        printf("%s%02X", i == 0 ? "" : " ", data[i]);
    }
    printf("\r\n");
}

static void fpga_spi_init(void) {
    // Keep the FPGA deselected before enabling the SPI peripheral.
    gpio_init(PIN_SPI_CS_N);
    gpio_set_dir(PIN_SPI_CS_N, GPIO_OUT);
    gpio_put(PIN_SPI_CS_N, 1);

    uint actual_baud = spi_init(FPGA_SPI, FPGA_SPI_BAUD_HZ);
    spi_set_format(
        FPGA_SPI,
        8,
        SPI_CPOL_0,
        SPI_CPHA_0,
        SPI_MSB_FIRST
    );

    gpio_set_function(PIN_SPI_MISO, GPIO_FUNC_SPI);
    gpio_set_function(PIN_SPI_SCK, GPIO_FUNC_SPI);
    gpio_set_function(PIN_SPI_MOSI, GPIO_FUNC_SPI);

    // Give both ends some time to settle after configuration.
    sleep_ms(10);

    printf("SPI0 ready: requested=%u Hz actual=%u Hz, Mode 0\r\n",
           FPGA_SPI_BAUD_HZ, actual_baud);
    printf("pins: MISO=GP%u CS#=GP%u SCK=GP%u MOSI=GP%u\r\n",
           PIN_SPI_MISO, PIN_SPI_CS_N, PIN_SPI_SCK, PIN_SPI_MOSI);
}

static void fpga_spi_transfer(const uint8_t *tx, uint8_t *rx, size_t len) {
    // Protocol requires >=20 us from CS# assertion to first SCK edge.
    gpio_put(PIN_SPI_CS_N, 0);
    busy_wait_us_32(SPI_FRAME_GUARD_US);

    spi_write_read_blocking(FPGA_SPI, tx, rx, len);

    // Protocol also requires >=20 us from final SCK edge to CS# release.
    busy_wait_us_32(SPI_FRAME_GUARD_US);
    gpio_put(PIN_SPI_CS_N, 1);

    // And >=20 us between frames.
    busy_wait_us_32(SPI_FRAME_GUARD_US);
}

static bool fpga_get_version(uint8_t rx[GET_VERSION_FRAME_LEN]) {
    memset(rx, 0, GET_VERSION_FRAME_LEN);
    fpga_spi_transfer(get_version_tx, rx, GET_VERSION_FRAME_LEN);

    // rx[0] is intentionally ignored by protocol v1.0.
    return rx[1] == 'G' &&
           rx[2] == 'B' &&
           rx[3] == 'F' &&
           rx[4] == 'C' &&
           rx[5] == 1 &&
           rx[6] == 0 &&
           rx[7] == 0 &&
           rx[8] == 0;
}

static void command_version(void) {
    uint8_t rx[GET_VERSION_FRAME_LEN];
    bool ok = fpga_get_version(rx);

    print_bytes("TX: ", get_version_tx, GET_VERSION_FRAME_LEN);
    print_bytes("RX: ", rx, GET_VERSION_FRAME_LEN);

    if (ok) {
        uint8_t major = rx[5];
        uint8_t minor = rx[6];
        uint16_t capabilities = (uint16_t)rx[7] | ((uint16_t)rx[8] << 8);

        printf("OK: FPGA protocol %u.%u, capabilities=0x%04X\r\n",
               major, minor, capabilities);
    } else {
        printf("ERROR: unexpected FPGA response\r\n");
    }
}

static void command_test(unsigned long count) {
    if (count == 0) {
        printf("ERROR: count must be > 0\r\n");
        return;
    }

    unsigned long passed = 0;
    unsigned long failed = 0;
    uint8_t rx[GET_VERSION_FRAME_LEN];
    uint8_t first_bad[GET_VERSION_FRAME_LEN] = {0};
    unsigned long first_bad_index = 0;

    absolute_time_t start = get_absolute_time();

    for (unsigned long i = 0; i < count; ++i) {
        if (fpga_get_version(rx)) {
            ++passed;
        } else {
            ++failed;
            if (failed == 1) {
                memcpy(first_bad, rx, sizeof(first_bad));
                first_bad_index = i + 1;
            }
        }
    }

    int64_t elapsed_us = absolute_time_diff_us(start, get_absolute_time());

    printf("TEST: total=%lu pass=%lu fail=%lu elapsed=%lld ms\r\n",
           count, passed, failed, (long long)(elapsed_us / 1000));

    if (failed == 0) {
        printf("PASS\r\n");
    } else {
        printf("FAIL: first bad frame #%lu\r\n", first_bad_index);
        print_bytes("RX: ", first_bad, GET_VERSION_FRAME_LEN);
    }
}

static void print_help(void) {
    printf("Commands:\r\n");
    printf("  version        one GET_VERSION transaction\r\n");
    printf("  v              alias for version\r\n");
    printf("  test [N]       repeat GET_VERSION N times (default 1000)\r\n");
    printf("  help           show this help\r\n");
}

int main(void) {
    stdio_init_all();

    // This firmware is controlled through USB CDC, so wait until a host opens it.
    sleep_ms(1500);

    printf("\r\nGame Boy flash cart - RP2040 SPI bring-up\r\n");
    fpga_spi_init();
    print_help();

    char line[64];

    while (true) {
        printf("> ");
        fflush(stdout);

        if (fgets(line, sizeof(line), stdin) == NULL) {
            clearerr(stdin);
            sleep_ms(10);
            continue;
        }

        line[strcspn(line, "\r\n")] = '\0';

        if (strcmp(line, "version") == 0 || strcmp(line, "v") == 0) {
            command_version();
            continue;
        }

        if (strncmp(line, "test", 4) == 0 &&
            (line[4] == '\0' || line[4] == ' ' || line[4] == '\t')) {
            char *arg = line + 4;
            while (*arg == ' ' || *arg == '\t') {
                ++arg;
            }

            unsigned long count = 1000;
            if (*arg != '\0') {
                char *end = NULL;
                unsigned long parsed = strtoul(arg, &end, 10);
                if (end == arg || *end != '\0') {
                    printf("ERROR: usage: test [N]\r\n");
                    continue;
                }
                count = parsed;
            }

            command_test(count);
            continue;
        }

        if (strcmp(line, "help") == 0 || strcmp(line, "?") == 0) {
            print_help();
            continue;
        }

        if (line[0] != '\0') {
            printf("ERROR: unknown command '%s'\r\n", line);
            print_help();
        }
    }
}
