// Appended to the actual main.c. Exported functions are used by Python/ctypes.
static uint8_t memory[0x400000], spi_buffer[SPI_BLOCK];
static unsigned commits, reads, writes, leases, releases;
static uint8_t query_op, fpga_seq, fpga_op, fpga_status;
static uint16_t fpga_result, fpga_completed;
static bool fpga_armed, leased, accepting, old_version, corrupt_status, corrupt_data;
static bool corrupt_after_write, stall, switch_during_write, bad_count;
static uint32_t fail_address;
static unsigned op_delay, input_delay;
static uint8_t usb_output[MAX_REPLY+10];
static size_t usb_size, input_size, input_offset;
static const uint8_t *usb_input;
static jmp_buf usb_end;
static int spi_write_blocking(int ignored,const uint8_t *p,size_t n) {
    (void)ignored; model_time+=2*n;
    if(n==1) { query_op=p[0]; return (int)n; }
    assert(n>=10 && n<=SPI_BLOCK+10 && valid(p,n));
    assert(accepting || leased);
    assert(p[1]!=fpga_seq);
    ++commits; fpga_seq=p[1]; fpga_op=p[0]; fpga_status=0; fpga_result=0; fpga_completed=0;
    uint32_t addr=(uint32_t)p[2]<<16|(uint32_t)p[3]<<8|p[4];
    size_t len=(size_t)p[5]<<8|p[6];
    switch(p[0]) {
        case 0x20: assert(p[7]==0xa5); fpga_armed=true; break;
        case 0x21: fpga_armed=false; break;
        case 0x22: assert(!leased && accepting && p[7]==0xa5); leased=true; ++leases; break;
        case 0x23: assert(leased); leased=false; ++releases; break;
        case 0x30: case 0x31:
            assert(leased && len>=1 && len<=SPI_BLOCK && addr+len<=0x400000);
            assert(n==10+(p[0]==0x31?len:0));
            if(p[0]==0x31) { assert(fpga_armed); ++writes; } else ++reads;
            model_time+=op_delay;
            for(size_t i=0;i<len;++i) {
                if(addr+i==fail_address) { fpga_status=5; fpga_armed=false; break; }
                if(p[0]==0x31) memory[addr+i]&=p[8+i];
                else spi_buffer[i]=memory[addr+i];
                ++fpga_completed;
            }
            if(p[0]==0x31 && switch_during_write) accepting=false;
            if(p[0]==0x31 && corrupt_after_write) {corrupt_status=true; corrupt_after_write=false;}
            break;
        case 0x12: {
            assert(leased && fpga_armed);
            uint32_t size=addr<0x10000 ? 8192 : 65536;
            memset(memory+(addr/size)*size,0xff,size); fpga_completed=1; break;
        }
        case 0x14: assert(leased && fpga_armed); fpga_completed=1; break;
        case 0x13: assert(leased && fpga_armed); fpga_result=0xa8c2; fpga_completed=1; break;
        default: assert(0);
    }
    return (int)n;
}
static int spi_read_blocking(int ignored,uint8_t filler,uint8_t *p,size_t n) {
    (void)ignored; (void)filler; model_time+=2*n; memset(p,0,n);
    if(query_op==1) {
        assert(n==8); memcpy(p,old_version?"GBFC\4\0\1\0":"GBFC\5\0\0\1",8); return (int)n;
    }
    if(query_op==3) {
        assert(leased && fpga_op==0x30 && fpga_status==0 && n==fpga_completed+2u);
        memcpy(p,spi_buffer,n-2); append_crc(p,n-2);
        if(corrupt_data) p[n-1]^=1;
        return (int)n;
    }
    assert(query_op==2 && n==10);
    p[0]=0x50; p[1]=fpga_seq; p[3]=fpga_op;
    p[2]=(leased?0x80:0)|(accepting?0x40:0)|(stall && fpga_op==0x31?1:fpga_status);
    p[4]=(uint8_t)fpga_result; p[5]=(uint8_t)(fpga_result>>8);
    unsigned count=fpga_completed+(bad_count && fpga_op==0x30 ? 1:0);
    p[6]=(uint8_t)count; p[7]=(uint8_t)(count>>8); append_crc(p,8);
    if(corrupt_status) { p[9]^=1; corrupt_status=false; }
    return (int)n;
}
static int stdio_put_string(const char *p,int n,bool newline,bool translate) {
    assert(!newline && !translate && n<=(int)sizeof(usb_output));
    memcpy(usb_output,p,n); usb_size=(size_t)n; return n;
}
static int getchar_timeout_us(unsigned timeout) {
    if(input_offset<input_size) { model_time+=input_delay; return usb_input[input_offset++]; }
    // Permit receive() and discard logic to time out, then stop the firmware loop.
    model_time+=timeout;
    if(timeout==100000) longjmp(usb_end,1);
    return PICO_ERROR_TIMEOUT;
}
void model_reset(void) {
    memset(memory,0xff,sizeof(memory)); model_time=0;
    commits=reads=writes=leases=releases=0;
    fpga_seq=fpga_op=fpga_status=0; fpga_result=fpga_completed=0;
    host_seq=host_op=host_status=0; host_result=host_completed=0;
    fpga_armed=leased=host_armed=old_version=corrupt_status=corrupt_data=false;
    corrupt_after_write=stall=switch_during_write=bad_count=false;
    accepting=true; fail_address=0xffffffff; op_delay=input_delay=0;
}
size_t model_exchange(const uint8_t *p,size_t n,uint8_t *out) {
    usb_input=p; input_size=n; input_offset=0; usb_size=0;
    if(!setjmp(usb_end)) firmware_main();
    memcpy(out,usb_output,usb_size); return usb_size;
}
void model_fault(unsigned kind,unsigned value) {
    switch(kind) {
        case 1: old_version=value; break;
        case 2: corrupt_data=value; break;
        case 3: corrupt_after_write=value; break;
        case 4: stall=value; break;
        case 5: switch_during_write=value; break;
        case 6: fail_address=value; break;
        case 7: bad_count=value; break;
        case 8: op_delay=value; break;
        case 9: input_delay=value; break;
        case 10: accepting=value; break;
        default: assert(0);
    }
}
unsigned model_count(unsigned kind) {
    switch(kind) {case 0:return commits; case 1:return reads; case 2:return writes;
        case 3:return leases; case 4:return releases; case 5:return host_completed;
        case 6:return (unsigned)(model_time/1000); default:assert(0); return 0;}
}
uint8_t *model_memory(void) {return memory;}
