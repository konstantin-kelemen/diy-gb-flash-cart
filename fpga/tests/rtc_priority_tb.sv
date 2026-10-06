`timescale 1ns/1ps
module rtc_priority_tb;
    reg clk=0, reset=1, write_toggle=0, latch_toggle=0;
    always #5 clk=~clk;
    reg [2:0] write_register=0, read_register=0;
    reg [7:0] write_data=0;
    wire [7:0] read_data, one_data;
    mbc_rtc #(.CLOCK_HZ(3),.SAME_CLOCK(1)) dut(.*);
    mbc_rtc #(.CLOCK_HZ(1),.SAME_CLOCK(1)) one(
        .clk(clk),.reset(reset),.write_toggle(1'b0),.latch_toggle(1'b0),
        .write_register(3'b0),.write_data(8'b0),.read_register(3'b0),.read_data(one_data));
    initial begin
        repeat(2) @(negedge clk); reset=0;
        // На третьем такте: секундный тик, запись seconds, latch.
        repeat(2) @(negedge clk);
        write_data=12; write_toggle=1; latch_toggle=1;
        @(negedge clk);
        if(dut.seconds!==12 || dut.divider!==0 || read_data!==0)
            $fatal(1,"write/tick/latch priority");
        if(one.seconds!==3 || one.divider!==0) $fatal(1,"CLOCK_HZ=1");
        if($bits(dut.divider)!=2 || $bits(one.divider)!=1) $fatal(1,"divider width");
        // Последовательные записи без промежуточных свободных clk.
        write_register=1; write_data=34; write_toggle=0;
        @(negedge clk); write_register=2; write_data=23; write_toggle=1;
        @(negedge clk); latch_toggle=0;
        @(negedge clk); read_register=1; #1;
        if(read_data!==34) $fatal(1,"consecutive minute write");
        read_register=2; #1; if(read_data!==23) $fatal(1,"consecutive hour write");
        @(negedge clk); reset=1;
        repeat(2) @(negedge clk); reset=0;
        @(negedge clk);
        if(dut.hours!==0 || dut.minutes!==0) $fatal(1,"power reset replayed event");
        $display("PASS rtc_priority: tick/write/latch order, consecutive events, divider boundaries");
        $finish;
    end
endmodule
