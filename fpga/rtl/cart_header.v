`timescale 1ns/1ps
// Read cartridge metadata before handing the Flash bus to the Game Boy.
// MBC1M: compare all 48 logo bytes in banks 00h and 10h of a 1 MiB MBC1 ROM.
// Reject blank templates; only one reference byte is held in the FPGA.
module cart_header (
    input wire clk, reset,
    input wire [7:0] data,
    output wire [21:0] address,
    output reg done=0,
    output reg [7:0] cart_type=8'hff, rom_size=8'hff, ram_size=8'hff,
    output reg multicart=0
);
    reg [5:0] index=0;
    reg [3:0] wait_ticks=0;
    reg second_copy=0, logo_match=1, nonzero_seen=0, nonff_seen=0;
    reg [7:0] logo_byte=0;
    wire [5:0] logo_address=index+6'd1;
    assign address=index==0 ? 22'h147 : index==1 ? 22'h148 :
                   index==2 ? 22'h149 :
                   {3'b0,second_copy,9'b0,1'b1,2'b0,logo_address};
    wire is_mbc1=cart_type>=1 && cart_type<=3;
    always @(posedge clk) begin
        if(reset) begin
            index<=0; wait_ticks<=0; done<=0; cart_type<=8'hff;
            rom_size<=8'hff; ram_size<=8'hff; multicart<=0;
            second_copy<=0; logo_match<=1; logo_byte<=0;
            nonzero_seen<=0; nonff_seen<=0;
        end else if(!done) begin
            if(wait_ticks==15) begin
                wait_ticks<=0;
                if(index<3) begin
                    case(index)
                        0: cart_type<=data;
                        1: rom_size<=data;
                        2: ram_size<=data;
                        default: ;
                    endcase
                    if(index==2 && !(is_mbc1 && rom_size==5)) done<=1;
                    else index<=index+1'b1;
                end else if(!second_copy) begin
                    logo_byte<=data; second_copy<=1;
                    if(data!=8'h00) nonzero_seen<=1;
                    if(data!=8'hff) nonff_seen<=1;
                end else begin
                    second_copy<=0;
                    if(data!=logo_byte) logo_match<=0;
                    if(index==50) begin
                        multicart<=logo_match && data==logo_byte && nonzero_seen && nonff_seen;
                        done<=1;
                    end else index<=index+1'b1;
                end
            end else wait_ticks<=wait_ticks+1'b1;
        end
    end
endmodule
