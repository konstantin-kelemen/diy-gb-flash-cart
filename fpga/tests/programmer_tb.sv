`timescale 1ns/1ns
module programmer_tb;
    reg clk=0, reset=1;
    always #240 clk=~clk;
    reg cs=1, sck=0, mosi=0;
    wire miso, start, busy, done;
    wire [7:0] command, data, op_status;
    wire [21:0] address, fa;
    wire [15:0] result;
    tri [7:0] fd;
    wire ce, oe, we;
    programmer_spi spi(.clk(clk), .reset(reset), .spi_cs_n(cs), .spi_sck(sck),
        .spi_mosi(mosi), .spi_miso(miso), .busy(busy), .done(done),
        .operation_status(op_status), .result(result), .start(start),
        .command(command), .address(address), .data(data), .seen());
    mx29_programmer #(.POWER_CYCLES(20), .PROGRAM_CYCLES(100), .ERASE_CYCLES(300))
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
    assign fd = !ce && !oe && we ? read_data : 8'bz;
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
    function [63:0] packet;
        input [47:0] payload;
        reg [15:0] crc;
        integer j;
        begin
            crc=16'hffff;
            for(j=47;j>=0;j=j-1) crc=(crc<<1)^((crc[15]^payload[j])?16'h1021:0);
            packet={payload,crc};
        end
    endfunction
    task bit_transfer;
        input tx;
        output rx;
        begin mosi=tx; #50000; sck=1; #100; rx=miso; #49900; sck=0; end
    endtask
    task send;
        input [63:0] frame;
        input integer bits;
        integer j;
        reg ignored;
        begin
            cs=0; #25000;
            for(j=0;j<bits;j=j+1) bit_transfer(j<64 ? frame[63-j] : 1'b0, ignored);
            #25000; cs=1; #25000;
            if(miso!==1'bz) $fatal(1, "MISO not released");
        end
    endtask
    task query;
        input [7:0] op;
        output [63:0] reply;
        integer j;
        reg rx;
        begin
            cs=0; #25000; reply=0;
            for(j=7;j>=0;j=j-1) bit_transfer(op[j],rx);
            for(j=0;j<64;j=j+1) begin bit_transfer(0,rx); reply={reply[62:0],rx}; end
            #25000; cs=1; #25000;
        end
    endtask
    reg [7:0] seq=0;
    reg [63:0] response;
    task operation;
        input [7:0] op;
        input [23:0] addr;
        input [7:0] value, expected_status;
        begin
            seq=seq+1;
            send(packet({op,seq,addr,value}),64);
            query(2,response);
            if(response!==packet(response[63:16])) $fatal(1,"response CRC");
            if(response[63:40]!=={8'h50,seq,expected_status} || response[23:16]!==op)
                $fatal(1,"bad response %h op=%h expected status=%h",response,op,expected_status);
        end
    endtask
    integer before_writes, length;
    initial begin
        #5000; reset=0; #50000;
        if(writes!=0 || !we || !ce || !oe) $fatal(1,"startup writes");
        query(1,response);
        if(response!==64'h4742464302000100) $fatal(1,"version");
        operation(8'h11,0,8'ha5,9);
        if(writes!=0) $fatal(1,"locked write");
        operation(8'h20,0,8'ha5,0);
        before_writes=writes;
        for(length=1;length<64;length=length+1)
            send(packet({8'h12,8'h90,24'b0,8'b0}),length);
        send(packet({8'h12,8'h90,24'b0,8'b0}),65);
        send(packet({8'h12,8'h90,24'b0,8'b0}),160);
        if(writes!=before_writes) $fatal(1,"malformed request wrote Flash");
        send(packet({8'h12,8'h90,24'b0,8'b0})^64'b1,64);
        if(writes!=before_writes) $fatal(1,"CRC error wrote Flash");
        operation(8'h11,0,8'ha5,9);
        operation(8'h20,0,8'ha5,0);
        operation(8'h11,24'h400000,8'ha5,8);
        operation(8'h33,0,0,2);
        operation(8'h13,0,0,0);
        if(response[39:24]!==16'hc2a8 || id_mode) $fatal(1,"ID/reset");
        memory[8192]=8'h55;
        operation(8'h12,0,0,0);
        if(memory[0]!==8'hff || memory[8191]!==8'hff || memory[8192]!==8'h55)
            $fatal(1,"sector isolation");
        operation(8'h11,0,8'ha5,0);
        operation(8'h10,0,0,0);
        if(response[39:32]!==8'ha5) $fatal(1,"readback");
        memory[22'h3fffff]=8'hff;
        operation(8'h11,24'h3fffff,8'h3c,0);
        operation(8'h10,24'h3fffff,0,0);
        if(response[39:32]!==8'h3c) $fatal(1,"last address");
        fault=3;
        operation(8'h11,2,8'h5a,0);
        fault=1;
        operation(8'h11,1,8'ha5,4);
        operation(8'h11,1,8'ha5,9);
        operation(8'h20,0,8'ha5,0);
        fault=2;
        operation(8'h11,1,8'ha5,3);
        operation(8'h20,0,8'ha5,0);
        operation(8'h12,0,0,3);
        fault=0;
        operation(8'h20,0,8'ha5,0);
        operation(8'h14,0,0,0);
        operation(8'h21,0,0,0);
        before_writes=writes;
        operation(8'h12,0,0,9);
        if(writes!=before_writes || !ce || !oe || !we) $fatal(1,"lock/end idle");
        $display("PASS programmer: CRC/framing/lock/ID/erase/program/read/bounds/Q5/timeout");
        $finish;
    end
    initial begin #2000000000; $fatal(1,"test timeout"); end
endmodule
