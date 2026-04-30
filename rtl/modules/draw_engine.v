/*
 * MODULE: draw_engine
 * DESCRIPTION:
 *   GPU drawing engine implementing four drawing operations:
 *   1. NOP: No-operation, completes immediately
 *   2. CLEAR: Fill entire framebuffer (320x240) with a single color
 *   3. DRAW_POINT: Plot a single pixel at (x0, y0)
 *   4. DRAW_LINE: Draw line from (x0, y0) to (x1, y1) using Bresenham algorithm
 *
 * ALGORITHM OVERVIEW (Bresenham Line Drawing):
 *   The Bresenham algorithm efficiently rasterizes a line by:
 *   - Computing dx = |x1 - x0| and dy = -|y1 - y0|
 *   - Using error term 'err' to decide pixel placement
 *   - Each step: check e2 = 2*err against dy and dx to determine X/Y direction
 *   - Runs until (cur_x, cur_y) reaches (end_x, end_y)
 *
 * STATE MACHINE:
 *   S_IDLE   -> Wait for start_pulse from cmd_decode
 *   S_CLEAR  -> Loop through all 76,800 framebuffer locations, write color
 *   S_POINT  -> Write single pixel, assert done
 *   S_LINE   -> Execute Bresenham algorithm until endpoint reached
 *
 * FRAMEBUFFER ADDRESSING:
 *   Address = y * 320 + x (linear addressing)
 *   Width   = 320 pixels (10-bit address space)
 *   Height  = 240 pixels (8-bit address space)
 *   Total   = 76,800 pixels (17-bit address)
 */
module draw_engine (
    input  wire        clk_sys,          // System clock
    input  wire        rst_n,            // Active-low reset
    input  wire [3:0]  opcode,           // Operation code (0-3)
    input  wire        start_pulse,      // One-cycle pulse to begin operation
    input  wire [9:0]  x0,               // Start X coordinate (10-bit)
    input  wire [8:0]  y0,               // Start Y coordinate (9-bit)
    input  wire [9:0]  x1,               // End X coordinate (10-bit)
    input  wire [8:0]  y1,               // End Y coordinate (9-bit)
    input  wire [11:0] color_in,         // Color value (12-bit RGB444)
    output reg         fb_we,            // Framebuffer write enable
    output reg  [16:0] fb_addr,          // Framebuffer address (17-bit)
    output reg  [11:0] fb_data,          // Framebuffer write data
    output reg         done_pulse        // One-cycle completion pulse
);

// Opcode definitions
localparam OPC_NOP        = 4'h0;
localparam OPC_CLEAR      = 4'h1;
localparam OPC_DRAW_POINT = 4'h2;
localparam OPC_DRAW_LINE  = 4'h3;

// State machine states
localparam S_IDLE  = 2'd0;
localparam S_CLEAR = 2'd1;
localparam S_POINT = 2'd2;
localparam S_LINE  = 2'd3;

// Framebuffer parameters
localparam FB_W    = 10'd320;        // Framebuffer width (pixels)
localparam FB_H    = 9'd240;         // Framebuffer height (pixels)
localparam FB_SIZE = 17'd76800;      // Total framebuffer size

// State and operation registers
reg [1:0]  state;                    // Current state machine state
reg [16:0] clear_idx;                // Clear operation: loop counter

// Bresenham algorithm registers (all signed for line drawing)
reg signed [10:0] cur_x;             // Current X position in line (11-bit signed, range -512 to +511)
reg signed [9:0]  cur_y;             // Current Y position in line (10-bit signed, range -256 to +255)
reg signed [10:0] end_x;             // Line endpoint X (11-bit signed)
reg signed [9:0]  end_y;             // Line endpoint Y (10-bit signed)
reg signed [11:0] dx;                // Delta X (absolute value, 12-bit signed)
reg signed [11:0] dy;                // Delta Y (negative, 12-bit signed)
reg signed [1:0]  sx;                // Sign of X step: +1 or -1
reg signed [1:0]  sy;                // Sign of Y step: +1 or -1
reg signed [12:0] err;               // Bresenham error term (13-bit signed)

// Wire for 2x error term (used in Bresenham comparisons)
wire signed [12:0] e2;
assign e2 = err <<< 1;               // Left shift by 1 (multiply by 2)

// ===== Helper Functions =====

// Absolute value for 11-bit signed input (returns 13-bit signed)
function signed [12:0] abs11;
    input signed [10:0] v;
    begin
        abs11 = v[10] ? $signed(13'(-v)) : $signed(13'(v));
    end
endfunction

// Absolute value for 10-bit signed input (returns 13-bit signed)
function signed [12:0] abs10;
    input signed [9:0] v;
    begin
        abs10 = v[9] ? $signed(13'(-v)) : $signed(13'(v));
    end
endfunction

// Convert (x, y) coordinates to linear framebuffer address
function [16:0] xy_to_addr;
    input [9:0] px;
    input [8:0] py;
    begin
        xy_to_addr = (py * 10'd320) + {7'b0, px};
    end
endfunction

// Range check: verify point is within framebuffer bounds
wire in_range_line;
assign in_range_line = (cur_x >= 0) && (cur_x < 11'd320) && (cur_y >= 0) && (cur_y < 10'd240);

