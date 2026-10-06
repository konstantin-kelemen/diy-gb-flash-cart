`timescale 1ns/1ps
module mapper_race_tb;
    reg clk=0;
    always #9.4 clk=~clk;
    reg configured=0, multicart=0;
    reg [7:0] cart_type=8'hff, rom_size=8'hff, ram_size=8'hff;
    reg [15:0] gb_a=0;
    reg [7:0] gb_data=0;
    reg gb_rd_n=1, gb_wr_n=1, gb_cs_n=1, gb_res_n=0;
    wire config_ready, supported, ram_access, nibble_ram, rtc_access;
    wire [21:0] rom_address;
    wire [16:0] ram_address;
    wire [2:0] rtc_register, rtc_write_register;
    wire [7:0] rtc_write_data;
    wire rtc_write_toggle, rtc_latch_toggle;
    cart_mapper dut(.*);
    wire [7:0] rtc_data;
    mbc_rtc #(.CLOCK_HZ(100),.SAME_CLOCK(1)) rtc(
        .clk(clk),.reset(1'b0),.write_toggle(rtc_write_toggle),
        .latch_toggle(rtc_latch_toggle),.write_register(rtc_write_register),
        .write_data(rtc_write_data),.read_register(rtc_register),.read_data(rtc_data));
    integer events=0, writes=0, latches=0, phase, duration, delay_data;
    reg old_write=0, old_latch=0;
    always @(negedge clk) begin
        if(dut.write_fire) events=events+1;
        if(rtc_write_toggle!=old_write) writes=writes+1;
        if(rtc_latch_toggle!=old_latch) latches=latches+1;
        old_write=rtc_write_toggle; old_latch=rtc_latch_toggle;
    end
    task wr(input [15:0] a,input [7:0] d,input integer phase_ns,
            input integer low_ns,input integer data_ns);
        integer before_events;
        begin
            @(negedge clk); #(phase_ns);
            before_events=events;
            gb_a=a; gb_cs_n=!(a>=16'ha000 && a<=16'hbfff);
            gb_data=8'hff; gb_wr_n=0;
            #(data_ns); gb_data=d;
            #(low_ns-data_ns); gb_wr_n=1;
            // Шина немедленно меняется у конца импульса: применять снимок.
            gb_a=16'hc000; gb_data=~d; gb_cs_n=1;
            #80;
            if(events!=before_events+1) $fatal(1,"lost/duplicate write before=%0d after=%0d supported=%b reset=%b",before_events,events,supported,dut.mapper_reset);
        end
    endtask
    initial begin
        #50; cart_type=8'h10; rom_size=7; ram_size=5;
        #50; configured=1; gb_res_n=1; #100;
        wr(0,8'ha,0,80,0);
        wr(16'h4000,12,0,80,0); wr(16'ha000,8'h40,0,80,0); // HALT
        wr(16'h4000,8,0,80,0);
        for(phase=0;phase<19;phase=phase+1)
            for(duration=80;duration<=160;duration=duration+40)
                for(delay_data=0;delay_data<=15;delay_data=delay_data+5) begin
                    wr(16'ha000,phase+1,phase,duration,delay_data);
                    wr(16'h6000,0,phase,80,0); wr(16'h6000,1,phase,80,0);
                    if(rtc_data!==phase+1) $fatal(1,"RTC payload/latch");
                end
        if(writes!=229 || latches!=228) $fatal(1,"RTC event count");
        // Длинный LOW остаётся одной записью, даже при изменении данных.
        wr(16'h2000,27,7,1000,0); gb_a=16'h4000; #1;
        if(rom_address!==27*16384) $fatal(1,"bank snapshot");
        // Отпускание /WR между захватом и применением: не читать живую шину.
        @(negedge clk); gb_a=16'h2000; gb_data=42; gb_wr_n=0;
        wait(dut.write_pending); #1;
        gb_wr_n=1; gb_a=16'h3000; gb_data=99;
        #80; gb_a=16'h4000; #1;
        if(rom_address!==42*16384) $fatal(1,"trailing edge payload race");
        for(phase=0;phase<19;phase=phase+1) begin
            @(negedge clk); #(phase); gb_res_n=0; gb_wr_n=0;
            #40; gb_res_n=1; #10; gb_wr_n=1; #100;
            if(dut.bank!==1 || dut.enabled!==0) $fatal(1,"reset release");
        end
        // Сброс отменяет ещё не применённую транзакцию.
        gb_a=16'h2000; gb_data=99; gb_wr_n=0;
        wait(dut.write_pending); #1; gb_res_n=0; gb_wr_n=1;
        #40; gb_res_n=1; #100;
        if(dut.bank!==1) $fatal(1,"pending reset write");
        if(writes!=229 || latches!=228) $fatal(1,"false RTC reset event");
        $display("PASS mapper_race: phases, pulse lengths, delayed payload, snapshot, event count, reset");
        $finish;
    end
    initial begin #1000000; $fatal(1,"timeout"); end
endmodule
