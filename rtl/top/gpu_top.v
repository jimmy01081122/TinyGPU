/*
 * MODULE: gpu_top
 * DESCRIPTION:
 *   Top-level GPU module serving as a Memory-Mapped I/O (MMIO) peripheral.
 *   Integrates all CPU-side components (cmd_decode, draw_engine) with framebuffer
 *   and VGA output path.
 *
 * KEY FEATURES:
 *   - Dual clock domain: clk_sys (50-100MHz) for CPU interface and draw engine,
 *     clk_vga (25.175MHz) for VGA timing generation.
 *   - 32-bit MMIO write command interface (host_cmd_data, host_cmd_valid, host_cmd_ready).
 *   - 320x240 framebuffer with dual-port access (write via clk_sys, read via clk_vga).
 *   - VGA output: 640x480@60Hz with 2x nearest-neighbor pixel upscaling.
 *
 * INTERFACES:
 *   - Input:  clk_sys, clk_vga, rst_n
 *   - Input:  host_cmd_data[31:0], host_cmd_valid
 *   - Output: host_cmd_ready
 *   - Output: vga_hsync, vga_vsync, vga_rgb[11:0]
 *
 * ARCHITECTURE:
 *   [Host CPU] ---> [cmd_decode] ---> [draw_engine] ---> [frame_buffer] <--- [vga_ctrl]
 *                                          |                                       |
 *                                          +--- Port A (clk_sys, write) ----+    |
 *                                                                            Port B
 *                                                      Port B (clk_vga, read) <--+
 */
module gpu_top (
    input  wire        clk_sys,
    input  wire        clk_vga,
    input  wire        rst_n,
    input  wire [31:0] host_cmd_data,
    input  wire        host_cmd_valid,
    output wire        host_cmd_ready,
    output wire        vga_hsync,
    output wire        vga_vsync,
    output wire [11:0] vga_rgb
);

// Internal interconnect signals
wire [3:0]  dec_opcode;      // Decoded operation code from cmd_decode
wire [11:0] dec_color;       // Decoded color value (12-bit RGB444)
wire [9:0]  dec_x0;          // Coordinate X0 (10-bit, range 0-319)
wire [8:0]  dec_y0;          // Coordinate Y0 (9-bit, range 0-239)
wire [9:0]  dec_x1;          // Coordinate X1 (10-bit, range 0-319)
wire [8:0]  dec_y1;          // Coordinate Y1 (9-bit, range 0-239)
wire        dec_start;       // Start pulse from cmd_decode to draw_engine
/* verilator lint_off UNUSEDSIGNAL */
wire        dec_busy;        // Busy flag (reserved for future use)
/* verilator lint_on UNUSEDSIGNAL */
wire        draw_done;       // Done pulse from draw_engine back to cmd_decode

// Framebuffer port A signals (write side, clk_sys domain)
wire        fb_we_a;         // Write enable for port A
wire [16:0] fb_addr_a;       // Address for port A (17-bit, supports 64k entries)
wire [11:0] fb_data_a;       // Write data for port A (12-bit RGB444)

// Framebuffer port B signals (read side, clk_vga domain)
wire [16:0] fb_addr_b;       // Address for port B
wire [11:0] fb_data_b;       // Read data from port B

// ===== Submodule Instances =====

// Command Decoder: Multi-word FSM to parse 32-bit MMIO writes
// Converts stream of 32-bit words into structured commands for draw_engine
cmd_decode u_cmd_decode (
    .clk_sys(clk_sys),
    .rst_n(rst_n),
    .cmd_in(host_cmd_data),
    .cmd_val(host_cmd_valid & host_cmd_ready),  // Only accept on ready
    .draw_done(draw_done),                       // Feedback from draw_engine
    .busy(dec_busy),                             // Status output
    .cmd_ready(host_cmd_ready),                  // Ready for next input word
    .opcode(dec_opcode),
    .out_color(dec_color),
    .out_x0(dec_x0),
    .out_y0(dec_y0),
    .out_x1(dec_x1),
    .out_y1(dec_y1),
    .start_pulse(dec_start)                      // Triggers draw_engine
);

// Draw Engine: Processes drawing operations (NOP, CLEAR, DRAW_POINT, DRAW_LINE)
// Implements Bresenham line algorithm, generates framebuffer write sequence
draw_engine u_draw_engine (
    .clk_sys(clk_sys),
    .rst_n(rst_n),
    .opcode(dec_opcode),
    .start_pulse(dec_start),                     // Pulse from decoder
    .x0(dec_x0),
    .y0(dec_y0),
    .x1(dec_x1),
    .y1(dec_y1),
    .color_in(dec_color),
    .fb_we(fb_we_a),
    .fb_addr(fb_addr_a),
    .fb_data(fb_data_a),
    .done_pulse(draw_done)                       // Signals completion to decoder
);

// Frame Buffer: 320x240 dual-port RAM (76,800 pixels @ 12-bit per pixel)
// Port A: Write side controlled by clk_sys (CPU domain)
// Port B: Read side controlled by clk_vga (VGA domain)
frame_buffer_dp u_frame_buffer (
    .clk_a(clk_sys),
    .we_a(fb_we_a),
    .addr_a(fb_addr_a),
    .din_a(fb_data_a),
    .clk_b(clk_vga),
    .addr_b(fb_addr_b),
    .dout_b(fb_data_b)
);

// VGA Controller: Generates VGA timing signals and pixel output
// Reads framebuffer sequentially and performs 2x nearest-neighbor upscaling
// Output: 640x480@60Hz with hsync/vsync timing
vga_ctrl u_vga_ctrl (
    .clk_vga(clk_vga),
    .rst_n(rst_n),
    .fb_data(fb_data_b),
    .fb_addr(fb_addr_b),
    .hsync(vga_hsync),
    .vsync(vga_vsync),
    .vga_rgb(vga_rgb)
);

endmodule