// ===== Combinational Wires for Bresenham Initialization =====
// These pre-compute values for OPC_DRAW_LINE to avoid complex function calls in sequential logic
wire signed [10:0] dx_diff;
wire signed [9:0]  dy_diff;
wire signed [12:0] dx_abs, dy_abs;
wire signed [12:0] err_init;

assign dx_diff = $signed({1'b0, x1}) - $signed({1'b0, x0});
assign dy_diff = $signed({1'b0, y1[8:0]}) - $signed({1'b0, y0[8:0]});
assign dx_abs = abs11(dx_diff);
assign dy_abs = abs10(dy_diff);
assign err_init = dx_abs - dy_abs;

always @(posedge clk_sys or negedge rst_n) begin
    if (!rst_n) begin
        // Reset to initial state
        state      <= S_IDLE;
        fb_we      <= 1'b0;
        fb_addr    <= 17'd0;
        fb_data    <= 12'd0;
        done_pulse <= 1'b0;
        clear_idx  <= 17'd0;
        cur_x      <= 11'sd0;
        cur_y      <= 10'sd0;
        end_x      <= 11'sd0;
        end_y      <= 10'sd0;
        dx         <= 12'sd0;
        dy         <= 12'sd0;
        sx         <= 2'sd0;
        sy         <= 2'sd0;
        err        <= 13'sd0;
    end else begin
        // Default: clear write signals each clock
        fb_we      <= 1'b0;
        done_pulse <= 1'b0;

        case (state)
            // ===== S_IDLE: Wait for start_pulse and dispatch to operation handler =====
            S_IDLE: begin
                if (start_pulse) begin
                    case (opcode)
                        // NOP: Complete immediately with no framebuffer writes
                        OPC_NOP: begin
                            done_pulse <= 1'b1;
                        end

                        // CLEAR: Fill entire framebuffer with color_in
                        OPC_CLEAR: begin
                            clear_idx <= 17'd0;
                            state     <= S_CLEAR;
                        end

                        // DRAW_POINT: Write single pixel at (x0, y0)
                        OPC_DRAW_POINT: begin
                            state <= S_POINT;
                        end

                        // DRAW_LINE: Set up Bresenham algorithm and execute
                        OPC_DRAW_LINE: begin
                            // Convert input coordinates to signed and initialize
                            cur_x <= $signed({1'b0, x0});
                            cur_y <= $signed({1'b0, y0});
                            end_x <= $signed({1'b0, x1});
                            end_y <= $signed({1'b0, y1});
                            
                            // Use pre-computed absolute values for dx and dy
                            dx    <= dx_abs[11:0];
                            dy    <= -dy_abs[11:0];
                            
                            // Determine step direction for x and y
                            sx    <= (x0 < x1) ? 2'sd1 : -2'sd1;
                            sy    <= (y0 < y1) ? 2'sd1 : -2'sd1;
                            
                            // Initialize error term: err = dx + dy
                            err   <= err_init;
                            
                            state <= S_LINE;
                        end

                        default: begin
                            done_pulse <= 1'b1;
                        end
                    endcase
                end
            end

            // ===== S_CLEAR: Loop through framebuffer and write color =====
            S_CLEAR: begin
                fb_we   <= 1'b1;
                fb_addr <= clear_idx;
                fb_data <= color_in;

                if (clear_idx == FB_SIZE - 1'b1) begin
                    // Reached end of framebuffer; operation complete
                    done_pulse <= 1'b1;
                    state      <= S_IDLE;
                end else begin
                    clear_idx <= clear_idx + 1'b1;
                end
            end

            // ===== S_POINT: Write single pixel and complete =====
            S_POINT: begin
                if ((x0 < FB_W) && (y0 < FB_H)) begin
                    // Coordinate in bounds: write pixel
                    fb_we   <= 1'b1;
                    fb_addr <= xy_to_addr(x0, y0);
                    fb_data <= color_in;
                end
                // Always complete (even if out of bounds)
                done_pulse <= 1'b1;
                state      <= S_IDLE;
            end

            // ===== S_LINE: Bresenham line drawing algorithm =====
            S_LINE: begin
                // Write current pixel if within framebuffer bounds
                if (in_range_line) begin
                    fb_we   <= 1'b1;
                    fb_addr <= xy_to_addr(cur_x[9:0], cur_y[8:0]);
                    fb_data <= color_in;
                end

                // Check if reached line endpoint
                if ((cur_x == end_x) && (cur_y == end_y)) begin
                    done_pulse <= 1'b1;
                    state      <= S_IDLE;
                end else begin
                    // Temporary variables for next state calculation
                    reg signed [12:0] err_next;
                    reg signed [10:0] x_next;
                    reg signed [9:0]  y_next;

                    // Initialize with current values
                    err_next = err;
                    x_next   = cur_x;
                    y_next   = cur_y;

                    // Bresenham decision logic:
                    // If 2*err >= dy, move in X direction
                    if (e2 >= $signed(13'(dy))) begin
                        err_next = err_next + dy;
                        x_next   = x_next + $signed(11'(sx));
                    end
                    
                    // If 2*err <= dx, move in Y direction
                    if (e2 <= $signed(13'(dx))) begin
                        err_next = err_next + dx;
                        y_next   = y_next + $signed(10'(sy));
                    end

                    // Update state for next iteration
                    err   <= err_next;
                    cur_x <= x_next;
                    cur_y <= y_next;
                end
            end

            default: begin
                state <= S_IDLE;
            end
        endcase
    end
end

endmodule
