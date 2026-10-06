`timescale 1ns/1ps

// Сканирование заголовка до передачи Flash шине Game Boy.
// MBC1M: сравнение 48 байт логотипа в банках 00h/10h у MBC1 ROM размером 1 МиБ.
// Пустые логотипы исключаются; одновременно хранится один эталонный байт.
module cart_header (
    input wire clk,
    input wire reset,
    input wire [7:0] data,
    output wire [21:0] address,
    output reg done = 0,
    output reg [7:0] cart_type = 8'hff,
    output reg [7:0] rom_size = 8'hff,
    output reg [7:0] ram_size = 8'hff,
    output reg multicart = 0
);
    // index=0..2: поля заголовка; index=3..50: байты логотипа 0104h..0133h.
    reg [5:0] index = 0;
    reg [3:0] wait_ticks = 0;
    reg second_copy = 0, logo_match = 1, nonzero_seen = 0, nonff_seen = 0;
    reg [7:0] logo_byte = 0;
    wire [5:0] logo_address = index + 6'd1;
    wire is_mbc1 = cart_type >= 1 && cart_type <= 3;

    // second_copy выбирает банк 10h; остальные биты задают область логотипа.
    assign address = index == 0 ? 22'h147 :
                     index == 1 ? 22'h148 :
                     index == 2 ? 22'h149 :
                     {3'b0, second_copy, 9'b0, 1'b1, 2'b0, logo_address};

    always @(posedge clk) begin
        if (reset) begin
            index <= 0;
            wait_ticks <= 0;
            done <= 0;
            cart_type <= 8'hff;
            rom_size <= 8'hff;
            ram_size <= 8'hff;
            multicart <= 0;
            second_copy <= 0;
            logo_match <= 1;
            logo_byte <= 0;
            nonzero_seen <= 0;
            nonff_seen <= 0;
        end else if (!done) begin
            // Перед каждым захватом адрес удерживается 16 тактов clk.
            if (wait_ticks == 15) begin
                wait_ticks <= 0;
                if (index < 3) begin
                    case (index)
                        0: cart_type <= data;
                        1: rom_size <= data;
                        2: ram_size <= data;
                        default: ;
                    endcase

                    if (index == 2 && !(is_mbc1 && rom_size == 5))
                        done <= 1;
                    else
                        index <= index + 1'b1;
                end else if (!second_copy) begin
                    // Эталон из банка 00h и проверка непустого шаблона.
                    logo_byte <= data;
                    second_copy <= 1;
                    if (data != 8'h00)
                        nonzero_seen <= 1;
                    if (data != 8'hff)
                        nonff_seen <= 1;
                end else begin
                    // Сравнение с банком 10h, затем переход к следующей паре.
                    second_copy <= 0;
                    if (data != logo_byte)
                        logo_match <= 0;
                    if (index == 50) begin
                        multicart <= logo_match && data == logo_byte && nonzero_seen && nonff_seen;
                        done <= 1;
                    end else
                        index <= index + 1'b1;
                end
            end else
                wait_ticks <= wait_ticks + 1'b1;
        end
    end
endmodule
