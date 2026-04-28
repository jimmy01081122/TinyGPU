/*
 * MODULE: vga_ctrl
 * DESCRIPTION:
 *   VGA timing controller producing standard 640x480@60Hz output with 2x nearest-neighbor
 *   pixel upscaling. Reads from 320x240 framebuffer and stretches to 640x480 display.
 *
 * VGA TIMING SPECIFICATION (640x480@60Hz):
 *   - Pixel Clock:      25.175 MHz (standard)
 *   - H-Total:          800 pixels/line
 *   - H-Visible:        640 pixels (left display area)
 *   - H-Front-Porch:    16 pixels (before hsync)
 *   - H-Sync:           96 pixels (hsync pulse width)
 *   - H-Back-Porch:     48 pixels (after hsync, calculated in reset)
 *
 *   - V-Total:          525 lines/frame
 *   - V-Visible:        480 lines (top display area)
 *   - V-Front-Porch:    10 lines (before vsync)
 *   - V-Sync:           2 lines (vsync pulse width)
 *   - V-Back-Porch:     33 lines (after vsync, calculated in reset)
 *
 *   - Refresh Rate:     60 Hz
 *
 * PIXEL UPSCALING (Nearest-Neighbor 2x):
 *   - Framebuffer pixel at (fbx, fby) maps to 2x2 block in VGA output
 *   - h_cnt[9:1] extracts source column (divides h_cnt by 2)
 *   - v_cnt[8:1] extracts source row (divides v_cnt by 2)
 *   - Each framebuffer pixel is displayed for 2 VGA clocks horizontally
 *     and 2 VGA lines vertically
 *
 * OPERATION:
 *   - Counters h_cnt and v_cnt track position within the 800x525 display cycle
 *   - When active_now=1, framebuffer address is generated via bit shifting
 *   - One cycle delay (active_d) accounts for memory read latency
 *   - RGB data is sampled and output during active video region
 */
module vga_ctrl (
    input  wire        clk_vga,        // VGA pixel clock (25.175 MHz)
    input  wire        rst_n,          // Active-low reset
    input  wire [11:0] fb_data,        // Framebuffer read data (12-bit RGB444)
    output reg  [16:0] fb_addr,        // Framebuffer read address (17-bit)
    output reg         hsync,          // Horizontal sync output (active-low)
    output reg         vsync,          // Vertical sync output (active-low)
    output reg  [11:0] vga_rgb         // VGA RGB output (12-bit RGB444)
);

// ===== VGA Timing Parameters =====
localparam H_VISIBLE = 10'd640;       // Horizontal display area (columns 0-639)
localparam H_FRONT   = 10'd16;        // Horizontal front porch (16 pixels between end of display and sync)
localparam H_SYNC    = 10'd96;        // Horizontal sync width (96 pixels at logic-0)
localparam H_TOTAL   = 10'd800;       // Total horizontal period

localparam V_VISIBLE = 10'd480;       // Vertical display area (rows 0-479)
localparam V_FRONT   = 10'd10;        // Vertical front porch (10 lines)
localparam V_SYNC    = 10'd2;         // Vertical sync width (2 lines)
localparam V_TOTAL   = 10'd525;       // Total vertical period

// ===== Timing Counter Registers =====
reg [9:0] h_cnt;                      // Horizontal position within current line (0-799)
reg [9:0] v_cnt;                      // Vertical position within current frame (0-524)
reg       active_d;                   // Delayed active signal (accounts for memory read latency)

// ===== Combinational Logic =====

// active_now: High during "active video" region (within display area)
// This signal is used to generate framebuffer read address
wire active_now;
assign active_now = (h_cnt < H_VISIBLE) && (v_cnt < V_VISIBLE);

// Source coordinates for framebuffer: divide VGA coordinates by 2 (nearest-neighbor 2x upscaling)
//   src_x = h_cnt[9:1]  -> drops LSB, effectively divides by 2 (range 0-319)
//   src_y = v_cnt[8:1]  -> drops LSB, effectively divides by 2 (range 0-239)
wire [8:0] src_x;
wire [7:0] src_y;
assign src_x = h_cnt[9:1];
assign src_y = v_cnt[8:1];

// ===== Sequential Logic =====

always @(posedge clk_vga or negedge rst_n) begin
    if (!rst_n) begin
        // Initialize all counters and outputs
        h_cnt   <= 10'd0;
        v_cnt   <= 10'd0;
        hsync   <= 1'b1;              // Negative logic: idle high
        vsync   <= 1'b1;              // Negative logic: idle high
        fb_addr <= 17'd0;
        vga_rgb <= 12'h000;           // Clear display (black)
        active_d <= 1'b0;
    end else begin
        // ===== Update Horizontal Counter =====
        if (h_cnt == H_TOTAL - 1'b1) begin
            // End of line (h_cnt reached 799): reset to 0 and increment vertical counter
            h_cnt <= 10'd0;
            if (v_cnt == V_TOTAL - 1'b1) begin
                // End of frame (v_cnt reached 524): reset to 0
                v_cnt <= 10'd0;
            end else begin
                v_cnt <= v_cnt + 1'b1;
            end
        end else begin
            // Normal operation: increment h_cnt
            h_cnt <= h_cnt + 1'b1;
        end

        // ===== Generate Sync Signals =====
        // hsync: Asserted (logic-0) during horizontal sync period
        // Sync region: pixels H_VISIBLE+H_FRONT through H_VISIBLE+H_FRONT+H_SYNC-1
        hsync <= ~((h_cnt >= H_VISIBLE + H_FRONT) && (h_cnt < H_VISIBLE + H_FRONT + H_SYNC));

        // vsync: Asserted (logic-0) during vertical sync period
        // Sync region: lines V_VISIBLE+V_FRONT through V_VISIBLE+V_FRONT+V_SYNC-1
        vsync <= ~((v_cnt >= V_VISIBLE + V_FRONT) && (v_cnt < V_VISIBLE + V_FRONT + V_SYNC));

        // ===== Framebuffer Address Generation =====
        // During active video region, generate address for next pixel read
        // Address formula: address = src_y * 320 + src_x (linear addressing)
        if (active_now) begin
            fb_addr <= (src_y * 10'd320) + {8'b0, src_x};
        end else begin
            fb_addr <= 17'd0;         // Safe default (first address)
        end

        // ===== Output Data Path with One-Cycle Delay =====
        // active_d: Delayed version of active_now (accounts for dual-port RAM read latency)
        // Data read from framebuffer on this cycle becomes available on next cycle
        active_d <= active_now;

        // Output RGB data when active_d is high, else display black (blanking)
        if (active_d) begin
            vga_rgb <= fb_data;
        end else begin
            vga_rgb <= 12'h000;       // Blanking output (black)
        end
    end
end

endmodule

