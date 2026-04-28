# Project Structure

- `rtl/top/`
  - Top-level RTL (`gpu_top.v`).
- `rtl/modules/`
  - Sub-modules (`cmd_decode.v`, `draw_engine.v`, `frame_buffer_dp.v`, `vga_ctrl.v`).
- `verification/Unit_Level/`
  - Unit verification per module.
  - Each module contains:
    - `tb/`: Verilog testbench.
    - `test_data/`: Input stimuli.
    - `golden_model/`: Python reference model.
    - `golden_output/`: Model-generated expected outputs.
- `verification/System_Level/`
  - End-to-end verification using integrated testbench.
  - Structure includes `tb/`, `test_data/`, `golden_model/`, `golden_output/`.
- `docs/`
  - ISA, memory map, and design notes.
- `scripts/`
  - Build/simulation automation (Makefile, helper scripts).
