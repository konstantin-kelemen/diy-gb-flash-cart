`timescale 1ns/1ps
// Функциональные модели примитивов для Icarus; не netlist Diamond.
module OSCH(input STDBY, output reg OSC=0, output SEDSTDBY);
    parameter NOM_FREQ="53.20";
    always #9.4 OSC=~OSC;
    assign SEDSTDBY=STDBY;
endmodule
module FD1S3AX(input D, CK, output reg Q=0);
    always @(posedge CK) Q<=D;
endmodule
module game_multi_tb;
    reg [15:0] gb_a=0;
    reg gb_rd_n=1, gb_wr_n=1, gb_cs_n=1, gb_res_n=0;
    tri [7:0] gb_d, flash_d, cpu_bus;
    reg cpu_drive=0;
    reg [7:0] cpu_data=0;
    wire data_oe_n, data_dir;
    wire [21:0] flash_a;
    wire flash_ce_n, flash_oe_n, flash_we_n, fram_ce_n, fram_oe_n, fram_we_n;
    top #(.RTC_CLOCK_HZ(100000)) dut(.*);
    reg [7:0] cart_type=0, rom_size=0, ram_size=0;
    reg secondary_logo=0;
    reg [1:0] logo_fill=0;
    integer corrupt_logo=-1;
    localparam [383:0] LOGO=384'hceed6666cc0d000b03730083000c000d0008111f8889000edccc6ee6ddddd999bbbb67636e0eecccdddc999fbbb9333e;
    reg [7:0] ram[0:131071];
    wire [7:0] rom_data=flash_a=='h147 ? cart_type : flash_a=='h148 ? rom_size :
        flash_a=='h149 ? ram_size :
        flash_a>='h104 && flash_a<='h133 ?
            (logo_fill==1 ? 8'h00 : logo_fill==2 ? 8'hff : (LOGO >> (('h133-flash_a)*8))) :
        secondary_logo && flash_a>='h40104 && flash_a<='h40133 ?
            (logo_fill==1 ? 8'h00 : logo_fill==2 ? 8'hff : (LOGO >> (('h40133-flash_a)*8))) ^
            (flash_a=='h40104+corrupt_logo ? 8'h01 : 8'h00) :
        (flash_a>>14) ^ flash_a;
    assign cpu_bus=cpu_drive ? cpu_data : 8'hzz;
    assign #(5,5,5) gb_d=!data_oe_n && !data_dir ? cpu_bus : 8'hzz;
    assign #(5,5,5) cpu_bus=!data_oe_n && data_dir ? gb_d : 8'hzz;
    assign #(70,70,10) flash_d=!flash_ce_n && !flash_oe_n ? rom_data : 8'hzz;
    assign #(90,90,10) flash_d=!fram_ce_n && !fram_oe_n && fram_we_n ? ram[flash_a[16:0]] : 8'hzz;
    reg writing=0;
    reg [16:0] write_address;
    reg [7:0] write_value;
    time ce_start=0, ce_end=0, we_start=0, data_changed=0;
    integer writes=0, i, b, old_writes;
    always @(flash_d) begin #0; if(writing && !fram_we_n) data_changed=$time; end
    always @(negedge fram_ce_n) begin
        if($time-ce_end<30) $fatal(1,"precharge"); ce_start=$time;
    end
    always @(posedge fram_ce_n) begin
        if($time>0 && $time-ce_start<60) $fatal(1,"CE pulse"); ce_end=$time;
    end
    always @(negedge fram_we_n) begin writing=1; we_start=$time; end
    always @(flash_d or flash_a or writing) begin
        #0; if(writing && !fram_we_n) begin write_address=flash_a[16:0]; write_value=flash_d; end
    end
    always @(posedge fram_we_n) if(writing) begin
        if($time-we_start<18 || $time-data_changed<15 || ^write_value===1'bx) $fatal(1,"RAM write timing/data");
        ram[write_address]=write_value; writes=writes+1; writing=0;
    end
    task idle;
        begin gb_rd_n=1; gb_wr_n=1; #30; cpu_drive=0; #50; end
    endtask
    task wr(input [15:0] a,input [7:0] d);
        begin idle(); gb_a=a; gb_cs_n=!(a>='ha000 && a<='hbfff); cpu_data=d; cpu_drive=1;
            #40; gb_wr_n=0; #160;
            if(cpu_bus!==d || gb_d!==d || data_dir!==0) $fatal(1,"write direction");
            gb_wr_n=1; #30; cpu_drive=0; #50;
        end
    endtask
    task rd(input [15:0] a,input [7:0] d);
        begin idle(); gb_a=a; gb_cs_n=!(a>='ha000 && a<='hbfff); #40; gb_rd_n=0; #160;
            if(cpu_bus!==d) $fatal(1,"type %h read %h got %h expected %h",cart_type,a,cpu_bus,d);
            idle();
        end
    endtask
    task boot(input [7:0] t,input [7:0] r,input [7:0] s,input multi);
        begin idle(); gb_res_n=0; cart_type=t; rom_size=r; ram_size=s; secondary_logo=multi;
            #200; if(!fram_ce_n || !flash_ce_n || !data_oe_n) $fatal(1,"reset isolation");
            gb_res_n=1;
            wait(dut.game.configured); #100;
            if(dut.game.cart_type!==t || dut.game.rom_size!==r || dut.game.ram_size!==s) $fatal(1,"header scan");
        end
    endtask
    task rtc_write(input [7:0] r,input [7:0] d);
        begin wr('h4000,r); wr('ha000,d); #4000; end
    endtask
    task latch;
        begin wr('h6000,0); wr('h6000,1); #4000; end
    endtask
    initial begin
        for(i=0;i<131072;i=i+1) ram[i]=8'h55;
        boot(0,0,0,0); rd('h4000,1); wr('h2000,4); rd('h4000,1);
        rd('ha000,'hff); wr('ha000,0); if(writes) $fatal(1,"ROM ONLY write");
        boot('h09,0,2,0); wr('ha000,'h77); rd('ha000,'h77);
        boot(3,4,3,0); wr(0,'ha); wr('h6000,1);
        for(b=0;b<4;b=b+1) begin wr('h4000,b); wr('hbfff,b+64); end
        for(b=0;b<4;b=b+1) begin wr('h4000,b); rd('hbfff,b+64); end
        boot(1,5,0,1);
        if(!dut.game.multicart) $fatal(1,"MBC1M logo");
        wr('h4000,2); wr('h6000,1); wr('h2000,0); rd('h0000,32); rd('h4000,33);
        wr('h2000,16); rd('h4000,32);
        for(i=0;i<48;i=i+1) begin
            corrupt_logo=i; boot(1,5,0,1); if(dut.game.multicart) $fatal(1,"partial MBC1M logo");
        end
        corrupt_logo=-1; boot(1,5,0,0); if(dut.game.multicart) $fatal(1,"false MBC1M");
        logo_fill=1; boot(1,5,0,1); if(dut.game.multicart) $fatal(1,"zero logos accepted");
        logo_fill=2; boot(1,5,0,1); if(dut.game.multicart) $fatal(1,"erased logos accepted");
        logo_fill=0;
        boot(6,3,0,0); wr('h0000,'ha); wr('ha123,'hab); rd('hb323,'hfb);
        wr('h2100,9); rd('h4000,9); wr('h2000,0); rd('ha123,'hff);
        boot('h1b,7,4,0); wr('h2000,255); rd('h7fff,0); wr('h3000,1); rd('h4000,255);
        wr(0,'ha);
        for(b=0;b<16;b=b+1) begin
            wr('h4000,b);
            for(i=0;i<8192;i=i+1) wr('ha000+i,i ^ (i>>8) ^ b);
        end
        for(b=0;b<16;b=b+1) begin
            wr('h4000,b);
            for(i=0;i<8192;i=i+1) rd('ha000+i,i ^ (i>>8) ^ b);
        end
        old_writes=writes; wr(0,0); wr('ha000,0); rd('ha000,'hff);
        if(writes!=old_writes) $fatal(1,"disabled RAM write");
        rd('h8000,'hzz); rd('hc000,'hzz);
        boot('h10,7,5,0); wr(0,'ha); wr('h2000,128); rd('h4000,128);
        rtc_write(12,'h40); rtc_write(8,25); latch(); wr('h4000,8); rd('ha000,25);
        rtc_write(8,26); rd('ha000,25);
        wr('h6000,1); #4000; rd('ha000,25); // Повтор 1 не защёлкивает.
        wr('h6000,2); wr('h6000,1); #4000; rd('ha000,25);
        latch(); rd('ha000,26);
        if(writes!=old_writes) $fatal(1,"RTC touched F-RAM");
        boot('h10,7,5,0); wr(0,'ha); latch(); wr('h4000,8); rd('ha000,26); // RESET GB сохраняет RTC.
        wr(0,0); wr('ha000,12); #4000; rd('ha000,'hff);
        wr(0,'ha); latch(); rd('ha000,26);
        wr('h4000,13); rd('ha000,'hff); wr('ha000,0);
        if(writes!=old_writes) $fatal(1,"invalid RTC select touched F-RAM");
        boot('h1e,7,5,0); wr(0,'ha); wr('h4000,1); wr('ha000,'h73); wr('h4000,9); rd('ha000,'h73);
        boot('h1b,8,4,0); rd('h4000,'hff); wr(0,'ha); old_writes=writes; wr('ha000,0);
        if(dut.game.supported || writes!=old_writes) $fatal(1,"oversize active");
        boot('h22,3,0,0); rd('h4000,'hff); if(dut.game.supported) $fatal(1,"unsupported type active");
        $display("PASS game_multi: auto header/MBC1M, delayed buses, 128 KiB F-RAM, MBC2 nibble, RTC mailbox/reset/latch, isolation");
        $finish;
    end
    always @(*) begin
        if(!flash_we_n) $fatal(1,"Flash written");
        if(!flash_ce_n && !fram_ce_n) $fatal(1,"both memories selected");
    end
    initial begin #200000000; $fatal(1,"timeout"); end
endmodule
