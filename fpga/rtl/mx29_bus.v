// ============================================================================
// MX29LV320E LOW-LEVEL BUS CONTROLLER
//
// This module is the ONLY place that directly drives:
//
//     flash_a
//     flash_d
//     flash_ce_n
//     flash_oe_n
//     flash_we_n
//
// This avoids multiple-driver problems in synthesis.
// ============================================================================

module mx29_bus (
    input wire clk,

    input wire        start,
    input wire        write_cycle,
    input wire [21:0] addr,
    input wire [7:0]  wdata,

    output reg         busy,
    output reg         done,
    output reg [7:0]   rdata,

    output reg [21:0]  flash_a,
    inout wire [7:0]   flash_d,

    output reg flash_ce_n,
    output reg flash_oe_n,
    output reg flash_we_n
);

    reg [7:0] flash_d_out;
    reg flash_d_drive;

    assign flash_d =
        flash_d_drive ?
        flash_d_out :
        8'bz;

    wire [7:0] flash_d_in = flash_d;


    reg [3:0] state;


    localparam IDLE          = 4'd0;

    localparam WRITE_SETUP   = 4'd1;
    localparam WRITE_WE_LOW  = 4'd2;
    localparam WRITE_WE_HIGH = 4'd3;
    localparam WRITE_RELEASE = 4'd4;

    localparam READ_SETUP    = 4'd5;
    localparam READ_WAIT1    = 4'd6;
    localparam READ_WAIT2    = 4'd7;
    localparam READ_SAMPLE   = 4'd8;
    localparam READ_RELEASE  = 4'd9;


    initial begin

        busy  = 1'b0;
        done  = 1'b0;
        rdata = 8'h00;

        flash_a = 22'h000000;

        flash_d_out   = 8'h00;
        flash_d_drive = 1'b0;

        flash_ce_n = 1'b1;
        flash_oe_n = 1'b1;
        flash_we_n = 1'b1;

        state = IDLE;

    end


    always @(posedge clk) begin

        done <= 1'b0;


        case (state)

            // ====================================================
            // IDLE
            // ====================================================

            IDLE: begin

                busy <= 1'b0;

                flash_ce_n <= 1'b1;
                flash_oe_n <= 1'b1;
                flash_we_n <= 1'b1;

                flash_d_drive <= 1'b0;


                if (start) begin

                    busy <= 1'b1;

                    flash_a <= addr;

                    if (write_cycle) begin

                        flash_d_out <= wdata;

                        state <= WRITE_SETUP;

                    end else begin

                        state <= READ_SETUP;

                    end

                end

            end


            // ====================================================
            // WRITE cycle
            // ====================================================

            WRITE_SETUP: begin

                flash_d_drive <= 1'b1;

                flash_ce_n <= 1'b0;
                flash_oe_n <= 1'b1;
                flash_we_n <= 1'b1;

                state <= WRITE_WE_LOW;

            end


            WRITE_WE_LOW: begin

                // Data/address have already been stable for
                // one full 2.08 MHz clock period.

                flash_we_n <= 1'b0;

                state <= WRITE_WE_HIGH;

            end


            WRITE_WE_HIGH: begin

                // WE# rising edge commits the bus write.

                flash_we_n <= 1'b1;

                state <= WRITE_RELEASE;

            end


            WRITE_RELEASE: begin

                flash_ce_n <= 1'b1;
                flash_we_n <= 1'b1;

                flash_d_drive <= 1'b0;

                busy <= 1'b0;
                done <= 1'b1;

                state <= IDLE;

            end


            // ====================================================
            // READ cycle
            // ====================================================

            READ_SETUP: begin

                flash_d_drive <= 1'b0;

                flash_we_n <= 1'b1;
                flash_ce_n <= 1'b0;
                flash_oe_n <= 1'b0;

                state <= READ_WAIT1;

            end


            READ_WAIT1: begin

                // > 480 ns already elapsed.
                // Flash is rated for ~70 ns access.

                state <= READ_WAIT2;

            end


            READ_WAIT2: begin

                state <= READ_SAMPLE;

            end


            READ_SAMPLE: begin

                rdata <= flash_d_in;

                state <= READ_RELEASE;

            end


            READ_RELEASE: begin

                flash_ce_n <= 1'b1;
                flash_oe_n <= 1'b1;

                busy <= 1'b0;
                done <= 1'b1;

                state <= IDLE;

            end


            default: begin

                flash_ce_n <= 1'b1;
                flash_oe_n <= 1'b1;
                flash_we_n <= 1'b1;

                flash_d_drive <= 1'b0;

                busy <= 1'b0;

                state <= IDLE;

            end

        endcase

    end

endmodule
