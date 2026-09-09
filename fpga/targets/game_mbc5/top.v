`timescale 1ns/1ps
// MBC5 без rumble, образ 1 МиБ (LSDj); старшие биты банка зеркалируются.
// Асинхронная шина. WR# служит тактом регистров, данные удерживаются CPU
// на его положительном фронте. Проверка setup/hold обязательна в Diamond.
module top (
    input wire [15:0] gb_a,
    input wire gb_rd_n, gb_wr_n, gb_cs_n, gb_res_n,
    inout wire [7:0] gb_d,
    output wire data_oe_n, data_dir,
    output wire [21:0] flash_a,
    inout wire [7:0] flash_d,
    output wire flash_ce_n, flash_oe_n, flash_we_n,
    output wire fram_ce_n, fram_oe_n, fram_we_n
);
    reg [8:0] rom_bank = 9'd1;
    reg [3:0] ram_bank = 4'd0;
    reg ram_enabled = 1'b0;
    always @(posedge gb_wr_n or negedge gb_res_n) begin
        if (!gb_res_n) begin
            rom_bank <= 9'd1;
            ram_bank <= 4'd0;
            ram_enabled <= 1'b0;
        end else if (gb_rd_n) begin
            case (gb_a[15:12])
                4'h0, 4'h1: ram_enabled <= (gb_d[3:0] == 4'ha);
                4'h2: rom_bank[7:0] <= gb_d;
                4'h3: rom_bank[8] <= gb_d[0];
                4'h4, 4'h5: ram_bank <= gb_d[3:0];
                default: ;
            endcase
        end
    end
    wire ram_window = gb_a[15:13] == 3'b101 && !gb_cs_n;
    wire reading = gb_res_n && !gb_rd_n && gb_wr_n;
    wire rom_read = reading && !gb_a[15];
    wire ram_read = reading && ram_window;
    wire ram_write = gb_res_n && gb_rd_n && !gb_wr_n && ram_window && ram_enabled;
    wire drive_gb = rom_read || ram_read;

    // Адрес RAM сохраняется и после WR#, пока CPU удерживает адрес.
    assign flash_a = ram_window ? {5'b0, ram_bank, gb_a[12:0]} :
                     {2'b0, (gb_a[14] ? rom_bank[5:0] : 6'b0), gb_a[13:0]};
    assign flash_ce_n = !rom_read;
    assign flash_oe_n = !rom_read;
    assign flash_we_n = 1'b1;
    // CE# отпускается между обращениями: отдельный precharge на каждый цикл.
    assign fram_ce_n = !((ram_read && ram_enabled) || ram_write);
    assign fram_oe_n = !(ram_read && ram_enabled);
    assign fram_we_n = !ram_write;
    assign flash_d = ram_write ? gb_d : 8'hzz;
    assign gb_d = drive_gb ? ((ram_read && !ram_enabled) ? 8'hff : flash_d) : 8'hzz;
    assign data_dir = drive_gb;
    // Приём остаётся включённым после WR#, обеспечивая hold на регистрах.
    assign data_oe_n = !gb_res_n;
endmodule
