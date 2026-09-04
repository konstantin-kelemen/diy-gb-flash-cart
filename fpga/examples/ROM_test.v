module top (
    output wire [21:0] flash_a,
    inout  wire [7:0]  flash_d,

    output wire flash_ce_n,
    output wire flash_oe_n,
    output wire flash_we_n,

    output reg test_pass,
    output reg test_fail
);

    // ============================================================
    // Internal oscillator
    // ============================================================

    wire clk;

    OSCH OSCH_inst (
        .STDBY(1'b0),
        .OSC(clk),
        .SEDSTDBY()
    );

    defparam OSCH_inst.NOM_FREQ = "2.08";


    // ============================================================
    // Low-level flash bus
    // ============================================================

    reg         bus_start;
    reg         bus_write;
    reg [21:0]  bus_addr;
    reg [7:0]   bus_wdata;

    wire        bus_busy;
    wire        bus_done;
    wire [7:0]  bus_rdata;


    mx29_bus bus (
        .clk(clk),

        .start(bus_start),
        .write_cycle(bus_write),
        .addr(bus_addr),
        .wdata(bus_wdata),

        .busy(bus_busy),
        .done(bus_done),
        .rdata(bus_rdata),

        .flash_a(flash_a),
        .flash_d(flash_d),

        .flash_ce_n(flash_ce_n),
        .flash_oe_n(flash_oe_n),
        .flash_we_n(flash_we_n)
    );


    // ============================================================
    // MX29LV320E constants
    // ============================================================

    // Byte mode unlock addresses
    localparam [21:0] UNLOCK1 = 22'h000AAA;
    localparam [21:0] UNLOCK2 = 22'h000555;

    // First ordinary 64 KiB test sector
    localparam [21:0] TEST_BASE = 22'h010000;

    // Separate area inside TEST_BASE sector for data-bus test.
    // Chosen so it does not collide with the one-hot address tests.
    localparam [21:0] DATA_BASE = 22'h013000;


    // ============================================================
    // Timing
    // ============================================================

    // clk = 2.08 MHz
    //
    // ~480.8 ns / clock

    // ~250 ms startup delay
    localparam [23:0] POWER_DELAY = 24'd520000;

    // Datasheet maximum byte-program time = 300 us.
    // 1000 clocks ~= 481 us.
    localparam [23:0] PROGRAM_DELAY = 24'd1000;

    // Datasheet maximum sector erase time = 2 s.
    // 5,200,000 clocks ~= 2.5 s.
    localparam [23:0] ERASE_DELAY = 24'd5200000;


    // ============================================================
    // Test data functions
    // ============================================================

    // Data bus test:
    //
    // 0..7:
    //   01 02 04 08 10 20 40 80
    //
    // 8..15:
    //   FE FD FB F7 EF DF BF 7F
    //
    function [7:0] data_pattern;
        input [4:0] index;
        begin
            case (index)

                0:  data_pattern = 8'h01;
                1:  data_pattern = 8'h02;
                2:  data_pattern = 8'h04;
                3:  data_pattern = 8'h08;
                4:  data_pattern = 8'h10;
                5:  data_pattern = 8'h20;
                6:  data_pattern = 8'h40;
                7:  data_pattern = 8'h80;

                8:  data_pattern = 8'hFE;
                9:  data_pattern = 8'hFD;
                10: data_pattern = 8'hFB;
                11: data_pattern = 8'hF7;
                12: data_pattern = 8'hEF;
                13: data_pattern = 8'hDF;
                14: data_pattern = 8'hBF;
                15: data_pattern = 8'h7F;

                default:
                    data_pattern = 8'h00;

            endcase
        end
    endfunction


    // Address-line test pattern.
    //
    // Every address gets different data.
    //
    function [7:0] address_pattern;
        input [4:0] index;
        begin
            address_pattern = 8'h40 + index;
        end
    endfunction


    // Address used to test address line N.
    //
    // TEST_BASE + 2^N
    //
    // Examples:
    //
    // A0  -> 010001
    // A1  -> 010002
    // ...
    // A15 -> 018000
    // A16 -> 020000
    // A17 -> 030000
    // A18 -> 050000
    // A19 -> 090000
    // A20 -> 110000
    // A21 -> 210000
    //
    function [21:0] address_probe;
        input [4:0] index;
        begin
            address_probe =
                TEST_BASE + (22'h000001 << index);
        end
    endfunction


    // Sectors which need to be erased for the address test.
    //
    // These correspond to TEST_BASE and A16..A21 probes.
    //
    function [21:0] erase_sector;
        input [3:0] index;
        begin
            case (index)

                0: erase_sector = 22'h010000;
                1: erase_sector = 22'h020000;
                2: erase_sector = 22'h030000;
                3: erase_sector = 22'h050000;
                4: erase_sector = 22'h090000;
                5: erase_sector = 22'h110000;
                6: erase_sector = 22'h210000;

                default:
                    erase_sector = 22'h010000;

            endcase
        end
    endfunction


    // ============================================================
    // Main state machine
    // ============================================================

    reg [7:0] state;

    reg [3:0] cmd_step;
    reg [4:0] test_index;
    reg [3:0] sector_index;

    reg [23:0] delay_counter;

    reg [7:0] manufacturer_id;
    reg [7:0] device_id;


    // ------------------------------------------------------------
    // States
    // ------------------------------------------------------------

    localparam ST_POWER_WAIT          = 8'd0;

    localparam ST_ID_CMD              = 8'd1;
    localparam ST_ID_CMD_WAIT         = 8'd2;

    localparam ST_ID_MFG_READ         = 8'd3;
    localparam ST_ID_MFG_WAIT         = 8'd4;

    localparam ST_ID_DEV_READ         = 8'd5;
    localparam ST_ID_DEV_WAIT         = 8'd6;

    localparam ST_ID_CHECK            = 8'd7;

    localparam ST_RESET_CMD           = 8'd8;
    localparam ST_RESET_WAIT          = 8'd9;


    // Erase
    localparam ST_ERASE_CMD           = 8'd10;
    localparam ST_ERASE_CMD_WAIT      = 8'd11;
    localparam ST_ERASE_DELAY         = 8'd12;

    localparam ST_ERASE_VERIFY        = 8'd13;
    localparam ST_ERASE_VERIFY_WAIT   = 8'd14;


    // Data bus programming
    localparam ST_DATA_PROG           = 8'd20;
    localparam ST_DATA_PROG_WAIT      = 8'd21;
    localparam ST_DATA_PROG_DELAY     = 8'd22;

    localparam ST_DATA_VERIFY         = 8'd23;
    localparam ST_DATA_VERIFY_WAIT    = 8'd24;


    // Reference address
    localparam ST_REF_PROG            = 8'd30;
    localparam ST_REF_PROG_WAIT       = 8'd31;
    localparam ST_REF_PROG_DELAY      = 8'd32;


    // Address-line programming
    localparam ST_ADDR_PROG           = 8'd33;
    localparam ST_ADDR_PROG_WAIT      = 8'd34;
    localparam ST_ADDR_PROG_DELAY     = 8'd35;


    // Address-line verification
    localparam ST_REF_VERIFY          = 8'd36;
    localparam ST_REF_VERIFY_WAIT     = 8'd37;

    localparam ST_ADDR_VERIFY         = 8'd38;
    localparam ST_ADDR_VERIFY_WAIT    = 8'd39;


    localparam ST_PASS                = 8'd250;
    localparam ST_FAIL                = 8'd251;


    // ============================================================
    // Initialization
    // ============================================================

    initial begin

        bus_start = 1'b0;
        bus_write = 1'b0;
        bus_addr  = 22'd0;
        bus_wdata = 8'd0;

        test_pass = 1'b0;
        test_fail = 1'b0;

        state = ST_POWER_WAIT;

        cmd_step     = 0;
        test_index   = 0;
        sector_index = 0;

        delay_counter = 0;

        manufacturer_id = 0;
        device_id       = 0;

    end


    // ============================================================
    // Test sequencer
    // ============================================================

    always @(posedge clk) begin

        // start is always a one-clock pulse
        bus_start <= 1'b0;


        case (state)

            // ====================================================
            // Startup delay
            // ====================================================

            ST_POWER_WAIT: begin

                if (delay_counter >= POWER_DELAY) begin

                    delay_counter <= 0;
                    cmd_step <= 0;

                    state <= ST_ID_CMD;

                end else begin

                    delay_counter <= delay_counter + 1'b1;

                end

            end


            // ====================================================
            // AUTOSELECT
            //
            // AAA <- AA
            // 555 <- 55
            // AAA <- 90
            // ====================================================

            ST_ID_CMD: begin

                if (!bus_busy) begin

                    bus_write <= 1'b1;

                    case (cmd_step)

                        0: begin
                            bus_addr  <= UNLOCK1;
                            bus_wdata <= 8'hAA;
                        end

                        1: begin
                            bus_addr  <= UNLOCK2;
                            bus_wdata <= 8'h55;
                        end

                        default: begin
                            bus_addr  <= UNLOCK1;
                            bus_wdata <= 8'h90;
                        end

                    endcase

                    bus_start <= 1'b1;

                    state <= ST_ID_CMD_WAIT;

                end

            end


            ST_ID_CMD_WAIT: begin

                if (bus_done) begin

                    if (cmd_step == 2) begin

                        cmd_step <= 0;
                        state <= ST_ID_MFG_READ;

                    end else begin

                        cmd_step <= cmd_step + 1'b1;
                        state <= ST_ID_CMD;

                    end

                end

            end


            // ====================================================
            // Manufacturer ID = C2
            // ====================================================

            ST_ID_MFG_READ: begin

                if (!bus_busy) begin

                    bus_write <= 1'b0;
                    bus_addr  <= 22'h000000;

                    bus_start <= 1'b1;

                    state <= ST_ID_MFG_WAIT;

                end

            end


            ST_ID_MFG_WAIT: begin

                if (bus_done) begin

                    manufacturer_id <= bus_rdata;

                    state <= ST_ID_DEV_READ;

                end

            end


            // ====================================================
            // Device ID
            //
            // A7 = top boot
            // A8 = bottom boot
            // ====================================================

            ST_ID_DEV_READ: begin

                if (!bus_busy) begin

                    bus_write <= 1'b0;
                    bus_addr  <= 22'h000002;

                    bus_start <= 1'b1;

                    state <= ST_ID_DEV_WAIT;

                end

            end


            ST_ID_DEV_WAIT: begin

                if (bus_done) begin

                    device_id <= bus_rdata;

                    state <= ST_ID_CHECK;

                end

            end


            ST_ID_CHECK: begin

                if (
                    manufacturer_id == 8'hC2 &&
                    (
                        device_id == 8'hA7 ||
                        device_id == 8'hA8
                    )
                ) begin

                    state <= ST_RESET_CMD;

                end else begin

                    state <= ST_FAIL;

                end

            end


            // ====================================================
            // Return to normal read mode
            // ====================================================

            ST_RESET_CMD: begin

                if (!bus_busy) begin

                    bus_write <= 1'b1;
                    bus_addr  <= 22'h000000;
                    bus_wdata <= 8'hF0;

                    bus_start <= 1'b1;

                    state <= ST_RESET_WAIT;

                end

            end


            ST_RESET_WAIT: begin

                if (bus_done) begin

                    sector_index <= 0;
                    cmd_step <= 0;

                    state <= ST_ERASE_CMD;

                end

            end


            // ====================================================
            // SECTOR ERASE
            //
            // AAA <- AA
            // 555 <- 55
            // AAA <- 80
            // AAA <- AA
            // 555 <- 55
            // SA  <- 30
            // ====================================================

            ST_ERASE_CMD: begin

                if (!bus_busy) begin

                    bus_write <= 1'b1;

                    case (cmd_step)

                        0: begin
                            bus_addr  <= UNLOCK1;
                            bus_wdata <= 8'hAA;
                        end

                        1: begin
                            bus_addr  <= UNLOCK2;
                            bus_wdata <= 8'h55;
                        end

                        2: begin
                            bus_addr  <= UNLOCK1;
                            bus_wdata <= 8'h80;
                        end

                        3: begin
                            bus_addr  <= UNLOCK1;
                            bus_wdata <= 8'hAA;
                        end

                        4: begin
                            bus_addr  <= UNLOCK2;
                            bus_wdata <= 8'h55;
                        end

                        default: begin
                            bus_addr  <= erase_sector(sector_index);
                            bus_wdata <= 8'h30;
                        end

                    endcase

                    bus_start <= 1'b1;

                    state <= ST_ERASE_CMD_WAIT;

                end

            end


            ST_ERASE_CMD_WAIT: begin

                if (bus_done) begin

                    if (cmd_step == 5) begin

                        cmd_step <= 0;
                        delay_counter <= 0;

                        state <= ST_ERASE_DELAY;

                    end else begin

                        cmd_step <= cmd_step + 1'b1;

                        state <= ST_ERASE_CMD;

                    end

                end

            end


            // ====================================================
            // Wait max erase time + margin
            // ====================================================

            ST_ERASE_DELAY: begin

                if (delay_counter >= ERASE_DELAY) begin

                    delay_counter <= 0;

                    if (sector_index == 6) begin

                        sector_index <= 0;

                        state <= ST_ERASE_VERIFY;

                    end else begin

                        sector_index <= sector_index + 1'b1;
                        cmd_step <= 0;

                        state <= ST_ERASE_CMD;

                    end

                end else begin

                    delay_counter <= delay_counter + 1'b1;

                end

            end


            // ====================================================
            // Verify sector start == FF
            // ====================================================

            ST_ERASE_VERIFY: begin

                if (!bus_busy) begin

                    bus_write <= 1'b0;
                    bus_addr <= erase_sector(sector_index);

                    bus_start <= 1'b1;

                    state <= ST_ERASE_VERIFY_WAIT;

                end

            end


            ST_ERASE_VERIFY_WAIT: begin

                if (bus_done) begin

                    if (bus_rdata != 8'hFF) begin

                        state <= ST_FAIL;

                    end else if (sector_index == 6) begin

                        test_index <= 0;
                        cmd_step <= 0;

                        state <= ST_DATA_PROG;

                    end else begin

                        sector_index <= sector_index + 1'b1;

                        state <= ST_ERASE_VERIFY;

                    end

                end

            end


            // ====================================================
            // DATA BUS TEST
            //
            // Program 16 different walking patterns.
            // ====================================================

            ST_DATA_PROG: begin

                if (!bus_busy) begin

                    bus_write <= 1'b1;

                    case (cmd_step)

                        0: begin
                            bus_addr  <= UNLOCK1;
                            bus_wdata <= 8'hAA;
                        end

                        1: begin
                            bus_addr  <= UNLOCK2;
                            bus_wdata <= 8'h55;
                        end

                        2: begin
                            bus_addr  <= UNLOCK1;
                            bus_wdata <= 8'hA0;
                        end

                        default: begin
                            bus_addr <= DATA_BASE + test_index;
                            bus_wdata <= data_pattern(test_index);
                        end

                    endcase

                    bus_start <= 1'b1;

                    state <= ST_DATA_PROG_WAIT;

                end

            end


            ST_DATA_PROG_WAIT: begin

                if (bus_done) begin

                    if (cmd_step == 3) begin

                        cmd_step <= 0;
                        delay_counter <= 0;

                        state <= ST_DATA_PROG_DELAY;

                    end else begin

                        cmd_step <= cmd_step + 1'b1;

                        state <= ST_DATA_PROG;

                    end

                end

            end


            ST_DATA_PROG_DELAY: begin

                if (delay_counter >= PROGRAM_DELAY) begin

                    delay_counter <= 0;

                    if (test_index == 15) begin

                        test_index <= 0;

                        state <= ST_DATA_VERIFY;

                    end else begin

                        test_index <= test_index + 1'b1;

                        state <= ST_DATA_PROG;

                    end

                end else begin

                    delay_counter <= delay_counter + 1'b1;

                end

            end


            // ====================================================
            // Verify data patterns
            // ====================================================

            ST_DATA_VERIFY: begin

                if (!bus_busy) begin

                    bus_write <= 1'b0;
                    bus_addr <= DATA_BASE + test_index;

                    bus_start <= 1'b1;

                    state <= ST_DATA_VERIFY_WAIT;

                end

            end


            ST_DATA_VERIFY_WAIT: begin

                if (bus_done) begin

                    if (
                        bus_rdata !=
                        data_pattern(test_index)
                    ) begin

                        state <= ST_FAIL;

                    end else if (test_index == 15) begin

                        cmd_step <= 0;

                        state <= ST_REF_PROG;

                    end else begin

                        test_index <= test_index + 1'b1;

                        state <= ST_DATA_VERIFY;

                    end

                end

            end


            // ====================================================
            // Program reference address
            //
            // TEST_BASE = A5
            // ====================================================

            ST_REF_PROG: begin

                if (!bus_busy) begin

                    bus_write <= 1'b1;

                    case (cmd_step)

                        0: begin
                            bus_addr  <= UNLOCK1;
                            bus_wdata <= 8'hAA;
                        end

                        1: begin
                            bus_addr  <= UNLOCK2;
                            bus_wdata <= 8'h55;
                        end

                        2: begin
                            bus_addr  <= UNLOCK1;
                            bus_wdata <= 8'hA0;
                        end

                        default: begin
                            bus_addr  <= TEST_BASE;
                            bus_wdata <= 8'hA5;
                        end

                    endcase

                    bus_start <= 1'b1;

                    state <= ST_REF_PROG_WAIT;

                end

            end


            ST_REF_PROG_WAIT: begin

                if (bus_done) begin

                    if (cmd_step == 3) begin

                        cmd_step <= 0;
                        delay_counter <= 0;

                        state <= ST_REF_PROG_DELAY;

                    end else begin

                        cmd_step <= cmd_step + 1'b1;

                        state <= ST_REF_PROG;

                    end

                end

            end


            ST_REF_PROG_DELAY: begin

                if (delay_counter >= PROGRAM_DELAY) begin

                    delay_counter <= 0;
                    test_index <= 0;

                    state <= ST_ADDR_PROG;

                end else begin

                    delay_counter <= delay_counter + 1'b1;

                end

            end


            // ====================================================
            // ADDRESS BUS TEST
            //
            // Program:
            //
            // BASE + 2^0
            // BASE + 2^1
            // ...
            // BASE + 2^21
            //
            // with unique data.
            // ====================================================

            ST_ADDR_PROG: begin

                if (!bus_busy) begin

                    bus_write <= 1'b1;

                    case (cmd_step)

                        0: begin
                            bus_addr  <= UNLOCK1;
                            bus_wdata <= 8'hAA;
                        end

                        1: begin
                            bus_addr  <= UNLOCK2;
                            bus_wdata <= 8'h55;
                        end

                        2: begin
                            bus_addr  <= UNLOCK1;
                            bus_wdata <= 8'hA0;
                        end

                        default: begin
                            bus_addr <= address_probe(test_index);
                            bus_wdata <= address_pattern(test_index);
                        end

                    endcase

                    bus_start <= 1'b1;

                    state <= ST_ADDR_PROG_WAIT;

                end

            end


            ST_ADDR_PROG_WAIT: begin

                if (bus_done) begin

                    if (cmd_step == 3) begin

                        cmd_step <= 0;
                        delay_counter <= 0;

                        state <= ST_ADDR_PROG_DELAY;

                    end else begin

                        cmd_step <= cmd_step + 1'b1;

                        state <= ST_ADDR_PROG;

                    end

                end

            end


            ST_ADDR_PROG_DELAY: begin

                if (delay_counter >= PROGRAM_DELAY) begin

                    delay_counter <= 0;

                    if (test_index == 21) begin

                        state <= ST_REF_VERIFY;

                    end else begin

                        test_index <= test_index + 1'b1;

                        state <= ST_ADDR_PROG;

                    end

                end else begin

                    delay_counter <= delay_counter + 1'b1;

                end

            end


            // ====================================================
            // Verify reference address first.
            //
            // If any address line caused an alias onto BASE,
            // its A5 value may have been corrupted.
            // ====================================================

            ST_REF_VERIFY: begin

                if (!bus_busy) begin

                    bus_write <= 1'b0;
                    bus_addr <= TEST_BASE;

                    bus_start <= 1'b1;

                    state <= ST_REF_VERIFY_WAIT;

                end

            end


            ST_REF_VERIFY_WAIT: begin

                if (bus_done) begin

                    if (bus_rdata != 8'hA5) begin

                        state <= ST_FAIL;

                    end else begin

                        test_index <= 0;

                        state <= ST_ADDR_VERIFY;

                    end

                end

            end


            // ====================================================
            // Verify all 22 one-hot addresses
            // ====================================================

            ST_ADDR_VERIFY: begin

                if (!bus_busy) begin

                    bus_write <= 1'b0;
                    bus_addr <= address_probe(test_index);

                    bus_start <= 1'b1;

                    state <= ST_ADDR_VERIFY_WAIT;

                end

            end


            ST_ADDR_VERIFY_WAIT: begin

                if (bus_done) begin

                    if (
                        bus_rdata !=
                        address_pattern(test_index)
                    ) begin

                        state <= ST_FAIL;

                    end else if (test_index == 21) begin

                        state <= ST_PASS;

                    end else begin

                        test_index <= test_index + 1'b1;

                        state <= ST_ADDR_VERIFY;

                    end

                end

            end


            // ====================================================
            // PASS
            // ====================================================

            ST_PASS: begin

                test_pass <= 1'b1;
                test_fail <= 1'b0;

            end


            // ====================================================
            // FAIL
            // ====================================================

            ST_FAIL: begin

                test_pass <= 1'b0;
                test_fail <= 1'b1;

            end


            default: begin
                state <= ST_FAIL;
            end

        endcase

    end

endmodule



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