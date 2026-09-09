`timescale 1ns/1ps
module game_mbc5_tb;
    reg [15:0] gb_a=0;
    reg gb_rd_n=1, gb_wr_n=1, gb_cs_n=1, gb_res_n=0;
    tri [7:0] gb_d, flash_d, cpu_bus;
    reg cpu_drive=0;
    reg [7:0] cpu_data=0;
    wire data_oe_n, data_dir;
    wire [21:0] flash_a;
    wire flash_ce_n, flash_oe_n, flash_we_n, fram_ce_n, fram_oe_n, fram_we_n;
    top dut(.*);
    reg [7:0] rom [0:1048575];
    reg [7:0] ram [0:131071];
    assign cpu_bus = cpu_drive ? cpu_data : 8'hzz;
    assign #(5,5,5) gb_d = !data_oe_n && !data_dir ? cpu_bus : 8'hzz;
    assign #(5,5,5) cpu_bus = !data_oe_n && data_dir ? gb_d : 8'hzz;
    assign #(70,70,10) flash_d = !flash_ce_n && !flash_oe_n ? rom[flash_a] : 8'hzz;
    assign #(90,90,10) flash_d = !fram_ce_n && !fram_oe_n && fram_we_n ? ram[flash_a[16:0]] : 8'hzz;
    integer i, bank, phase, writes=0;
    reg [16:0] write_addr;
    reg [7:0] write_data;
    time ce_start, ce_end=0, we_start;
    reg writing=0;
    // Запоминаются данные в активной части цикла; проверяется setup до конца.
    time data_changed;
    always @(flash_d) data_changed=$time;
    always @(negedge fram_ce_n) begin
        if ($time-ce_end < 30) $fatal(1,"precharge <30 ns");
        ce_start=$time;
    end
    always @(posedge fram_ce_n) begin
        if ($time>0 && $time-ce_start < 60) $fatal(1,"CE pulse <60 ns");
        ce_end=$time;
    end
    always @(negedge fram_we_n) begin
        we_start=$time; writing=1;
    end
    always @(flash_a or flash_d or writing) if (writing) begin
        write_addr=flash_a[16:0]; write_data=flash_d;
    end
    always @(posedge fram_we_n) if (writing) begin
        if ($time-we_start < 18 || $time-data_changed < 15 || ^write_data===1'bx)
            $fatal(1,"invalid RAM write timing/data");
        ram[write_addr]=write_data; writes=writes+1; writing=0;
    end
    task idle;
        begin gb_rd_n=1; gb_wr_n=1; #30; cpu_drive=0; #50; end
    endtask
    task wr(input [15:0] a, input [7:0] d, input cs);
        begin
            idle(); gb_a=a; gb_cs_n=cs; cpu_data=d; cpu_drive=1;
            #40; gb_wr_n=0; #160;
            if (cpu_bus !== d || gb_d !== d || data_dir !== 0) $fatal(1,"write direction");
            gb_wr_n=1; #30; cpu_drive=0; #50;
        end
    endtask
    task rd(input [15:0] a, input [7:0] expected, input cs);
        begin
            idle(); gb_a=a; gb_cs_n=cs; #40; gb_rd_n=0; #160;
            if (cpu_bus !== expected) $fatal(1,"read %h got %h expected %h bank %d",a,cpu_bus,expected,bank);
            idle();
        end
    endtask
    function [7:0] pattern(input integer address, input integer pass);
        pattern=(address ^ (address>>8) ^ (address>>16)) ^ (pass ? 8'ha5 : 8'h5a);
    endfunction
    initial begin
        for(i=0;i<1048576;i=i+1) rom[i]=(i>>14) ^ i ^ (i>>8);
        for(i=0;i<131072;i=i+1) ram[i]=8'hcc;
        #100; gb_res_n=1;
        rd('h4000,rom['h4000],1);
        rd('ha000,8'hff,0);
        wr('ha000,8'h12,0);
        if (writes!=0) $fatal(1,"disabled RAM modified");
        for(bank=0;bank<512;bank=bank+1) begin
            wr('h2000,bank,1); wr('h3000,bank>>8,1);
            rd('h0000,rom[0],1); rd('h3fff,rom['h3fff],1);
            rd('h4000,rom[(bank%64)*16384],1);
            rd('h7fff,rom[(bank%64)*16384+16383],1);
        end
        wr('h0000,8'h1a,1);
        // Два полных прохода; чтение после записи ВСЕХ банков ловит aliasing.
        for(phase=0;phase<2;phase=phase+1) begin
            for(bank=0;bank<16;bank=bank+1) begin
                wr('h5fff,bank | 8'hf0,1);
                for(i=0;i<8192;i=i+1) wr('ha000+i,pattern(bank*8192+i,phase),0);
            end
            for(bank=0;bank<16;bank=bank+1) begin
                wr('h4000,bank,1);
                for(i=0;i<8192;i=i+1) rd('ha000+i,pattern(bank*8192+i,phase),0);
            end
        end
        wr('h1fff,0,1); wr('ha000,0,0); rd('ha000,8'hff,0);
        wr('h0000,8'h0a,1); rd('ha000,pattern(15*8192,1),0);
        wr('ha000,0,1); rd('ha000,8'hzz,1);
        rd('h8000,8'hzz,0); rd('h9fff,8'hzz,0); rd('hc000,8'hzz,0); rd('hffff,8'hzz,0);
        wr('h6000,0,1); rd('ha000,pattern(15*8192,1),0);
        gb_res_n=0; #100;
        if (!fram_ce_n || !fram_we_n || !flash_ce_n || !data_oe_n) $fatal(1,"reset outputs");
        gb_res_n=1; rd('h4000,rom['h4000],1); rd('ha000,8'hff,0);
        if(writes!=262144) $fatal(1,"unexpected RAM writes %d",writes);
        $display("PASS game_mbc5: 512 bank selections, 64 ROM banks, 2 x 128 KiB RAM, reset/disable/windows/direction");
        $finish;
    end
    always @(*) begin
        if (!flash_ce_n && !fram_ce_n) $fatal(1,"both memories selected");
        if (!flash_we_n) $fatal(1,"Flash write in GAME");
    end
    initial begin #1000000000; $fatal(1,"timeout"); end
endmodule
