module conv33 #(
    parameter PIXEL_WIDTH = 8,          // bits per pixel
    parameter ACCW        = 16          // width of accumulator 
)(
    input  wire                   clk,  // one tick  per pixel
    input  wire                   rst_n,
    \\ thre input pixels (per row)
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

    // fill state: provides information about how many columns are present in the current window 
    reg [1:0] fill_count;  // has up to 3 columns

    // sign-extension into accumulator to hold large magnitude convolution sums  
    function automatic signed [ACCW-1:0] sx;
       input signed [PIXEL_WIDTH-1:0] v;
       sx = $signed({{(ACCW-PIXEL_WIDTH){v[PIXEL_WIDTH-1]}}, v});
   endfunction



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

endmodule
