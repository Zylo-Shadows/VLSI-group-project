// testbench for image convolution

`timescale 1ns/1ps

module tb_conv33;

  // Geometry
  parameter W = 8;   // columns
  parameter H = 6;   // rows

  // Clock / reset / control
  reg clk;
  reg rst_n;                 // synchronous, active-low
  reg shift_en;              // advance window one column when 1
  reg [1:0] mode;            // 0=pass, 1=sharpen, 2=gauss, 3=edge

  // Per-channel taps
  reg  signed [7:0] r_top, r_mid, r_bot;
  reg  signed [7:0] g_top, g_mid, g_bot;
  reg  signed [7:0] b_top, b_mid, b_bot;

  wire  [7:0] r_out, g_out, b_out;

  // 3x conv33 instances
  conv33 u_conv_r (
    .clk(clk), .rst_n(rst_n), .shift_en(shift_en),
    .pix_top(r_top), .pix_mid(r_mid), .pix_bot(r_bot),
    .mode(mode),
    .pixel_out(r_out)
  );

  conv33 u_conv_g (
    .clk(clk), .rst_n(rst_n), .shift_en(shift_en),
    .pix_top(g_top), .pix_mid(g_mid), .pix_bot(g_bot),
    .mode(mode),
    .pixel_out(g_out)
  );

  conv33 u_conv_b (
    .clk(clk), .rst_n(rst_n), .shift_en(shift_en),
    .pix_top(b_top), .pix_mid(b_mid), .pix_bot(b_bot),
    .mode(mode),
    .pixel_out(b_out)
  );

  // 32-bit image buffer (A ignored). Layout: R[7:0], G[15:8], B[23:16]
  reg [31:0] img [0:H-1][0:W-1];

  // unpack helpers
  function [7:0] GET_R; input [31:0] p; begin GET_R = p[7:0];   end endfunction
  function [7:0] GET_G; input [31:0] p; begin GET_G = p[15:8];  end endfunction
  function [7:0] GET_B; input [31:0] p; begin GET_B = p[23:16]; end endfunction

  // zero-padded accessors
  function [7:0] r_at; input integer yy, xx; begin
    if (yy < 0 || yy >= H || xx < 0 || xx >= W) r_at = 8'd0; else r_at = GET_R(img[yy][xx]);
  end endfunction
  function [7:0] g_at; input integer yy, xx; begin
    if (yy < 0 || yy >= H || xx < 0 || xx >= W) g_at = 8'd0; else g_at = GET_G(img[yy][xx]);
  end endfunction
  function [7:0] b_at; input integer yy, xx; begin
    if (yy < 0 || yy >= H || xx < 0 || xx >= W) b_at = 8'd0; else b_at = GET_B(img[yy][xx]);
  end endfunction

  // Clock
  initial clk = 1'b0;
  always #5 clk = ~clk; // 100 MHz

  // Stimulus
  integer x, y;

  initial begin
    // Simple image pattern (mask to 8 bits; no SystemVerilog casts)
    for (y = 0; y < H; y = y + 1) begin
      for (x = 0; x < W; x = x + 1) begin
        img[y][x] = { 8'hFF,
                      (16*(y^x)) & 8'hFF,   // B
                      (32*x)      & 8'hFF,  // G
                      (32*y)      & 8'hFF   // R
                    };
      end
    end

    // init signals
    r_top=0; r_mid=0; r_bot=0;
    g_top=0; g_mid=0; g_bot=0;
    b_top=0; b_mid=0; b_bot=0;
    shift_en = 1'b0;
    mode     = 2'd1; // Pass 1 = SHARPEN 

    // sync reset
    rst_n = 1'b0;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    // Pass 1: Sharpen (mode=1)
    for (y = 0; y < H; y = y + 1) begin
      for (x = 0; x < W; x = x + 1) begin
        // present vertical taps for current column x at rows y-1,y,y+1
        r_top <= r_at(y-1, x); r_mid <= r_at(y, x); r_bot <= r_at(y+1, x);
        g_top <= g_at(y-1, x); g_mid <= g_at(y, x); g_bot <= g_at(y+1, x);
        b_top <= b_at(y-1, x); b_mid <= b_at(y, x); b_bot <= b_at(y+1, x);
        // one column advance
        shift_en <= 1'b1; @(posedge clk); shift_en <= 1'b0;
        // print outputs (note: internal 2-column warmup due to t0/t1)
        $display("t=%0t SHARP y=%0d x=%0d  R=%0d G=%0d B=%0d",
                 $time, y, x, r_out, g_out, b_out);
      end
    end

    repeat (2) @(posedge clk);

    // Pass 2: Gaussian (mode=2)
    mode = 2'd2;
    for (y = 0; y < H; y = y + 1) begin
      for (x = 0; x < W; x = x + 1) begin
        r_top <= r_at(y-1, x); r_mid <= r_at(y, x); r_bot <= r_at(y+1, x);
        g_top <= g_at(y-1, x); g_mid <= g_at(y, x); g_bot <= g_at(y+1, x);
        b_top <= b_at(y-1, x); b_mid <= b_at(y, x); b_bot <= b_at(y+1, x);
        shift_en <= 1'b1; @(posedge clk); shift_en <= 1'b0;
        $display("t=%0t GAUSS y=%0d x=%0d  R=%0d G=%0d B=%0d",
                 $time, y, x, r_out, g_out, b_out);
      end
    end

    repeat (2) @(posedge clk);

    // Pass 3: Edge (mode=3)
    mode = 2'd3;
    for (y = 0; y < H; y = y + 1) begin
      for (x = 0; x < W; x = x + 1) begin
        r_top <= r_at(y-1, x); r_mid <= r_at(y, x); r_bot <= r_at(y+1, x);
        g_top <= g_at(y-1, x); g_mid <= g_at(y, x); g_bot <= g_at(y+1, x);
        b_top <= b_at(y-1, x); b_mid <= b_at(y, x); b_bot <= b_at(y+1, x);
        shift_en <= 1'b1; @(posedge clk); shift_en <= 1'b0;
        $display("t=%0t EDGE  y=%0d x=%0d  R=%0d G=%0d B=%0d",
                 $time, y, x, r_out, g_out, b_out);
      end
    end

    repeat (4) @(posedge clk);
    $stop; // pause instead of quit
  end

endmodule
