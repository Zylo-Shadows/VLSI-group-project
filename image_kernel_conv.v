module conv33 #(
    parameter PIXEL_WIDTH = 8,          // bits per pixel
    parameter ACCW        = 16          // width of accumulator 
)(
    input  wire                   clk,  // one tick  per pixel
    input  wire                   rst_n,
    \\ three input pixels (1 per row)
    input  wire signed [PIXEL_WIDTH-1:0] pix_top, // 8-bit pixel input (for single channel color)
    input  wire signed [PIXEL_WIDTH-1:0] pix_mid, 
    input  wire signed [PIXEL_WIDTH-1:0] pix_bot, 
    
    input  wire [1:0]             mode,      // 0=sharpen, 1=gaussian blur, 2=edge detection
    
    output reg  signed [PIXEL_WIDTH-1:0] pixel_out
    
);

    // 3x3 window to apply kernel to 
    //  | Column 0 |  Column 1 |  Column 2
    // -------------------------------------
    //  |    t0    |     t1    |   pix_top
    // -------------------------------------
    //  |    m0    |     m1    |   pix_mid
    // -------------------------------------
    //  |    b0    |     b1    |   pix_bot
    reg signed [PIXEL_WIDTH-1:0] t0, t1;     // row 0: col0, col1   
    reg signed [PIXEL_WIDTH-1:0] m0, m1;     // row 1: col0, col1
    reg signed [PIXEL_WIDTH-1:0] b0, b1;     // row 2: col0, col1

    // sign-extension into accumulator to hold large magnitude convolution sums  
    function automatic signed [ACCW-1:0] sx;
       input signed [PIXEL_WIDTH-1:0] v;
       sx = $signed({{(ACCW-PIXEL_WIDTH){v[PIXEL_WIDTH-1]}}, v});
    endfunction

    // Writing the three convolution kernels

    // Sharpen: [ 0 -1 0; -1 5 -1; 0 -1 0 ]
    wire signed [ACCW-1:0] conv_sharpen =
        (5 * sx(m1)) - ( sx(t1) + sx(m0) + sx(pix_mid) + sx(b1) );

   // Gaussian: [1 2 1; 2 4 2; 1 2 1] * 1/16
   wire signed [ACCW -1:0] gauss_sum =
        sx(t0) + ((2*sx(t1)) + sx(pix_top)
      + (2*sx(m0)) + (4*sx(m1)) + (2*sx(pix_mid))
      + sx(b0) + (2*sx(b1)) + sx(pix_bot);
   
   wire signed [ACCW-1:0] conv_gaussian = gauss_sum >>> 4; // arithmetic right shift by 4: divide by 2^4

   // Edge detection: [-1 -1 -1; -1 8 -1; -1 -1 -1]
   wire signed [ACCW-1:0]
        8 * sx(m1)
      - ( sx(t0) + sx(t1) + sx(pix_top)
        + sx(m0)          + sx(pix_mid)
        + sx(b0) + sx(b1) + sx(pix_bot) );

    // Function to clip result to 8-bit unsigned
    function signed [PIXEL_WIDTH-1:0] saturate_8bit;
        input signed [15:0] val;
        begin
            if (val < 0)
                saturate_8bit = 0;
            else if (val > 255)
                saturate_8bit = 8'd255;
            else
                saturate_8bit = val[7:0];
        end
    endfunction

   // Mode selection mux
   reg signed [ACCW-1:0] selected_kernel;
   always @* begin
      case (mode)
         2'd0: selected_kernel = conv_sharpen;
         2'd1: selected_kernel = conv_gaussian;
         2'd2: selected_kernel = conv_edge;
         default: selected_kernel = sx(mm); // pass-through logic
      endcase
   end

   // output logic
   always @(posedge clk or negedge rst_n) begin
   // reset logic (clear all values if low)
      if (!rst_n) begin
         t0<=0;  t1<=0; m0<=0;  m1<=0; b0<=0; b1<=0:
         pixel_out <= '0;
      end else begin
         // Production of output ffor selected kernel
         pixel_out <= saturate_8bit(selected_kernel)
      end
   end
  
   // shift input to registers
   always @(posedge clk)
      t0 <= t1;    t1 <= pix_top;
      m0 <= m1;    m1 <= pix_mid;
      b0 <= b1;    b1 <= pix_bot;
   end
endmodule
