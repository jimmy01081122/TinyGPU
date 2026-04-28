`timescale 1ns/1ps

module vga_ctrl_tb;
    reg         clk;
    reg         rst_n;
    reg  [11:0] fb_data;
    wire [16:0] fb_addr;
    wire        hsync;
    wire        vsync;
    wire [11:0] vga_rgb;

    integer cyc;
    integer h_low_count;

    vga_ctrl dut (
        .clk_vga(clk),
        .rst_n(rst_n),
        .fb_data(fb_data),
        .fb_addr(fb_addr),
        .hsync(hsync),
        .vsync(vsync),
        .vga_rgb(vga_rgb)
    );

    always #20 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        fb_data = 12'hABC;
        cyc = 0;
        h_low_count = 0;

        repeat (4) @(posedge clk);
        rst_n = 1;

        // run for slightly more than one line
        for (cyc = 0; cyc < 820; cyc = cyc + 1) begin
            @(posedge clk);
            if (!hsync) h_low_count = h_low_count + 1;
        end

        if (h_low_count < 90 || h_low_count > 110) begin
            $display("FAIL: hsync low width unexpected: %0d", h_low_count);
            $finish_and_return(1);
        end

        $display("PASS: vga_ctrl_tb");
        $finish;
    end
endmodule
