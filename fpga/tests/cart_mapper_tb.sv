`timescale 1ns/1ps
module cart_mapper_tb;
    reg configured=1, multicart=0;
    reg [7:0] cart_type=255, rom_size=255, ram_size=255;
    reg [15:0] gb_a=0;
    reg [7:0] gb_data=0;
    reg gb_rd_n=1, gb_wr_n=1, gb_cs_n=1, gb_res_n=0;
    wire supported, ram_access, nibble_ram, rtc_access;
    wire [21:0] rom_address;
    wire [16:0] ram_address;
    wire [2:0] rtc_register, rtc_write_register;
    wire [7:0] rtc_write_data;
    wire rtc_write_toggle, rtc_latch_toggle;
    cart_mapper dut(.*);
    integer size, hi, lo, mode, expected, i, mask;
    task boot(input [7:0] t, input [7:0] r, input [7:0] s, input multi);
        begin gb_res_n=0; cart_type=t; rom_size=r; ram_size=s; multicart=multi;
            #10; gb_res_n=1; #10;
        end
    endtask
    task wr(input [15:0] a, input [7:0] d);
        begin gb_a=a; gb_data=d; #10; gb_wr_n=0; #100; gb_wr_n=1; #20; end
    endtask
    task rom(input [15:0] a, input integer bank);
        begin gb_a=a; #1;
            if(rom_address !== bank*16384+(a & 'h3fff))
                $fatal(1,"ROM type=%h size=%d address=%h got=%h bank=%d",cart_type,rom_size,a,rom_address,bank);
        end
    endtask
    initial begin
        boot(0,0,0,0); rom('h7fff,1); wr('h2000,7); rom('h4000,1);
        if(ram_access) $fatal(1,"ROM ONLY RAM");
        boot('h09,0,2,0); if(!ram_access) $fatal(1,"ROM RAM always enabled");
        wr(0,0); if(!ram_access) $fatal(1,"ROM RAM enable register");
        for(size=0;size<=6;size=size+1) begin
            boot(1,size,0,0); mask=(2<<size)-1;
            if(!supported) $fatal(1,"MBC1 header");
            for(mode=0;mode<2;mode=mode+1) begin
                wr('h6000,mode);
                for(hi=0;hi<4;hi=hi+1) begin
                    wr('h4000,hi);
                    for(lo=0;lo<32;lo=lo+1) begin
                        wr('h2000,lo | 'he0);
                        expected=((hi*32)+(lo==0 ? 1 : lo)) & mask;
                        rom('h4000,expected); rom('h7fff,expected);
                        rom('h0000,(mode ? hi*32 : 0) & mask);
                    end
                end
            end
        end
        boot(3,4,3,0); wr(0,'h1a);
        for(mode=0;mode<2;mode=mode+1) begin
            wr('h7fff,mode);
            for(hi=0;hi<4;hi=hi+1) begin
                wr('h5fff,hi); gb_a='hbfff; #1;
                if(!ram_access || ram_address !== (mode ? hi*8192 : 0)+8191) $fatal(1,"MBC1 RAM mode");
            end
        end
        boot(1,5,0,1);
        for(hi=0;hi<4;hi=hi+1) begin
            wr('h4000,hi); wr('h6000,1);
            for(lo=0;lo<32;lo=lo+1) begin
                wr('h2000,lo); rom('h0000,hi*16);
                rom('h4000,hi*16+((lo==0 ? 1 : lo)&15));
            end
        end
        boot(6,3,0,0);
        for(i=0;i<16;i=i+1) begin wr('h0100,i); rom('h4000,i==0 ? 1 : i); end
        wr('h2100,0); rom('h4000,1); wr('h2000,'ha);
        if(!ram_access || !nibble_ram) $fatal(1,"MBC2 A8 RAM enable");
        for(i='ha000;i<='hbfff;i=i+1) begin
            gb_a=i; #1; if(ram_address !== (i & 511)) $fatal(1,"MBC2 mirror");
        end
        wr('h4000,0); if(!ram_access) $fatal(1,"MBC2 ignored register");
        wr('h3e00,0); if(ram_access) $fatal(1,"MBC2 disable");
        boot('h10,6,3,0);
        for(i=0;i<256;i=i+1) begin wr('h2000,i); rom('h4000,(i & 127)==0 ? 1 : (i & 127)); end
        wr(0,'ha);
        for(i=0;i<256;i=i+1) begin
            wr('h4000,i); gb_a='ha000; #1;
            if(ram_access !== (i<4) || rtc_access !== (i>=8 && i<=12)) $fatal(1,"MBC3 select %d",i);
        end
        boot('h10,7,5,0); wr(0,'ha);
        for(i=0;i<256;i=i+1) begin wr('h2000,i); rom('h4000,i==0 ? 1 : i); end
        for(i=0;i<8;i=i+1) begin wr('h4000,i); gb_a='hbfff; #1;
            if(!ram_access || ram_address !== i*8192+8191) $fatal(1,"MBC30 RAM");
        end
        boot('h13,6,3,0); wr(0,'ha); wr('h4000,8);
        if(rtc_access || ram_access) $fatal(1,"RTC absent");
        for(size=0;size<=7;size=size+1) begin
            boot('h1b,size,4,0); mask=(2<<size)-1;
            for(i=0;i<512;i=i+1) begin
                wr('h2000,i); wr('h3000,i>>8); rom('h4000,i & mask); rom('h3fff,0);
            end
        end
        wr(0,'ha);
        for(i=0;i<16;i=i+1) begin wr('h4000,i); gb_a='ha000; #1;
            if(ram_address !== i*8192 || !ram_access) $fatal(1,"MBC5 RAM");
        end
        boot('h1e,7,5,0); wr(0,'ha);
        for(i=0;i<16;i=i+1) begin wr('h4000,i); gb_a='ha000; #1;
            if(ram_address !== (i & 7)*8192) $fatal(1,"rumble bank bit");
        end
        boot('h1a,3,1,0); wr(0,'ha); wr('h4000,15); gb_a='hbfff; #1;
        if(ram_address !== 2047) $fatal(1,"2 KiB RAM mask");
        boot('h1b,8,4,0); if(supported || ram_access) $fatal(1,"8 MiB accepted");
        boot('h22,3,0,0); if(supported) $fatal(1,"unknown accepted");
        boot(3,5,3,0); if(supported) $fatal(1,"impossible MBC1 wiring");
        boot('h1b,7,4,0); configured=0; #1; if(supported || ram_access) $fatal(1,"unconfigured");
        $display("PASS cart_mapper: ROM ONLY, MBC1/MBC1M, MBC2, MBC3/MBC30, MBC5 masks/registers/RAM/invalid headers");
        $finish;
    end
endmodule
