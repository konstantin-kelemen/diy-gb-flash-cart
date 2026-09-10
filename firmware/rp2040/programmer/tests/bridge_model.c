// Appended to the actual firmware source by test_bridge.py (SDK calls stubbed).
static unsigned commits, reads, writes, leases, releases;
static uint8_t query_op, fpga_seq, fpga_op, fpga_status;
static uint16_t fpga_result;
static bool fpga_armed, leased, accepting=true, force_busy, stall, stall_after_read;
static bool corrupt_next, corrupt_write_reply, switch_during_write, old_version;
static unsigned fail_read;
static uint8_t usb[1200];
static size_t usb_size;

static int spi_write_blocking(int ignored,const uint8_t *p,size_t n) {
    (void)ignored;
    if(n==1) { query_op=p[0]; return (int)n; }
    assert((n==10 || n==11) && valid(p,n));
    assert(accepting || leased);
    ++commits; fpga_seq=p[1]; fpga_op=p[0]; fpga_status=0; fpga_result=0;
    uint32_t addr=(uint32_t)p[2]<<16|(uint32_t)p[3]<<8|p[4];
    switch(p[0]) {
        case 0x20: assert(p[7]==0xa5); fpga_armed=true; break;
        case 0x21: fpga_armed=false; break;
        case 0x22: assert(!leased && accepting && p[7]==0xa5); leased=true; ++leases; break;
        case 0x23: assert(leased); leased=false; ++releases; break;
        case 0x30:
            assert(leased && n==10 && p[5]==0 && p[6]==1);
            ++reads; fpga_result=(uint8_t)(addr^(addr>>8)^(addr>>16));
            if(fail_read && reads==fail_read) fpga_status=5;
            if(stall_after_read) stall=true;
            break;
        case 0x31:
            assert(leased && fpga_armed && n==11 && p[5]==0 && p[6]==1 && p[8]!=0xff);
            ++writes; fpga_result=p[8];
            if(switch_during_write) accepting=false;
            if(corrupt_write_reply) { corrupt_next=true; corrupt_write_reply=false; }
            break;
        case 0x12: case 0x14: assert(leased && fpga_armed); break;
        case 0x13: assert(leased && fpga_armed); fpga_result=0xa8c2; break;
        default: assert(0);
    }
    return (int)n;
}
static int spi_read_blocking(int ignored,uint8_t filler,uint8_t *p,size_t n) {
    (void)ignored; (void)filler;
    memset(p,0,n);
    if(query_op==1) {
        assert(n==8); memcpy(p,old_version?"GBFC\3\0\0\4":"GBFC\4\0\1\0",8);
        return (int)n;
    }
    assert(query_op==2 && n==10);
    p[0]=0x50; p[1]=fpga_seq; p[3]=fpga_op;
    p[2]=(leased?0x80:0)|(accepting?0x40:0)|((force_busy||stall)?1:fpga_status);
    p[4]=(uint8_t)fpga_result; p[5]=(uint8_t)(fpga_result>>8);
    p[6]=(fpga_op==0x30 || fpga_op==0x31) && fpga_status==0;
    append_crc(p,8);
    if(corrupt_next) { p[9]^=1; corrupt_next=false; }
    return (int)n;
}
static int stdio_put_string(const char *p,int n,bool newline,bool translate) {
    assert(!newline && !translate); memcpy(usb,p,n); usb_size=(size_t)n; return n;
}
static size_t prepare(uint8_t op,uint32_t addr,size_t length) {
    size_t n=10+(op==0x31?length:0);
    memset(request,0,sizeof(request));
    request[0]=op; request[1]=(uint8_t)(host_seq+1);
    request[2]=(uint8_t)(addr>>16); request[3]=(uint8_t)(addr>>8); request[4]=(uint8_t)addr;
    request[5]=(uint8_t)(length>>8); request[6]=(uint8_t)length;
    if(op==0x20) request[7]=0xa5;
    for(size_t i=0;i<(op==0x31?length:0);++i) request[8+i]=(uint8_t)i;
    append_crc(request,n-2); return n;
}
static void arm_host(void) {
    size_t n=prepare(0x20,0,0);
    assert(execute(n)==10 && response[2]==0 && host_armed && fpga_armed);
}
int main(void) {
    request[0]=1; assert(execute(1)==8 && !memcmp(response,"GBFC\3\0\0\4",8));
    old_version=true; assert(execute(1)==1 && response[0]==0xe1); old_version=false;
    size_t n=prepare(0x30,0x00ff80,1024);
    assert(execute(n)==1036 && reads==1024 && leases==1 && releases==1 && !leased);
    assert(host_completed==1024 && valid(response,10) && valid(response+10,1026));
    for(size_t i=0;i<1024;++i) {
        uint32_t addr=0x00ff80+(uint32_t)i;
        assert(response[10+i]==(uint8_t)(addr^(addr>>8)^(addr>>16)));
    }
    send_reply(1036); assert(usb_size==1044 && !memcmp(usb,"GB3R",4) && valid(usb+4,1040));
    unsigned before=commits;
    assert(execute(n)==1 && response[0]==0xe3 && commits==before); // duplicate host sequence
    n=prepare(0x31,0,3); request[n-1]^=1;
    assert(execute(n)==1 && response[0]==0xe2 && commits==before);
    n=prepare(0x31,0,3); assert(execute(n-1)==1 && commits==before);
    n=prepare(0x30,0,0); assert(execute(n)==1 && commits==before);
    n=prepare(0x30,0x3fffff,2); assert(execute(n)==10 && response[2]==8 && commits==before);
    n=prepare(0x30,0x3fffff,1); assert(execute(n)==13 && host_completed==1);
    n=prepare(0x31,0,1); assert(execute(n)==10 && response[2]==9 && writes==0);
    arm_host();
    switch_during_write=true;
    n=prepare(0x31,0x100,1024);
    assert(execute(n)==10 && host_completed==1024 && writes==1020 && !leased && !accepting);
    assert(response[2]==0 && valid(response,10));
    // The mode may change only after the whole leased block, including skipped FF bytes.
    before=commits; n=prepare(0x30,0,1);
    assert(execute(n)==1 && response[0]==0xe3 && commits==before);
    accepting=true; switch_during_write=false;
    arm_host(); n=prepare(0x13,0,0);
    assert(execute(n)==10 && host_result==0xa8c2 && host_completed==1 && !leased);
    n=prepare(0x30,0,30); fail_read=reads+17;
    assert(execute(n)==10 && response[2]==5 && host_completed==16 && !host_armed && !leased);
    fail_read=0;
    arm_host(); corrupt_write_reply=true; before=writes; n=prepare(0x31,0,1);
    assert(execute(n)==1 && response[0]==0xe1 && writes==before+1 && !leased);
    arm_host(); force_busy=true; before=commits; n=prepare(0x31,0,1);
    assert(execute(n)==1 && response[0]==0xe3 && commits==before); force_busy=false;
    // Invalid CRCs in status are never accepted as successful operations.
    corrupt_next=true; n=prepare(0x30,0,1);
    assert(execute(n)==1 && response[0]==0xe1);
    stall_after_read=true; before=reads; n=prepare(0x30,0,1);
    assert(execute(n)==1 && response[0]==0xe4 && reads==before+1 && leased);
    stall_after_read=false; stall=false; leased=false; // model the idle-lease watchdog
    request[0]=2; assert(execute(1)==10 && valid(response,10));
    uint8_t b; assert(!receive(&b,1,0));
    puts("PASS RP2040 offload: 1024-byte blocks, CRC, bounds, lease, mode change, partial failure, no retry");
    return 0;
}
