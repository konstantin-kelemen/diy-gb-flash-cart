"""Compile the actual bridge code with deterministic SDK/SPI stubs (CC selects compiler)."""
import os
import pathlib
import shlex
import subprocess
import tempfile
import unittest

STUBS = r'''
#include <stdbool.h>
#include <stddef.h>
#include <assert.h>
typedef unsigned long absolute_time_t;
#define PICO_ERROR_TIMEOUT (-1)
#define spi0 0
#define SPI_CPOL_0 0
#define SPI_CPHA_0 0
#define SPI_MSB_FIRST 0
#define GPIO_OUT 1
#define GPIO_FUNC_SPI 1
static void gpio_put(int a,int b) {(void)a;(void)b;}
static void busy_wait_us_32(unsigned a) {(void)a;}
static void sleep_ms(unsigned a) {(void)a;}
static void gpio_init(int a) {(void)a;}
static void gpio_set_dir(int a,int b) {(void)a;(void)b;}
static void gpio_set_function(int a,int b) {(void)a;(void)b;}
static void spi_init(int a,int b) {(void)a;(void)b;}
static void spi_set_format(int a,int b,int c,int d,int e) {(void)a;(void)b;(void)c;(void)d;(void)e;}
static void stdio_init_all(void) {}
static void stdio_flush(void) {}
static absolute_time_t make_timeout_time_ms(unsigned a) {return a;}
static bool time_reached(absolute_time_t a) {(void)a;return true;}
static int getchar_timeout_us(unsigned a) {(void)a;return PICO_ERROR_TIMEOUT;}
static int spi_write_blocking(int, const uint8_t *, size_t);
static int spi_read_blocking(int, uint8_t, uint8_t *, size_t);
static int stdio_put_string(const char *,int,bool,bool);
'''
TEST = pathlib.Path(__file__).with_name('bridge_model.c').read_text()


class BridgeTests(unittest.TestCase):
    def test_actual_bridge_with_spi_model(self):
        source = (pathlib.Path(__file__).parents[1] / 'src/main.c').read_text()
        source = source.replace('#include "pico/stdlib.h"', STUBS)
        source = source.replace('#include "hardware/spi.h"', '')
        source = source.replace('int main(void)', 'int firmware_main(void)')
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp)
            (path / 'bridge.c').write_text(source + TEST)
            executable = path / ('bridge.exe' if os.name == 'nt' else 'bridge')
            compiler = shlex.split(os.environ.get('CC', 'cc'))
            subprocess.run(compiler + ['-std=c11', '-Wall', '-Wextra', '-Werror',
                            str(path / 'bridge.c'), '-o', str(executable)], check=True)
            subprocess.run([str(executable)], check=True)


if __name__ == '__main__':
    unittest.main()
