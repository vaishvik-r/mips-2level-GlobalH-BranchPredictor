## Makefile — MIPS Pipeline + Two-Level Branch Predictor
## Usage:
##   make        → compile + run simulation
##   make wave   → open GTKWave
##   make clean  → remove build artifacts

SIM_DIR = sim
TB      = tb/tb_mips_pipeline.sv
RTL     = rtl/alu.sv \
          rtl/alu_control.sv \
          rtl/regfile.sv \
          rtl/control.sv \
          rtl/hazard_unit.sv \
          rtl/forwarding_unit.sv \
          rtl/branch_predictor.sv \
          rtl/memory.sv \
          rtl/mips_pipeline.sv

all: $(SIM_DIR)/mips_sim
	vvp $(SIM_DIR)/mips_sim

$(SIM_DIR)/mips_sim: $(RTL) $(TB)
	@mkdir -p $(SIM_DIR)
	iverilog -g2012 -o $(SIM_DIR)/mips_sim $(RTL) $(TB)

wave: $(SIM_DIR)/mips_wave.vcd
	gtkwave $(SIM_DIR)/mips_wave.vcd docs/gtkwave_signals.gtkw &

$(SIM_DIR)/mips_wave.vcd: $(SIM_DIR)/mips_sim
	vvp $(SIM_DIR)/mips_sim

clean:
	rm -f $(SIM_DIR)/mips_sim $(SIM_DIR)/mips_wave.vcd
