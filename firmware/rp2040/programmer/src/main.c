// USB v5 blocks (16 KiB) -> SPI v5 EBR portions (256 bytes).
// Wire formats and deadlines: docs/PROGRAMMER_PROTOCOL.md.
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "pico/stdlib.h"
#include "hardware/spi.h"
#define BLOCK 16384
#define SPI_BLOCK 256
#define MAX_REQUEST (BLOCK + 8)
#define MAX_REPLY (BLOCK + 8)
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
static uint32_t crc32(const uint8_t *p, size_t n) {
    uint32_t c=0xffffffff;
    while(n--) {
        c^=*p++;
        for(int i=0;i<8;++i) c=(c>>1)^((c&1)?0xedb88320:0);
    }
    return c^0xffffffff;
}
static uint32_t le32(const uint8_t *p) {
    return (uint32_t)p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24;
}
static void put32(uint8_t *p, uint32_t c) {
    for(unsigned i=0;i<4;++i) p[i]=(uint8_t)(c>>(8*i));
}
static void append_crc(uint8_t *p, size_t n) {
    uint16_t c=crc16(p,n); p[n]=(uint8_t)(c>>8); p[n+1]=(uint8_t)c;
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
static bool probe_link(void) {
    uint8_t version[8]; query(1,version,sizeof(version));
    return memcmp(version,"GBFC\5\0\0\1",8)==0;
}
static uint8_t host_seq, host_op, host_status;
static uint16_t host_result, host_completed;
static bool host_armed;
static size_t host_reply(void) {
    response[0]=host_op; response[1]=host_seq; response[2]=host_status;
    response[3]=(uint8_t)host_result; response[4]=(uint8_t)(host_result>>8);
    response[5]=(uint8_t)host_completed; response[6]=(uint8_t)(host_completed>>8);
    response[7]=0; return 8;
}
static size_t bridge_error(uint8_t error) {
    host_armed=false; host_status=error; return host_reply();
}
// All deadlines are checked even if input/status arrives continuously.
static absolute_time_t portion_deadline(absolute_time_t overall) {
    absolute_time_t local=make_timeout_time_ms(7000);
    return absolute_time_diff_us(local,overall)<0 ? overall : local;
}
// No retries: a lost response may follow a successfully committed Flash write.
static uint8_t link_command(uint8_t op, uint32_t address, uint16_t length,
                            uint8_t key, const uint8_t *payload, bool leased,
                            uint8_t *status, absolute_time_t deadline) {
    if(time_reached(deadline)) return 0xe4;
    if(!get_status(status)) return 0xe1;
    if((status[2]&15)==1 || (leased ? !(status[2]&0x80) : !(status[2]&0x40))) return 0xe3;
    uint8_t seq=(uint8_t)(status[1]+1);
    uint8_t packet[SPI_BLOCK+10]={op,seq,(uint8_t)(address>>16),(uint8_t)(address>>8),
                                (uint8_t)address,(uint8_t)(length>>8),(uint8_t)length,key};
    size_t n=8;
    if(op==0x31) { memcpy(packet+n,payload,length); n+=length; }
    append_crc(packet,n);
    select_spi(); spi_write_blocking(spi0,packet,n+2); release_spi();
    do {
        if(!get_status(status)) return 0xe1;
        if(status[1]==seq && status[3]==op && (status[2]&15)!=1) return 0;
        busy_wait_us_32(20);
    } while(!time_reached(deadline));
    return 0xe4;
}
static size_t execute(size_t n) {
    if(n==1 && request[0]==1) {
        if(!probe_link()) { response[0]=0xe1; return 1; }
        memcpy(response,"GBFC\5\0\0\100",8); return 8;
    }
    if(n==1 && request[0]==2) return host_reply();
    if(n<8) { response[0]=0xe2; host_armed=false; return 1; }
    const uint8_t op=request[0], seq=request[1];
    const size_t length=(size_t)request[5]<<8|request[6];
    const uint32_t address=(uint32_t)request[2]<<16|(uint32_t)request[3]<<8|request[4];
    const bool block=op==0x30 || op==0x31;
    if(seq==host_seq) { response[0]=0xe3; host_armed=false; return 1; }
    host_seq=seq; host_op=op; host_status=0; host_result=0; host_completed=0;
    if((block ? (length==0 || length>BLOCK) : length!=0) ||
       n!=8+(op==0x31?length:0) ||
       !(block || op==0x12 || op==0x13 || op==0x14 || op==0x20 || op==0x21) ||
       (op!=0x20 && request[7]!=0)) return bridge_error(0xe2);
    if(address>=0x400000 || (block && length>0x400000-address)) return bridge_error(8);
    if(op==0x20 && (address!=0 || request[7]!=0xa5)) return bridge_error(9);
    if(op!=0x30 && op!=0x20 && op!=0x21 && !host_armed) return bridge_error(9);
    if(!probe_link()) return bridge_error(0xe1);
    absolute_time_t overall=make_timeout_time_ms(90000);
    uint8_t status[10], error;
    if(op==0x20 || op==0x21) {
        host_armed=false;
        error=link_command(op,address,0,request[7],NULL,false,status,portion_deadline(overall));
        if(error) return bridge_error(error);
        host_status=status[2]&15;
        host_armed=op==0x20 && host_status==0;
        return host_reply();
    }
    size_t count=block ? length : 1;
    for(size_t offset=0;offset<count;) {
        absolute_time_t deadline=portion_deadline(overall);
        size_t portion=count-offset;
        if(portion>SPI_BLOCK) portion=SPI_BLOCK;
        error=link_command(0x22,0,0,0xa5,NULL,false,status,deadline);
        if(error) return bridge_error(error);
        if((status[2]&15)!=0 || !(status[2]&0x80)) return bridge_error(0xe3);
        error=link_command(op,address+(uint32_t)offset,block?(uint16_t)portion:0,
                           0,op==0x31?request+8+offset:NULL,true,status,deadline);
        if(!error) {
            host_status=status[2]&15;
            host_result=(uint16_t)status[4]|(uint16_t)status[5]<<8;
            uint16_t completed=(uint16_t)status[6]|(uint16_t)status[7]<<8;
            if(completed>portion || (!host_status && completed!=portion)) error=0xe5;
            else host_completed+=(uint16_t)completed;
            if(!(status[2]&0x80)) error=0xe3;
            if(!error && !host_status && op==0x30) {
                uint8_t data[SPI_BLOCK+2]; query(3,data,portion+2);
                if(!valid(data,portion+2)) error=0xe1;
                else memcpy(response+8+offset,data,portion);
            }
        }
        // Preserve the operation status; releasing has a different SPI sequence.
        uint8_t release_error=link_command(0x23,0,0,0,NULL,true,status,deadline);
        if(error) return bridge_error(error);
        if(release_error) return bridge_error(release_error);
        if((status[2]&15)!=0 || (status[2]&0x80)) return bridge_error(0xe3);
        if(host_status) { host_armed=false; return host_reply(); }
        if(time_reached(overall)) return bridge_error(0xe4);
        offset+=portion;
    }
    host_reply(); return op==0x30 ? 8+length : 8;
}
static bool receive(uint8_t *p, size_t n, absolute_time_t deadline) {
    while(n) {
        if(time_reached(deadline)) return false;
        int c=getchar_timeout_us(1000);
        if(c!=PICO_ERROR_TIMEOUT) { *p++=(uint8_t)c; --n; }
    }
    return true;
}
static void send_reply(size_t n) {
    static uint8_t frame[MAX_REPLY+10];
    memcpy(frame,"GB5R",4); frame[4]=(uint8_t)(n>>8); frame[5]=(uint8_t)n;
    memcpy(frame+6,response,n); put32(frame+n+6,crc32(frame+4,n+2));
    stdio_put_string((const char *)frame,(int)(n+10),false,false); stdio_flush();
}
// Decode only a complete USB body after validating its outer CRC32.
static size_t execute_frame(const uint8_t *frame, size_t n) {
    size_t length=n>=6 ? ((size_t)frame[0]<<8|frame[1]) : 0;
    if(!length || length>MAX_REQUEST || n!=length+6 ||
       crc32(frame,n-4)!=le32(frame+n-4)) {
        host_armed=false; response[0]=0xe2; return 1;
    }
    memcpy(request,frame+2,length); return execute(length);
}
int main(void) {
    stdio_init_all();
    gpio_init(1); gpio_put(1,1); gpio_set_dir(1,GPIO_OUT);
    spi_init(spi0,GB_SPI_HZ);
    spi_set_format(spi0,8,SPI_CPOL_0,SPI_CPHA_0,SPI_MSB_FIRST);
    gpio_set_function(0,GPIO_FUNC_SPI); gpio_set_function(2,GPIO_FUNC_SPI);
    gpio_set_function(3,GPIO_FUNC_SPI); sleep_ms(400);
    static uint8_t frame[MAX_REQUEST+6];
    unsigned matched=0; bool discard=false;
    while(true) {
        int c=getchar_timeout_us(100000);
        if(c==PICO_ERROR_TIMEOUT) { matched=0; discard=false; continue; }
        // Never search binary payload for embedded commands after framing errors.
        if(discard) continue;
        if((uint8_t)c!=(uint8_t)"GB5Q"[matched]) { matched=0; discard=true; continue; }
        if(++matched<4) continue;
        matched=0;
        absolute_time_t deadline=make_timeout_time_ms(2000);
        if(!receive(frame,2,deadline)) { host_armed=false; discard=true; continue; }
        size_t n=(size_t)frame[0]<<8|frame[1];
        if(!n || n>MAX_REQUEST || !receive(frame+2,n+4,deadline)) {
            host_armed=false; response[0]=0xe2; send_reply(1); discard=true; continue;
        }
        size_t reply=execute_frame(frame,n+6);
        send_reply(reply);
        if(reply==1) discard=true;
    }
}
