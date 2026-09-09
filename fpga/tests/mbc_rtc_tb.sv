`timescale 1ns/1ps
module mbc_rtc_tb;
    reg clk=0, reset=1, write_toggle=0, latch_toggle=0;
    reg [2:0] write_register=0, read_register=0;
    reg [7:0] write_data=0;
    wire [7:0] read_data;
    always #5 clk=~clk;
    mbc_rtc #(.CLOCK_HZ(100)) dut(.*);
    task wr(input [2:0] r,input [7:0] d);
        begin @(negedge clk); write_register=r; write_data=d; write_toggle=~write_toggle; repeat(5) @(negedge clk); end
    endtask
    task latch;
        begin @(negedge clk); latch_toggle=~latch_toggle; repeat(5) @(negedge clk); end
    endtask
    task check(input [2:0] r,input [7:0] d);
        begin read_register=r; #1; if(read_data!==d) $fatal(1,"RTC r%0d got %h expected %h",r,read_data,d); end
    endtask
    initial begin
        #30; reset=0; wr(4,'h40); wr(0,59); wr(1,59); wr(2,23); wr(3,255); wr(4,'h41);
        latch(); check(0,59); check(1,59); check(2,23); check(3,255); check(4,'h41);
        #2200; latch(); check(0,59); // HALT
        wr(4,1); #1050; // 511 дней 23:59:59 -> день 0, carry
        check(0,59); // Снимок не изменяется до следующего latch.
        latch(); check(0,0); check(1,0); check(2,0); check(3,0); check(4,'h80);
        wr(4,'h40); latch(); check(4,'h40); // Очистка carry и halt.
        wr(0,12); latch(); check(0,12);
        wr(0,34); check(0,12); latch(); check(0,34);
        check(7,'hff);
        reset=1; #30; reset=0; latch(); check(0,0); check(4,0);
        $display("PASS mbc_rtc: ticks, halt, latch, writes, day rollover, sticky carry, reset"); $finish;
    end
endmodule
