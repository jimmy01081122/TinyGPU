/*
 * MODULE: frame_buffer_dp
 * DESCRIPTION:
 *   Dual-port RAM (DPRAM) framebuffer storing 320x240 pixel image data.
 *   - Port A (write): Clocked by clk_a, controlled by draw_engine (clk_sys domain)
 *   - Port B (read):  Clocked by clk_b, controlled by vga_ctrl (clk_vga domain)
 *   
 *   This allows simultaneous writes (drawing) and reads (display output) without
 *   clock domain synchronization at the memory interface level.
 *   
 * MEMORY SPECIFICATIONS:
 *   - Depth:  76,800 words (320 x 240)
 *   - Width:  12 bits per pixel (RGB444 color format)
 *   - Addressing: Linear (address = y * 320 + x)
 *   - Total:  921,600 bits (~113.4 KB)
 *
 * PROTOCOL:
 *   - Port A: Synchronous write. When we_a=1, din_a is written to mem[addr_a] on clk_a edge
 *   - Port B: Synchronous read. dout_b reflects mem[addr_b] on clk_b edge (registered output)
 *   - Out of bounds: Addresses >= FB_SIZE return 0 (black color)
 */
module frame_buffer_dp (
    // Port A: Write interface (CPU domain, clk_sys)
    input  wire        clk_a,           // Write clock
    input  wire        we_a,            // Write enable
    input  wire [16:0] addr_a,          // Write address (17-bit supports up to 128k)
    input  wire [11:0] din_a,           // Write data (12-bit RGB444)
    
    // Port B: Read interface (VGA domain, clk_vga)
    input  wire        clk_b,           // Read clock
    input  wire [16:0] addr_b,          // Read address
    output reg  [11:0] dout_b           // Read data (12-bit RGB444, registered)
);

// Memory array: 76,800 locations x 12 bits
localparam FB_SIZE = 76800;
reg [11:0] mem [0:FB_SIZE-1];

// ===== Port A: Synchronous Write =====
// On rising edge of clk_a, if we_a is asserted and address is valid,
// write din_a to memory[addr_a]
always @(posedge clk_a) begin
    if (we_a && (addr_a < FB_SIZE)) begin
        mem[addr_a] <= din_a;
    end
end

// ===== Port B: Synchronous Read =====
// On rising edge of clk_b, latch memory[addr_b] to dout_b
// If address is out of bounds, return black (0x000)
always @(posedge clk_b) begin
    if (addr_b < FB_SIZE) begin
        dout_b <= mem[addr_b];
    end else begin
        dout_b <= 12'h000;  // Return black for out-of-bounds addresses
    end
end

endmodule

