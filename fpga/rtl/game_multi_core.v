`timescale 1ns/1ps
// Общий GAME без генератора и трёхстабильных внутренних шин.
// enable=0 отключает память, сбрасывает маппер/сканер, сохраняет RTC.
module game_multi_core #(parameter integer RTC_CLOCK_HZ=53200000) (
    input wire clk, power_reset, enable,
    input wire [15:0] gb_a,
    input wire gb_rd_n, gb_wr_n, gb_cs_n, gb_res_n,
    input wire [7:0] gb_data_in, memory_data_in,
    output wire [7:0] gb_data_out, memory_data_out,
    output wire gb_data_drive, memory_data_drive,
    output wire data_oe_n, data_dir,
    output wire [21:0] flash_a,
    output wire flash_ce_n, flash_oe_n, flash_we_n,
    output wire fram_ce_n, fram_oe_n, fram_we_n
);
    wire scan_reset=power_reset || !enable || !gb_res_n;
    wire configured, multicart, supported;
    wire [7:0] cart_type, rom_size, ram_size;
    wire [21:0] scan_address, rom_address;
    wire [16:0] ram_address;
    wire ram_access, nibble_ram, rtc_access;
    wire rtc_write_toggle, rtc_latch_toggle;
    wire [2:0] rtc_register, rtc_write_register;
    wire [7:0] rtc_write_data, rtc_data;
    cart_header header(.clk(clk),.reset(scan_reset),.data(memory_data_in),.address(scan_address),
        .done(configured),.cart_type(cart_type),.rom_size(rom_size),.ram_size(ram_size),.multicart(multicart));
    cart_mapper mapper(.configured(configured),.multicart(multicart),.cart_type(cart_type),
        .rom_size(rom_size),.ram_size(ram_size),.gb_a(gb_a),.gb_data(gb_data_in),
        .gb_rd_n(gb_rd_n),.gb_wr_n(gb_wr_n),.gb_cs_n(gb_cs_n),.gb_res_n(gb_res_n && enable),
        .supported(supported),.rom_address(rom_address),.ram_address(ram_address),
        .ram_access(ram_access),.nibble_ram(nibble_ram),.rtc_access(rtc_access),
        .rtc_register(rtc_register),.rtc_write_toggle(rtc_write_toggle),
        .rtc_latch_toggle(rtc_latch_toggle),.rtc_write_register(rtc_write_register),.rtc_write_data(rtc_write_data));
    mbc_rtc #(.CLOCK_HZ(RTC_CLOCK_HZ)) rtc(.clk(clk),.reset(power_reset),
        .write_toggle(rtc_write_toggle),.latch_toggle(rtc_latch_toggle),
        .write_register(rtc_write_register),.write_data(rtc_write_data),
        .read_register(rtc_register),.read_data(rtc_data));
    wire running=configured && gb_res_n && enable && !power_reset;
    wire scanning=!configured && !scan_reset;
    wire ram_window=gb_a[15:13]==3'b101 && !gb_cs_n;
    wire reading=running && !gb_rd_n && gb_wr_n;
    wire rom_read=reading && !gb_a[15];
    wire ram_read=reading && ram_window;
    wire ram_write=running && gb_rd_n && !gb_wr_n && ram_window && ram_access;
    wire drive_gb=rom_read || ram_read;
    assign flash_a=!configured ? scan_address : ram_window ? {5'b0,ram_address} : rom_address;
    assign flash_ce_n=!(scanning || (rom_read && supported));
    assign flash_oe_n=flash_ce_n;
    assign flash_we_n=1'b1;
    assign fram_ce_n=!((ram_read && ram_access) || ram_write);
    assign fram_oe_n=!(ram_read && ram_access);
    assign fram_we_n=!ram_write;
    assign memory_data_out=nibble_ram ? {4'hf,gb_data_in[3:0]} : gb_data_in;
    assign memory_data_drive=ram_write;
    wire [7:0] ram_data=rtc_access ? rtc_data : !ram_access ? 8'hff :
                         nibble_ram ? {4'hf,memory_data_in[3:0]} : memory_data_in;
    assign gb_data_out=ram_read ? ram_data : supported ? memory_data_in : 8'hff;
    assign gb_data_drive=drive_gb;
    assign data_dir=drive_gb;
    // Приём включён между обращениями для hold регистров на фронте WR#.
    assign data_oe_n=!running;
endmodule
