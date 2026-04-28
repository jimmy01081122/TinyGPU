`timescale 1ns/1ps

module cmd_decode_tb;
    reg         clk;
    reg         rst_n;
    reg  [31:0] cmd_in;
    reg         cmd_val;
    reg         draw_done;
    wire        cmd_ready;
    wire        busy;
    wire [3:0]  opcode;
    wire [11:0] out_color;
    wire [9:0]  out_x0;
    wire [8:0]  out_y0;
    wire [9:0]  out_x1;
    wire [8:0]  out_y1;
    wire        start_pulse;

    reg [31:0] words [0:31];
    integer total_words;
    integer i;
    integer starts;
    integer done_cnt;
    integer clear_count, point_count, line_count;

    cmd_decode dut (
        .clk_sys(clk),
        .rst_n(rst_n),
        .cmd_in(cmd_in),
        .cmd_val(cmd_val),
        .draw_done(draw_done),
        .cmd_ready(cmd_ready),
        .busy(busy),
        .opcode(opcode),
        .out_color(out_color),
        .out_x0(out_x0),
        .out_y0(out_y0),
        .out_x1(out_x1),
        .out_y1(out_y1),
        .start_pulse(start_pulse)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        cmd_in = 0;
        cmd_val = 0;
        draw_done = 0;
        starts = 0;
        done_cnt = 0;
        clear_count = 0;
        point_count = 0;
        line_count = 0;

        $readmemh("../verification/Unit_Level/cmd_decode/test_data/cmd_stream.hex", words);
        total_words = 20;  // Read up to 20 words (more than actual test data)

        repeat (4) @(posedge clk);
        rst_n = 1;

        for (i = 0; i < total_words; i = i + 1) begin
            @(posedge clk);
            while (!cmd_ready) begin
                @(posedge clk);
            end
            cmd_in  <= words[i];
            cmd_val <= 1'b1;
            @(posedge clk);
            cmd_val <= 1'b0;
        end

        repeat (100) @(posedge clk);

        if (starts == 0) begin
            $display("FAIL: No start pulses detected");
            $finish_and_return(1);
        end

        $display("INFO: Detected %0d command(s)", starts);
        $display("  CLEAR: %0d, POINT: %0d, LINE: %0d", clear_count, point_count, line_count);
        $display("PASS: cmd_decode_tb");
        $finish;
    end

    always @(posedge clk) begin
        draw_done <= 1'b0;

        if (start_pulse) begin
            done_cnt <= 2;
            starts <= starts + 1;
            case (opcode)
                4'h1: begin
                    clear_count <= clear_count + 1;
                    $display("  Command: CLEAR (color=0x%03X)", out_color);
                end
                4'h2: begin
                    point_count <= point_count + 1;
                    $display("  Command: DRAW_POINT at (%0d, %0d) color=0x%03X", out_x0, out_y0, out_color);
                end
                4'h3: begin
                    line_count <= line_count + 1;
                    $display("  Command: DRAW_LINE from (%0d, %0d) to (%0d, %0d) color=0x%03X", 
                        out_x0, out_y0, out_x1, out_y1, out_color);
                end
                default: begin
                    $display("  Command: Unknown opcode=0x%X", opcode);
                end
            endcase
        end

        if (done_cnt > 0) begin
            done_cnt <= done_cnt - 1;
            if (done_cnt == 1) begin
                draw_done <= 1'b1;
            end
        end
    end
endmodule

