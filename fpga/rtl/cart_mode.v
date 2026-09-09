`timescale 1ns/1ps
// Присутствие Game Boy задаётся отдельным аппаратным детектором, не RESET#.
// Выходы one-hot. Между владельцами все CE#/OE#/WE# отключены.
module cart_mode #(
    parameter integer DETECT_TICKS=106400,
    parameter integer GUARD_TICKS=16
) (
    input wire clk, reset, game_present,
    input wire game_idle, programmer_active, flash_busy, flash_done,
    input wire [7:0] flash_status,
    output wire game_enable, programmer_enable, accept_requests,
    output reg cleanup_start=0,
    output wire cleanup,
    output wire fault
);
    (* syn_preserve=1 *) reg [1:0] present_sync=0;
    reg present_stable=0, detect_valid=0;
    localparam DETECT_WIDTH=DETECT_TICKS<2 ? 1 : $clog2(DETECT_TICKS);
    localparam GUARD_WIDTH=GUARD_TICKS<2 ? 1 : $clog2(GUARD_TICKS);
    reg [DETECT_WIDTH-1:0] detect_count=0;
    reg [GUARD_WIDTH-1:0] guard_count=0;
    localparam WAIT_DETECT=0, GAME_GAP=1, GAME=2, PROGRAM_GAP=3,
               PROGRAM=4, DRAIN=5, CLEAN_START=6, CLEAN_WAIT=7, FAILED=8;
    reg [3:0] state=WAIT_DETECT;
    always @(posedge clk) begin
        if(reset) begin
            present_sync<=0; present_stable<=0; detect_valid<=0; detect_count<=0;
            guard_count<=0; state<=WAIT_DETECT; cleanup_start<=0;
        end else begin
            present_sync<={present_sync[0],game_present};
            if(present_sync[1]!=present_sync[0]) begin
                detect_count<=0;
            end else if(detect_count<DETECT_TICKS-1) detect_count<=detect_count+1'b1;
            else begin present_stable<=present_sync[1]; detect_valid<=1; end
            cleanup_start<=0;
            case(state)
                WAIT_DETECT: if(detect_valid) begin
                    guard_count<=0; state<=present_stable ? GAME_GAP : PROGRAM_GAP;
                end
                GAME_GAP: begin
                    if(!present_stable) begin guard_count<=0; state<=PROGRAM_GAP; end
                    else if(guard_count==GUARD_TICKS-1) state<=GAME;
                    else guard_count<=guard_count+1'b1;
                end
                GAME: if(!present_stable && game_idle) begin guard_count<=0; state<=PROGRAM_GAP; end
                PROGRAM_GAP: begin
                    if(present_stable) begin guard_count<=0; state<=GAME_GAP; end
                    else if(guard_count==GUARD_TICKS-1) state<=PROGRAM;
                    else guard_count<=guard_count+1'b1;
                end
                PROGRAM: if(present_stable) state<=DRAIN;
                DRAIN: if(!programmer_active && !flash_busy) state<=CLEAN_START;
                CLEAN_START: begin cleanup_start<=1; state<=CLEAN_WAIT; end
                CLEAN_WAIT: if(flash_done) begin
                    if(flash_status!=0) state<=FAILED;
                    else begin guard_count<=0; state<=GAME_GAP; end
                end
                FAILED: ; // Ошибка возврата Flash в read-array: GAME не запускается.
                default: state<=FAILED;
            endcase
        end
    end
    assign game_enable=state==GAME;
    assign programmer_enable=state==PROGRAM || state==DRAIN || state==CLEAN_START || state==CLEAN_WAIT;
    // Синхронизированный положительный сигнал сразу запрещает новые команды,
    // даже до окончания фильтра. Принятый блок завершается целиком.
    assign accept_requests=state==PROGRAM && !present_sync[1] && !present_stable;
    assign cleanup=state==CLEAN_START || state==CLEAN_WAIT;
    assign fault=state==FAILED;
endmodule
