"""Compile the actual bridge code with deterministic SDK/SPI stubs on macOS."""
import pathlib
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
TEST = r'''
static unsigned commits=0;
static uint8_t query_op=0, seq=0, cmd=0;
static size_t count=0;
static bool corrupt_block=false, force_busy=false;
static uint8_t usb[1200]; static size_t usb_size;
static int spi_write_blocking(int ignored,const uint8_t *p,size_t n) {
    (void)ignored;
    if(n==1) query_op=p[0];
    else { assert(valid(p,n)); ++commits; seq=p[1]; cmd=p[0]; count=(size_t)p[5]<<8|p[6]; }
    return (int)n;
}
static int spi_read_blocking(int ignored,uint8_t filler,uint8_t *p,size_t n) {
    (void)ignored; (void)filler; memset(p,0,n);
    if(query_op==2) {
        assert(n==10); p[0]=0x50; p[1]=seq; p[2]=force_busy?1:0; p[3]=cmd;
        p[6]=(uint8_t)count; p[7]=(uint8_t)(count>>8);
    } else if(query_op==3) {
        assert(n==count+2); for(size_t i=0;i<count;++i) p[i]=(uint8_t)i;
    } else { assert(query_op==1 && n==8); memcpy(p,"GBFC\3\0\0\4",8); return (int)n; }
    uint16_t c=crc16(p,n-2); p[n-2]=(uint8_t)(c>>8); p[n-1]=(uint8_t)c;
    if(query_op==3 && corrupt_block) p[n-1]^=1;
    return (int)n;
}
static int stdio_put_string(const char *p,int n,bool newline,bool translate) {
    assert(!newline && !translate); memcpy(usb,p,n); usb_size=(size_t)n; return n;
}
static size_t prepare(uint8_t op,size_t length) {
    size_t n=10+(op==0x31?length:0); memset(request,0,sizeof(request));
    request[0]=op; request[1]=seq+1; request[5]=(uint8_t)(length>>8); request[6]=(uint8_t)length;
    for(size_t i=8;i<n-2;++i) request[i]=(uint8_t)i;
    uint16_t c=crc16(request,n-2); request[n-2]=(uint8_t)(c>>8); request[n-1]=(uint8_t)c;
    return n;
}
int main(void) {
    size_t n=prepare(0x30,1024); assert(execute(n)==1036);
    for(size_t i=0;i<1024;++i) assert(response[i+10]==(uint8_t)i);
    assert(valid(response,10) && valid(response+10,1026));
    send_reply(1036); assert(usb_size==1044 && !memcmp(usb,"GB3R",4));
    assert(valid(usb+4,1040)); // includes USB length and all unescaped binary bytes
    n=prepare(0x31,1024); assert(execute(n)==10 && commits==2);
    n=prepare(0x31,3); request[n-1]^=1; assert(execute(n)==1 && response[0]==0xe2 && commits==2);
    n=prepare(0x31,3); assert(execute(n-1)==1 && commits==2);
    n=prepare(0x30,0); assert(execute(n)==1 && commits==2);
    n=prepare(0x30,1); corrupt_block=true;
    assert(execute(n)==1 && response[0]==0xe1 && commits==3);
    corrupt_block=false; force_busy=true; n=prepare(0x31,1);
    assert(execute(n)==1 && response[0]==0xe3 && commits==3);
    uint8_t b; assert(!receive(&b,1,0));
    puts("PASS native RP2040 bridge: binary blocks/CRC/length/busy/no retry");
    return 0;
}
'''


class BridgeTests(unittest.TestCase):
    def test_actual_bridge_with_spi_model(self):
        source = (pathlib.Path(__file__).parents[1] / 'src/main.c').read_text()
        source = source.replace('#include "pico/stdlib.h"', STUBS)
        source = source.replace('#include "hardware/spi.h"', '')
        source = source.replace('int main(void)', 'int firmware_main(void)')
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp)
            (path / 'bridge.c').write_text(source + TEST)
            subprocess.run(['cc', '-std=c11', '-Wall', '-Wextra', '-Werror',
                            str(path / 'bridge.c'), '-o', str(path / 'bridge')], check=True)
            subprocess.run([str(path / 'bridge')], check=True)


if __name__ == '__main__':
    unittest.main()
