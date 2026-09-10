// RP2040 owns USB v3 blocks; the FPGA runs short SPI v4 Flash operations.
// See docs/PROGRAMMER_SPI_V4.md.
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
// SPI v4 is a one-byte executor. USB v3 blocks are assembled entirely here.
static uint8_t host_seq, host_op, host_status;
static uint16_t host_result, host_completed;
static bool host_armed;

static void append_crc(uint8_t *p, size_t n) {
    uint16_t crc=crc16(p,n);
    p[n]=(uint8_t)(crc>>8); p[n+1]=(uint8_t)crc;
}
static size_t host_reply(void) {
    response[0]=0x50; response[1]=host_seq; response[2]=host_status; response[3]=host_op;
    response[4]=(uint8_t)host_result; response[5]=(uint8_t)(host_result>>8);
    response[6]=(uint8_t)host_completed; response[7]=(uint8_t)(host_completed>>8);
    append_crc(response,8); return 10;
}
static size_t bridge_error(uint8_t error) {
    host_armed=false; host_status=3;
    response[0]=error; return 1;
}
static bool probe_link(void) {
    uint8_t version[8]; query(1,version,sizeof(version));
    return memcmp(version,"GBFC\4\0\1\0",8)==0;
}
// No retries: a lost response may follow a successfully committed Flash write.
static uint8_t link_command(uint8_t op, uint32_t address, uint8_t value,
                            bool leased, uint8_t *status, absolute_time_t deadline) {
    if(!get_status(status)) return 0xe1;
    if((status[2]&15)==1 || (leased ? !(status[2]&0x80) : !(status[2]&0x40))) return 0xe3;
    uint8_t seq=(uint8_t)(status[1]+1);
    uint8_t packet[11]={op,seq,(uint8_t)(address>>16),(uint8_t)(address>>8),
                        (uint8_t)address,0,0,0,0,0,0};
    size_t n=10;
    if(op==0x30 || op==0x31) packet[6]=1;
    if(op==0x31) { packet[8]=value; n=11; }
    else if(op==0x20 || op==0x22) packet[7]=value;
    append_crc(packet,n-2);
    select_spi(); spi_write_blocking(spi0,packet,n); release_spi();
    do {
        if(!get_status(status)) return 0xe1;
        if(status[1]==seq && status[3]==op && (status[2]&15)!=1) return 0;
        busy_wait_us_32(20);
    } while(!time_reached(deadline));
    return 0xe4;
}
static size_t execute(size_t n) {
    if(n==1 && request[0]==1) {
        if(!probe_link()) return bridge_error(0xe1);
        memcpy(response,"GBFC\3\0\0\4",8); return 8;
    }
    if(n==1 && request[0]==2) return host_reply();
    if(n<10 || !valid(request,n)) return bridge_error(0xe2);
    const uint8_t op=request[0], seq=request[1];
    const size_t length=(size_t)request[5]<<8|request[6];
    const uint32_t address=(uint32_t)request[2]<<16|(uint32_t)request[3]<<8|request[4];
    const bool block=op==0x30 || op==0x31;
    if((block ? (length==0 || length>BLOCK) : length!=0) ||
       n!=10+(op==0x31?length:0) ||
       !(block || op==0x12 || op==0x13 || op==0x14 || op==0x20 || op==0x21))
        return bridge_error(0xe2);
    if(seq==host_seq) return bridge_error(0xe3);
    host_seq=seq; host_op=op; host_status=0; host_result=0; host_completed=0;
    if(address>=0x400000 || (block && length>0x400000-address)) {
        host_status=8; host_armed=false; return host_reply();
    }
    if(op==0x20 && (address!=0 || request[7]!=0xa5)) {
        host_status=9; host_armed=false; return host_reply();
    }
    if(op!=0x30 && op!=0x20 && op!=0x21 && !host_armed) {
        host_status=9; return host_reply();
    }
    if(!probe_link()) return bridge_error(0xe1);
    absolute_time_t deadline=make_timeout_time_ms(7000);
    uint8_t status[10], error;
    if(op==0x20 || op==0x21) {
        host_armed=false;
        error=link_command(op,address,request[7],false,status,deadline);
        if(error) return bridge_error(error);
        host_status=status[2]&15;
        host_armed=op==0x20 && host_status==0;
        return host_reply();
    }
    error=link_command(0x22,0,0xa5,false,status,deadline);
    if(error) return bridge_error(error);
    if((status[2]&15)!=0 || !(status[2]&0x80)) return bridge_error(0xe3);
    size_t count=block ? length : 1;
    for(size_t i=0;i<count;++i) {
        // Erased bytes need no program pulse. The full block is already CRC checked.
        if(op==0x31 && request[8+i]==0xff) { ++host_completed; continue; }
        error=link_command(op,address+(uint32_t)i,op==0x31?request[8+i]:0,true,status,deadline);
        if(error) break;
        host_status=status[2]&15;
        host_result=(uint16_t)status[4]|(uint16_t)status[5]<<8;
        if(host_status!=0) { host_armed=false; break; }
        if(!(status[2]&0x80)) { error=0xe3; break; }
        if(op==0x30) response[10+i]=status[4];
        ++host_completed;
    }
    // Release only through a checked command; if communication failed, the FPGA
    // watchdog releases an idle lease after ~20 ms, after any Flash operation.
    uint8_t release_error=link_command(0x23,0,0,true,status,deadline);
    if(error) return bridge_error(error);
    if(release_error) return bridge_error(release_error);
    if((status[2]&15)!=0 || (status[2]&0x80)) return bridge_error(0xe3);
    host_reply();
    if(op==0x30 && host_status==0) {
        append_crc(response+10,length); return 12+length;
    }
    return 10;
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
