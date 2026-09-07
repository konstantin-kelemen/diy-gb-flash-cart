// Binary USB bridge for FPGA programmer protocol 3. See docs/PROGRAMMER_PROTOCOL.md.
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "pico/stdlib.h"
#include "hardware/spi.h"
#define BLOCK 1024
#define MAX_REQUEST (BLOCK + 10)
#define MAX_REPLY (BLOCK + 12)
#ifndef GB_SPI_HZ
#define GB_SPI_HZ 4000000
#endif
static uint8_t request[MAX_REQUEST], response[MAX_REPLY];
static uint16_t crc16(const uint8_t *p, size_t n) {
    uint16_t c=0xffff;
    while(n--) {
        c^=(uint16_t)*p++<<8;
        for(int i=0;i<8;++i) c=(uint16_t)((c<<1)^((c&0x8000)?0x1021:0));
    }
    return c;
}
static bool valid(const uint8_t *p, size_t n) {
    return n>=2 && crc16(p,n-2)==((uint16_t)p[n-2]<<8|p[n-1]);
}
static void select_spi(void) { gpio_put(1,0); busy_wait_us_32(2); }
static void release_spi(void) { busy_wait_us_32(2); gpio_put(1,1); busy_wait_us_32(2); }
static void query(uint8_t op, uint8_t *out, size_t n) {
    select_spi(); spi_write_blocking(spi0,&op,1);
    spi_read_blocking(spi0,0,out,n); release_spi();
}
static bool get_status(uint8_t *out) {
    query(2,out,10); return out[0]==0x50 && valid(out,10);
}
static size_t execute(size_t n) {
    if(n==1 && request[0]==1) { query(1,response,8); return 8; }
    if(n==1 && request[0]==2) {
        if(get_status(response)) return 10;
        response[0]=0xe1; return 1;
    }
    if(n<10 || !valid(request,n)) { response[0]=0xe2; return 1; }
    const uint8_t op=request[0], seq=request[1];
    const size_t length=(size_t)request[5]<<8|request[6];
    if((op==0x30 || op==0x31) ? (length==0 || length>BLOCK) : length!=0) {
        response[0]=0xe2; return 1;
    }
    if(n!=10+(op==0x31?length:0) ||
       !(op==0x30 || op==0x31 || op==0x12 || op==0x13 || op==0x14 || op==0x20 || op==0x21)) {
        response[0]=0xe2; return 1;
    }
    if(!get_status(response) || response[2]==1 || response[1]==seq) {
        response[0]=0xe3; return 1;
    }
    select_spi(); spi_write_blocking(spi0,request,n); release_spi();
    // A worst-case 1024-byte block can take >2 s (per-byte timeout).
    absolute_time_t deadline=make_timeout_time_ms(7000);
    do {
        if(!get_status(response)) { response[0]=0xe1; return 1; }
        if(response[1]==seq && response[3]==op && response[2]!=1) {
            if(response[2]==0 && op==0x30) {
                if(((size_t)response[6]|(size_t)response[7]<<8)!=length) {
                    response[0]=0xe3; return 1;
                }
                query(3,response+10,length+2);
                if(!valid(response+10,length+2)) { response[0]=0xe1; return 1; }
                return 10+length+2;
            }
            return 10;
        }
        busy_wait_us_32(20);
    } while(!time_reached(deadline));
    response[0]=0xe4; return 1; // Never retry a possibly committed operation.
}
static bool receive(uint8_t *p, size_t n, absolute_time_t deadline) {
    while(n) {
        int c=getchar_timeout_us(1000);
        if(c!=PICO_ERROR_TIMEOUT) { *p++=(uint8_t)c; --n; }
        else if(time_reached(deadline)) return false;
    }
    return true;
}
static void send_reply(size_t n) {
    static uint8_t frame[MAX_REPLY+8];
    memcpy(frame,"GB3R",4); frame[4]=(uint8_t)(n>>8); frame[5]=(uint8_t)n;
    memcpy(frame+6,response,n);
    uint16_t crc=crc16(frame+4,n+2);
    frame[n+6]=(uint8_t)(crc>>8); frame[n+7]=(uint8_t)crc;
    stdio_put_string((const char *)frame,(int)(n+8),false,false);
    stdio_flush();
}
int main(void) {
    stdio_init_all();
    gpio_init(1); gpio_put(1,1); gpio_set_dir(1,GPIO_OUT);
    spi_init(spi0,GB_SPI_HZ);
    spi_set_format(spi0,8,SPI_CPOL_0,SPI_CPHA_0,SPI_MSB_FIRST);
    gpio_set_function(0,GPIO_FUNC_SPI); gpio_set_function(2,GPIO_FUNC_SPI);
    gpio_set_function(3,GPIO_FUNC_SPI);
    sleep_ms(400);
    static uint8_t frame[MAX_REQUEST+4];
    unsigned matched=0;
    bool discard=false;
    while(true) {
        int c=getchar_timeout_us(100000);
        if(c==PICO_ERROR_TIMEOUT) { matched=0; discard=false; continue; }
        // After damaged framing, drain until a 100 ms idle gap; do not scan
        // the remaining binary payload for accidental embedded commands.
        if(discard) continue;
        if((uint8_t)c!=(uint8_t)"GB3Q"[matched]) { matched=0; discard=true; continue; }
        if(++matched<4) continue;
        matched=0;
        absolute_time_t deadline=make_timeout_time_ms(2000);
        if(!receive(frame,2,deadline)) { discard=true; continue; }
        size_t n=(size_t)frame[0]<<8|frame[1];
        if(n==0 || n>MAX_REQUEST || !receive(frame+2,n+2,deadline) || !valid(frame,n+4)) {
            response[0]=0xe2; send_reply(1); discard=true; continue;
        }
        memcpy(request,frame+2,n); send_reply(execute(n));
    }
}
