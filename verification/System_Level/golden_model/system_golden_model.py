#!/usr/bin/env python3
from pathlib import Path

try:
    from PIL import Image
except Exception:
    Image = None

FB_W = 320
FB_H = 240

OPC_NOP = 0
OPC_CLEAR = 1
OPC_DRAW_POINT = 2
OPC_DRAW_LINE = 3


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


def parse_words(path: Path):
    words = []
    for line in path.read_text().splitlines():
        s = line.strip()
        if s:
            words.append(int(s, 16))
    return words


def decode_stream(words):
    cmds = []
    i = 0
    while i < len(words):
        w0 = words[i]
        i += 1
        opc = (w0 >> 28) & 0xF
        color = (w0 >> 16) & 0xFFF
        x0 = y0 = x1 = y1 = 0
        if opc in (OPC_DRAW_POINT, OPC_DRAW_LINE):
            if i >= len(words):
                break
            w1 = words[i]
            i += 1
            x0 = w1 & 0x3FF
            y0 = (w1 >> 10) & 0x1FF
        if opc == OPC_DRAW_LINE:
            if i >= len(words):
                break
            w2 = words[i]
            i += 1
            x1 = w2 & 0x3FF
            y1 = (w2 >> 10) & 0x1FF
        if opc == OPC_DRAW_POINT:
            x1, y1 = x0, y0
        cmds.append((opc, color, x0, y0, x1, y1))
    return cmds


def rgb444_to_rgb888(c):
    r = ((c >> 8) & 0xF) * 17
    g = ((c >> 4) & 0xF) * 17
    b = (c & 0xF) * 17
    return (r, g, b)


def run(cmds):
    fb = [[0 for _ in range(FB_W)] for _ in range(FB_H)]
    for opc, color, x0, y0, x1, y1 in cmds:
        if opc == OPC_NOP:
            continue
        if opc == OPC_CLEAR:
            for y in range(FB_H):
                for x in range(FB_W):
                    fb[y][x] = color
        elif opc == OPC_DRAW_POINT:
            if 0 <= x0 < FB_W and 0 <= y0 < FB_H:
                fb[y0][x0] = color
        elif opc == OPC_DRAW_LINE:
            for x, y in bresenham(x0, y0, x1, y1):
                if 0 <= x < FB_W and 0 <= y < FB_H:
                    fb[y][x] = color
    return fb


def export_outputs(fb, out_dir: Path):
    """
    Export framebuffer data in multiple formats:
    - frame_dump.txt: Raw hex values (320 columns x 240 rows)
    - frame_golden.png: PNG image (if PIL available) or PPM (fallback)
    """
    out_dir.mkdir(parents=True, exist_ok=True)

    # Export as text hex dump
    print(f"  Exporting frame dump to {out_dir}/frame_dump.txt")
    with (out_dir / "frame_dump.txt").open("w") as f:
        for y in range(FB_H):
            f.write(" ".join(f"{fb[y][x]:03X}" for x in range(FB_W)) + "\n")

    # Export as image (PNG if PIL available, otherwise PPM)
    if Image is not None:
        print(f"  Exporting image to {out_dir}/frame_golden.png (PIL)")
        pixels = []
        for y in range(FB_H):
            for x in range(FB_W):
                pixels.append(rgb444_to_rgb888(fb[y][x]))
        img = Image.new("RGB", (FB_W, FB_H))
        img.putdata(pixels)
        img.save(out_dir / "frame_golden.png")
    else:
        print(f"  PIL not available, exporting PPM format to {out_dir}/frame_golden.ppm")
        with (out_dir / "frame_golden.ppm").open("w") as f:
            f.write("P3\n")
            f.write(f"{FB_W} {FB_H}\n255\n")
            for y in range(FB_H):
                row = " ".join(
                    f"{rgb444_to_rgb888(fb[y][x])[0]} {rgb444_to_rgb888(fb[y][x])[1]} {rgb444_to_rgb888(fb[y][x])[2]}"
                    for x in range(FB_W)
                )
                f.write(row + "\n")


def main():
    base = Path(__file__).resolve().parents[1]
    
    test_data_path = base / "test_data" / "system_cmds.hex"
    output_dir = base / "golden_output"
    
    print("System-Level Golden Model")
    print(f"  Reading test data: {test_data_path}")
    
    words = parse_words(test_data_path)
    print(f"  Parsed {len(words)} words from hex file")
    
    cmds = decode_stream(words)
    print(f"  Decoded {len(cmds)} commands")
    for i, (opc_name, cmd) in enumerate(zip(
        ['NOP', 'CLEAR', 'POINT', 'LINE'],
        [OPC_NOP, OPC_CLEAR, OPC_DRAW_POINT, OPC_DRAW_LINE]
    )):
        count = sum(1 for op, _, _, _, _, _ in cmds if op == cmd)
        if count > 0:
            print(f"    {opc_name}: {count}")
    
    print("  Running simulation...")
    fb = run(cmds)
    
    print(f"  Exporting outputs to {output_dir}")
    export_outputs(fb, output_dir)
    print("✓ System-level golden outputs generated successfully")



if __name__ == "__main__":
    main()
