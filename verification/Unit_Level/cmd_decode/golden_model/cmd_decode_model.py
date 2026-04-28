#!/usr/bin/env python3
from pathlib import Path
import csv

OPC_NOP = 0x0
OPC_CLEAR = 0x1
OPC_DRAW_POINT = 0x2
OPC_DRAW_LINE = 0x3

S_IDLE = 0
S_WAIT_W1 = 1
S_WAIT_W2 = 2
S_WAIT_DONE = 3


def parse_hex_file(path: Path):
    words = []
    for line in path.read_text().splitlines():
        s = line.strip()
        if not s:
            continue
        words.append(int(s, 16))
    return words


def model(words):
    state = S_IDLE
    latched = {}
    events = []
    cycle = 0
    for w in words:
        cycle += 1
        start = 0
        busy = 1 if state != S_IDLE else 0

        if state == S_IDLE:
            latched["opcode"] = (w >> 28) & 0xF
            latched["color"] = (w >> 16) & 0xFFF
            opc = latched["opcode"]
            if opc in (OPC_NOP, OPC_CLEAR):
                start = 1
                state = S_WAIT_DONE
            elif opc in (OPC_DRAW_POINT, OPC_DRAW_LINE):
                state = S_WAIT_W1
        elif state == S_WAIT_W1:
            latched["x0"] = w & 0x3FF
            latched["y0"] = (w >> 10) & 0x1FF
            if latched["opcode"] == OPC_DRAW_POINT:
                latched["x1"] = latched["x0"]
                latched["y1"] = latched["y0"]
                start = 1
                state = S_WAIT_DONE
            else:
                state = S_WAIT_W2
        elif state == S_WAIT_W2:
            latched["x1"] = w & 0x3FF
            latched["y1"] = (w >> 10) & 0x1FF
            start = 1
            state = S_WAIT_DONE

        if start:
            events.append(
                {
                    "cycle": cycle,
                    "opcode": latched.get("opcode", 0),
                    "color": latched.get("color", 0),
                    "x0": latched.get("x0", 0),
                    "y0": latched.get("y0", 0),
                    "x1": latched.get("x1", 0),
                    "y1": latched.get("y1", 0),
                    "start_pulse": 1,
                    "busy": busy,
                }
            )
            state = S_IDLE
    return events


def main():
    base = Path(__file__).resolve().parents[1]
    in_path = base / "test_data" / "cmd_stream.hex"
    out_path = base / "golden_output" / "cmd_decode_events.csv"
    words = parse_hex_file(in_path)
    events = model(words)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", newline="") as f:
        writer = csv.DictWriter(
            f, fieldnames=["cycle", "opcode", "color", "x0", "y0", "x1", "y1", "start_pulse", "busy"]
        )
        writer.writeheader()
        writer.writerows(events)
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
