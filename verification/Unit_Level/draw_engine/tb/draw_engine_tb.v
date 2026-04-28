`timescale 1ns/1ps

module draw_engine_tb;
    reg         clk;
    reg         rst_n;
    reg  [3:0]  opcode;
    reg         start_pulse;
    reg  [9:0]  x0;
    reg  [8:0]  y0;
    reg  [9:0]  x1;
    reg  [8:0]  y1;
    reg  [11:0] color_in;

    wire        fb_we;
    wire [16:0] fb_addr;
    wire [11:0] fb_data;
    wire        done_pulse;

    integer fh;
    integer we_count;

    draw_engine dut (
        .clk_sys(clk),
        .rst_n(rst_n),
        .opcode(opcode),
        .start_pulse(start_pulse),
        .x0(x0),
        .y0(y0),
        .x1(x1),
        .y1(y1),
        .color_in(color_in),
        .fb_we(fb_we),
        .fb_addr(fb_addr),
        .fb_data(fb_data),
        .done_pulse(done_pulse)
    );

    always #5 clk = ~clk;

    task run_case;
        input [3:0]  t_opcode;
        input [11:0] t_color;
        input [9:0]  t_x0;
        input [8:0]  t_y0;
        input [9:0]  t_x1;
        input [8:0]  t_y1;
        begin
            @(posedge clk);
            opcode <= t_opcode;
            color_in <= t_color;
            x0 <= t_x0;
            y0 <= t_y0;
            x1 <= t_x1;
            y1 <= t_y1;
            start_pulse <= 1'b1;
            @(posedge clk);
            start_pulse <= 1'b0;

            wait(done_pulse === 1'b1);
            @(posedge clk);
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        opcode = 0;
        start_pulse = 0;
        x0 = 0;
        y0 = 0;
        x1 = 0;
        y1 = 0;
        color_in = 0;
        we_count = 0;

        fh = $fopen("../verification/Unit_Level/draw_engine/golden_output/draw_engine_tb_capture.txt", "w");
        if (fh == 0) begin
            $display("FAIL: cannot open capture file");
            $finish_and_return(1);
        end

        repeat (4) @(posedge clk);
        rst_n = 1;

        run_case(4'h2, 12'h0F0, 10, 20, 0, 0);
        run_case(4'h3, 12'h00F, 0, 0, 10, 6);
        run_case(4'h3, 12'hF00, 10, 6, 0, 0);

        if (we_count < 3) begin
            $display("FAIL: too few framebuffer writes");
            $finish_and_return(1);
        end

        $fclose(fh);
        $display("PASS: draw_engine_tb");
        $finish;
    end

    always @(posedge clk) begin
        if (fb_we) begin
            we_count <= we_count + 1;
            $fwrite(fh, "%0d,%0h\n", fb_addr, fb_data);
        end
    end
endmodule
