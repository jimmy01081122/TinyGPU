# Tiny-Easy-GPU 1.0 MMIO Command ISA

## Overview
Tiny-Easy-GPU is a CPU MMIO peripheral. Commands are written by CPU store operations to a 32-bit MMIO data register (`GPU_CMD_DATA`).

## Opcode (Word 0 [31:28])
- `0000` (`0x0`): NOP, 1 word
- `0001` (`0x1`): CLEAR, 1 word
- `0010` (`0x2`): DRAW_POINT, 2 words
- `0011` (`0x3`): DRAW_LINE, 3 words

## Payload Format
### Word 0: Command Header
- `[31:28]` Opcode (4-bit)
- `[27:16]` Color (12-bit, RGB444)
- `[15:0]` Reserved

### Word 1: Coord 0
- `[31:19]` Reserved
- `[18:10]` Y0 (9-bit, 0..239)
- `[9:0]` X0 (10-bit, 0..319)

### Word 2: Coord 1
- `[31:19]` Reserved
- `[18:10]` Y1 (9-bit, 0..239)
- `[9:0]` X1 (10-bit, 0..319)

## Command Semantics
- `NOP`: No framebuffer write. Engine returns done immediately.
- `CLEAR`: Fill all 320x240 pixels with `Color`.
- `DRAW_POINT`: Plot one pixel at `(X0, Y0)` in `Color`.
- `DRAW_LINE`: Draw line from `(X0, Y0)` to `(X1, Y1)` via Bresenham.

## Host Handshake
- `host_cmd_valid`: one-cycle pulse with valid `host_cmd_data`.
- `host_cmd_ready`: high when decoder can accept a word.
- Decoder asserts internal `busy` after command header is accepted and keeps it asserted until draw engine returns `done_pulse`.
