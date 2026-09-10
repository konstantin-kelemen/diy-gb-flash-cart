// SPI v3: 1..1024 byte blocks. HOST_BLOCKS selects SPI v4: one-byte operations
// with an RP2040-owned block lease. Mode 0; CRC protected requests/status.
// All logic uses clk (53.20 MHz). SPI <=4 MHz, CS guards >=2 us.
module programmer_block #(parameter CONTROLLED=0, HOST_BLOCKS=0, LEASE_BITS=20) (
    input wire clk, reset, spi_cs_n, spi_sck, spi_mosi,
    input wire accept_requests,
    output wire spi_miso,
    input wire busy, done,
    input wire [7:0] operation_status,
    input wire [15:0] result,
    output reg start,
    output wire [7:0] command, data,
    output reg [21:0] address,
    output reg seen,
    output wire active
);
    localparam MAX_BLOCK=HOST_BLOCKS ? 1 : 1024;
    localparam COUNT_WIDTH=HOST_BLOCKS ? 1 : 11;
    localparam BYTE_WIDTH=HOST_BLOCKS ? 4 : 11;
    localparam BIT_WIDTH=BYTE_WIDTH+3;
    localparam [BYTE_WIDTH-1:0] ONE=1, TWO=2, EIGHT=8;
    reg lease, lease_release;
    reg [LEASE_BITS-1:0] lease_timer;
    wire accepting=(!CONTROLLED || accept_requests || (HOST_BLOCKS && lease)) &&
                   !(HOST_BLOCKS && lease_release);
    function [15:0] crc_byte;
        input [15:0] crc; input [7:0] value;
        reg [15:0] c; integer j;
        begin
            c=crc ^ {value,8'b0};
            for(j=0;j<8;j=j+1) c=(c<<1)^(c[15] ? 16'h1021:16'h0);
            crc_byte=c;
        end
    endfunction
    (* syn_preserve=1 *) reg [1:0] cs_sync, sck_sync, mosi_sync;
    reg old_cs, old_sck;
    reg [BIT_WIDTH-1:0] bits;
    reg [7:0] rx_shift, tx_shift, frame_op;
    reg [63:0] header;
    reg [15:0] rx_crc;
    wire [7:0] rx_byte={rx_shift[6:0],mosi_sync[1]};
    wire [BYTE_WIDTH-1:0] byte_count=bits[BIT_WIDTH-1:3];
    wire [15:0] frame_length=header[23:8];
    // Decode in separate clock stages. Header/byte counters remain stable for
    // many clk cycles between SPI bytes; CS guards provide >=2 us before commit.
    // Avoid header -> length mux -> two adders -> comparator -> state/EBR enable.
    reg [BYTE_WIDTH-1:0] payload_end, frame_end;
    reg payload_byte, crc_byte_slot, frame_complete;
    reg crc_ok, sequence_ok, address_ok, length_ok, arm_key_ok;
    reg block_op, read_op, known_op;
    reg range_ok;
    reg armed, frame_blocked;
    reg [7:0] sequence_id, last_op, status;
    reg [15:0] last_result;
    // Requests complete at most 1024 bytes.
    reg [COUNT_WIDTH-1:0] completed;
    wire [15:0] completed_wide=completed;
    reg [15:0] block_crc;
    reg [COUNT_WIDTH-1:0] length;
    wire [7:0] op=last_op;
    assign command=op==8'h30 ? 8'h10 : op==8'h31 ? 8'h11 : op;
    localparam IDLE=0, FETCH=1, ISSUE=2, WAIT_OP=3;
    reg [1:0] state;
    wire operation_active=busy || start || state!=IDLE;
    always @(posedge clk) begin
        if(reset) begin
            payload_end<=8; frame_end<=10;
            payload_byte<=0; crc_byte_slot<=0; frame_complete<=0;
            crc_ok<=0; sequence_ok<=0; address_ok<=0; length_ok<=0;
            arm_key_ok<=0; block_op<=0; read_op<=0; known_op<=0;
            range_ok<=0;
        end else begin
            payload_end <= (frame_op==8'h31 && frame_length<=MAX_BLOCK) ?
                           EIGHT + frame_length[COUNT_WIDTH-1:0] : EIGHT;
            frame_end <= payload_end + TWO;
            payload_byte <= byte_count>=EIGHT && byte_count<payload_end;
            crc_byte_slot <= byte_count>=payload_end && byte_count<frame_end;
            frame_complete <= bits=={frame_end,3'b000};
            // Appending the big-endian CRC gives a zero CCITT residue.
            crc_ok <= rx_crc==16'h0000;
            sequence_ok <= header[55:48]!=sequence_id;
            address_ok <= header[47:46]==0;
            length_ok <= frame_length!=0 && frame_length<=MAX_BLOCK;
            // With length_ok, only the final 1 KiB page can cross 4 MiB.
            range_ok <= HOST_BLOCKS || header[45:34]!=12'hfff ||
                        ({1'b0,header[33:24]} + frame_length[10:0])<=11'd1024;
            arm_key_ok <= header[47:0]==48'h0000000000a5;
            block_op <= frame_op==8'h30 || frame_op==8'h31;
            read_op <= frame_op==8'h30;
            known_op <= frame_op==8'h30 || frame_op==8'h31 || frame_op==8'h12 ||
                        frame_op==8'h13 || frame_op==8'h14;
        end
    end
    assign active = operation_active || (HOST_BLOCKS && lease);
    assign spi_miso = !spi_cs_n && !reset  ?  tx_shift[7] : 1'bz;

    // Legacy v3 uses two EBR buffers. In v4 only the incoming byte remains;
    // reads return through last_result and no block buffer/CRC is synthesized.
    (* syn_ramstyle="block_ram" *) reg [7:0] incoming[0:MAX_BLOCK-1];
    (* syn_ramstyle="block_ram" *) reg [7:0] outgoing[0:MAX_BLOCK-1];
    reg [7:0] input_data, output_data;
    // completed stays fixed through the start handshake and Flash operation.
    assign data=input_data;
    wire [9:0] memory_index=completed;
    wire [9:0] byte_address=byte_count;
    wire [9:0] output_address = byte_count==0 ? 10'd0 : byte_address-1'b1;
    always @(posedge clk) begin
        input_data <= incoming[HOST_BLOCKS ? 10'd0 : memory_index];
        if(!HOST_BLOCKS) output_data <= outgoing[output_address];
        if (!reset && !cs_sync[1] && sck_sync[1] && !old_sck && bits[2:0]==7 &&
            frame_op==8'h31 && payload_byte && !operation_active && !frame_blocked)
            incoming[HOST_BLOCKS ? 10'd0 : byte_address-10'd8] <= rx_byte;
        if (!HOST_BLOCKS && !reset && state==WAIT_OP && done && operation_status==0 && op==8'h30)
            outgoing[memory_index] <= result[7:0];
    end

    reg [63:0] status_header;
    // Status queries never commit a request, so their CRC shares the RX unit.
    wire [15:0] status_crc=rx_crc;
    wire [7:0] link_status=HOST_BLOCKS ?
        {lease && !lease_release,accept_requests,2'b00,(operation_active ? 4'h1:status[3:0])} :
        (operation_active ? 8'h01:status);
    wire [63:0] snapshot={8'h50,sequence_id,link_status,last_op,
                          last_result[7:0],last_result[15:8],completed_wide[7:0],completed_wide[15:8]};
    reg [7:0] next_tx;
    // Requests and status replies arrive one bit at a time on the SPI clock.
    wire crc_input=frame_op==2 ? tx_shift[7] : mosi_sync[1];
    wire [15:0] frame_crc_next={rx_crc[14:0],1'b0} ^
                              ((rx_crc[15]^crc_input) ? 16'h1021 : 16'h0);
    reg [7:0] reply_byte;
    always @* begin
        reply_byte=0;
        if(frame_op==1) begin
            case(byte_count)
                1: reply_byte=8'h47; 2: reply_byte=8'h42;
                3: reply_byte=8'h46; 4: reply_byte=8'h43;
                5: reply_byte=HOST_BLOCKS ? 8'h04 : 8'h03;
                7: reply_byte=HOST_BLOCKS ? 8'h01 : 8'h00;
                8: reply_byte=HOST_BLOCKS ? 8'h00 : 8'h04;
                default: ;
            endcase
        end else begin
            case(byte_count)
                1: reply_byte=status_header[63:56];
                2: reply_byte=status_header[55:48];
                3: reply_byte=status_header[47:40];
                4: reply_byte=status_header[39:32];
                5: reply_byte=status_header[31:24];
                6: reply_byte=status_header[23:16];
                7: reply_byte=status_header[15:8];
                8: reply_byte=status_header[7:0];
                default: ;
            endcase
        end
    end
    always @* begin
        next_tx=0;
        case(frame_op)
            8'h01: next_tx=reply_byte;
            8'h02: begin
                if(byte_count>=1 && byte_count<=8) next_tx=reply_byte;
                else if(byte_count==9) next_tx=status_crc[15:8];
                else if(byte_count==10) next_tx=status_crc[7:0];
            end
            8'h03: if(!HOST_BLOCKS && !operation_active && status==0 && last_op==8'h30) begin
                if(byte_count>=1 && byte_count<=completed) next_tx=output_data;
                else if(byte_count==completed+ONE) next_tx=block_crc[15:8];
                else if(byte_count==completed+TWO) next_tx=block_crc[7:0];
            end
        endcase
    end

    always @(posedge clk) begin
        if(reset) begin
            cs_sync<=3; sck_sync<=0; mosi_sync<=0; old_cs<=1; old_sck<=0;
            bits<=0; rx_shift<=0; tx_shift<=0; frame_op<=0; header<=0;
            rx_crc<=16'hffff;
            armed<=0; frame_blocked<=0; sequence_id<=0; last_op<=0; status<=0;
            last_result<=0; completed<=0; block_crc<=16'hffff;
            length<=0; state<=IDLE;
            start<=0; address<=0; seen<=0;
            status_header<=0;
            lease<=0; lease_release<=0; lease_timer<=0;
        end else begin
            cs_sync<={cs_sync[0],spi_cs_n}; sck_sync<={sck_sync[0],spi_sck};
            mosi_sync<={mosi_sync[0],spi_mosi}; old_cs<=cs_sync[1]; old_sck<=sck_sync[1];
            start<=0;
            if(!cs_sync[1] && old_cs) frame_blocked<=operation_active;
            if(HOST_BLOCKS && lease && !operation_active) begin
                lease_timer<=lease_timer+1'b1;
                if(&lease_timer) begin lease<=0; lease_release<=0; armed<=0; status<=3; end
            end else lease_timer<=0;
            case(state)
                FETCH: state<=ISSUE;
                ISSUE: begin
                    if(op==8'h31 && input_data==8'hff) begin
                        completed<=completed+1'b1;
                        if(HOST_BLOCKS || completed+11'd1==length) begin state<=IDLE; status<=0; end
                        else begin address<=address+1'b1; state<=FETCH; end
                    end else begin
                        start<=1; state<=WAIT_OP;
                    end
                end
                WAIT_OP: if(done) begin
                    last_result<=result;
                    if(operation_status!=0) begin
                        status<=operation_status; armed<=0; state<=IDLE;
                    end else begin
                        if(!HOST_BLOCKS && op==8'h30) block_crc<=crc_byte(block_crc,result[7:0]);
                        completed<=completed+1'b1;
                        if(HOST_BLOCKS || completed+11'd1==length) begin status<=0; state<=IDLE; end
                        else begin address<=address+1'b1; state<=FETCH; end
                    end
                end
            endcase
            if(cs_sync[1]) begin
                // Keep PROGRAMMER alive until RP2040 clocks out the release ACK.
                if(HOST_BLOCKS && lease_release && !old_cs && frame_op==2 &&
                   byte_count==11 && bits[2:0]==0) begin lease<=0; lease_release<=0; end
                bits<=0; rx_shift<=0; tx_shift<=0; frame_op<=0;
                header<=0; rx_crc<=16'hffff;
                // Commit only a complete, exact-length frame after CS rises.
                if(!old_cs && frame_op!=1 && frame_op!=2 && frame_op!=3 &&
                    frame_complete && !operation_active && !frame_blocked && accepting) begin
                    lease_timer<=0;
                    sequence_id<=header[55:48]; last_op<=frame_op; completed<=0; last_result<=0;
                    if(!crc_ok) begin status<=7; armed<=0; end
                    else if(!sequence_ok) begin status<=10; armed<=0; end
                    else if(!address_ok || (block_op && (!length_ok || !range_ok))) begin status<=8; armed<=0; end
                    else if(HOST_BLOCKS && frame_op==8'h22) begin
                        if(lease || !accept_requests || !arm_key_ok) status<=9;
                        else begin lease<=1; status<=0; end
                    end else if(HOST_BLOCKS && frame_op==8'h23) begin
                        if(!lease) status<=9;
                        else begin lease_release<=1; status<=0; end
                    end
                    else if(frame_op==8'h20) begin
                        armed<=arm_key_ok;
                        status<=arm_key_ok ? 0:9;
                    end else if(frame_op==8'h21) begin armed<=0; status<=0; end
                    else if(!known_op) status<=2;
                    else if(!read_op && !armed) status<=9;
                    else if(!block_op && frame_length!=0) status<=8;
                    else begin
                        address<=header[45:24];
                        length<=block_op ? frame_length[COUNT_WIDTH-1:0]:1'b1;
                        block_crc<=16'hffff; status<=1; state<=FETCH; seen<=1;
                    end
                end
            end else begin
                if(sck_sync[1] && !old_sck) begin
                    if(!(&bits)) bits<=bits+1'b1;
                    rx_shift<=rx_byte;
                    if(frame_op==2 ? (byte_count>=1 && byte_count<=8) :
                                      (byte_count<8 || payload_byte || crc_byte_slot)) rx_crc<=frame_crc_next;
                    if(bits[2:0]==7) begin
                        if(byte_count==0) begin
                            frame_op<=rx_byte;
                            // Hold the snapshot in place; select a byte for SPI.
                            status_header<=snapshot;
                        end
                        if(byte_count<8) header<={header[55:0],rx_byte};
                        if(byte_count==0 && rx_byte==2) rx_crc<=16'hffff;
                    end
                end
                if(!sck_sync[1] && old_sck) begin
                    if(bits[2:0]==0) begin
                        tx_shift<=next_tx;
                    end else tx_shift<={tx_shift[6:0],1'b0};
                end
            end
        end
    end
endmodule
