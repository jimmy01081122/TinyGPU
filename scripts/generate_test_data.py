#!/usr/bin/env python3
"""
Generate comprehensive test data for Tiny-Easy-GPU verification.
Creates test vectors covering all opcodes and various edge cases.
"""

from pathlib import Path

# Opcode definitions (must match hardware)
OPC_NOP = 0x0
OPC_CLEAR = 0x1
OPC_DRAW_POINT = 0x2
OPC_DRAW_LINE = 0x3

def encode_word0(opcode, color):
    """
    Encode Word 0 (Command Header)
    [31:28] Opcode (4-bit)
    [27:16] Color (12-bit RGB444)
    [15:0]  Reserved (always 0)
    """
    return (opcode << 28) | (color << 16)

def encode_word1(x0, y0):
    """
    Encode Word 1 (Coordinate 0)
    [31:19] Reserved (always 0)
    [18:10] Y0 (9-bit)
    [9:0]   X0 (10-bit)
    """
    return (y0 << 10) | x0

def encode_word2(x1, y1):
    """
    Encode Word 2 (Coordinate 1)
    [31:19] Reserved (always 0)
    [18:10] Y1 (9-bit)
    [9:0]   X1 (10-bit)
    """
    return (y1 << 10) | x1

def generate_test_cases():
    """
    Generate 10 comprehensive test cases covering:
    1. NOP - No operation
    2. CLEAR - Fill screen with color
    3-6. DRAW_POINT - Single pixels at various positions
    7-10. DRAW_LINE - Various slopes and directions
    """
    cases = []

    # Case 0: NOP (1 word)
    # Description: No-op, no framebuffer writes
    # Expected: Completes immediately with no visible effect
    cases.append({
        'name': 'NOP',
        'desc': 'No-operation test',
        'words': [
            encode_word0(OPC_NOP, 0x000)
        ]
    })

    # Case 1: CLEAR (1 word)
    # Fill entire screen with red (RGB444: R=0xF, G=0x0, B=0x0)
    # Expected: 76,800 writes of 0xF00 to framebuffer addresses 0x00000-0x12C00
    cases.append({
        'name': 'CLEAR_RED',
        'desc': 'Clear screen with red color (0xF00)',
        'words': [
            encode_word0(OPC_CLEAR, 0xF00)
        ]
    })

    # Case 2: DRAW_POINT - Corner (top-left)
    # Draw at (10, 10) with green (0x0F0)
    # Expected: 1 write to address 0x0A0A = 10*320+10
    cases.append({
        'name': 'POINT_TL',
        'desc': 'Draw point at (10, 10) green',
        'words': [
            encode_word0(OPC_DRAW_POINT, 0x0F0),
            encode_word1(10, 10)
        ]
    })

    # Case 3: DRAW_POINT - Center
    # Draw at (160, 120) with blue (0x00F)
    # Expected: 1 write to address 0x5A80 = 120*320+160
    cases.append({
        'name': 'POINT_CENTER',
        'desc': 'Draw point at (160, 120) blue',
        'words': [
            encode_word0(OPC_DRAW_POINT, 0x00F),
            encode_word1(160, 120)
        ]
    })

    # Case 4: DRAW_POINT - Corner (bottom-right)
    # Draw at (319, 239) with white (0xFFF)
    # Expected: 1 write to address 0x12C7F = 239*320+319
    cases.append({
        'name': 'POINT_BR',
        'desc': 'Draw point at (319, 239) white',
        'words': [
            encode_word0(OPC_DRAW_POINT, 0xFFF),
            encode_word1(319, 239)
        ]
    })

    # Case 5: DRAW_POINT - Out of bounds (should not write)
    # Try to draw at (400, 300) with cyan (0x0FF)
    # Expected: 0 writes (out of bounds)
    cases.append({
        'name': 'POINT_OOB',
        'desc': 'Draw point out of bounds (400, 300)',
        'words': [
            encode_word0(OPC_DRAW_POINT, 0x0FF),
            encode_word1(400, 300)
        ]
    })

    # Case 6: DRAW_LINE - Horizontal line
    # Line from (50, 50) to (100, 50) with magenta (0xF0F)
    # Expected: 51 writes along the horizontal line
    cases.append({
        'name': 'LINE_HORIZ',
        'desc': 'Horizontal line from (50, 50) to (100, 50) magenta',
        'words': [
            encode_word0(OPC_DRAW_LINE, 0xF0F),
            encode_word1(50, 50),
            encode_word2(100, 50)
        ]
    })

    # Case 7: DRAW_LINE - Vertical line
    # Line from (100, 50) to (100, 100) with yellow (0xFF0)
    # Expected: 51 writes along the vertical line
    cases.append({
        'name': 'LINE_VERT',
        'desc': 'Vertical line from (100, 50) to (100, 100) yellow',
        'words': [
            encode_word0(OPC_DRAW_LINE, 0xFF0),
            encode_word1(100, 50),
            encode_word2(100, 100)
        ]
    })

    # Case 8: DRAW_LINE - Diagonal (slope ~1)
    # Line from (20, 20) to (80, 80) with cyan (0x0FF)
    # Expected: ~61 writes forming diagonal line
    cases.append({
        'name': 'LINE_DIAG_POS',
        'desc': 'Diagonal line (slope +1) from (20, 20) to (80, 80) cyan',
        'words': [
            encode_word0(OPC_DRAW_LINE, 0x0FF),
            encode_word1(20, 20),
            encode_word2(80, 80)
        ]
    })

    # Case 9: DRAW_LINE - Steep slope with negative direction
    # Line from (150, 100) to (130, 160) with light red (0xC00)
    # Expected: ~62 writes forming steep line (more Y steps than X)
    cases.append({
        'name': 'LINE_STEEP',
        'desc': 'Steep line from (150, 100) to (130, 160) red',
        'words': [
            encode_word0(OPC_DRAW_LINE, 0xC00),
            encode_word1(150, 100),
            encode_word2(130, 160)
        ]
    })

    return cases

def write_test_file(cases, output_path):
    """Write test cases to hex file for simulation"""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_path, 'w') as f:
        for case in cases:
            for word in case['words']:
                # Write as lowercase hex without 0x prefix
                f.write(f"{word:08x}\n")
    
    print(f"Generated test file: {output_path}")
    print(f"Total test cases: {len(cases)}")
    print("Test cases:")
    for i, case in enumerate(cases):
        print(f"  {i}: {case['name']:15} ({len(case['words'])} word{'s' if len(case['words']) != 1 else ''}) - {case['desc']}")

def main():
    """Generate all test data files"""
    base_path = Path(__file__).resolve().parent.parent
    
    cases = generate_test_cases()
    
    # Write comprehensive system-level test data
    system_test_path = base_path / "verification" / "System_Level" / "test_data" / "system_cmds.hex"
    write_test_file(cases, system_test_path)
    
    # Write unit-level test data for cmd_decode
    cmd_decode_test_path = base_path / "verification" / "Unit_Level" / "cmd_decode" / "test_data" / "cmd_stream.hex"
    # Filter just the multi-word commands for cmd_decode testing
    cmd_cases = []
    for case in cases:
        if len(case['words']) > 1:  # Only include multi-word commands for interesting testing
            cmd_cases.append(case)
    write_test_file(cmd_cases, cmd_decode_test_path)
    
    print("\n✓ Test data generation complete!")

if __name__ == '__main__':
    main()
