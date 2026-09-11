# Author(s):
#   - Spyridon Poursalidis <s.poursalidis@gmail.com>
#
# Description:
#

WORK_DIR = work
COMPILE_OPTS = --2008

TB_FILE = tb_sobel_3x3_core_axis

.PHONY: all compile sim clean

all:
	make compile sim

compile:
	xvhdl $(COMPILE_OPTS) -work vhdl_tb_lib $(HOME)/vhdl_tb_lib/*.vhd
	xvlog -work $(WORK_DIR) $(VIVADO_PATH)/data/verilog/src/glbl.v
	xvhdl $(COMPILE_OPTS) -work $(WORK_DIR) ../hdl/sobel_3x3_core_axis.vhd
	xvhdl $(COMPILE_OPTS) -work $(WORK_DIR) $(TB_FILE).vhd
	
sim:
	if [ "$(GUI)" = "1" ]; then \
		xelab --debug wave $(TB_FILE) glbl -s $(TB_FILE); \
		xsim $(TB_FILE) -gui; \
	else \
		xelab $(TB_FILE) glbl -s $(TB_FILE); \
		xsim $(TB_FILE); \
	fi

clean:
	rm -rf xsim_dir/ xvhdl* xvlog* xelab* xsim* .Xil vivado* $(WORK_DIR)* *.wdb *.hex *.png *.jou *.log
