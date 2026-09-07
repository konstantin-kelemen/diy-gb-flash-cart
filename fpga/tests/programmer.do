onerror {quit -code 1 -force}
onbreak {quit -code 1 -force}
vlib programmer_work
vlog -sv -work programmer_work ../../rtl/mx29_bus.v ../../rtl/mx29_programmer.v ../../rtl/programmer_spi.v ../programmer_tb.sv
vsim -c programmer_work.programmer_tb
run -all
quit -code 0 -force
