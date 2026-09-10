`timescale 1ns/1ps
// Автовыбор по отдельному сигналу питания Game Boy.
// Питание Game Boy отсутствует: PROGRAMMER v3. Присутствует: GAME multi.
// Новый режим не прерывает принятую операцию Flash; CPU на время PROGRAMMER
// отключён от шины. Включать Game Boy следует после завершения записи ROM.
module top #(
    parameter integer DETECT_TICKS=106400,
    parameter HOST_BLOCKS=1,
    parameter integer POWER_CYCLES=16000000,
    parameter integer PROGRAM_CYCLES=128000,
    parameter integer ERASE_CYCLES=192000000,
    parameter integer RTC_CLOCK_HZ=53200000
) (
    input wire gb_power_present,
    input wire [15:0] gb_a,
    input wire gb_rd_n, gb_wr_n, gb_cs_n, gb_res_n,
    inout wire [7:0] gb_d,
    output wire data_oe_n, data_dir,
    input wire spi_cs_n, spi_sck, spi_mosi,
    output wire spi_miso,
    output wire [21:0] flash_a,
    inout wire [7:0] flash_d,
    output wire flash_ce_n, flash_oe_n, flash_we_n,
    output wire fram_ce_n, fram_oe_n, fram_we_n
);
    wire clk, game_bus_idle;
    // Game Boy reset is local to its mapper, never a reset of the whole FPGA.
    GSR global_reset(.GSR(1'b1));
    OSCH osc(.STDBY(1'b0),.OSC(clk),.SEDSTDBY());
    defparam osc.NOM_FREQ="53.20";
    wire [3:0] ready;
    FD1S3AX r0(.D(1'b1),.CK(clk),.Q(ready[0]));
    FD1S3AX r1(.D(ready[0]),.CK(clk),.Q(ready[1]));
    FD1S3AX r2(.D(ready[1]),.CK(clk),.Q(ready[2]));
    FD1S3AX r3(.D(ready[2]),.CK(clk),.Q(ready[3]));
    wire reset=!ready[3];
    wire game_enable, programmer_enable, accept_requests, cleanup, cleanup_start, mode_fault;
    wire active, busy, done, start;
    wire [7:0] command, data, status;
    wire [21:0] address;
    wire [15:0] result;
    wire [21:0] game_address, programmer_address;
    wire [7:0] game_gb_data, game_memory_data, programmer_memory_data;
    wire game_gb_drive, game_memory_drive, programmer_memory_drive;
    wire game_data_oe_n, game_data_dir;
    wire game_ce_n, game_oe_n, game_we_n, game_ram_ce_n, game_ram_oe_n, game_ram_we_n;
    wire programmer_ce_n, programmer_oe_n, programmer_we_n;
    cart_mode #(.DETECT_TICKS(DETECT_TICKS)) mode(
        .clk(clk),.reset(reset),.game_present(gb_power_present),
        .game_idle(game_bus_idle),
        .programmer_active(active),.flash_busy(busy),.flash_done(done),.flash_status(status),
        .game_enable(game_enable),.programmer_enable(programmer_enable),.accept_requests(accept_requests),
        .cleanup_start(cleanup_start),.cleanup(cleanup),.fault(mode_fault));
    game_multi_core #(.RTC_CLOCK_HZ(RTC_CLOCK_HZ)) game(
        .clk(clk),.power_reset(reset),.enable(game_enable),
        .gb_a(gb_a),.gb_rd_n(gb_rd_n),.gb_wr_n(gb_wr_n),.gb_cs_n(gb_cs_n),.gb_res_n(gb_res_n),
        .gb_data_in(gb_d),.memory_data_in(flash_d),.gb_data_out(game_gb_data),.memory_data_out(game_memory_data),
        .gb_data_drive(game_gb_drive),.memory_data_drive(game_memory_drive),
        .data_oe_n(game_data_oe_n),.data_dir(game_data_dir),
        .flash_a(game_address),.flash_ce_n(game_ce_n),.flash_oe_n(game_oe_n),.flash_we_n(game_we_n),
        .fram_ce_n(game_ram_ce_n),.fram_oe_n(game_ram_oe_n),.fram_we_n(game_ram_we_n),
        .bus_idle(game_bus_idle));
    programmer_block #(.CONTROLLED(1),.HOST_BLOCKS(HOST_BLOCKS)) protocol(
        .clk(clk),.reset(reset || !programmer_enable || cleanup),.accept_requests(accept_requests),
        .spi_cs_n(spi_cs_n),.spi_sck(spi_sck),.spi_mosi(spi_mosi),.spi_miso(spi_miso),
        .busy(busy),.done(done),.operation_status(status),.result(result),
        .start(start),.command(command),.address(address),.data(data),.seen(),.active(active));
    // Контроллер не сбрасывается при исчезновении USB/питания Game Boy:
    // уже начатая операция должна закончиться, включая F0/read-array.
    mx29_programmer #(.POWER_CYCLES(POWER_CYCLES),.PROGRAM_CYCLES(PROGRAM_CYCLES),
        .ERASE_CYCLES(ERASE_CYCLES),.READ_TICKS(4),.WRITE_TICKS(32),.SPLIT_DATA(1)) programmer(
        .clk(clk),.reset(reset),.start((start && programmer_enable && !cleanup) || cleanup_start),
        .command(cleanup ? 8'h14 : command),.address(address),.data(data),
        .busy(busy),.done(done),.status(status),.result(result),
        .flash_a(programmer_address),.flash_d(),.flash_ce_n(programmer_ce_n),
        .flash_oe_n(programmer_oe_n),.flash_we_n(programmer_we_n),
        .memory_data_in(flash_d),.memory_data_out(programmer_memory_data),.memory_data_drive(programmer_memory_drive));
    // Единственное место управления внешними двунаправленными портами.
    assign gb_d=game_enable && game_gb_drive ? game_gb_data : 8'hzz;
    assign flash_d=programmer_enable && programmer_memory_drive ? programmer_memory_data :
                   game_enable && game_memory_drive ? game_memory_data : 8'hzz;
    assign flash_a=programmer_enable ? programmer_address : game_enable ? game_address : 22'b0;
    assign flash_ce_n=programmer_enable ? programmer_ce_n : game_enable ? game_ce_n : 1'b1;
    assign flash_oe_n=programmer_enable ? programmer_oe_n : game_enable ? game_oe_n : 1'b1;
    assign flash_we_n=programmer_enable ? programmer_we_n : 1'b1;
    assign fram_ce_n=game_enable ? game_ram_ce_n : 1'b1;
    assign fram_oe_n=game_enable ? game_ram_oe_n : 1'b1;
    assign fram_we_n=game_enable ? game_ram_we_n : 1'b1;
    assign data_oe_n=game_enable ? game_data_oe_n : 1'b1;
    assign data_dir=game_enable ? game_data_dir : 1'b0;
endmodule
