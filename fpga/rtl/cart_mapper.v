`timescale 1ns/1ps

// ROM ONLY, MBC1/MBC1M, MBC2, MBC3/MBC30 и MBC5.
// Заголовок задаёт возможности и маски памяти; записи приходят через снимок A/D.
module cart_mapper (
    input wire clk,
    input wire configured,
    input wire multicart,
    input wire [7:0] cart_type,
    input wire [7:0] rom_size,
    input wire [7:0] ram_size,
    input wire [15:0] gb_a,
    input wire [7:0] gb_data,
    input wire gb_rd_n,
    input wire gb_wr_n,
    input wire gb_cs_n,
    input wire gb_res_n,
    output wire supported,
    output reg config_ready = 0,
    output wire [21:0] rom_address,
    output wire [16:0] ram_address,
    output wire ram_access,
    output wire nibble_ram,
    output wire rtc_access,
    output wire [2:0] rtc_register,
    output reg rtc_write_toggle = 0,
    output reg rtc_latch_toggle = 0,
    output reg [2:0] rtc_write_register = 0,
    output reg [7:0] rtc_write_data = 0
);
    localparam NONE = 0, MBC1 = 1, MBC2 = 2, MBC3 = 3, MBC5 = 5, INVALID = 7;

    // Декодирование заголовка отделено от пути записи регистров банка.
    reg [2:0] kind = INVALID, kind_next;
    reg has_ram = 0, has_rtc = 0, rumble = 0;
    reg has_ram_next, has_rtc_next, rumble_next;
    reg [7:0] rom_mask = 0, rom_mask_next;
    reg [16:0] ram_mask = 0, ram_mask_next;
    reg supported_config = 0;

    wire mbc30 = kind == MBC3 && (rom_size == 7 || ram_size == 5);
    assign supported = configured && config_ready && supported_config;

    always @* begin
        kind_next = INVALID;
        has_ram_next = 0;
        has_rtc_next = 0;
        rumble_next = 0;

        case (cart_type)
            'h00: kind_next = NONE;
            'h08, 'h09: begin
                kind_next = NONE;
                has_ram_next = 1;
            end
            'h01: kind_next = MBC1;
            'h02, 'h03: begin
                kind_next = MBC1;
                has_ram_next = 1;
            end
            'h05, 'h06: begin
                kind_next = MBC2;
                has_ram_next = 1;
            end
            'h0f: begin
                kind_next = MBC3;
                has_rtc_next = 1;
            end
            'h10: begin
                kind_next = MBC3;
                has_ram_next = 1;
                has_rtc_next = 1;
            end
            'h11: kind_next = MBC3;
            'h12, 'h13: begin
                kind_next = MBC3;
                has_ram_next = 1;
            end
            'h19: kind_next = MBC5;
            'h1a, 'h1b: begin
                kind_next = MBC5;
                has_ram_next = 1;
            end
            'h1c: begin
                kind_next = MBC5;
                rumble_next = 1;
            end
            'h1d, 'h1e: begin
                kind_next = MBC5;
                has_ram_next = 1;
                rumble_next = 1;
            end
            default: ;
        endcase

        case (rom_size)
            0: rom_mask_next = 8'h01;
            1: rom_mask_next = 8'h03;
            2: rom_mask_next = 8'h07;
            3: rom_mask_next = 8'h0f;
            4: rom_mask_next = 8'h1f;
            5: rom_mask_next = 8'h3f;
            6: rom_mask_next = 8'h7f;
            7: rom_mask_next = 8'hff;
            default: rom_mask_next = 0;
        endcase

        case (ram_size)
            1: ram_mask_next = 17'h007ff;
            2: ram_mask_next = 17'h01fff;
            3: ram_mask_next = 17'h07fff;
            4: ram_mask_next = 17'h1ffff;
            5: ram_mask_next = 17'h0ffff;
            default: ram_mask_next = 0;
        endcase
    end

    // Конфигурация фиксируется один раз, после окончания сканирования.
    always @(posedge clk) begin
        if (!configured) begin
            config_ready <= 0;
            supported_config <= 0;
        end else if (!config_ready) begin
            kind <= kind_next;
            has_ram <= has_ram_next;
            has_rtc <= has_rtc_next;
            rumble <= rumble_next;
            rom_mask <= rom_mask_next;
            ram_mask <= ram_mask_next;
            supported_config <= kind_next != INVALID && rom_size <= 7 && ram_size <= 5;

            if (kind_next == NONE && (rom_size != 0 || (has_ram_next && ram_size > 2)))
                supported_config <= 0;
            if (kind_next == MBC1 &&
                (rom_size > 6 || ram_size > 3 || (rom_size >= 5 && ram_size > 2)))
                supported_config <= 0;
            if (kind_next == MBC2 && rom_size > 3)
                supported_config <= 0;
            if (kind_next == MBC3 && ram_size == 4)
                supported_config <= 0;
            if (rumble_next && ram_size == 4)
                supported_config <= 0;

            config_ready <= 1;
        end
    end

    // Регистры мапперов. MBC5 хранит девятый бит банка, но Flash ограничена 4 МиБ.
    reg enabled = 0; // Разрешение RAM/RTC.
    reg mode = 0;    // Режим банков MBC1.
    reg [4:0] mbc1_low = 0;
    reg [1:0] mbc1_high = 0;
    reg [8:0] bank = 1;
    reg [7:0] ram_select = 0;
    reg [7:0] latch_previous = 8'hff;

    // RESET утверждается асинхронно, снимается через два регистра clk.
    (* syn_preserve = 1 *) reg [1:0] reset_release = 0;
    always @(posedge clk or negedge gb_res_n) begin
        if (!gb_res_n)
            reset_release <= 0;
        else
            reset_release <= {reset_release[0], 1'b1};
    end
    wire mapper_reset = !reset_release[1];

    (* syn_preserve = 1 *) reg wr_meta = 1'b1, wr_sync = 1'b1;
    reg wr_seen = 0, write_pending = 0;
    reg [15:0] write_address = 0;
    reg [7:0] write_data = 0;
    reg write_rd_n = 1, write_cs_n = 1;
    wire write_fire = write_pending && !mapper_reset;
    wire [7:0] mbc3_write_bank = mbc30 ? write_data : (write_data & 8'h7f);

    // A/D захватываются вместе после двух ступеней /WR.
    // Следующий clk применяет снимок; внешний /WR запрещает поздний захват.
    always @(posedge clk or posedge mapper_reset) begin
        if (mapper_reset) begin
            wr_meta <= 1;
            wr_sync <= 1;
            wr_seen <= 0;
            write_pending <= 0;
            write_address <= 0;
            write_data <= 0;
            write_rd_n <= 1;
            write_cs_n <= 1;
            enabled <= 0;
            mode <= 0;
            mbc1_low <= 0;
            mbc1_high <= 0;
            bank <= 1;
            ram_select <= 0;
            latch_previous <= 8'hff;
        end else begin
            wr_meta <= gb_wr_n;
            wr_sync <= wr_meta;
            write_pending <= 0;

            if (wr_sync)
                wr_seen <= 0;
            if (!wr_sync && !gb_wr_n && !wr_seen) begin
                wr_seen <= 1;
                if (supported) begin
                    write_address <= gb_a;
                    write_data <= gb_data;
                    write_rd_n <= gb_rd_n;
                    write_cs_n <= gb_cs_n;
                    write_pending <= 1;
                end
            end

            if (write_fire) begin
                if (supported && write_rd_n && !write_address[15]) begin
                    // У MBC2 адрес A8 выбирает RAM enable или ROM bank.
                    if (kind == MBC2) begin
                        if (!write_address[14]) begin
                            if (!write_address[8])
                                enabled <= write_data[3:0] == 4'ha;
                            else
                                bank <= {5'b0, (write_data[3:0] == 0 ? 4'd1 : write_data[3:0])};
                        end
                    end else begin
                        case (write_address[14:13])
                            // 0000–1FFF: разрешение RAM/RTC.
                            0: begin
                                if (kind != NONE)
                                    enabled <= write_data[3:0] == 4'ha;
                            end

                            // 2000–3FFF: банк ROM.
                            1: begin
                                case (kind)
                                    MBC1: mbc1_low <= write_data[4:0];
                                    MBC3: bank <= {1'b0, (mbc3_write_bank == 0 ? 8'd1 : mbc3_write_bank)};
                                    MBC5: begin
                                        if (!write_address[12])
                                            bank[7:0] <= write_data;
                                        else
                                            bank[8] <= write_data[0];
                                    end
                                    default: ;
                                endcase
                            end

                            // 4000–5FFF: старшие биты MBC1 или выбор RAM/RTC.
                            2: begin
                                if (kind == MBC1)
                                    mbc1_high <= write_data[1:0];
                                else if (kind == MBC3 || kind == MBC5)
                                    ram_select <= write_data;
                            end

                            // 6000–7FFF: режим MBC1 или последовательность latch RTC.
                            3: begin
                                if (kind == MBC1)
                                    mode <= write_data[0];
                                else if (kind == MBC3)
                                    latch_previous <= write_data;
                            end
                        endcase
                    end
                end
            end
        end
    end

    // События RTC принадлежат clk и сохраняются при RESET Game Boy.
    // Payload и toggle обновляются вместе; приёмник видит их на следующем clk.
    always @(posedge clk) begin
        if (gb_res_n && write_fire && supported && write_rd_n && has_rtc) begin
            if (write_address[15:13] == 3'b011 && latch_previous == 0 && write_data == 1)
                rtc_latch_toggle <= ~rtc_latch_toggle;
            if (write_address[15:13] == 3'b101 && !write_cs_n && enabled && rtc_access) begin
                rtc_write_register <= ram_select[2:0];
                rtc_write_data <= write_data;
                rtc_write_toggle <= ~rtc_write_toggle;
            end
        end
    end

    // Асинхронный выбор банков для текущего адреса Game Boy.
    reg [7:0] rom_bank;
    reg [3:0] ram_bank;
    wire [4:0] low_nonzero = mbc1_low == 0 ? 5'd1 : mbc1_low;

    always @* begin
        rom_bank = 0;
        ram_bank = 0;
        case (kind)
            NONE: rom_bank = {7'b0, gb_a[14]};
            MBC1: begin
                if (gb_a[14])
                    rom_bank = multicart
                        ? {2'b0, mbc1_high, low_nonzero[3:0]}
                        : {1'b0, mbc1_high, low_nonzero};
                else if (mode)
                    rom_bank = multicart
                        ? {2'b0, mbc1_high, 4'b0}
                        : {1'b0, mbc1_high, 5'b0};
                if (mode && rom_size <= 4)
                    ram_bank = {2'b0, mbc1_high};
            end
            MBC2: begin
                if (gb_a[14])
                    rom_bank = bank[7:0];
            end
            MBC3: begin
                if (gb_a[14])
                    rom_bank = bank[7:0];
                ram_bank = mbc30 ? {1'b0, ram_select[2:0]} : {2'b0, ram_select[1:0]};
            end
            MBC5: begin
                if (gb_a[14])
                    rom_bank = bank[7:0];
                ram_bank = rumble ? {1'b0, ram_select[2:0]} : ram_select[3:0];
            end
            default: ;
        endcase
    end

    assign rom_address = {rom_bank & rom_mask, gb_a[13:0]};
    assign nibble_ram = kind == MBC2;
    assign ram_address = nibble_ram
        ? {8'b0, gb_a[8:0]}
        : ({ram_bank, gb_a[12:0]} & ram_mask);

    wire ram_selected = kind != MBC3 || ram_select < (mbc30 ? 8 : 4);
    assign ram_access = supported && has_ram && (kind == NONE || enabled) &&
                        ram_selected && (nibble_ram || ram_size != 0);
    assign rtc_access = supported && has_rtc && enabled && ram_select >= 8 && ram_select <= 12;
    assign rtc_register = ram_select[2:0];
endmodule
