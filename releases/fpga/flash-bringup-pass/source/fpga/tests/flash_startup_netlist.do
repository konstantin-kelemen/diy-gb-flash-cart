onerror {quit -code 1 -force}
onbreak {quit -code 1 -force}
if {![file isdirectory gate_work]} {vlib gate_work}
if {[info exists expect_bad_startup]} {
    vlog -work gate_work +define+EXPECT_BAD_STARTUP ../../diamond/flash_bringup/top_prim.v ../flash_startup_netlist_tb.sv
    vsim -c -L ovi_machxo2 gate_work.flash_startup_netlist_tb +expect_bad_startup
} else {
    vlog -work gate_work ../../diamond/flash_bringup/top_prim.v ../flash_startup_netlist_tb.sv
    vsim -c -L ovi_machxo2 gate_work.flash_startup_netlist_tb
}
run -all
quit -code 0 -force
