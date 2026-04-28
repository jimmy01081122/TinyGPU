/*
 * MODULE: cmd_decode
 * DESCRIPTION:
 *   Multi-word command decoder implementing a state machine to parse 32-bit
 *   MMIO writes into structured GPU commands.
 *
 * PROTOCOL:
 *   Commands arrive as a sequence of 32-bit words. Opcode in Word 0 determines
 *   how many additional words are required:
 *   - NOP (0x0):        1 word total
 *   - CLEAR (0x1):      1 word total
 *   - DRAW_POINT (0x2): 2 words total (Word 0 + Word 1)
 *   - DRAW_LINE (0x3):  3 words total (Word 0 + Word 1 + Word 2)
 *
 * STATE MACHINE:
 *   S_IDLE    -> Wait for valid command word 0
 *   S_WAIT_W1 -> Wait for word 1 (coordinates X0, Y0)
 *   S_WAIT_W2 -> Wait for word 2 (coordinates X1, Y1, DRAW_LINE only)
 *   S_WAIT_DONE -> Wait for draw_engine completion before returning to IDLE
 *
 * PAYLOAD FORMAT:
 *   Word 0: [31:28] Opcode, [27:16] Color (12-bit), [15:0] Reserved
 *   Word 1: [31:19] Reserved, [18:10] Y0 (9-bit), [9:0] X0 (10-bit)
 *   Word 2: [31:19] Reserved, [18:10] Y1 (9-bit), [9:0] X1 (10-bit)
 *
 * HANDSHAKE:
 *   - cmd_ready:   High when decoder can accept a word (not busy)
 *   - cmd_val:     Input: High when cmd_in contains valid data
 *   - start_pulse: Output: One-cycle pulse when command is complete
 *   - busy:        High while processing a command or when draw_engine is running
 */
module cmd_decode (
    input  wire        clk_sys,          // System clock
    input  wire        rst_n,            // Active-low reset
    input  wire [31:0] cmd_in,           // Command word input
    input  wire        cmd_val,          // Command valid (input handshake)
    input  wire        draw_done,        // Completion feedback from draw_engine
    output wire        cmd_ready,        // Ready to accept word (output handshake)
    output reg         busy,             // Busy flag (command in progress)
    output reg  [3:0]  opcode,           // Decoded opcode
    output reg  [11:0] out_color,        // Decoded color (12-bit RGB444)
    output reg  [9:0]  out_x0,           // X0 coordinate (10-bit)
    output reg  [8:0]  out_y0,           // Y0 coordinate (9-bit)
    output reg  [9:0]  out_x1,           // X1 coordinate (10-bit)
    output reg  [8:0]  out_y1,           // Y1 coordinate (9-bit)
    output reg         start_pulse       // Pulse to trigger draw_engine
);

// Opcode definitions
localparam OPC_NOP        = 4'h0;
localparam OPC_CLEAR      = 4'h1;
localparam OPC_DRAW_POINT = 4'h2;
localparam OPC_DRAW_LINE  = 4'h3;

// State machine state definitions
localparam S_IDLE      = 2'd0;
localparam S_WAIT_W1   = 2'd1;
localparam S_WAIT_W2   = 2'd2;
localparam S_WAIT_DONE = 2'd3;

// Internal state register
reg [1:0] state;

// Ready signal: decoder can accept a word when not in S_WAIT_DONE
assign cmd_ready = (state != S_WAIT_DONE);

always @(posedge clk_sys or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all outputs
        state       <= S_IDLE;
        busy        <= 1'b0;
        opcode      <= 4'd0;
        out_color   <= 12'd0;
        out_x0      <= 10'd0;
        out_y0      <= 9'd0;
        out_x1      <= 10'd0;
        out_y1      <= 9'd0;
        start_pulse <= 1'b0;
    end else begin
        // Default: clear one-cycle pulse signals
        start_pulse <= 1'b0;

        case (state)
            // ===== S_IDLE: Waiting for Word 0 (command header) =====
            S_IDLE: begin
                busy <= 1'b0;
                if (cmd_val) begin
                    // Extract opcode and color from Word 0
                    opcode    <= cmd_in[31:28];
                    out_color <= cmd_in[27:16];
                    
                    case (cmd_in[31:28])
                        // Single-word commands: trigger immediately
                        OPC_NOP,
                        OPC_CLEAR: begin
                            busy        <= 1'b1;
                            start_pulse <= 1'b1;
                            state       <= S_WAIT_DONE;
                        end
                        // Two-word command: wait for Word 1
                        OPC_DRAW_POINT: begin
                            busy  <= 1'b1;
                            state <= S_WAIT_W1;
                        end
                        // Three-word command: wait for Word 1
                        OPC_DRAW_LINE: begin
                            busy  <= 1'b1;
                            state <= S_WAIT_W1;
                        end
                        // Unknown opcode: stay idle (consume and ignore)
                        default: begin
                            state <= S_IDLE;
                            busy  <= 1'b0;
                        end
                    endcase
                end
            end

            // ===== S_WAIT_W1: Waiting for Word 1 (coordinates 0) =====
            S_WAIT_W1: begin
                if (cmd_val) begin
                    // Extract X0 and Y0 from Word 1
                    // [9:0] = X0, [18:10] = Y0
                    out_y0 <= cmd_in[18:10];
                    out_x0 <= cmd_in[9:0];

                    if (opcode == OPC_DRAW_POINT) begin
                        // DRAW_POINT uses same coordinates for both endpoints
                        out_x1      <= cmd_in[9:0];
                        out_y1      <= cmd_in[18:10];
                        start_pulse <= 1'b1;
                        state       <= S_WAIT_DONE;
                    end else begin
                        // DRAW_LINE needs Word 2, so wait for it
                        state <= S_WAIT_W2;
                    end
                end
            end

            // ===== S_WAIT_W2: Waiting for Word 2 (coordinates 1, DRAW_LINE only) =====
            S_WAIT_W2: begin
                if (cmd_val) begin
                    // Extract X1 and Y1 from Word 2
                    // [9:0] = X1, [18:10] = Y1
                    out_y1      <= cmd_in[18:10];
                    out_x1      <= cmd_in[9:0];
                    start_pulse <= 1'b1;
                    state       <= S_WAIT_DONE;
                end
            end

            // ===== S_WAIT_DONE: Waiting for draw_engine completion =====
            S_WAIT_DONE: begin
                if (draw_done) begin
                    // Command execution complete; return to idle and release busy
                    busy  <= 1'b0;
                    state <= S_IDLE;
                end
            end

            default: begin
                state <= S_IDLE;
                busy  <= 1'b0;
            end
        endcase
    end
end

endmodule

