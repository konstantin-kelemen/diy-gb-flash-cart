// Mode 0, <=10 kHz, >=20 us CS guards. Fixed 8-byte CRC-protected requests.
// Request: op, sequence, address[23:16], address[15:8], address[7:0], data,
//          CRC16-CCITT-FALSE high, low. Commit only on CS rising after 64 bits.
// Poll: 02 + eight dummy bytes. Snapshot: 50 seq status result_lo result_hi op CRC16.
module programmer_spi (
    input wire clk, reset, spi_cs_n, spi_sck, spi_mosi,
    output wire spi_miso,
    input wire busy, done,
    input wire [7:0] operation_status,
    input wire [15:0] result,
    output reg start,
    output reg [7:0] command, data,
    output reg [21:0] address,
    output reg seen
);
    (* syn_preserve=1 *) reg [1:0] cs_sync, sck_sync, mosi_sync;
    reg previous_cs, previous_sck;
    reg [6:0] count;
    reg [63:0] request, response;
    reg miso_bit, armed;
    reg [7:0] sequence_id, last_command, status;
    reg [15:0] last_result;
    reg [15:0] request_crc;
    wire [63:0] received = {request[62:0], mosi_sync[1]};
    assign spi_miso = !spi_cs_n && !reset ? miso_bit : 1'bz;

    function [15:0] crc48;
        input [47:0] bytes;
        integer i;
        reg [15:0] crc;
        begin
            crc = 16'hffff;
            for (i=47; i>=0; i=i-1)
                crc = (crc << 1) ^ ((crc[15] ^ bytes[i]) ? 16'h1021 : 16'h0000);
            crc48 = crc;
        end
    endfunction
    wire [47:0] snapshot = {8'h50, sequence_id,
        (busy || start ? 8'h01 : status), last_result[7:0], last_result[15:8], last_command};

    always @(posedge clk) begin
        if (reset) begin
            cs_sync <= 3; sck_sync <= 0; mosi_sync <= 0;
            previous_cs <= 1; previous_sck <= 0;
            count <= 0; request <= 0; response <= 0; miso_bit <= 0;
            armed <= 0; sequence_id <= 0; last_command <= 0; status <= 0;
            last_result <= 0; start <= 0; command <= 0; data <= 0; address <= 0; seen <= 0;
            request_crc <= 16'hffff;
        end else begin
            cs_sync <= {cs_sync[0], spi_cs_n};
            sck_sync <= {sck_sync[0], spi_sck};
            mosi_sync <= {mosi_sync[0], spi_mosi};
            previous_cs <= cs_sync[1]; previous_sck <= sck_sync[1];
            start <= 0;
            if (done) begin
                status <= operation_status; last_result <= result;
                if (operation_status != 0) armed <= 0;
            end
            if (cs_sync[1]) begin
                count <= 0; request <= 0; response <= 0; miso_bit <= 0;
                request_crc <= 16'hffff;
                if (!previous_cs && count == 64 && request[63:56] != 8'h01 && request[63:56] != 8'h02
                    && !busy && !start && !done) begin
                    sequence_id <= request[55:48]; last_command <= request[63:56];
                    last_result <= 0;
                    if (request_crc != request[15:0]) begin status <= 8'h07; armed <= 0; end
                    else if (request[47:46] != 0) status <= 8'h08;
                    else if (request[63:56] == 8'h20) begin
                        armed <= request[45:16] == {22'h000000, 8'ha5};
                        status <= request[45:16] == {22'h000000, 8'ha5} ? 8'h00 : 8'h09;
                    end else if (request[63:56] == 8'h21) begin armed <= 0; status <= 0; end
                    else if (request[63:56] < 8'h10 || request[63:56] > 8'h14) status <= 8'h02;
                    else if (!armed && request[63:56] != 8'h10) status <= 8'h09;
                    else begin
                        start <= 1; command <= request[63:56]; address <= request[45:24];
                        data <= request[23:16]; status <= 1; seen <= 1;
                    end
                end
            end else begin
                if (sck_sync[1] && !previous_sck) begin
                    if (count < 127) count <= count + 1'b1;
                    if (count < 64) request <= received;
                    if (count < 48)
                        request_crc <= (request_crc << 1) ^
                            ((request_crc[15] ^ mosi_sync[1]) ? 16'h1021 : 16'h0000);
                    if (count == 7) begin
                        case (received[7:0])
                            8'h01: response <= 64'h4742464302000100;
                            8'h02: response <= {snapshot, crc48(snapshot)};
                            default: response <= 0;
                        endcase
                    end
                end
                if (!sck_sync[1] && previous_sck) begin
                    if (count >= 8 && count < 72) begin
                        miso_bit <= response[63]; response <= {response[62:0], 1'b0};
                    end else miso_bit <= 0;
                end
            end
        end
    end
endmodule
