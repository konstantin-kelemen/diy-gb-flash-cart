onerror {quit -code 1 -force}
onbreak {quit -code 1 -force}
vlib spi_work
if {[info exists netlist]} {
    vlog -sv -work spi_work +define+NETLIST ../../diamond/spi_bringup/top_prim.v ../spi_bringup_tb.sv
    vsim -c -L ovi_machxo2 spi_work.spi_bringup_tb
} else {
    vlog -sv -work spi_work ../../targets/spi_bringup/top.v ../spi_bringup_tb.sv
    vsim -c spi_work.spi_bringup_tb
}
run -all
quit -code 0 -force
