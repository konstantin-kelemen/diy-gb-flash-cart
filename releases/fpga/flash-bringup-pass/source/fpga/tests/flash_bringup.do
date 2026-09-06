onerror {quit -code 1 -force}
onbreak {quit -code 1 -force}
vlib work
vlog -sv ../../rtl/mx29_bus.v ../../targets/flash_bringup/top.v ../flash_bringup_tb.sv
vsim -c work.flash_bringup_tb
run -all
quit -code 0 -force
