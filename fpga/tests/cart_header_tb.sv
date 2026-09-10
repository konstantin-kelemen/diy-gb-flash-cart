`timescale 1ns/1ps
module cart_header_tb;
    reg clk=0, reset=1;
    always #9.4 clk=~clk;
    wire [21:0] address;
    wire done, multicart;
    wire [7:0] cart_type, rom_size, ram_size;
    reg [7:0] kind=1, size=5, ram=0;
    reg [7:0] primary_logo[0:47], secondary_logo[0:47];
    reg [7:0] rom_data;
    wire [7:0] data;
    assign #70 data=rom_data;
    cart_header dut(.*);
    always @* begin
        rom_data=8'hff;
        if(address==22'h147) rom_data=kind;
        else if(address==22'h148) rom_data=size;
        else if(address==22'h149) rom_data=ram;
        else if(address>=22'h104 && address<=22'h133) rom_data=primary_logo[address-22'h104];
        else if(address>=22'h40104 && address<=22'h40133) rom_data=secondary_logo[address-22'h40104];
    end
    task scan(input expected);
        begin
            reset=1; #100; reset=0;
            wait(done); #20;
            if(cart_type!==kind || rom_size!==size || ram_size!==ram)
                $fatal(1,"metadata changed");
            if(multicart!==expected) $fatal(1,"MBC1M got %b expected %b",multicart,expected);
        end
    endtask
    integer i, bad;
    initial begin
        // A nonblank template is read from ROM; no specific logo is hardcoded.
        for(i=0;i<48;i=i+1) begin primary_logo[i]=i^8'ha5; secondary_logo[i]=i^8'ha5; end
        scan(1);
        for(bad=0;bad<48;bad=bad+1) begin
            secondary_logo[bad]=secondary_logo[bad]^8'h01;
            scan(0);
            secondary_logo[bad]=secondary_logo[bad]^8'h01;
            primary_logo[bad]=primary_logo[bad]^8'h80;
            scan(0);
            primary_logo[bad]=primary_logo[bad]^8'h80;
        end
        // Reset during a pair read must discard its byte and mismatch flags.
        reset=1; #100; reset=0; #2000; scan(1);
        kind=2; scan(1); kind=3; scan(1);
        kind=1; size=4; scan(0); size=5; kind=8'h19; scan(0); kind=1;
        for(i=0;i<48;i=i+1) begin primary_logo[i]=0; secondary_logo[i]=0; end
        scan(0);
        for(i=0;i<48;i=i+1) begin primary_logo[i]=8'hff; secondary_logo[i]=8'hff; end
        scan(0);
        // The last byte must participate in the blank-template checks, too.
        primary_logo[47]=8'h7e; secondary_logo[47]=8'h7e; scan(1);
        $display("PASS cart_header: ROM comparison, all 48 positions, blanks, reset, mapper/size gates");
        $finish;
    end
    initial begin #10000000; $fatal(1,"timeout"); end
endmodule
