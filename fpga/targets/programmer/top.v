// Dedicated PROGRAMMER target. Game Boy must be disconnected.
module top (
    input wire spi_cs_n, spi_sck, spi_mosi,
    output wire spi_miso,
    output wire [21:0] flash_a,
    inout wire [7:0] flash_d,
    output wire flash_ce_n, flash_oe_n, flash_we_n,
    output wire spi_ready, spi_seen
);
    wire clk;
    OSCH osc (.STDBY(1'b0), .OSC(clk), .SEDSTDBY());
    defparam osc.NOM_FREQ = "2.08";
    wire [3:0] ready;
    FD1S3AX r0 (.D(1'b1), .CK(clk), .Q(ready[0]));
    FD1S3AX r1 (.D(ready[0]), .CK(clk), .Q(ready[1]));
    FD1S3AX r2 (.D(ready[1]), .CK(clk), .Q(ready[2]));
    FD1S3AX r3 (.D(ready[2]), .CK(clk), .Q(ready[3]));
    wire reset = !ready[3];
    wire start, busy, done;
    wire [7:0] command, data, status;
    wire [21:0] address;
    wire [15:0] result;
    assign spi_ready = !reset && !busy;
    programmer_spi protocol(.clk(clk), .reset(reset), .spi_cs_n(spi_cs_n),
        .spi_sck(spi_sck), .spi_mosi(spi_mosi), .spi_miso(spi_miso),
        .busy(busy), .done(done), .operation_status(status), .result(result),
        .start(start), .command(command), .address(address), .data(data), .seen(spi_seen));
    mx29_programmer flash(.clk(clk), .reset(reset), .start(start),
        .command(command), .address(address), .data(data), .busy(busy),
        .done(done), .status(status), .result(result), .flash_a(flash_a),
        .flash_d(flash_d), .flash_ce_n(flash_ce_n), .flash_oe_n(flash_oe_n), .flash_we_n(flash_we_n));
endmodule
