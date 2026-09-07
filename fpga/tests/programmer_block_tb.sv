`timescale 1ns/1ps
module programmer_block_tb #(parameter real CLOCK_HALF=9.4);
    reg clk=0, reset=1;
    always #(CLOCK_HALF) clk=~clk;
    reg cs=1, sck=0, mosi=0;
    wire miso, start, busy, done;
    wire [7:0] command, data, op_status;
    wire [21:0] address, fa;
    wire [15:0] result;
    tri [7:0] fd;
    wire ce, oe, we;
    programmer_block spi(.clk(clk), .reset(reset), .spi_cs_n(cs), .spi_sck(sck),
        .spi_mosi(mosi), .spi_miso(miso), .busy(busy), .done(done),
        .operation_status(op_status), .result(result), .start(start),
        .command(command), .address(address), .data(data), .seen(), .active());
    mx29_programmer #(.POWER_CYCLES(20), .PROGRAM_CYCLES(2000), .ERASE_CYCLES(6000), .READ_TICKS(4), .WRITE_TICKS(32))
        flash(.clk(clk), .reset(reset), .start(start), .command(command),
        .address(address), .data(data), .busy(busy), .done(done), .status(op_status),
        .result(result), .flash_a(fa), .flash_d(fd),
        .flash_ce_n(ce), .flash_oe_n(oe), .flash_we_n(we));

    // Behavioral x8 command model. Checks physical write edges and unlock addresses.
    reg [7:0] memory [0:4194303];
    integer model_state=0, writes=0, i;
    reg id_mode=0;
    reg [1:0] fault=0;
    reg fault_active=0;
    reg expected_bit=0;
    wire [7:0] read_data = id_mode ? (fa==0 ? 8'hc2 : fa==2 ? 8'ha8 : 8'hff) :
        fault_active ? {~expected_bit, 1'b0, (fault==1 || fault==3), 5'b0} : memory[fa];
    assign #(70,70,30) fd = !ce && !oe && we ? read_data : 8'bz;
    // Completion racing with Q5: the mandatory second Q7 read must accept success.
    always @(posedge oe) if (!reset && fault==3) fault_active=0;
    always @(negedge we) if (!reset) begin
        if (ce || !oe || ^fd === 1'bx) $fatal(1, "unsafe write bus");
    end
    always @(posedge we) if (!reset && !ce) begin
        writes=writes+1;
        if (model_state==3) begin
            if (fault != 0) begin
                fault_active=1; expected_bit=fd[7];
                if (fault==3) memory[fa]=memory[fa] & fd;
            end
            else memory[fa]=memory[fa] & fd;
            model_state=0;
        end else if (fd==8'hf0) begin model_state=0; id_mode=0; fault_active=0; end
        else case (model_state)
            0: begin
                if (fa!=22'haaa || fd!=8'haa) $fatal(1, "unlock1");
                model_state=1;
            end
            1: begin
                if (fa!=22'h555 || fd!=8'h55) $fatal(1, "unlock2");
                model_state=2;
            end
            2: begin
                if (fa!=22'haaa) $fatal(1, "command address");
                case (fd)
                    8'ha0: model_state=3;
                    8'h80: model_state=4;
                    8'h90: begin id_mode=1; model_state=0; end
                    default: $fatal(1, "command data");
                endcase
            end
            4: begin
                if (fa!=22'haaa || fd!=8'haa) $fatal(1, "erase unlock1");
                model_state=5;
            end
            5: begin
                if (fa!=22'h555 || fd!=8'h55) $fatal(1, "erase unlock2");
                model_state=6;
            end
            6: begin
                if (fd!=8'h30) $fatal(1, "erase command");
                if (fault != 0) begin fault_active=1; expected_bit=1; end
                else if (fa<65536)
                    for (i=(fa/8192)*8192; i<(fa/8192)*8192+8192; i=i+1) memory[i]=8'hff;
                else
                    for (i=(fa/65536)*65536; i<(fa/65536)*65536+65536; i=i+1) memory[i]=8'hff;
                model_state=0;
            end
        endcase
    end
    function [15:0] crc_byte;
        input [15:0] c0; input [7:0] b;
        reg [15:0] c; integer k;
        begin c=c0^{b,8'b0}; for(k=0;k<8;k=k+1) c=(c<<1)^(c[15] ? 16'h1021:16'h0); crc_byte=c; end
    endfunction
    reg [7:0] tx[0:1033], rx[0:1033];
    reg [7:0] seq=0;
    integer n, j, before_writes;
    realtime write_edge, read_edge;
    always @(negedge we) write_edge=$realtime;
    always @(posedge we) if(!reset && !ce && $realtime-write_edge<35)
        $fatal(1,"WE pulse shorter than 35 ns");
    always @(negedge oe) read_edge=$realtime;
    always @(posedge clk) if(!reset && flash.bus.state==8 && flash.bus.advance &&
        $realtime-read_edge<70) $fatal(1,"Flash sampled before 70 ns");
    reg [15:0] crc;
    task byte_transfer;
        input [7:0] value; output [7:0] out;
        integer b;
        begin
            for(b=7;b>=0;b=b-1) begin
                mosi=value[b]; #125; sck=1; #1; out[b]=miso; #124; sck=0;
            end
        end
    endtask
    task request_frame;
        input [7:0] op; input [23:0] addr; input integer count;
        input [7:0] key; input integer extra; input corrupt;
        integer k, size; reg [7:0] ignored;
        begin
            seq=seq+1;
            tx[0]=op; tx[1]=seq; tx[2]=addr[23:16]; tx[3]=addr[15:8]; tx[4]=addr[7:0];
            tx[5]=count>>8; tx[6]=count; tx[7]=key;
            size=8+(op==8'h31 ? count:0); crc=16'hffff;
            for(k=0;k<size;k=k+1) crc=crc_byte(crc,tx[k]);
            tx[size]=crc[15:8]; tx[size+1]=crc[7:0]^{7'b0,corrupt};
            cs=0; #2000;
            for(k=0;k<size+2+extra;k=k+1) byte_transfer(tx[k],ignored);
            #2000; cs=1; #2000;
            if(miso!==1'bz) $fatal(1,"MISO not released");
        end
    endtask
    task query;
        input [7:0] op; input integer count;
        integer k; reg [7:0] ignored;
        begin
            cs=0; #2000; byte_transfer(op,ignored);
            for(k=0;k<count;k=k+1) byte_transfer(0,rx[k]);
            #2000; cs=1; #2000;
        end
    endtask
    task finish_op;
        input [7:0] op, expected;
        integer polls;
        begin
            query(2,10); polls=0;
            while(rx[2]==1 && polls<2000) begin #2000; query(2,10); polls=polls+1; end
            crc=16'hffff;
            for(integer k=0;k<8;k=k+1) crc=crc_byte(crc,rx[k]);
            if({rx[8],rx[9]}!==crc) $fatal(1,"status CRC %h%h != %h",rx[8],rx[9],crc);
            if(rx[0]!==8'h50 || rx[1]!==seq || rx[2]!==expected || rx[3]!==op)
                $fatal(1,"status seq=%h/%h status=%h/%h op=%h/%h",rx[1],seq,rx[2],expected,rx[3],op);
        end
    endtask
    initial begin
        for(n=0;n<4194304;n=n+1) memory[n]=(n^(n>>8)^(n>>16))&255;
        #5000; reset=0; #50000;
        query(1,8);
        if({rx[0],rx[1],rx[2],rx[3],rx[4],rx[5],rx[6],rx[7]}!==64'h4742464303000004)
            $fatal(1,"version");
        before_writes=writes;
        // Unaligned full block, crosses byte and address boundaries.
        request_frame(8'h30,24'h00ff80,1024,0,0,0); finish_op(8'h30,0);
        if({rx[7],rx[6]}!==16'd1024) $fatal(1,"read count");
        query(3,1026); crc=16'hffff;
        for(n=0;n<1024;n=n+1) begin
            if(rx[n]!==memory[24'h00ff80+n]) $fatal(1,"read byte %d: %h",n,rx[n]);
            crc=crc_byte(crc,rx[n]);
        end
        if({rx[1024],rx[1025]}!==crc || writes!=before_writes) $fatal(1,"read CRC/writes");
        request_frame(8'h30,24'h3fffff,1,0,0,0); finish_op(8'h30,0);
        query(3,3); if(rx[0]!==memory[22'h3fffff]) $fatal(1,"last address");
        request_frame(8'h30,24'h3fffff,2,0,0,0); finish_op(8'h30,8);
        request_frame(8'h30,0,0,0,0,0); finish_op(8'h30,8);
        request_frame(8'h30,0,1025,0,0,0); finish_op(8'h30,8);
        request_frame(8'h31,0,1,0,0,0); finish_op(8'h31,9);
        request_frame(8'h20,0,0,8'ha5,0,0); finish_op(8'h20,0);
        request_frame(8'h13,0,0,0,0,0); finish_op(8'h13,0);
        if({rx[5],rx[4]}!==16'ha8c2 || id_mode) $fatal(1,"ID");
        request_frame(8'h12,0,0,0,0,0); finish_op(8'h12,0);
        for(n=0;n<1024;n=n+1) tx[8+n]=n&255;
        request_frame(8'h31,24'h000100,1024,0,0,0); finish_op(8'h31,0);
        for(n=0;n<1024;n=n+1)
            if(memory[256+n]!== (n&255)) $fatal(1,"program byte %d",n);
        if(memory[255]!==8'hff || memory[1280]!==8'hff) $fatal(1,"write boundary");
        before_writes=writes;
        request_frame(8'h31,24'h002000,3,0,0,1); finish_op(8'h31,7);
        request_frame(8'h31,24'h002000,3,0,0,0); finish_op(8'h31,9);
        request_frame(8'h20,0,0,8'ha5,0,0); finish_op(8'h20,0);
        request_frame(8'h31,24'h002000,3,0,-1,0);
        request_frame(8'h31,24'h002000,3,0,1,0);
        if(writes!=before_writes) $fatal(1,"bad framing wrote Flash");
        fault=1; tx[8]=8'ha5;
        request_frame(8'h31,24'h002000,1,0,0,0); finish_op(8'h31,4);
        request_frame(8'h31,24'h002000,1,0,0,0); finish_op(8'h31,9);
        fault=0;
        request_frame(8'h20,0,0,8'ha5,0,0); finish_op(8'h20,0);
        seq=seq-1;
        request_frame(8'h12,0,0,0,0,0); finish_op(8'h12,10);
        request_frame(8'h20,0,0,8'ha5,0,0); finish_op(8'h20,0);
        fault=2; tx[8]=8'ha5;
        request_frame(8'h31,24'h002000,1,0,0,0);
        // Frame beginning while busy must not commit even if busy clears mid-frame.
        request_frame(8'h12,0,0,0,0,0);
        seq=seq-1; finish_op(8'h31,3);
        fault=0;
        request_frame(8'h21,0,0,0,0,0); finish_op(8'h21,0);
        $display("PASS block programmer: 4 MHz SPI, block CRC/read/write/ID/erase/bounds/lock/framing/Q5");
        $finish;
    end
    initial begin #200000000; $fatal(1,"timeout"); end
endmodule
