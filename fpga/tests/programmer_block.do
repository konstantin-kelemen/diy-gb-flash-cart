onerror {quit -code 1 -force}
onbreak {quit -code 1 -force}
vlib programmer_block_work
vlog -sv -work programmer_block_work ../../rtl/mx29_bus.v ../../rtl/mx29_programmer.v ../../rtl/programmer_block.v ../programmer_block_tb.sv
vsim -c programmer_block_work.programmer_block_tb
run -all
quit -code 0 -force
