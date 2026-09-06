// SPI Mode 0, 10 kHz. Inputs are oversampled by the 2.08 MHz oscillator.
module top (
    input wire spi_cs_n, spi_sck, spi_mosi,
    output wire spi_miso,
    output wire [21:0] flash_a,
    inout wire [7:0] flash_d,
    output wire flash_ce_n, flash_oe_n, flash_we_n,
    output wire spi_ready,
    output reg spi_seen
);
    wire clk;
    OSCH osc (.STDBY(1'b0), .OSC(clk), .SEDSTDBY());
    defparam osc.NOM_FREQ = "2.08";
    wire [3:0] startup_ready;
    FD1S3AX r0 (.D(1'b1), .CK(clk), .Q(startup_ready[0]));
    FD1S3AX r1 (.D(startup_ready[0]), .CK(clk), .Q(startup_ready[1]));
    FD1S3AX r2 (.D(startup_ready[1]), .CK(clk), .Q(startup_ready[2]));
    FD1S3AX r3 (.D(startup_ready[2]), .CK(clk), .Q(startup_ready[3]));
    wire reset = !startup_ready[3];
    assign spi_ready = !reset;
    assign flash_a = 22'b0;
    assign flash_d = 8'bz;
    assign flash_ce_n = 1'b1;
    assign flash_oe_n = 1'b1;
    assign flash_we_n = 1'b1;

    // Separate two-stage synchronizers, then edge detection on synchronized SCK.
    (* syn_preserve=1 *) reg [1:0] cs_sync, sck_sync, mosi_sync;
    reg sck_previous;
    reg [6:0] bit_count; // Saturates: extra clocks cannot start another command.
    reg [7:0] command;
    reg [63:0] response;
    reg known_command, miso_bit;
    // Raw CS only gates the output enable; all protocol state uses synchronized CS.
    assign spi_miso = (!spi_cs_n && !reset) ? miso_bit : 1'bz;

    always @(posedge clk) begin
        if (reset) begin
            cs_sync <= 2'b11;
            sck_sync <= 0;
            mosi_sync <= 0;
            sck_previous <= 0;
        end else begin
            cs_sync <= {cs_sync[0], spi_cs_n};
            sck_sync <= {sck_sync[0], spi_sck};
            mosi_sync <= {mosi_sync[0], spi_mosi};
            sck_previous <= sck_sync[1];
        end
        if (reset) spi_seen <= 0;
        if (reset || cs_sync[1]) begin
            bit_count <= 0;
            command <= 0;
            response <= 0;
            known_command <= 0;
            miso_bit <= 0;
        end else begin
            if (sck_sync[1] && !sck_previous) begin
                if (bit_count < 72) bit_count <= bit_count + 1'b1;
                if (bit_count < 8) command <= {command[6:0], mosi_sync[1]};
                if (bit_count == 7) begin
                    known_command <= ({command[6:0], mosi_sync[1]} == 8'h01);
                    response <= ({command[6:0], mosi_sync[1]} == 8'h01)
                              ? 64'h4742464301000000 : 64'b0;
                end
                if (bit_count == 71 && known_command) spi_seen <= 1;
            end
            if (!sck_sync[1] && sck_previous) begin
                if (bit_count >= 8 && bit_count < 72) begin
                    miso_bit <= response[63];
                    response <= {response[62:0], 1'b0};
                end else miso_bit <= 0;
            end
        end
    end
endmodule
