# Makefile for CocoTB testbench — BRV32 MCU
#
# Usage:
#   make                 # Run all tests
#   make TESTCASE=test_01_reset   # Run a single test
#   make SIM=verilator   # Use Verilator (default: icarus)
#   make WAVES=1         # Dump waveforms

TOPLEVEL_LANG = verilog
VERILOG_SOURCES = \
    $(PWD)/../rtl/riscv_pkg.sv \
    $(PWD)/../rtl/alu.sv \
    $(PWD)/../rtl/regfile.sv \
    $(PWD)/../rtl/decoder.sv \
    $(PWD)/../rtl/imem.sv \
    $(PWD)/../rtl/dmem.sv \
    $(PWD)/../rtl/gpio.sv \
    $(PWD)/../rtl/uart.sv \
    $(PWD)/../rtl/timer.sv \
    $(PWD)/../rtl/csr.sv \
    $(PWD)/../rtl/brv32_core.sv \
    $(PWD)/../rtl/brv32_mcu.sv

TOPLEVEL = brv32_mcu
MODULE = test_brv32_mcu

# Simulator selection (icarus, verilator, questa, etc.)
SIM ?= icarus

# Icarus Verilog flags
ifeq ($(SIM),icarus)
  COMPILE_ARGS += -g2012
  COMPILE_ARGS += -DINIT_FILE=\"$(PWD)/../firmware/firmware.hex\"
endif

# Waveform dumping
ifeq ($(WAVES),1)
  COMPILE_ARGS += -DWAVES
  ifeq ($(SIM),icarus)
    PLUSARGS += +VCD
  endif
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

# Copy firmware hex to sim build directory
sim: $(PWD)/../firmware/firmware.hex
$(PWD)/../firmware/firmware.hex:
	cd ../firmware && python3 gen_firmware.py
