module vga256 (
    input clk, rst_n,
    input [7:0] cidx_top, cidx_mid, cidx_bot,
    output vga_clk, vga_blank_n, vga_vs, vga_hs,
    output  [9:0] x, y,
    output [31:0] color_rgba_top, color_rgba_mid, color_rgba_bot
);

wire [9:0] hcount, vcount;

// recall x_start = 158 = H_BACK_PORCH + H_SYNC + H_FRONT_PORCH
//        x_end   = 745 = H_TOTAL - H_BACK_PORCH
//        y_start = 0
//        y_end   = 480 = V_DISPLAY_INT
assign x = hcount - 10'd158;
assign y = vcount; 

vga_control #(10,10) ctrl (
    clk, ~rst_n,
    vga_hs, vga_vs,
    vga_blank_n, vga_clk,
    hcount,
    vcount
);

bitgen256 bitgen (
    clk,
    vga_blank_n,
    cidx_top, cidx_mid, cidx_bot,
    color_rgba_top, color_rgba_mid, color_rgba_bot
);

endmodule
