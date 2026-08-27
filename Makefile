# Makefile for RISC-V 5-stage Pipelined Processor Simulation

# LOG=0: only start/end on console
# LOG=1: timestamped log file
# LOG=2: log file and console traces
LOG ?= 1

LOG_TIME = $(shell date +%Y%m%d_%H%M%S)

HEX = program.hex
SIM_OUT = riscv_sim

ifneq ($(filter test-dhrystone,$(MAKECMDGOALS)),)
    TEST_TYPE = DHRYSTONE
    TEST_FILE = tests/dhrystone
else ifneq ($(filter test-coremark,$(MAKECMDGOALS)),)
    TEST_TYPE = COREMARK
    TEST_FILE = tests/coremark
else
    TEST_TYPE = DHRYSTONE
    TEST_FILE = tests/dhrystone
endif

COMPILE_FLAGS = -DLOG_LEVEL=$(LOG) -DLOG_TIME='"$(LOG_TIME)"' -DLOG_FILENAME='"tests/sim_log_$(LOG_TIME).log"' -DTEST_TYPE='"$(TEST_TYPE)"' -DTEST_FILE='"$(TEST_FILE)"'

PKG = src/includes/riscv_pkg.sv

PRIM_SRC = src/core/primitives/adder.sv

WALL_SRC = src/core/walls/riscv_ifu_reg_ifu2idu.sv \
           src/core/walls/riscv_idu_reg_idu2exu.sv \
           src/core/walls/riscv_exu_reg_exu2mem.sv \
           src/core/walls/riscv_mem_reg_mem2wb.sv

FETCH_SRC = src/core/fetch/riscv_ifu_pc.sv \
            src/core/fetch/riscv_ifu.sv

DECODE_SRC = src/core/decode/riscv_idu_reg_file.sv \
             src/core/decode/riscv_idu_imm.sv \
             src/core/decode/riscv_idu_cmp.sv \
             src/core/decode/riscv_idu_ctrl.sv \
             src/core/decode/riscv_idu_dec.sv \
             src/core/decode/riscv_idu.sv

EXECUTE_SRC = src/core/execute/riscv_exu_ialu.sv \
              src/core/execute/riscv_exu_imul.sv \
              src/core/execute/riscv_exu_idiv.sv \
              src/core/execute/riscv_exu_fwd.sv \
              src/core/execute/riscv_exu.sv

MEMORY_SRC = src/core/memory/riscv_mem.sv

WB_SRC = src/core/writeback/riscv_wb.sv

HAZARD_SRC = src/core/hazard/riscv_hazard_hdu.sv

TOP_SRC = src/core/riscv_core.sv \
          src/top/riscv_imem.sv \
          src/top/riscv_dmem.sv \
          src/top/riscv_top.sv

TB_SRC = src/tb/riscv_tb.sv

SRCS = $(PKG) $(PRIM_SRC) $(WALL_SRC) $(FETCH_SRC) $(DECODE_SRC) $(EXECUTE_SRC) \
       $(MEMORY_SRC) $(WB_SRC) $(HAZARD_SRC) $(TOP_SRC) $(TB_SRC)

.PHONY: all compile run wave clean test-dhrystone test-coremark html

all: test-dhrystone

test-dhrystone:
	python3 tests/compile_to_hex.py dhrystone $(HEX)
	iverilog -g2012 -I src/includes $(COMPILE_FLAGS) -s riscv_tb -o $(SIM_OUT) $(SRCS)
	vvp $(SIM_OUT)

test-coremark:
	python3 tests/compile_to_hex.py coremark $(HEX)
	iverilog -g2012 -I src/includes $(COMPILE_FLAGS) -s riscv_tb -o $(SIM_OUT) $(SRCS)
	vvp $(SIM_OUT)

compile:
	python3 tests/compile_to_hex.py dhrystone $(HEX)
	iverilog -g2012 -I src/includes $(COMPILE_FLAGS) -s riscv_tb -o $(SIM_OUT) $(SRCS)

run: compile
	vvp $(SIM_OUT)

wave:
	gtkwave riscv_sim.vcd &

SPHINXBUILD = $(shell which sphinx-build 2>/dev/null || echo "$$HOME/.local/bin/sphinx-build")

html:
	$(SPHINXBUILD) -b html docs docs/build/html
	@echo "============================================="
	@echo "Documentation built successfully!"
	@echo "Open file://$(CURDIR)/docs/build/html/index.html in your browser."
	@echo "============================================="

clean:
	rm -f $(HEX) data.hex $(SIM_OUT) riscv_sim.vcd
	rm -rf docs/build
