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
    wire scan_reset=power_reset || !gb_res_n;
    wire configured, multicart, supported;
    wire [7:0] cart_type, rom_size, ram_size;
    wire [21:0] scan_address, rom_address;
    wire [16:0] ram_address;
    wire ram_access, nibble_ram, rtc_access;
    wire rtc_write_toggle, rtc_latch_toggle;
    wire [2:0] rtc_register, rtc_write_register;
    wire [7:0] rtc_write_data, rtc_data;
    cart_header header(.clk(clk),.reset(scan_reset),.data(flash_d),.address(scan_address),
        .done(configured),.cart_type(cart_type),.rom_size(rom_size),.ram_size(ram_size),.multicart(multicart));
    cart_mapper mapper(.configured(configured),.multicart(multicart),.cart_type(cart_type),
        .rom_size(rom_size),.ram_size(ram_size),.gb_a(gb_a),.gb_data(gb_d),
        .gb_rd_n(gb_rd_n),.gb_wr_n(gb_wr_n),.gb_cs_n(gb_cs_n),.gb_res_n(gb_res_n),
        .supported(supported),.rom_address(rom_address),.ram_address(ram_address),
        .ram_access(ram_access),.nibble_ram(nibble_ram),.rtc_access(rtc_access),
        .rtc_register(rtc_register),.rtc_write_toggle(rtc_write_toggle),
        .rtc_latch_toggle(rtc_latch_toggle),.rtc_write_register(rtc_write_register),.rtc_write_data(rtc_write_data));
    mbc_rtc #(.CLOCK_HZ(RTC_CLOCK_HZ)) rtc(.clk(clk),.reset(power_reset),
        .write_toggle(rtc_write_toggle),.latch_toggle(rtc_latch_toggle),
        .write_register(rtc_write_register),.write_data(rtc_write_data),
        .read_register(rtc_register),.read_data(rtc_data));
    wire running=configured && gb_res_n && !power_reset;
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
    assign flash_d=ram_write ? (nibble_ram ? {4'hf,gb_d[3:0]} : gb_d) : 8'hzz;
    wire [7:0] ram_data=rtc_access ? rtc_data : !ram_access ? 8'hff :
                         nibble_ram ? {4'hf,flash_d[3:0]} : flash_d;
    assign gb_d=drive_gb ? (ram_read ? ram_data : supported ? flash_d : 8'hff) : 8'hzz;
    assign data_dir=drive_gb;
    // Приём включён между обращениями для hold регистров на фронте WR#.
    assign data_oe_n=!running;
endmodule
