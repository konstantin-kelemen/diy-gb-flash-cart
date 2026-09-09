`timescale 1ns/1ps
// Чтение заголовка из Flash до передачи шины Game Boy.
// MBC1M: полный логотип Nintendo в банке 10h образа MBC1 размером 1 МиБ.
// Источник правил: gbdev/pandocs, MBC1 и The_Cartridge_Header.
module cart_header (
    input wire clk, reset,
    input wire [7:0] data,
    output wire [21:0] address,
    output reg done=0,
    output reg [7:0] cart_type=8'hff, rom_size=8'hff, ram_size=8'hff,
    output reg multicart=0
);
    localparam [383:0] LOGO=384'hceed6666cc0d000b03730083000c000d0008111f8889000edccc6ee6ddddd999bbbb67636e0eecccdddc999fbbb9333e;
    reg [5:0] index=0;
    reg [3:0] wait_ticks=0;
    reg logo_match=1;
    assign address = index==0 ? 22'h147 : index==1 ? 22'h148 :
                     index==2 ? 22'h149 : 22'h40104 + (index-6'd3);
    wire is_mbc1 = cart_type>=1 && cart_type<=3;
    wire [7:0] logo_byte = LOGO >> ((50-index)*8);
    always @(posedge clk) begin
        if(reset) begin
            index<=0; wait_ticks<=0; done<=0; cart_type<=8'hff;
            rom_size<=8'hff; ram_size<=8'hff; multicart<=0; logo_match<=1;
        end else if(!done) begin
            if(wait_ticks==15) begin
                wait_ticks<=0;
                case(index)
                    0: cart_type<=data;
                    1: rom_size<=data;
                    2: ram_size<=data;
                    default: if(data!=logo_byte) logo_match<=0;
                endcase
                if(index==2 && !(is_mbc1 && rom_size==5)) done<=1;
                else if(index==50) begin
                    multicart<=logo_match && data==logo_byte; done<=1;
                end else index<=index+1'b1;
            end else wait_ticks<=wait_ticks+1'b1;
        end
    end
endmodule
