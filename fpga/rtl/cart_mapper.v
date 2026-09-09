`timescale 1ns/1ps
// ROM ONLY, MBC1/MBC1M, MBC2, MBC3/MBC30, MBC5.
// Параметры определяются заголовком. Неподдерживаемые сочетания отключают память.
// Правила регистров: https://github.com/gbdev/pandocs/tree/master/src
module cart_mapper (
    input wire configured, multicart,
    input wire [7:0] cart_type, rom_size, ram_size,
    input wire [15:0] gb_a,
    input wire [7:0] gb_data,
    input wire gb_rd_n, gb_wr_n, gb_cs_n, gb_res_n,
    output reg supported,
    output wire [21:0] rom_address,
    output wire [16:0] ram_address,
    output wire ram_access, nibble_ram, rtc_access,
    output wire [2:0] rtc_register,
    output reg rtc_write_toggle=0, rtc_latch_toggle=0,
    output reg [2:0] rtc_write_register=0,
    output reg [7:0] rtc_write_data=0
);
    localparam NONE=0, MBC1=1, MBC2=2, MBC3=3, MBC5=5, INVALID=7;
    reg [2:0] kind;
    reg has_ram, has_rtc, rumble;
    wire mbc30 = kind==MBC3 && (rom_size==7 || ram_size==5);
    reg [7:0] rom_mask;
    reg [16:0] ram_mask;
    always @* begin
        kind=INVALID; has_ram=0; has_rtc=0; rumble=0;
        case(cart_type)
            'h00: kind=NONE;
            'h08,'h09: begin kind=NONE; has_ram=1; end
            'h01: kind=MBC1;
            'h02,'h03: begin kind=MBC1; has_ram=1; end
            'h05,'h06: begin kind=MBC2; has_ram=1; end
            'h0f: begin kind=MBC3; has_rtc=1; end
            'h10: begin kind=MBC3; has_ram=1; has_rtc=1; end
            'h11: kind=MBC3;
            'h12,'h13: begin kind=MBC3; has_ram=1; end
            'h19: kind=MBC5;
            'h1a,'h1b: begin kind=MBC5; has_ram=1; end
            'h1c: begin kind=MBC5; rumble=1; end
            'h1d,'h1e: begin kind=MBC5; has_ram=1; rumble=1; end
            default: ;
        endcase
        case(rom_size)
            0: rom_mask=8'h01; 1: rom_mask=8'h03; 2: rom_mask=8'h07;
            3: rom_mask=8'h0f; 4: rom_mask=8'h1f; 5: rom_mask=8'h3f;
            6: rom_mask=8'h7f; 7: rom_mask=8'hff; default: rom_mask=0;
        endcase
        case(ram_size)
            1: ram_mask=17'h007ff; 2: ram_mask=17'h01fff;
            3: ram_mask=17'h07fff; 4: ram_mask=17'h1ffff;
            5: ram_mask=17'h0ffff; default: ram_mask=0;
        endcase
        supported=configured && kind!=INVALID && rom_size<=7 && ram_size<=5;
        if(kind==NONE && (rom_size!=0 || (has_ram && ram_size>2))) supported=0;
        if(kind==MBC1 && (rom_size>6 || ram_size>3 || (rom_size>=5 && ram_size>2))) supported=0;
        if(kind==MBC2 && rom_size>3) supported=0;
        if(kind==MBC3 && ram_size==4) supported=0;
        if(rumble && ram_size==4) supported=0;
    end
    reg enabled=0, mode=0;
    reg [4:0] mbc1_low=0;
    reg [1:0] mbc1_high=0;
    reg [8:0] bank=1;
    reg [7:0] ram_select=0;
    reg [7:0] latch_previous=8'hff;
    always @(posedge gb_wr_n or negedge gb_res_n) begin
        if(!gb_res_n) begin
            enabled<=0; mode<=0; mbc1_low<=0; mbc1_high<=0;
            bank<=1; ram_select<=0; latch_previous<=8'hff;
        end else if(supported && gb_rd_n && !gb_a[15]) begin
            if(kind==MBC2) begin
                if(!gb_a[14]) begin
                    if(!gb_a[8]) enabled<=gb_data[3:0]==4'ha;
                    else bank<={5'b0,(gb_data[3:0]==0 ? 4'd1 : gb_data[3:0])};
                end
            end else begin
                case(gb_a[14:13])
                    0: if(kind!=NONE) enabled<=gb_data[3:0]==4'ha;
                    1: case(kind)
                        MBC1: mbc1_low<=gb_data[4:0];
                        MBC3: bank<={1'b0,((mbc30 ? gb_data : (gb_data & 8'h7f))==0 ? 8'd1 :
                                                      (mbc30 ? gb_data : (gb_data & 8'h7f)))};
                        MBC5: if(!gb_a[12]) bank[7:0]<=gb_data; else bank[8]<=gb_data[0];
                        default: ;
                    endcase
                    2: if(kind==MBC1) mbc1_high<=gb_data[1:0];
                       else if(kind==MBC3 || kind==MBC5) ram_select<=gb_data;
                    3: if(kind==MBC1) mode<=gb_data[0];
                       else if(kind==MBC3) latch_previous<=gb_data;
                endcase
            end
        end
    end
    // RTC не сбрасывается сигналом RESET Game Boy; только при конфигурации FPGA.
    always @(posedge gb_wr_n) begin
        if(gb_res_n && supported && gb_rd_n && has_rtc) begin
            if(gb_a[15:13]==3'b011 && latch_previous==0 && gb_data==1)
                rtc_latch_toggle<=~rtc_latch_toggle;
            if(gb_a[15:13]==3'b101 && !gb_cs_n && enabled && rtc_access) begin
                rtc_write_register<=ram_select[2:0]; rtc_write_data<=gb_data;
                rtc_write_toggle<=~rtc_write_toggle;
            end
        end
    end
    reg [7:0] rom_bank;
    reg [3:0] ram_bank;
    wire [4:0] low_nonzero = mbc1_low==0 ? 5'd1 : mbc1_low;
    always @* begin
        rom_bank=0; ram_bank=0;
        case(kind)
            NONE: rom_bank={7'b0,gb_a[14]};
            MBC1: begin
                if(gb_a[14])
                    rom_bank=multicart ? {2'b0,mbc1_high,low_nonzero[3:0]} : {1'b0,mbc1_high,low_nonzero};
                else if(mode)
                    rom_bank=multicart ? {2'b0,mbc1_high,4'b0} : {1'b0,mbc1_high,5'b0};
                if(mode && rom_size<=4) ram_bank={2'b0,mbc1_high};
            end
            MBC2: if(gb_a[14]) rom_bank=bank[7:0];
            MBC3: begin
                if(gb_a[14]) rom_bank=bank[7:0];
                ram_bank=mbc30 ? {1'b0,ram_select[2:0]} : {2'b0,ram_select[1:0]};
            end
            MBC5: begin
                if(gb_a[14]) rom_bank=bank[7:0];
                ram_bank=rumble ? {1'b0,ram_select[2:0]} : ram_select[3:0];
            end
            default: ;
        endcase
    end
    assign rom_address={rom_bank & rom_mask,gb_a[13:0]};
    assign nibble_ram=kind==MBC2;
    assign ram_address=nibble_ram ? {8'b0,gb_a[8:0]} : ({ram_bank,gb_a[12:0]} & ram_mask);
    wire ram_selected=kind!=MBC3 || ram_select<(mbc30 ? 8 : 4);
    assign ram_access=supported && has_ram && (kind==NONE || enabled) && ram_selected &&
                      (nibble_ram || ram_size!=0);
    assign rtc_access=supported && has_rtc && enabled && ram_select>=8 && ram_select<=12;
    assign rtc_register=ram_select[2:0];
endmodule
