# Auto-generated Vivado synthesis script for brv32_mcu
set_param general.maxThreads 4

create_project -in_memory -part xc7a35tcpg236-1

set_property include_dirs {/home/brendan/synthesis_workspace/RISCV_RV32I_SingleCycle/rtl} [current_fileset]

read_verilog [list \
    /home/brendan/synthesis_workspace/RISCV_RV32I_SingleCycle/rtl/alu.v \
    /home/brendan/synthesis_workspace/RISCV_RV32I_SingleCycle/rtl/brv32_core.v \
    /home/brendan/synthesis_workspace/RISCV_RV32I_SingleCycle/rtl/brv32_mcu.v \
    /home/brendan/synthesis_workspace/RISCV_RV32I_SingleCycle/rtl/csr.v \
    /home/brendan/synthesis_workspace/RISCV_RV32I_SingleCycle/rtl/decoder.v \
    /home/brendan/synthesis_workspace/RISCV_RV32I_SingleCycle/rtl/dmem.v \
    /home/brendan/synthesis_workspace/RISCV_RV32I_SingleCycle/rtl/gpio.v \
    /home/brendan/synthesis_workspace/RISCV_RV32I_SingleCycle/rtl/imem.v \
    /home/brendan/synthesis_workspace/RISCV_RV32I_SingleCycle/rtl/regfile.v \
    /home/brendan/synthesis_workspace/RISCV_RV32I_SingleCycle/rtl/timer.v \
    /home/brendan/synthesis_workspace/RISCV_RV32I_SingleCycle/rtl/uart.v \
]

# Write XDC constraint file for clock
set xdc_file "/home/brendan/synthesis_workspace/RISCV_RV32I_SingleCycle/synthesis_logs/clock.xdc"
set fp [open $xdc_file w]
puts $fp "create_clock -period 10.000 -name clk \[get_ports clk\]"
close $fp
read_xdc $xdc_file

synth_design -top brv32_mcu -part xc7a35tcpg236-1

report_utilization -file /home/brendan/synthesis_workspace/RISCV_RV32I_SingleCycle/synthesis_logs/utilization_brv32_mcu.rpt
report_timing_summary -file /home/brendan/synthesis_workspace/RISCV_RV32I_SingleCycle/synthesis_logs/timing_brv32_mcu.rpt
