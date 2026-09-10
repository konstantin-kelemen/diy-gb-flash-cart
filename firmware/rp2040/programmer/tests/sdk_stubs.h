#include <stdbool.h>
#include <stddef.h>
#include <assert.h>
#include <setjmp.h>
typedef uint64_t absolute_time_t;
#define PICO_ERROR_TIMEOUT (-1)
#define spi0 0
#define SPI_CPOL_0 0
#define SPI_CPHA_0 0
#define SPI_MSB_FIRST 0
#define GPIO_OUT 1
#define GPIO_FUNC_SPI 1
static uint64_t model_time;
static void gpio_put(int a,int b) {(void)a;(void)b;}
static void busy_wait_us_32(unsigned a) {model_time+=a;}
static void sleep_ms(unsigned a) {model_time+=1000*a;}
static void gpio_init(int a) {(void)a;}
static void gpio_set_dir(int a,int b) {(void)a;(void)b;}
static void gpio_set_function(int a,int b) {(void)a;(void)b;}
static void spi_init(int a,int b) {(void)a;assert(b==4000000);}
static void spi_set_format(int a,int b,int c,int d,int e) {(void)a;(void)b;(void)c;(void)d;(void)e;}
static void stdio_init_all(void) {}
static void stdio_flush(void) {}
static absolute_time_t make_timeout_time_ms(unsigned a) {return model_time+1000*(uint64_t)a;}
static int64_t absolute_time_diff_us(absolute_time_t a,absolute_time_t b) {return (int64_t)b-(int64_t)a;}
static bool time_reached(absolute_time_t a) {return model_time>=a;}
static int getchar_timeout_us(unsigned);
static int spi_write_blocking(int, const uint8_t *, size_t);
static int spi_read_blocking(int, uint8_t, uint8_t *, size_t);
static int stdio_put_string(const char *,int,bool,bool);
