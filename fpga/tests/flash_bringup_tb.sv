`timescale 1ns/1ps

// Simulation-only oscillator; production uses the MachXO2 primitive.
module OSCH #(parameter NOM_FREQ = "2.08") (
    input STDBY, output reg OSC = 0, output SEDSTDBY
);
    assign SEDSTDBY = STDBY;
    always #5 OSC = ~OSC;
endmodule

// RTL model of the explicit clear-on-power-up primitive. The additional
// netlist test uses Lattice's real primitive models to verify this assumption.
module FD1S3AX (input D, CK, output reg Q = 0);
    always @(posedge CK) Q <= D;
endmodule

module flash_case #(parameter SCENARIO = 0) (output reg finished = 0);
    wire [21:0] addr;
    tri [7:0] data;
    wire ce_n, oe_n, we_n, passed, failed;
    top #(.POWER_DELAY(4), .PROGRAM_DELAY(4), .ERASE_DELAY(4),
          .DIAG_TICK_CYCLES(8)) dut (
        .flash_a(addr), .flash_d(data), .flash_ce_n(ce_n),
        .flash_oe_n(oe_n), .flash_we_n(we_n),
        .test_pass(passed), .test_fail(failed)
    );

    // Sparse byte memory with an independent command decoder. This checks
    // sequencer/bus integration, not the electrical timing of a real Flash.
    reg [7:0] memory [int unsigned];
    reg autoselect = 0;
    integer command_step = 0;
    integer writes = 0;
    reg [7:0] read_value;
    always @* begin
        read_value = 8'hFF;
        if (memory.exists(int'(addr))) read_value = memory[int'(addr)];
        if (autoselect) begin
            case (addr)
                0: read_value = SCENARIO == 1 ? 8'h00 : 8'hC2;
                2: read_value = SCENARIO == 2 ? 8'h00 : 8'hA8;
                default: read_value = 8'hFF;
            endcase
        end
        // Inject a read mismatch only at the selected verification stage.
        if ((SCENARIO == 3 && dut.state == dut.ST_ERASE_VERIFY_WAIT) ||
            (SCENARIO == 4 && dut.state == dut.ST_DATA_VERIFY_WAIT) ||
            (SCENARIO == 5 && dut.state == dut.ST_REF_VERIFY_WAIT) ||
            (SCENARIO == 6 && dut.state == dut.ST_ADDR_VERIFY_WAIT))
            read_value = read_value ^ 8'h01;
    end
    assign data = !ce_n && !oe_n && we_n ? read_value : 8'bz;

    always @(posedge we_n) begin
        if (!ce_n) begin
            if (!oe_n || $isunknown({addr, data}))
                $fatal(1, "Invalid bus write, scenario %0d", SCENARIO);
            writes = writes + 1;
            case (command_step)
                0: begin
                    if (data == 8'hF0) autoselect = 0;
                    else if (addr == 22'hAAA && data == 8'hAA) command_step = 1;
                    else $fatal(1, "Expected unlock 1");
                end
                1: begin
                    if (addr != 22'h555 || data != 8'h55) $fatal(1, "Expected unlock 2");
                    command_step = 2;
                end
                2: begin
                    if (addr != 22'hAAA) $fatal(1, "Invalid command address");
                    case (data)
                        8'h90: begin autoselect = 1; command_step = 0; end
                        8'hA0: command_step = 3;
                        8'h80: command_step = 4;
                        default: $fatal(1, "Unexpected command");
                    endcase
                end
                3: begin
                    if (memory.exists(int'(addr))) memory[int'(addr)] &= data;
                    else memory[int'(addr)] = data;
                    command_step = 0;
                end
                4: begin
                    if (addr != 22'hAAA || data != 8'hAA) $fatal(1, "Erase unlock 1");
                    command_step = 5;
                end
                5: begin
                    if (addr != 22'h555 || data != 8'h55) $fatal(1, "Erase unlock 2");
                    command_step = 6;
                end
                6: begin
                    if (data != 8'h30) $fatal(1, "Erase confirm");
                    foreach (memory[a])
                        if ((a >> 16) == (addr >> 16)) memory[a] = 8'hFF;
                    command_step = 0;
                end
            endcase
        end
    end

    // Illegal-state fallback is checked independently of normal commands.
    initial if (SCENARIO == 7) begin
        wait (!dut.startup_reset);
        @(negedge dut.clk);
        dut.state = 8'd200;
    end

    integer sample_index, slots, terminal_writes;
    reg expected_high;
    initial begin
        if (SCENARIO == 0) begin
            wait (passed === 1'b1);
            terminal_writes = writes;
            repeat (64) begin
                @(negedge dut.clk);
                if (failed !== 0 || passed !== 1 || writes != terminal_writes)
                    $fatal(1, "PASS did not remain stable");
            end
        end else begin
            wait (failed === 1'b1);
            terminal_writes = writes;
            slots = 2 * SCENARIO + 4;
            // Check every output sample over two complete pulse groups,
            // including the long inter-group gap and sticky failure.
            for (sample_index = 0; sample_index < 2 * slots * 8; sample_index++) begin
                @(negedge dut.clk);
                expected_high = (((sample_index / 8) % slots) < 2 * SCENARIO) &&
                                (((sample_index / 8) % 2) == 0);
                if (failed !== expected_high || passed !== 0)
                    $fatal(1, "Pulse mismatch scenario %0d sample %0d", SCENARIO, sample_index);
                if (writes != terminal_writes || !ce_n || !oe_n || !we_n)
                    $fatal(1, "Bus active after failure");
            end
        end
        $display("PASS scenario %0d", SCENARIO);
        finished = 1;
    end
endmodule

module flash_bringup_tb;
    wire [7:0] finished;
    for (genvar i = 0; i < 8; i++) begin : cases
        flash_case #(.SCENARIO(i)) test_case (.finished(finished[i]));
    end
    initial begin
        wait (&finished);
        $display("All flash bringup diagnostics passed");
        $finish;
    end
    initial begin
        #2000000;
        $fatal(1, "Simulation timeout");
    end
endmodule
