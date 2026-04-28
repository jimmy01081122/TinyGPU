ROOT := ..
RTL := $(ROOT)/rtl
VERIF := $(ROOT)/verification

IVERILOG ?= iverilog
VVP ?= vvp
VERILATOR ?= verilator
PYTHON ?= python3

RTL_SRCS := \
	$(RTL)/modules/cmd_decode.v \
	$(RTL)/modules/draw_engine.v \
	$(RTL)/modules/frame_buffer_dp.v \
	$(RTL)/modules/vga_ctrl.v \
	$(RTL)/top/gpu_top.v

.PHONY: all gen_golden unit_cmd_decode unit_draw_engine unit_vga system_tb lint clean

all: gen_golden unit_cmd_decode unit_draw_engine unit_vga system_tb lint

gen_golden:
	$(PYTHON) $(VERIF)/Unit_Level/cmd_decode/golden_model/cmd_decode_model.py
	$(PYTHON) $(VERIF)/Unit_Level/draw_engine/golden_model/draw_engine_model.py
	$(PYTHON) $(VERIF)/System_Level/golden_model/system_golden_model.py

unit_cmd_decode:
	$(IVERILOG) -g2012 -o /tmp/cmd_decode_tb.out \
		$(RTL)/modules/cmd_decode.v \
		$(VERIF)/Unit_Level/cmd_decode/tb/cmd_decode_tb.v
	$(VVP) /tmp/cmd_decode_tb.out

unit_draw_engine:
	$(IVERILOG) -g2012 -o /tmp/draw_engine_tb.out \
		$(RTL)/modules/draw_engine.v \
		$(VERIF)/Unit_Level/draw_engine/tb/draw_engine_tb.v
	$(VVP) /tmp/draw_engine_tb.out

unit_vga:
	$(IVERILOG) -g2012 -o /tmp/vga_ctrl_tb.out \
		$(RTL)/modules/vga_ctrl.v \
		$(VERIF)/Unit_Level/vga_ctrl/tb/vga_ctrl_tb.v
	$(VVP) /tmp/vga_ctrl_tb.out

system_tb:
	$(IVERILOG) -g2012 -o /tmp/gpu_top_tb.out \
		$(RTL_SRCS) \
		$(VERIF)/System_Level/tb/gpu_top_tb.v
	$(VVP) /tmp/gpu_top_tb.out

lint:
	$(VERILATOR) --lint-only -Wall $(RTL_SRCS)

clean:
	rm -f /tmp/cmd_decode_tb.out /tmp/draw_engine_tb.out /tmp/vga_ctrl_tb.out /tmp/gpu_top_tb.out
