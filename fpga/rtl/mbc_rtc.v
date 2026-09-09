`timescale 1ns/1ps
// MBC3 RTC. OSCH даёт приблизительное время только пока FPGA включена.
// Записи/защёлкивание приходят через mailbox с toggle из домена WR#.
// Источник удерживает payload до следующей записи (интервал RTC >=4 мкс).
module mbc_rtc #(parameter integer CLOCK_HZ=53200000) (
    input wire clk, reset,
    input wire write_toggle, latch_toggle,
    input wire [2:0] write_register,
    input wire [7:0] write_data,
    input wire [2:0] read_register,
    output reg [7:0] read_data
);
    reg [1:0] write_sync=0, latch_sync=0;
    reg write_seen=0, latch_seen=0;
    reg [25:0] divider=0;
    reg [5:0] seconds=0, minutes=0;
    reg [4:0] hours=0;
    reg [8:0] days=0;
    reg halted=0, carry=0;
    reg [7:0] latched [0:4];
    integer i;
    always @(posedge clk) begin
        write_sync <= {write_sync[0],write_toggle};
        latch_sync <= {latch_sync[0],latch_toggle};
        if (reset) begin
            write_sync<=0; latch_sync<=0; write_seen<=0; latch_seen<=0;
            divider<=0; seconds<=0; minutes<=0; hours<=0; days<=0;
            halted<=0; carry<=0;
            for(i=0;i<5;i=i+1) latched[i]<=0;
        end else begin
            if (!halted) begin
                if (divider == CLOCK_HZ-1) begin
                    divider<=0;
                    if(seconds==59) begin
                        seconds<=0;
                        if(minutes==59) begin
                            minutes<=0;
                            if(hours==23) begin
                                hours<=0; days<=days+1'b1;
                                if(days==511) carry<=1;
                            end else hours<=hours+1'b1;
                        end else minutes<=minutes+1'b1;
                    end else seconds<=seconds+1'b1;
                end else divider<=divider+1'b1;
            end
            if(write_sync[1]!=write_seen) begin
                write_seen<=write_sync[1];
                case(write_register)
                    0: begin seconds<=write_data[5:0]; divider<=0; end
                    1: minutes<=write_data[5:0];
                    2: hours<=write_data[4:0];
                    3: days[7:0]<=write_data;
                    4: begin days[8]<=write_data[0]; halted<=write_data[6]; carry<=write_data[7]; end
                    default: ;
                endcase
            end
            if(latch_sync[1]!=latch_seen) begin
                latch_seen<=latch_sync[1];
                latched[0]<={2'b0,seconds}; latched[1]<={2'b0,minutes};
                latched[2]<={3'b0,hours}; latched[3]<=days[7:0];
                latched[4]<={carry,halted,5'b0,days[8]};
            end
        end
    end
    always @* begin
        read_data=8'hff;
        case(read_register)
            0: read_data=latched[0]; 1: read_data=latched[1];
            2: read_data=latched[2]; 3: read_data=latched[3];
            4: read_data=latched[4]; default: ;
        endcase
    end
endmodule
