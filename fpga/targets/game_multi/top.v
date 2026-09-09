`timescale 1ns/1ps
// Универсальный GAME. Flash должна быть в read-array; SPI не используется.
// Аппаратные ограничения: Flash 4 МиБ, F-RAM 128 КиБ, без мотора/датчиков.
// RTC от OSCH приблизительный и не работает без питания.
module top #(parameter integer RTC_CLOCK_HZ=53200000) (
    input wire [15:0] gb_a,
    input wire gb_rd_n, gb_wr_n, gb_cs_n, gb_res_n,
    inout wire [7:0] gb_d,
    output wire data_oe_n, data_dir,
    output wire [21:0] flash_a,
    inout wire [7:0] flash_d,
    output wire flash_ce_n, flash_oe_n, flash_we_n,
    output wire fram_ce_n, fram_oe_n, fram_we_n
);
    wire clk;
    OSCH osc(.STDBY(1'b0),.OSC(clk),.SEDSTDBY());
    defparam osc.NOM_FREQ="53.20";
    wire [3:0] ready;
    FD1S3AX r0(.D(1'b1),.CK(clk),.Q(ready[0]));
    FD1S3AX r1(.D(ready[0]),.CK(clk),.Q(ready[1]));
    FD1S3AX r2(.D(ready[1]),.CK(clk),.Q(ready[2]));
    FD1S3AX r3(.D(ready[2]),.CK(clk),.Q(ready[3]));
    wire power_reset=!ready[3];
    wire [7:0] gb_out, memory_out;
    wire gb_drive, memory_drive;
    assign gb_d=gb_drive ? gb_out : 8'hzz;
    assign flash_d=memory_drive ? memory_out : 8'hzz;
    game_multi_core #(.RTC_CLOCK_HZ(RTC_CLOCK_HZ)) game(
        .clk(clk),.power_reset(power_reset),.enable(1'b1),
        .gb_a(gb_a),.gb_rd_n(gb_rd_n),.gb_wr_n(gb_wr_n),.gb_cs_n(gb_cs_n),.gb_res_n(gb_res_n),
        .gb_data_in(gb_d),.memory_data_in(flash_d),.gb_data_out(gb_out),.memory_data_out(memory_out),
        .gb_data_drive(gb_drive),.memory_data_drive(memory_drive),.data_oe_n(data_oe_n),.data_dir(data_dir),
        .flash_a(flash_a),.flash_ce_n(flash_ce_n),.flash_oe_n(flash_oe_n),.flash_we_n(flash_we_n),
        .fram_ce_n(fram_ce_n),.fram_oe_n(fram_oe_n),.fram_we_n(fram_we_n));
endmodule
