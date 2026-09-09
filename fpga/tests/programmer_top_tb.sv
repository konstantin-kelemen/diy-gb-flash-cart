`timescale 1ns/1ps
// Функциональные модели примитивов; не заменяют netlist Diamond.
module OSCH(input STDBY, output reg OSC=0, output SEDSTDBY);
    parameter NOM_FREQ="53.20";
    always #9.4 OSC=~OSC;
    assign SEDSTDBY=STDBY;
endmodule
module FD1S3AX(input D, CK, output reg Q=0);
    always @(posedge CK) Q<=D;
endmodule
module programmer_top_tb;
    reg spi_cs_n=1, spi_sck=0, spi_mosi=0;
    wire spi_miso;
    wire [21:0] flash_a;
    tri [7:0] flash_d;
    wire flash_ce_n, flash_oe_n, flash_we_n;
    wire fram_ce_n, fram_oe_n, fram_we_n;
    top dut(.*);
    integer i;
    always @(fram_ce_n or fram_oe_n or fram_we_n) begin
        #1;
        if ({fram_ce_n,fram_oe_n,fram_we_n} !== 3'b111)
            $fatal(1,"F-RAM not isolated");
    end
    initial begin
        #100;
        // Повреждённый SPI-кадр и переходы CS не должны выбирать F-RAM.
        spi_cs_n=0;
        for(i=0;i<128;i=i+1) begin
            spi_mosi=i; #125; spi_sck=1; #125; spi_sck=0;
        end
        spi_cs_n=1; #1000;
        if ({fram_ce_n,fram_oe_n,fram_we_n} !== 3'b111) $fatal(1,"F-RAM isolation");
        $display("PASS programmer_top: F-RAM disabled at startup and during SPI"); $finish;
    end
endmodule
