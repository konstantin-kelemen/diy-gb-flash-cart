`timescale 1ns/1ps
module spi_bringup_tb;
    reg spi_cs_n=1, spi_sck=0, spi_mosi=0;
    wire spi_miso, flash_ce_n, flash_oe_n, flash_we_n, spi_ready, spi_seen;
    wire [21:0] flash_a;
    wire [7:0] flash_d;
    top dut (.*);
    reg [7:0] rx;
    reg [63:0] expected = 64'h4742464301000000;
    integer n, k;
    task start_frame;
        #23017; spi_cs_n=0; #21013;
    endtask
    task end_frame;
        #21019; spi_cs_n=1; #21023;
        if (spi_miso !== 1'bz) $fatal(1,"MISO not released");
    endtask
    task exchange(input [7:0] tx, output [7:0] result);
        for (integer b=7;b>=0;b=b-1) begin
            spi_mosi=tx[b]; #50003;
            spi_sck=1; #1; result[b]=spi_miso; #50008;
            spi_sck=0;
        end
    endtask
    task version_frame;
        start_frame;
        exchange(8'h01,rx);
        if(rx !== 0) $fatal(1,"Command dummy byte");
        for(integer j=0;j<8;j=j+1) begin
            exchange(0,rx);
            if(rx !== expected[63-j*8 -: 8]) $fatal(1,"Version byte %0d = %h",j,rx);
        end
        end_frame;
        if(spi_seen !== 1) $fatal(1,"Missing complete frame indication");
    endtask
    initial begin
        #30000;
        if(spi_ready !== 1 || spi_seen !== 0) $fatal(1,"Startup");
        // Every partial frame length, including a partial opcode and response.
        for(n=1;n<72;n=n+1) begin
            start_frame;
            for(k=0;k<n;k=k+1) begin
                spi_mosi=(k==7); #50003; spi_sck=1; #50009; spi_sck=0;
            end
            end_frame;
            if(n==1 && spi_seen !== 0) $fatal(1,"Partial frame marked complete");
            version_frame;
        end
        // Unknown command and more than 128 clocks: counter must not wrap.
        start_frame;
        exchange(8'hff,rx);
        repeat(24) begin
            exchange(8'h01,rx);
            if(rx !== 0) $fatal(1,"Unknown command/extra clocks");
        end
        end_frame;
        version_frame;
        start_frame;
        exchange(1,rx);
        repeat(8) exchange(0,rx);
        repeat(24) begin
            exchange(1,rx);
            if(rx !== 0) $fatal(1,"Extra bytes after version");
        end
        end_frame;
        repeat(10) version_frame;
        $display("PASS: SPI startup, version, 71 abort lengths, unknown command, extra clocks, recovery");
        $finish;
    end
    always @(flash_ce_n or flash_oe_n or flash_we_n or flash_d or flash_a) begin
        #1;
        if({flash_ce_n,flash_oe_n,flash_we_n} !== 3'b111 || flash_d !== 8'bz || flash_a !== 0)
            $fatal(1,"Flash not inactive");
    end
    initial begin #2000000000; $fatal(1,"Timeout"); end
endmodule
`ifndef NETLIST
module OSCH(input STDBY, output reg OSC=0, output SEDSTDBY);
    parameter NOM_FREQ="2.08";
    always #240.385 OSC=~OSC;
    assign SEDSTDBY=0;
endmodule
module FD1S3AX(input D, CK, output reg Q=0);
    always @(posedge CK) Q<=D;
endmodule
`endif
