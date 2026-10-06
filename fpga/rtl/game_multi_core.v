`timescale 1ns/1ps

// Общий GAME: сканер заголовка, маппер, RTC и асинхронный доступ к памяти.
// enable=0 отключает память и сбрасывает сканер/маппер, сохраняя RTC.
// Двунаправленные выводы и генератор clk остаются в target.
module game_multi_core #(
    parameter integer RTC_CLOCK_HZ = 53200000
) (
    input wire clk,
    input wire power_reset,
    input wire enable,
    input wire [15:0] gb_a,
    input wire gb_rd_n,
    input wire gb_wr_n,
    input wire gb_cs_n,
    input wire gb_res_n,
    input wire [7:0] gb_data_in,
    input wire [7:0] memory_data_in,
    output wire [7:0] gb_data_out,
    output wire [7:0] memory_data_out,
    output wire gb_data_drive,
    output wire memory_data_drive,
    output wire data_oe_n,
    output wire data_dir,
    output wire [21:0] flash_a,
    output wire flash_ce_n,
    output wire flash_oe_n,
    output wire flash_we_n,
    output wire fram_ce_n,
    output wire fram_oe_n,
    output wire fram_we_n,
    output wire bus_idle
);
    // Немедленное отключение шины и синхронный выход сканера из RESET.
    wire reset_request = power_reset || !enable || !gb_res_n;
    (* syn_preserve = 1 *) reg [1:0] reset_release = 0;
    always @(posedge clk or posedge reset_request) begin
        if (reset_request)
            reset_release <= 0;
        else
            reset_release <= {reset_release[0], 1'b1};
    end
    wire scan_reset = !reset_release[1];

    wire configured, multicart, supported, config_ready;
    wire [7:0] cart_type, rom_size, ram_size;
    wire [21:0] scan_address, rom_address;
    wire [16:0] ram_address;
    wire ram_access, nibble_ram, rtc_access;
    wire rtc_write_toggle, rtc_latch_toggle;
    wire [2:0] rtc_register, rtc_write_register;
    wire [7:0] rtc_write_data, rtc_data;

    cart_header header (
        .clk(clk),
        .reset(scan_reset),
        .data(memory_data_in),
        .address(scan_address),
        .done(configured),
        .cart_type(cart_type),
        .rom_size(rom_size),
        .ram_size(ram_size),
        .multicart(multicart)
    );

    cart_mapper mapper (
        .clk(clk),
        .configured(configured),
        .multicart(multicart),
        .cart_type(cart_type),
        .rom_size(rom_size),
        .ram_size(ram_size),
        .gb_a(gb_a),
        .gb_data(gb_data_in),
        .gb_rd_n(gb_rd_n),
        .gb_wr_n(gb_wr_n),
        .gb_cs_n(gb_cs_n),
        .gb_res_n(!reset_request),
        .supported(supported),
        .config_ready(config_ready),
        .rom_address(rom_address),
        .ram_address(ram_address),
        .ram_access(ram_access),
        .nibble_ram(nibble_ram),
        .rtc_access(rtc_access),
        .rtc_register(rtc_register),
        .rtc_write_toggle(rtc_write_toggle),
        .rtc_latch_toggle(rtc_latch_toggle),
        .rtc_write_register(rtc_write_register),
        .rtc_write_data(rtc_write_data)
    );

    mbc_rtc #(
        .CLOCK_HZ(RTC_CLOCK_HZ),
        .SAME_CLOCK(1)
    ) rtc (
        .clk(clk),
        .reset(power_reset),
        .write_toggle(rtc_write_toggle),
        .latch_toggle(rtc_latch_toggle),
        .write_register(rtc_write_register),
        .write_data(rtc_write_data),
        .read_register(rtc_register),
        .read_data(rtc_data)
    );

    // Передача памяти Game Boy разрешается только после декодирования заголовка.
    wire running = configured && config_ready && !scan_reset && !reset_request;
    wire scanning = !configured && !scan_reset;

    // Адрес F-RAM выбирается до /CS и сохраняется при его отпускании.
    wire ram_addr_window = gb_a[15:13] == 3'b101;
    wire ram_window = ram_addr_window && !gb_cs_n;
    wire reading = running && !gb_rd_n && gb_wr_n;
    wire rom_read = reading && !gb_a[15];
    wire ram_read = reading && ram_window;
    wire ram_write = running && gb_rd_n && !gb_wr_n && ram_window && ram_access;
    wire drive_gb = rom_read || ram_read;

    // Консервативная проверка: декодирование маппера не входит в путь смены режима.
    assign bus_idle = !scanning && (!running || (gb_rd_n && gb_wr_n));

    // Общая адресная шина и независимые разрешения Flash/F-RAM.
    assign flash_a = !configured ? scan_address :
                    ram_addr_window ? {5'b0, ram_address} : rom_address;
    assign flash_ce_n = !(scanning || (rom_read && supported));
    assign flash_oe_n = flash_ce_n;
    assign flash_we_n = 1'b1;
    assign fram_ce_n = !((ram_read && ram_access) || ram_write);
    assign fram_oe_n = !(ram_read && ram_access);
    assign fram_we_n = !ram_write;

    assign memory_data_out = nibble_ram ? {4'hf, gb_data_in[3:0]} : gb_data_in;
    assign memory_data_drive = ram_write;

    // RTC и отключённая RAM отвечают без доступа к физической F-RAM.
    wire [7:0] ram_data = rtc_access ? rtc_data :
                          !ram_access ? 8'hff :
                          nibble_ram ? {4'hf, memory_data_in[3:0]} : memory_data_in;
    assign gb_data_out = ram_read ? ram_data : supported ? memory_data_in : 8'hff;
    assign gb_data_drive = drive_gb;
    assign data_dir = drive_gb;

    // Приём данных остаётся включённым между обращениями для удержания после /WR.
    assign data_oe_n = !running;
endmodule
