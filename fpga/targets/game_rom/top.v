`timescale 1ns/1ps
// 32 KiB ROM ONLY cartridge. Flash must already be in read-array mode.
// Asynchronous path: GB address -> Flash -> GB data, without an OSCH/FSM.
module top (
    input  wire [15:0] gb_a,
    input  wire        gb_rd_n,
    output wire [7:0]  gb_d,
    output wire        data_oe_n,
    output wire        data_dir,
    output wire [21:0] flash_a,
    input  wire [7:0]  flash_d,
    output wire        flash_ce_n,
    output wire        flash_oe_n,
    output wire        flash_we_n
);
    wire rom_read = !gb_a[15] && !gb_rd_n;

    // Same byte-address wiring as programmer: flash_a[0] is Flash A-1.
    assign flash_a = {7'b0, gb_a[14:0]};
    assign flash_we_n = 1'b1;
    assign flash_ce_n = !rom_read;
    assign flash_oe_n = !rom_read;

    // Direction inherited from the tested internal_rom configuration.
    // FPGA drives only the shifter input; its GB-side output is gated by OE#.
    assign data_dir = 1'b1;
    assign data_oe_n = !rom_read;
    assign gb_d = flash_d;
endmodule
