`timescale 1ns/1ps
module game_rom_tb;
    reg [15:0] gb_a = 16'hffff;
    reg gb_rd_n = 1;
    wire [7:0] gb_d, flash_d;
    wire [21:0] flash_a;
    wire data_oe_n, data_dir, flash_ce_n, flash_oe_n, flash_we_n;
    reg [7:0] memory [0:32767];
    reg cpu_drive = 0;
    reg [7:0] cpu_data = 8'ha5;
    wire [7:0] gb_bus;
    integer i, reads = 0;
    reg [1023:0] rom_file;
    top dut(.*);

    // Model 70 ns asynchronous Flash access and 10 ns shifter propagation.
    assign #70 flash_d = (!flash_ce_n && !flash_oe_n)
                         ? memory[flash_a[14:0]] : 8'hzz;
    assign #10 gb_bus = !data_oe_n && data_dir ? gb_d : 8'hzz;
    assign gb_bus = cpu_drive ? cpu_data : 8'hzz;

    task check_read(input [15:0] address);
        begin
            gb_a = address;
            gb_rd_n = 0;
            #100;
            if (flash_a !== {7'b0,address[14:0]} || flash_we_n !== 1 ||
                flash_ce_n !== 0 || flash_oe_n !== 0 ||
                data_oe_n !== 0 || data_dir !== 1 ||
                gb_bus !== memory[address])
                $fatal(1,"ROM read failed at %h: got %h expected %h",address,gb_bus,memory[address]);
            reads = reads + 1;
        end
    endtask
    task check_inactive;
        begin
            #100;
            if (data_oe_n !== 1 || flash_ce_n !== 1 ||
                flash_oe_n !== 1 || flash_we_n !== 1 ||
                gb_bus !== (cpu_drive ? cpu_data : 8'hzz))
                $fatal(1,"Bus not released at %h RD#=%b",gb_a,gb_rd_n);
        end
    endtask
    initial begin
        for(i=0;i<32768;i=i+1) memory[i] = $random;
        if ($value$plusargs("ROM=%s",rom_file)) $readmemh(rom_file,memory);
        check_inactive();
        // Sequential reads including 3fff/4000 and 7fff; RD stays asserted.
        for(i=0;i<32768;i=i+1) check_read(i);
        // Every non-ROM address must release the cartridge data bus.
        for(i=32768;i<65536;i=i+1) begin
            gb_a=i; check_inactive();
        end
        // Separate RD pulses, random access, and CPU writes in ROM space.
        for(i=0;i<1024;i=i+1) begin
            gb_rd_n=1; check_inactive();
            cpu_drive=1; gb_a=$random; check_inactive();
            cpu_drive=0; gb_a=gb_a & 16'h7fff; check_read(gb_a);
        end
        gb_a=16'h8000; check_inactive();
        check_read(16'h0000);
        gb_rd_n=1; check_inactive();
        $display("PASS game_rom: %0d reads, all non-ROM addresses released, CPU writes isolated",reads);
        $finish;
    end
    always @(negedge flash_we_n) $fatal(1,"Flash write enabled");
endmodule
