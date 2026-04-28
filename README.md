# Tiny-Easy-GPU 1.0 (Starter Implementation)

## Quick Start
```bash
cd Tiny-Easy-GPU/scripts
make gen_golden
make unit_cmd_decode
make unit_draw_engine
make unit_vga
make system_tb
make lint
```

## Toolchain
- Verilog simulation: `iverilog`, `vvp`
- Lint: `verilator --lint-only`
- Golden model: `python3` + `numpy` (+ optional `pillow`)

## Directory
See [docs/project_structure.md](docs/project_structure.md).

## Notes
- `gpu_top` is designed as MMIO peripheral endpoint.
- `cmd_decode` supports multi-word command FSM.
- `draw_engine` includes NOP/CLEAR/POINT/LINE (Bresenham).
- Framebuffer is 320x240 dual-port RAM (sys write / vga read).
- VGA path performs 2x nearest-neighbor up-scaling to 640x480.
