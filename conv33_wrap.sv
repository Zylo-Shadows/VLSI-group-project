// split 3x32b inputs into RGB channels, run per-channel conv33, repack to 32b

module conv33_wrap #(
  parameter int PIXEL_WIDTH = 8,
  parameter int ACCW        = 16,
  // byte indices: 0=[7:0], 1=[15:8], 2=[23:16], 3=[31:24]
  parameter int R_IDX = 0,
  parameter int G_IDX = 1,
  parameter int B_IDX = 2,
  parameter int A_IDX = 3
)(
  input wire       clk,       // one tick per pixel
  input wire       rst_n,
  input wire       shift_en,  // gate the shift in conv33
  input wire [1:0] mode,      // 0=pass,1=sharpen,2=gauss,3=edge

  // packed ARGB32 words for the current column of the 3 rows
  input wire [31:0] top_pix,   // {X,R,G,B}
  input wire [31:0] mid_pix,   // {X,R,G,B}
  input wire [31:0] bot_pix,   // {X,R,G,B}

  output wire [31:0] pixel_out  // {0,R,G,B}
);

  // byte extraction
  function automatic [7:0] byte_at (input logic [31:0] w, input int idx);
    byte_at = w[idx*8 +: 8];
  endfunction

  // keep alpha from mid_pix unchanged since we aren't performing convolution on the alpha channel
  wire [7:0] A_passthru = byte_at(mid_pix, A_IDX);

  // R channel
  wire [PIXEL_WIDTH-1:0] R_out;
  conv33 #(.PIXEL_WIDTH(PIXEL_WIDTH), .ACCW(ACCW)) u_conv_R (
    .clk(clk), .rst_n(rst_n), .shift_en(shift_en),
    .pix_top( byte_at(top_pix, R_IDX) ),   // ports are signed; width matches; OK
    .pix_mid( byte_at(mid_pix, R_IDX) ),
    .pix_bot( byte_at(bot_pix, R_IDX) ),
    .mode(mode),
    .pixel_out(R_out)
  );

  // G channel
  wire [PIXEL_WIDTH-1:0] G_out;
  conv33 #(.PIXEL_WIDTH(PIXEL_WIDTH), .ACCW(ACCW)) u_conv_G (
    .clk(clk), .rst_n(rst_n), .shift_en(shift_en),
    .pix_top( byte_at(top_pix, G_IDX) ),
    .pix_mid( byte_at(mid_pix, G_IDX) ),
    .pix_bot( byte_at(bot_pix, G_IDX) ),
    .mode(mode),
    .pixel_out(G_out)
  );

  // B channel
  wire [PIXEL_WIDTH-1:0] B_out;
  conv33 #(.PIXEL_WIDTH(PIXEL_WIDTH), .ACCW(ACCW)) u_conv_B (
    .clk(clk), .rst_n(rst_n), .shift_en(shift_en),
    .pix_top( byte_at(top_pix, B_IDX) ),
    .pix_mid( byte_at(mid_pix, B_IDX) ),
    .pix_bot( byte_at(bot_pix, B_IDX) ),
    .mode(mode),
    .pixel_out(B_out)
  );

  // repack to 32-bit (pass alpha)
  assign pixel_out[7:0]   = R_out;
  assign pixel_out[15:8]  = G_out;
  assign pixel_out[23:16] = B_out;
  assign pixel_out[31:24] = A_passthru;

endmodule
