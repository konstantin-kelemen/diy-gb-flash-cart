`timescale 1ns/1ps
module game_programmer_tb;
    localparam real CLOCK_HALF=9.4;
    reg clk=0, reset=1;
    always #(CLOCK_HALF) clk=~clk;
    reg cs=1, sck=0, mosi=0;
    wire miso, start, busy, done;
    wire [7:0] command, data, op_status;
    wire [21:0] address, fa;
    wire [15:0] result;
    tri [7:0] fd;
    wire ce, oe, we;
    reg gb_power_present=0;
    reg [15:0] gb_a=0;
    reg gb_rd_n=1, gb_wr_n=1, gb_cs_n=1, gb_res_n=0;
    tri [7:0] gb_d, cpu_bus;
    reg cpu_drive=0;
    reg [7:0] cpu_data=0;
    wire data_oe_n, data_dir, fram_ce_n, fram_oe_n, fram_we_n;
    top #(.DETECT_TICKS(16),.POWER_CYCLES(20),.PROGRAM_CYCLES(2000),.ERASE_CYCLES(6000)) dut(
        .gb_power_present(gb_power_present),.gb_a(gb_a),.gb_rd_n(gb_rd_n),.gb_wr_n(gb_wr_n),
        .gb_cs_n(gb_cs_n),.gb_res_n(gb_res_n),.gb_d(gb_d),.data_oe_n(data_oe_n),.data_dir(data_dir),
        .spi_cs_n(cs),.spi_sck(sck),.spi_mosi(mosi),.spi_miso(miso),
        .flash_a(fa),.flash_d(fd),.flash_ce_n(ce),.flash_oe_n(oe),.flash_we_n(we),
        .fram_ce_n(fram_ce_n),.fram_oe_n(fram_oe_n),.fram_we_n(fram_we_n));
    assign cpu_bus=cpu_drive ? cpu_data : 8'hzz;
    assign #(5,5,5) gb_d=!data_oe_n && !data_dir ? cpu_bus : 8'hzz;
    assign #(5,5,5) cpu_bus=!data_oe_n && data_dir ? gb_d : 8'hzz;
    reg [7:0] ram[0:131071];
    assign #(90,90,10) fd=!fram_ce_n && !fram_oe_n && fram_we_n ? ram[fa[16:0]] : 8'hzz;
    reg ram_writing=0;
    reg [16:0] ram_address;
    reg [7:0] ram_data;
    integer ram_writes=0;
    always @(negedge fram_we_n) ram_writing=1;
    always @(fa or fd or ram_writing) if(ram_writing) begin ram_address=fa[16:0]; ram_data=fd; end
    always @(posedge fram_we_n) if(ram_writing) begin
        if(^ram_data===1'bx) $fatal(1,"invalid RAM write");
        ram[ram_address]=ram_data; ram_writes=ram_writes+1; ram_writing=0;
    end
    task game_write(input [15:0] a,input [7:0] d);
        begin gb_a=a; gb_cs_n=!(a>='ha000 && a<='hbfff); cpu_data=d; cpu_drive=1;
            #40; gb_wr_n=0; #160; gb_wr_n=1; #30; cpu_drive=0; #80;
        end
    endtask
    task game_read(input [15:0] a,input [7:0] d);
        begin gb_a=a; gb_cs_n=!(a>='ha000 && a<='hbfff); #40; gb_rd_n=0; #160;
            if(cpu_bus!==d) $fatal(1,"GAME read %h got %h expected %h",a,cpu_bus,d);
            gb_rd_n=1; #100;
        end
    endtask
    always @(posedge clk) if(!reset) begin
        if(dut.game_enable && dut.programmer_enable) $fatal(1,"two bus owners");
        if(dut.game_enable && !we) $fatal(1,"Flash write in GAME");
        if(dut.programmer_enable && (!data_oe_n || !fram_ce_n || !fram_oe_n || !fram_we_n)) $fatal(1,"programmer isolation");
        if(!dut.game_enable && !dut.programmer_enable && (!ce || !oe || !we || !fram_ce_n || !fram_we_n)) $fatal(1,"handover isolation");
        if(!ce && !fram_ce_n) $fatal(1,"both memories selected");
    end

    // Behavioral x8 command model. Checks physical write edges and unlock addresses.
    reg [7:0] memory [0:4194303];
    integer model_state=0, writes=0, i;
    reg id_mode=0;
    reg [1:0] fault=0;
    reg fault_active=0;
    reg expected_bit=0;
    wire [7:0] read_data = id_mode ? (fa==0 ? 8'hc2 : fa==2 ? 8'ha8 : 8'hff) :
        fault_active ? {~expected_bit, 1'b0, (fault==1 || fault==3), 5'b0} : memory[fa];
    assign #(70,70,30) fd = !ce && !oe && we ? read_data : 8'bz;
    // Completion racing with Q5: the mandatory second Q7 read must accept success.
    always @(posedge oe) if (!reset && fault==3) fault_active=0;
    always @(negedge we) if (!reset) begin
        if (ce || !oe || ^fd === 1'bx) $fatal(1, "unsafe write bus");
    end
    always @(posedge we) if (!reset && !ce) begin
        writes=writes+1;
        if (model_state==3) begin
            if (fault != 0) begin
                fault_active=1; expected_bit=fd[7];
                if (fault==3) memory[fa]=memory[fa] & fd;
            end
            else memory[fa]=memory[fa] & fd;
            model_state=0;
        end else if (fd==8'hf0) begin model_state=0; id_mode=0; fault_active=0; end
        else case (model_state)
            0: begin
                if (fa!=22'haaa || fd!=8'haa) $fatal(1, "unlock1");
                model_state=1;
            end
            1: begin
                if (fa!=22'h555 || fd!=8'h55) $fatal(1, "unlock2");
                model_state=2;
            end
            2: begin
                if (fa!=22'haaa) $fatal(1, "command address");
                case (fd)
                    8'ha0: model_state=3;
                    8'h80: model_state=4;
                    8'h90: begin id_mode=1; model_state=0; end
                    default: $fatal(1, "command data");
                endcase
            end
            4: begin
                if (fa!=22'haaa || fd!=8'haa) $fatal(1, "erase unlock1");
                model_state=5;
            end
            5: begin
                if (fa!=22'h555 || fd!=8'h55) $fatal(1, "erase unlock2");
                model_state=6;
            end
            6: begin
                if (fd!=8'h30) $fatal(1, "erase command");
                if (fault != 0) begin fault_active=1; expected_bit=1; end
                else if (fa<65536)
                    for (i=(fa/8192)*8192; i<(fa/8192)*8192+8192; i=i+1) memory[i]=8'hff;
                else
                    for (i=(fa/65536)*65536; i<(fa/65536)*65536+65536; i=i+1) memory[i]=8'hff;
                model_state=0;
            end
        endcase
    end
    function [15:0] crc_byte;
        input [15:0] c0; input [7:0] b;
        reg [15:0] c; integer k;
        begin c=c0^{b,8'b0}; for(k=0;k<8;k=k+1) c=(c<<1)^(c[15] ? 16'h1021:16'h0); crc_byte=c; end
    endfunction
    reg [7:0] tx[0:1033], rx[0:1033];
    reg [7:0] seq=0;
    integer n, j, before_writes;
    realtime write_edge, read_edge;
    always @(negedge we) write_edge=$realtime;
    always @(posedge we) if(!reset && !ce && $realtime-write_edge<35)
        $fatal(1,"WE pulse shorter than 35 ns");
    always @(negedge oe) read_edge=$realtime;
    always @(posedge clk) if(!reset && dut.programmer.bus.state==8 && dut.programmer.bus.advance &&
        $realtime-read_edge<70) $fatal(1,"Flash sampled before 70 ns");
    reg [15:0] crc;
    task byte_transfer;
        input [7:0] value; output [7:0] out;
        integer b;
        begin
            for(b=7;b>=0;b=b-1) begin
                mosi=value[b]; #125; sck=1; #1; out[b]=miso; #124; sck=0;
            end
        end
    endtask
    task request_frame;
        input [7:0] op; input [23:0] addr; input integer count;
        input [7:0] key; input integer extra; input corrupt;
        integer k, size; reg [7:0] ignored;
        begin
            seq=seq+1;
            tx[0]=op; tx[1]=seq; tx[2]=addr[23:16]; tx[3]=addr[15:8]; tx[4]=addr[7:0];
            tx[5]=count>>8; tx[6]=count; tx[7]=key;
            size=8+(op==8'h31 ? count:0); crc=16'hffff;
            for(k=0;k<size;k=k+1) crc=crc_byte(crc,tx[k]);
            tx[size]=crc[15:8]; tx[size+1]=crc[7:0]^{7'b0,corrupt};
            cs=0; #2000;
            for(k=0;k<size+2+extra;k=k+1) byte_transfer(tx[k],ignored);
            #2000; cs=1; #2000;
            if(miso!==1'bz) $fatal(1,"MISO not released");
        end
    endtask
    // Reuse tx from an incomplete request, ending on either side of its CRC.
    task malformed_bits;
        input integer count;
        integer bit_index;
        begin
            cs=0; #2000;
            for(bit_index=0;bit_index<count;bit_index=bit_index+1) begin
                mosi=tx[bit_index/8][7-(bit_index%8)];
                #125; sck=1; #125; sck=0;
            end
            #2000; cs=1; #2000;
        end
    endtask
    task query;
        input [7:0] op; input integer count;
        integer k; reg [7:0] ignored;
        begin
            cs=0; #2000; byte_transfer(op,ignored);
            for(k=0;k<count;k=k+1) byte_transfer(0,rx[k]);
            #2000; cs=1; #2000;
        end
    endtask
    task finish_op;
        input [7:0] op, expected;
        integer polls;
        begin
            query(2,10); polls=0;
            while(rx[2]==1 && polls<2000) begin #2000; query(2,10); polls=polls+1; end
            crc=16'hffff;
            for(integer k=0;k<8;k=k+1) crc=crc_byte(crc,rx[k]);
            if({rx[8],rx[9]}!==crc) $fatal(1,"status CRC %h%h != %h",rx[8],rx[9],crc);
            if(rx[0]!==8'h50 || rx[1]!==seq || rx[2]!==expected || rx[3]!==op)
                $fatal(1,"status seq=%h/%h status=%h/%h op=%h/%h",rx[1],seq,rx[2],expected,rx[3],op);
        end
    endtask
    initial begin
        for(n=0;n<4194304;n=n+1) memory[n]=(n^(n>>8)^(n>>16))&255;
        #5000; reset=0; #50000;
        query(1,8);
        if({rx[0],rx[1],rx[2],rx[3],rx[4],rx[5],rx[6],rx[7]}!==64'h4742464303000004)
            $fatal(1,"version");
        before_writes=writes;
        // Unaligned full block, crosses byte and address boundaries.
        request_frame(8'h30,24'h00ff80,1024,0,0,0); finish_op(8'h30,0);
        if({rx[7],rx[6]}!==16'd1024) $fatal(1,"read count");
        query(3,1026); crc=16'hffff;
        for(n=0;n<1024;n=n+1) begin
            if(rx[n]!==memory[24'h00ff80+n]) $fatal(1,"read byte %d: %h",n,rx[n]);
            crc=crc_byte(crc,rx[n]);
        end
        if({rx[1024],rx[1025]}!==crc || writes!=before_writes) $fatal(1,"read CRC/writes");
        request_frame(8'h30,24'h3fffff,1,0,0,0); finish_op(8'h30,0);
        query(3,3); if(rx[0]!==memory[22'h3fffff]) $fatal(1,"last address");
        request_frame(8'h30,24'h3fffff,2,0,0,0); finish_op(8'h30,8);
        request_frame(8'h30,0,0,0,0,0); finish_op(8'h30,8);
        request_frame(8'h30,0,1025,0,0,0); finish_op(8'h30,8);
        request_frame(8'h31,0,1,0,0,0); finish_op(8'h31,9);
        request_frame(8'h20,0,0,8'ha5,0,0); finish_op(8'h20,0);
        request_frame(8'h13,0,0,0,0,0); finish_op(8'h13,0);
        if({rx[5],rx[4]}!==16'ha8c2 || id_mode) $fatal(1,"ID");
        request_frame(8'h12,0,0,0,0,0); finish_op(8'h12,0);
        for(n=0;n<1024;n=n+1) tx[8+n]=n&255;
        request_frame(8'h31,24'h000100,1024,0,0,0); finish_op(8'h31,0);
        for(n=0;n<1024;n=n+1)
            if(memory[256+n]!== (n&255)) $fatal(1,"program byte %d",n);
        if(memory[255]!==8'hff || memory[1280]!==8'hff) $fatal(1,"write boundary");
        before_writes=writes;
        request_frame(8'h31,24'h002000,3,0,0,1); finish_op(8'h31,7);
        request_frame(8'h31,24'h002000,3,0,0,0); finish_op(8'h31,9);
        request_frame(8'h20,0,0,8'ha5,0,0); finish_op(8'h20,0);
        request_frame(8'h31,24'h002000,3,0,-1,0);
        malformed_bits(13*8-1);
        malformed_bits(13*8+1);
        request_frame(8'h31,24'h002000,3,0,1,0);
        if(writes!=before_writes) $fatal(1,"bad framing wrote Flash");
        fault=1; tx[8]=8'ha5;
        request_frame(8'h31,24'h002000,1,0,0,0); finish_op(8'h31,4);
        request_frame(8'h31,24'h002000,1,0,0,0); finish_op(8'h31,9);
        fault=0;
        request_frame(8'h20,0,0,8'ha5,0,0); finish_op(8'h20,0);
        seq=seq-1;
        request_frame(8'h12,0,0,0,0,0); finish_op(8'h12,10);
        request_frame(8'h20,0,0,8'ha5,0,0); finish_op(8'h20,0);
        fault=2; tx[8]=8'ha5;
        request_frame(8'h31,24'h002000,1,0,0,0);
        // Frame beginning while busy must not commit even if busy clears mid-frame.
        request_frame(8'h12,0,0,0,0,0);
        seq=seq-1; finish_op(8'h31,3);
        fault=0;
        request_frame(8'h21,0,0,0,0,0); finish_op(8'h21,0);
        // Короткий импульс детектора не переключает режим.
        gb_power_present=1; #60; gb_power_present=0; #1000;
        if(!dut.programmer_enable) $fatal(1,"detector glitch switched mode");
        request_frame(8'h20,0,0,8'ha5,0,0); finish_op(8'h20,0);
        memory['h147]='h1b; memory['h148]=5; memory['h149]=4;
        memory['h4000]='h72;
        for(n=0;n<64;n=n+1) begin memory['h3000+n]='hff; tx[8+n]=n+32; end
        request_frame(8'h31,24'h003000,64,0,0,0);
        if(!dut.active) $fatal(1,"expected active block");
        gb_power_present=1; gb_res_n=1;
        // Питание Game Boy появилось во время записи: закончить весь блок.
        wait(dut.game_enable); wait(dut.game.configured); #1000;
        for(n=0;n<64;n=n+1) if(memory['h3000+n]!==n+32) $fatal(1,"block interrupted %d",n);
        if(id_mode || model_state!=0) $fatal(1,"Flash not in read-array");
        game_read('h4000,'h72); game_write(0,'ha); game_write('h4000,15);
        game_write('hbfff,'h9a); game_read('hbfff,'h9a);
        before_writes=writes;
        request_frame(8'h20,0,0,8'ha5,0,0);
        request_frame(8'h12,0,0,0,0,0);
        if(writes!=before_writes) $fatal(1,"SPI mutated Flash in GAME");
        // Уход из GAME ждёт окончания текущего чтения.
        gb_a='h4000; gb_cs_n=1; gb_rd_n=0; #200; gb_power_present=0; #1000;
        if(!dut.game_enable) $fatal(1,"GAME read interrupted");
        gb_rd_n=1; gb_res_n=0; wait(dut.programmer_enable); #1000; seq=0;
        if(ram_writes!=1) $fatal(1,"unexpected RAM writes");
        query(1,8); if(rx[4]!==3) $fatal(1,"programmer not restored");
        request_frame(8'h20,0,0,8'ha5,0,0); finish_op(8'h20,0);
        before_writes=writes;
        // Появление питания посреди SPI-кадра запрещает его commit.
        fork
            request_frame(8'h12,0,0,0,0,0);
            begin #5000; gb_power_present=1; gb_res_n=1; end
        join
        wait(dut.game_enable); wait(dut.game.configured); #1000;
        if(writes!=before_writes+1) $fatal(1,"in-flight SPI accepted (only cleanup F0 expected)");
        if(memory['h147]!==8'h1b) $fatal(1,"ROM erased on switch");
        game_write(0,'ha); game_write('h4000,15); game_read('hbfff,'h9a);
        $display("PASS game_programmer: v3 regression, GAME/FRAM, power detection, drain block, read-array, SPI rejection, bus isolation");
        $finish;
    end
    initial begin #200000000; $fatal(1,"timeout"); end
endmodule

module OSCH(input STDBY, output reg OSC=0, output SEDSTDBY);
    parameter NOM_FREQ="53.20";
    always #9.4 OSC=~OSC;
    assign SEDSTDBY=STDBY;
endmodule
module FD1S3AX(input D, CK, output reg Q=0);
    always @(posedge CK) Q<=D;
endmodule
