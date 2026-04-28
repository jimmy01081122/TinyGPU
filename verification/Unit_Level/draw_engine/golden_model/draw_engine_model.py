#!/usr/bin/env python3
from pathlib import Path
import csv

FB_W = 320
FB_H = 240

OPC_NOP = 0
OPC_CLEAR = 1
OPC_DRAW_POINT = 2
OPC_DRAW_LINE = 3


def addr(x, y):
    return y * FB_W + x


def bresenham(x0, y0, x1, y1):
    points = []
    dx = abs(x1 - x0)
    sx = 1 if x0 < x1 else -1
    dy = -abs(y1 - y0)
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    x, y = x0, y0
    while True:
        points.append((x, y))
        if x == x1 and y == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x += sx
        if e2 <= dx:
            err += dx
            y += sy
    return points


def run_case(opcode, color, x0=0, y0=0, x1=0, y1=0):
    writes = []
    if opcode == OPC_NOP:
        return writes
    if opcode == OPC_CLEAR:
        for a in range(FB_W * FB_H):
            writes.append((a, color, a % FB_W, a // FB_W))
        return writes
    if opcode == OPC_DRAW_POINT:
        if 0 <= x0 < FB_W and 0 <= y0 < FB_H:
            writes.append((addr(x0, y0), color, x0, y0))
        return writes
    if opcode == OPC_DRAW_LINE:
        for x, y in bresenham(x0, y0, x1, y1):
            if 0 <= x < FB_W and 0 <= y < FB_H:
                writes.append((addr(x, y), color, x, y))
        return writes
    return writes


def main():
    base = Path(__file__).resolve().parents[1]
    out_path = base / "golden_output" / "draw_engine_writes.csv"
    cases = [
        (OPC_DRAW_POINT, 0x0F0, 10, 20, 0, 0),
        (OPC_DRAW_LINE, 0x00F, 0, 0, 10, 6),
        (OPC_DRAW_LINE, 0xF00, 10, 6, 0, 0),
    ]

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["case_id", "addr", "color", "x", "y"])
        for idx, c in enumerate(cases):
            for row in run_case(*c):
                writer.writerow([idx, row[0], row[1], row[2], row[3]])
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
