// Single-operation MX29LV320E x8 sequencer. Defaults are for 2.08 MHz.
// The block target supplies timers and bus ticks for 53.20 MHz.
// Commands: 10 read, 11 program byte, 12 sector erase, 13 ID, 14 reset.
// No Game Boy interface: use only in the separate PROGRAMMER build.
module mx29_programmer #(
    parameter POWER_CYCLES = 520000,
    parameter PROGRAM_CYCLES = 4160,
    parameter ERASE_CYCLES = 6240000,
    parameter READ_TICKS = 1, WRITE_TICKS = 1
) (
    input wire clk, reset, start,
    input wire [7:0] command,
    input wire [21:0] address,
    input wire [7:0] data,
    output wire busy,
    output reg done,
    output reg [7:0] status,
    output reg [15:0] result,
    output wire [21:0] flash_a,
    inout wire [7:0] flash_d,
    output wire flash_ce_n, flash_oe_n, flash_we_n
);
    localparam POWER=0, IDLE=1, ISSUE=2, WAIT_BUS=3,
               POLL=4, WAIT_POLL=5, RESET_FLASH=6, WAIT_RESET=7,
               VERIFY=8, WAIT_VERIFY=9;
    reg [3:0] state;
    reg [2:0] step;
    reg [7:0] op, value;
    reg [21:0] target;
    reg [27:0] timer;
    reg recheck;
    reg bus_start, bus_write;
    reg [21:0] bus_addr;
    reg [7:0] bus_data;
    wire bus_done;
    wire [7:0] bus_result;
    assign busy = state != IDLE;
    mx29_bus #(.READ_TICKS(READ_TICKS), .WRITE_TICKS(WRITE_TICKS)) bus(.clk(clk), .reset(reset), .start(bus_start),
        .write_cycle(bus_write), .addr(bus_addr), .wdata(bus_data),
        .busy(), .done(bus_done), .rdata(bus_result),
        .flash_a(flash_a), .flash_d(flash_d), .flash_ce_n(flash_ce_n),
        .flash_oe_n(flash_oe_n), .flash_we_n(flash_we_n));

    always @(posedge clk) begin
        if (reset) begin
            state <= POWER; timer <= 0; done <= 0; status <= 0;
            result <= 0; step <= 0; op <= 0; value <= 0; target <= 0;
            recheck <= 0; bus_start <= 0; bus_write <= 0;
            bus_addr <= 0; bus_data <= 0;
        end else begin
            bus_start <= 0;
            done <= 0;
            if ((state == POLL || state == WAIT_POLL) && timer != 28'hfffffff)
                timer <= timer + 1'b1;
            case (state)
                POWER: if (timer >= POWER_CYCLES) state <= IDLE;
                       else timer <= timer + 1'b1;
                IDLE: if (start) begin
                    op <= command; target <= address; value <= data;
                    result <= 0; status <= 0; step <= 0; recheck <= 0;
                    if (command == 8'h14) state <= RESET_FLASH;
                    else if (command >= 8'h10 && command <= 8'h13) state <= ISSUE;
                    else begin status <= 8'h02; done <= 1; end
                end
                ISSUE: begin
                    bus_start <= 1;
                    bus_write <= 1;
                    bus_addr <= 22'h000aaa;
                    bus_data <= 8'haa;
                    if (op == 8'h10) begin
                        bus_write <= 0; bus_addr <= target;
                    end else case (step)
                        0: begin end
                        1: begin bus_addr <= 22'h000555; bus_data <= 8'h55; end
                        2: bus_data <= op == 8'h11 ? 8'ha0 : op == 8'h12 ? 8'h80 : 8'h90;
                        3: if (op == 8'h11) begin bus_addr <= target; bus_data <= value; end
                           else if (op == 8'h13) begin bus_write <= 0; bus_addr <= 0; end
                        4: if (op == 8'h13) begin bus_write <= 0; bus_addr <= 2; end
                           else begin bus_addr <= 22'h000555; bus_data <= 8'h55; end
                        5: begin bus_addr <= target; bus_data <= 8'h30; end
                        default: begin end
                    endcase
                    state <= WAIT_BUS;
                end
                WAIT_BUS: if (bus_done) begin
                    if (op == 8'h10) begin
                        result <= {8'b0, bus_result}; done <= 1; state <= IDLE;
                    end else if (op == 8'h13 && step == 4) begin
                        result[15:8] <= bus_result; state <= RESET_FLASH;
                    end else if ((op == 8'h11 && step == 3) || (op == 8'h12 && step == 5)) begin
                        timer <= 0; state <= POLL;
                    end else begin
                        if (op == 8'h13 && step == 3) result[7:0] <= bus_result;
                        step <= step + 1'b1; state <= ISSUE;
                    end
                end
                POLL: begin
                    bus_start <= 1; bus_write <= 0; bus_addr <= target;
                    state <= WAIT_POLL;
                end
                WAIT_POLL: if (bus_done) begin
                    // Datasheet Fig. 20: re-read Q7 if Q5 becomes set.
                    if (bus_result[7] == (op == 8'h12 ? 1'b1 : value[7]))
                        state <= VERIFY;
                    else if (recheck) begin status <= 8'h04; state <= RESET_FLASH; end
                    else if (timer >= (op == 8'h12 ? ERASE_CYCLES : PROGRAM_CYCLES)) begin
                        status <= 8'h03; state <= RESET_FLASH;
                    end else begin recheck <= bus_result[5]; state <= POLL; end
                end
                VERIFY: begin
                    bus_start <= 1; bus_write <= 0; bus_addr <= target;
                    state <= WAIT_VERIFY;
                end
                WAIT_VERIFY: if (bus_done) begin
                    result <= {8'b0, bus_result};
                    if (bus_result != (op == 8'h12 ? 8'hff : value)) status <= 8'h05;
                    state <= RESET_FLASH;
                end
                RESET_FLASH: begin
                    bus_start <= 1; bus_write <= 1; bus_addr <= 0; bus_data <= 8'hf0;
                    state <= WAIT_RESET;
                end
                WAIT_RESET: if (bus_done) begin done <= 1; state <= IDLE; end
                default: begin status <= 8'h06; state <= RESET_FLASH; end
            endcase
        end
    end
endmodule
