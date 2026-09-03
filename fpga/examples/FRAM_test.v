module top (
    output reg  [16:0] fram_a,
    inout  wire [7:0]  fram_dq,

    output reg         fram_ce_n,
    output reg         fram_oe_n,
    output reg         fram_we_n,

    output reg         test_ok,
    output reg         test_fail
);

    // ---------------------------------------------------------
    // Internal MachXO2 oscillator: ~2.08 MHz
    // ---------------------------------------------------------

    wire clk;

    OSCH osc_inst (
        .STDBY(1'b0),
        .OSC(clk),
        .SEDSTDBY()
    );

    defparam osc_inst.NOM_FREQ = "2.08";


    // ---------------------------------------------------------
    // FRAM data bus
    // ---------------------------------------------------------

    reg  [7:0] dq_out;
    reg        dq_drive;

    assign fram_dq = dq_drive ? dq_out : 8'bz;


    // ---------------------------------------------------------
    // Test parameters
    // ---------------------------------------------------------

    localparam [16:0] TEST_ADDR = 17'h01234;
    localparam [7:0]  TEST_DATA = 8'hA5;


    // ---------------------------------------------------------
    // State machine
    // ---------------------------------------------------------

    localparam
        ST_POWER_WAIT  = 4'd0,
        ST_WRITE_SETUP = 4'd1,
        ST_WRITE_BEGIN = 4'd2,
        ST_WRITE_END   = 4'd3,
        ST_WRITE_IDLE  = 4'd4,
        ST_READ_SETUP  = 4'd5,
        ST_READ_WAIT   = 4'd6,
        ST_READ_SAMPLE = 4'd7,
        ST_DONE        = 4'd8;

    reg [3:0] state = ST_POWER_WAIT;

    reg [11:0] delay_counter = 0;
    reg [7:0] read_data;


    // ---------------------------------------------------------
    // Test controller
    // ---------------------------------------------------------

    always @(posedge clk) begin

        case (state)

            // -------------------------------------------------
            // Wait after power-up.
            //
            // 2.08 MHz:
            // 1024 clocks ≈ 492 us
            //
            // Datasheet requires >= 250 us.
            // -------------------------------------------------

            ST_POWER_WAIT: begin

                fram_ce_n <= 1'b1;
                fram_oe_n <= 1'b1;
                fram_we_n <= 1'b1;

                dq_drive <= 1'b0;

                test_ok   <= 1'b0;
                test_fail <= 1'b0;

                if (delay_counter == 12'd1023) begin
                    delay_counter <= 0;
                    state <= ST_WRITE_SETUP;
                end
                else begin
                    delay_counter <= delay_counter + 1'b1;
                end

            end


            // -------------------------------------------------
            // Put address and data on buses.
            // FRAM is still disabled.
            // -------------------------------------------------

            ST_WRITE_SETUP: begin

                fram_a <= TEST_ADDR;

                dq_out   <= TEST_DATA;
                dq_drive <= 1'b1;

                fram_ce_n <= 1'b1;
                fram_oe_n <= 1'b1;
                fram_we_n <= 1'b1;

                state <= ST_WRITE_BEGIN;

            end


            // -------------------------------------------------
            // Start write.
            //
            // CE active
            // WE active
            // OE disabled
            // -------------------------------------------------

            ST_WRITE_BEGIN: begin

                fram_ce_n <= 1'b0;
                fram_oe_n <= 1'b1;
                fram_we_n <= 1'b0;

                state <= ST_WRITE_END;

            end


            // -------------------------------------------------
            // Rising WE edge completes the write.
            // -------------------------------------------------

            ST_WRITE_END: begin

                fram_we_n <= 1'b1;

                state <= ST_WRITE_IDLE;

            end


            // -------------------------------------------------
            // Deselect FRAM.
            // Also release FPGA data bus.
            // -------------------------------------------------

            ST_WRITE_IDLE: begin

                fram_ce_n <= 1'b1;

                dq_drive <= 1'b0;

                state <= ST_READ_SETUP;

            end


            // -------------------------------------------------
            // Begin read.
            //
            // Address is already present.
            // WE high
            // CE low
            // OE low
            // -------------------------------------------------

            ST_READ_SETUP: begin

                fram_a <= TEST_ADDR;

                fram_we_n <= 1'b1;
                fram_ce_n <= 1'b0;
                fram_oe_n <= 1'b0;

                dq_drive <= 1'b0;

                state <= ST_READ_WAIT;

            end


            // -------------------------------------------------
            // Give FRAM a full clock (~481 ns)
            // to put valid data on DQ.
            //
            // Requirement is only ~60 ns.
            // -------------------------------------------------

            ST_READ_WAIT: begin

                state <= ST_READ_SAMPLE;

            end


            // -------------------------------------------------
            // Capture FRAM output
            // -------------------------------------------------

            ST_READ_SAMPLE: begin

                read_data <= fram_dq;

                fram_ce_n <= 1'b1;
                fram_oe_n <= 1'b1;

                if (fram_dq == TEST_DATA) begin
                    test_ok   <= 1'b1;
                    test_fail <= 1'b0;
                end
                else begin
                    test_ok   <= 1'b0;
                    test_fail <= 1'b1;
                end

                state <= ST_DONE;

            end


            // -------------------------------------------------
            // Stop here forever.
            // -------------------------------------------------

            ST_DONE: begin

                fram_ce_n <= 1'b1;
                fram_oe_n <= 1'b1;
                fram_we_n <= 1'b1;

                dq_drive <= 1'b0;

            end


            default: begin
                state <= ST_POWER_WAIT;
            end

        endcase
    end

endmodule