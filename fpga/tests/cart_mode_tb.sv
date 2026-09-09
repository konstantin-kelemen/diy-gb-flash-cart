`timescale 1ns/1ps
module cart_mode_tb;
    reg clk=0, reset=1, game_present=1, game_idle=1;
    reg programmer_active=0, flash_busy=0, flash_done=0;
    reg [7:0] flash_status=0;
    wire game_enable, programmer_enable, accept_requests, cleanup_start, cleanup, fault;
    always #5 clk=~clk;
    cart_mode #(.DETECT_TICKS(8),.GUARD_TICKS(4)) dut(.*);
    task ticks(input integer n); repeat(n) @(negedge clk); endtask
    initial begin
        ticks(3); reset=0; ticks(20);
        if(!game_enable || programmer_enable) $fatal(1,"boot GAME");
        game_present=0; ticks(2); game_present=1; ticks(20);
        if(!game_enable) $fatal(1,"power glitch");
        game_idle=0; game_present=0; ticks(20);
        if(!game_enable) $fatal(1,"GAME transaction interrupted");
        game_idle=1; ticks(8);
        if(!programmer_enable || !accept_requests) $fatal(1,"PROGRAMMER entry");
        programmer_active=1; flash_busy=1; game_present=1; ticks(20);
        if(!programmer_enable || accept_requests || cleanup_start) $fatal(1,"drain active block");
        programmer_active=0; ticks(5); if(cleanup) $fatal(1,"busy flash interrupted");
        flash_busy=0; wait(cleanup_start); ticks(2);
        flash_done=1; ticks(1); flash_done=0; ticks(8);
        if(!game_enable) $fatal(1,"GAME handover");
        game_present=0; ticks(25); game_present=1; wait(cleanup_start); ticks(2);
        flash_status=3; flash_done=1; ticks(1); flash_done=0; ticks(8);
        if(!fault || game_enable || programmer_enable) $fatal(1,"cleanup fault not isolated");
        reset=1; game_present=0; ticks(3); reset=0; ticks(25);
        if(!programmer_enable) $fatal(1,"boot PROGRAMMER");
        $display("PASS cart_mode: both startup modes, debounce, drain, guard, cleanup failure"); $finish;
    end
    always @(negedge clk) if(game_enable && programmer_enable) $fatal(1,"dual owner");
    initial begin #10000; $fatal(1,"timeout"); end
endmodule
