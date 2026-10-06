`timescale 1ns/1ps

// MBC3 RTC: приблизительное время от OSCH, только пока FPGA включена.
// SAME_CLOCK=1: события и payload зарегистрированы в том же clk.
// SAME_CLOCK=0: прежний mailbox; источник удерживает payload до приёма.
module mbc_rtc #(
    parameter integer CLOCK_HZ = 53200000,
    parameter SAME_CLOCK = 0
) (
    input wire clk,
    input wire reset,
    input wire write_toggle,
    input wire latch_toggle,
    input wire [2:0] write_register,
    input wire [7:0] write_data,
    input wire [2:0] read_register,
    output reg [7:0] read_data
);
    localparam DIVIDER_WIDTH = CLOCK_HZ < 2 ? 1 : $clog2(CLOCK_HZ);

    reg [1:0] write_sync = 0, latch_sync = 0;
    reg write_seen = 0, latch_seen = 0;
    wire write_event = SAME_CLOCK ? write_toggle : write_sync[1];
    wire latch_event = SAME_CLOCK ? latch_toggle : latch_sync[1];

    // Текущее время и отдельный снимок для чтения Game Boy.
    reg [DIVIDER_WIDTH-1:0] divider = 0;
    reg [5:0] seconds = 0, minutes = 0;
    reg [4:0] hours = 0;
    reg [8:0] days = 0;
    reg halted = 0, carry = 0;
    reg [7:0] latched [0:4];
    integer i;

    always @(posedge clk) begin
        write_sync <= {write_sync[0], write_toggle};
        latch_sync <= {latch_sync[0], latch_toggle};

        if (reset) begin
            write_sync <= 0;
            latch_sync <= 0;
            write_seen <= SAME_CLOCK ? write_toggle : 1'b0;
            latch_seen <= SAME_CLOCK ? latch_toggle : 1'b0;
            divider <= 0;
            seconds <= 0;
            minutes <= 0;
            hours <= 0;
            days <= 0;
            halted <= 0;
            carry <= 0;
            for (i = 0; i < 5; i = i + 1)
                latched[i] <= 0;
        end else begin
            // Секундный тик; HALT сохраняет и время, и фазу делителя.
            if (!halted) begin
                if (divider == CLOCK_HZ - 1) begin
                    divider <= 0;
                    if (seconds == 59) begin
                        seconds <= 0;
                        if (minutes == 59) begin
                            minutes <= 0;
                            if (hours == 23) begin
                                hours <= 0;
                                days <= days + 1'b1;
                                if (days == 511)
                                    carry <= 1;
                            end else
                                hours <= hours + 1'b1;
                        end else
                            minutes <= minutes + 1'b1;
                    end else
                        seconds <= seconds + 1'b1;
                end else
                    divider <= divider + 1'b1;
            end

            // Запись имеет приоритет над тиком для записываемого поля.
            if (write_event != write_seen) begin
                write_seen <= write_event;
                case (write_register)
                    0: begin
                        seconds <= write_data[5:0];
                        divider <= 0;
                    end
                    1: minutes <= write_data[5:0];
                    2: hours <= write_data[4:0];
                    3: days[7:0] <= write_data;
                    4: begin
                        days[8] <= write_data[0];
                        halted <= write_data[6];
                        carry <= write_data[7];
                    end
                    default: ;
                endcase
            end

            // Неблокирующие присваивания фиксируют состояние до записи/тика.
            if (latch_event != latch_seen) begin
                latch_seen <= latch_event;
                latched[0] <= {2'b0, seconds};
                latched[1] <= {2'b0, minutes};
                latched[2] <= {3'b0, hours};
                latched[3] <= days[7:0];
                latched[4] <= {carry, halted, 5'b0, days[8]};
            end
        end
    end

    // Регистры 0..4 соответствуют выбору MBC3 08h..0Ch (младшие три бита).
    always @* begin
        read_data = 8'hff;
        case (read_register)
            0: read_data = latched[0];
            1: read_data = latched[1];
            2: read_data = latched[2];
            3: read_data = latched[3];
            4: read_data = latched[4];
            default: ;
        endcase
    end
endmodule
