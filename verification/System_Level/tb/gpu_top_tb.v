`timescale 1ns/1ps

module gpu_top_tb;
    reg         clk_sys;
    reg         clk_vga;
    reg         rst_n;
    reg  [31:0] host_cmd_data;
    reg         host_cmd_valid;
    wire        host_cmd_ready;
    wire        vga_hsync;
    wire        vga_vsync;
    wire [11:0] vga_rgb;

    reg [31:0] words [0:25];
    integer total_words;
    integer i;
    integer fh;
    integer idx;

    gpu_top dut (
        .clk_sys(clk_sys),
        .clk_vga(clk_vga),
        .rst_n(rst_n),
        .host_cmd_data(host_cmd_data),
        .host_cmd_valid(host_cmd_valid),
        .host_cmd_ready(host_cmd_ready),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .vga_rgb(vga_rgb)
    );

    always #5  clk_sys = ~clk_sys;
    always #20 clk_vga = ~clk_vga;

    initial begin
        clk_sys = 0;
        clk_vga = 0;
        rst_n = 0;
        host_cmd_data = 0;
        host_cmd_valid = 0;

        $readmemh("../verification/System_Level/test_data/system_cmds.hex", words);
        total_words = 26;

        repeat (10) @(posedge clk_sys);
        rst_n = 1;

        for (i = 0; i < total_words; i = i + 1) begin
            @(posedge clk_sys);
            while (!host_cmd_ready) @(posedge clk_sys);
            host_cmd_data  <= words[i];
            host_cmd_valid <= 1'b1;
            @(posedge clk_sys);
            host_cmd_valid <= 1'b0;
        end

        // wait for draw completion
        repeat (80000) @(posedge clk_sys);

        fh = $fopen("../verification/System_Level/golden_output/fb_dump_from_tb.txt", "w");
        if (fh == 0) begin
            $display("FAIL: cannot open fb dump");
            $finish_and_return(1);
        end

        for (idx = 0; idx < 76800; idx = idx + 1) begin
            $fwrite(fh, "%03h\n", dut.u_frame_buffer.mem[idx]);
        end

        $fclose(fh);
        $display("PASS: gpu_top_tb");
        $finish;
    end
endmodule
