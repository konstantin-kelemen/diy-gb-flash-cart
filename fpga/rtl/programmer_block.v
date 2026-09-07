// Protocol 3: CRC protected requests, 1..1024 byte blocks, Mode 0 SPI.
// All logic uses clk (53.20 MHz). SPI <=4 MHz, CS guards >=2 us.
module programmer_block (
    input wire clk, reset, spi_cs_n, spi_sck, spi_mosi,
    output wire spi_miso,
    input wire busy, done,
    input wire [7:0] operation_status,
    input wire [15:0] result,
    output reg start,
    output reg [7:0] command, data,
    output reg [21:0] address,
    output reg seen,
    output wire active
);
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
    reg [13:0] bits;
    reg [7:0] rx_shift, tx_shift, frame_op;
    reg [63:0] header;
    reg [15:0] rx_crc, received_crc;
    wire [7:0] rx_byte={rx_shift[6:0],mosi_sync[1]};
    wire [10:0] byte_count=bits[13:3];
    wire [15:0] frame_length=header[23:8];
    wire [11:0] payload_end=12'd8 + ((frame_op==8'h31 && frame_length<=1024) ? frame_length[10:0]:11'd0);
    reg armed, frame_blocked;
    reg [7:0] sequence_id, last_op, status;
    reg [15:0] last_result, completed;
    reg [15:0] block_crc;
    reg [10:0] index, length;
    reg [21:0] base;
    reg [7:0] op;
    localparam IDLE=0, FETCH=1, ISSUE=2, WAIT_OP=3;
    reg [1:0] state;
    assign active = busy || start || state!=IDLE;
    assign spi_miso = !spi_cs_n && !reset  ?  tx_shift[7] : 1'bz;

    // Separate synchronous 1 KiB memories; no array reset, infer EBR.
    (* syn_ramstyle="block_ram" *) reg [7:0] incoming[0:1023];
    (* syn_ramstyle="block_ram" *) reg [7:0] outgoing[0:1023];
    reg [7:0] input_data, output_data;
    wire [9:0] output_address = byte_count==0  ?  10'd0 : byte_count[9:0]-1'b1;
    always @(posedge clk) begin
        input_data <= incoming[index[9:0]];
        output_data <= outgoing[output_address];
        if (!reset && !cs_sync[1] && sck_sync[1] && !old_sck && bits[2:0]==7 &&
            frame_op==8'h31 && byte_count>=8 && byte_count<payload_end && !active && !frame_blocked)
            incoming[byte_count-8] <= rx_byte;
        if (!reset && state==WAIT_OP && done && operation_status==0 && op==8'h30)
            outgoing[index[9:0]] <= result[7:0];
    end

    reg [63:0] status_header;
    reg [63:0] version_reply;
    reg [15:0] status_crc;
    wire [63:0] snapshot={8'h50,sequence_id,(active ? 8'h01:status),last_op,
                          last_result[7:0],last_result[15:8],completed[7:0],completed[15:8]};
    reg [7:0] next_tx;
    always @* begin
        next_tx=0;
        case(frame_op)
            8'h01: if(byte_count>=1 && byte_count<=8) next_tx=version_reply[63:56];
            8'h02: begin
                if(byte_count>=1 && byte_count<=8) next_tx=status_header[63:56];
                else if(byte_count==9) next_tx=status_crc[15:8];
                else if(byte_count==10) next_tx=status_crc[7:0];
            end
            8'h03: if(!active && status==0 && last_op==8'h30) begin
                if(byte_count>=1 && byte_count<=completed) next_tx=output_data;
                else if(byte_count==completed+1) next_tx=block_crc[15:8];
                else if(byte_count==completed+2) next_tx=block_crc[7:0];
            end
        endcase
    end

    always @(posedge clk) begin
        if(reset) begin
            cs_sync<=3; sck_sync<=0; mosi_sync<=0; old_cs<=1; old_sck<=0;
            bits<=0; rx_shift<=0; tx_shift<=0; frame_op<=0; header<=0;
            rx_crc<=16'hffff; received_crc<=0;
            armed<=0; frame_blocked<=0; sequence_id<=0; last_op<=0; status<=0;
            last_result<=0; completed<=0; block_crc<=16'hffff;
            index<=0; length<=0; base<=0; op<=0; state<=IDLE;
            start<=0; command<=0; data<=0; address<=0; seen<=0;
            status_header<=0; version_reply<=0; status_crc<=16'hffff;
        end else begin
            cs_sync<={cs_sync[0],spi_cs_n}; sck_sync<={sck_sync[0],spi_sck};
            mosi_sync<={mosi_sync[0],spi_mosi}; old_cs<=cs_sync[1]; old_sck<=sck_sync[1];
            start<=0;
            if(!cs_sync[1] && old_cs) frame_blocked<=active;
            case(state)
                FETCH: state<=ISSUE;
                ISSUE: begin
                    if(op==8'h31 && input_data==8'hff) begin
                        completed<=completed+1'b1;
                        if(index+1==length) begin state<=IDLE; status<=0; end
                        else begin index<=index+1'b1; state<=FETCH; end
                    end else begin
                        start<=1; command<=op==8'h30 ? 8'h10:op==8'h31 ? 8'h11:op;
                        address<=base+index; data<=input_data; state<=WAIT_OP;
                    end
                end
                WAIT_OP: if(done) begin
                    last_result<=result;
                    if(operation_status!=0) begin
                        status<=operation_status; armed<=0; state<=IDLE;
                    end else begin
                        if(op==8'h30) block_crc<=crc_byte(block_crc,result[7:0]);
                        completed<=completed+1'b1;
                        if(index+1==length) begin status<=0; state<=IDLE; end
                        else begin index<=index+1'b1; state<=FETCH; end
                    end
                end
            endcase
            if(cs_sync[1]) begin
                bits<=0; rx_shift<=0; tx_shift<=0; frame_op<=0;
                header<=0; rx_crc<=16'hffff; received_crc<=0;
                // Commit only a complete, exact-length frame after CS rises.
                if(!old_cs && frame_op!=1 && frame_op!=2 && frame_op!=3 &&
                    bits==((payload_end+2)<<3) && !active && !frame_blocked) begin
                    sequence_id<=header[55:48]; last_op<=frame_op; completed<=0; last_result<=0;
                    if(received_crc!=rx_crc) begin status<=7; armed<=0; end
                    else if(header[55:48]==sequence_id) begin status<=10; armed<=0; end
                    else if(header[47:46]!=0 ||
                        ((frame_op==8'h30 || frame_op==8'h31) &&
                        (frame_length==0 || frame_length>1024 ||
                         {1'b0,header[45:24]}+frame_length>23'h400000))) begin status<=8; armed<=0; end
                    else if(frame_op==8'h20) begin
                        armed<=header[47:0]==48'h0000000000a5;
                        status<=header[47:0]==48'h0000000000a5 ? 0:9;
                    end else if(frame_op==8'h21) begin armed<=0; status<=0; end
                    else if(frame_op!=8'h30 && frame_op!=8'h31 && frame_op!=8'h12 &&
                            frame_op!=8'h13 && frame_op!=8'h14) status<=2;
                    else if(frame_op!=8'h30 && !armed) status<=9;
                    else if(frame_op!=8'h30 && frame_op!=8'h31 && frame_length!=0) status<=8;
                    else begin
                        op<=frame_op; base<=header[45:24]; index<=0;
                        length<=(frame_op==8'h30 || frame_op==8'h31) ? frame_length[10:0]:11'd1;
                        block_crc<=16'hffff; status<=1; state<=FETCH; seen<=1;
                    end
                end
            end else begin
                if(sck_sync[1] && !old_sck) begin
                    if(bits<14'h3fff) bits<=bits+1'b1;
                    rx_shift<=rx_byte;
                    if(bits[2:0]==7) begin
                        if(byte_count==0) begin
                            frame_op<=rx_byte;
                            status_header<=snapshot; status_crc<=16'hffff;
                            version_reply<=64'h4742464303000004; // v3, 1024-byte blocks (LE)
                        end
                        if(byte_count<8) header<={header[55:0],rx_byte};
                        if(byte_count<payload_end) rx_crc<=crc_byte(rx_crc,rx_byte);
                        else if(byte_count<payload_end+2) received_crc<={received_crc[7:0],rx_byte};
                    end
                end
                if(!sck_sync[1] && old_sck) begin
                    if(bits[2:0]==0) begin
                        tx_shift<=next_tx;
                        if(frame_op==1) version_reply<={version_reply[55:0],8'b0};
                        if(frame_op==2 && byte_count>=1 && byte_count<=8) begin
                            status_header<={status_header[55:0],8'b0};
                            status_crc<=crc_byte(status_crc,next_tx);
                        end
                    end else tx_shift<={tx_shift[6:0],1'b0};
                end
            end
        end
    end
endmodule
