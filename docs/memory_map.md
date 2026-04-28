# Tiny-Easy-GPU 1.0 Memory Map (MMIO)

## Suggested Base Address
- `GPU_BASE = 0x4002_0000`

## Registers
- `0x00` `GPU_CMD_DATA` (WO, 32-bit)
  - CPU writes command words (Word0/Word1/Word2) here.
- `0x04` `GPU_STATUS` (RO, 32-bit)
  - Bit[0] `BUSY`: 1 while decoder/engine are processing a command.
  - Bit[1] `READY`: 1 when decoder can accept next word.
  - Others reserved.

## Software Programming Model
1. Poll `GPU_STATUS.READY == 1`.
2. Write Word 0 to `GPU_CMD_DATA`.
3. For multi-word opcodes, poll `READY`, then write Word 1 and Word 2.
4. Poll `BUSY == 0` for completion.
