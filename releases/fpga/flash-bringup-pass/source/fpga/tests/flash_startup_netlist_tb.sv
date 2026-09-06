`timescale 1ns/1ps
// Run against LSE's top_prim.v with the vendor ovi_machxo2 library.
// Unlike RTL simulation, this exercises the actual FF power-up polarity.
module flash_startup_netlist_tb;
    wire [21:0] flash_a;
    tri [7:0] flash_d;
    wire ce_n, oe_n, we_n, passed, failed;
    top dut (.flash_a(flash_a), .flash_d(flash_d), .flash_ce_n(ce_n),
             .flash_oe_n(oe_n), .flash_we_n(we_n),
             .test_pass(passed), .test_fail(failed));
    initial begin
        #10;
`ifdef EXPECT_BAD_STARTUP
        $display("Power-up state = %h", dut.state);
`endif
        #20000;
`ifdef EXPECT_BAD_STARTUP
        begin
            if (dut.state !== 8'd251 || dut.fail_code !== 3'd7)
                $fatal(1, "Old netlist did not reproduce startup failure");
            $display("REPRODUCED: power-up enters ST_FAIL, code 7");
        end
`else
        begin
            if (dut.startup_ready !== 4'hF || dut.fail_code !== 0 ||
                $isunknown(dut.delay_counter) || dut.delay_counter > 100 ||
                passed !== 0 || failed !== 0 ||
                ce_n !== 1 || oe_n !== 1 || we_n !== 1)
                $fatal(1, "Startup did not settle to safe ST_POWER_WAIT");
            $display("PASS: netlist starts in ST_POWER_WAIT with Flash inactive");
        end
`endif
        $finish;
    end
endmodule
