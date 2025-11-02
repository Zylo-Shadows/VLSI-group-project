module conv33 #(
    parameter PIXEL_WIDTH = 8,          // bits per pixel
    parameter ACC         = 16          // width of accumulator 
)(
    input  wire                   clk,  // one tick  per pixel
    input  wire                   rst_n,
    \\ thre input pixels (per row)
    input  wire signed [PIXEL_WIDTH-1:0] pix_top, // 8-bit pixel input (for single channel color)
    input  wire signed [PIXEL_WIDTH-1:0] pix_mid, 
    input  wire signed [PIXEL_WIDTH-1:0] pix_bot, 
    
    input  wire [1:0]             mode,      // 0=sharpen, 1=gaussian blur, 2=edge
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


    // Simple circular shifter per line (each clk)
    always @(posedge clk) begin
        if (!rst_n) begin // Active low logic for reset behavior
            for (i=0; i<3; i=i+1) begin
                line0[i] <= 0;
                line1[i] <= 0;
                line2[i] <= 0;
            end
            pixel_out <= 0;
        end else begin
            // Shift horizontally
            line0[0] <= line0[1];
            line0[1] <= line0[2];
            line0[2] <= line1[0];

            line1[0] <= line1[1];
            line1[1] <= line1[2];
            line1[2] <= line2[0];

            line2[0] <= line2[1];
            line2[1] <= line2[2];
            line2[2] <= pixel_in;

            // Perform convolution based on mode
            case (mode)
                2'd0: begin
                    // Sharpen kernel
                    // [ 0 -1  0; -1 5 -1; 0 -1 0]
                    pixel_out <= saturate_8bit(    
                        // Define the kernel for convolution
                        5*line1[1]
                        - line0[1] - line1[0] - line1[2] - line2[1]
                    );
                end

                2'd1: begin
                    // Gaussian blur kernel (sum/16)
                    // [1 2 1; 2 4 2; 1 2 1]
                    pixel_out <= saturate_8bit((
                          line0[0] + 2*line0[1] + line0[2]
                        + 2*line1[0] + 4*line1[1] + 2*line1[2]
                        + line2[0] + 2*line2[1] + line2[2]
                    ) >>> 4); // divide by 16
                end

                2'd2: begin
                    // Edge detection kernel
                    // [-1 -1 -1; -1 8 -1; -1 -1 -1]
                    pixel_out <= saturate_8bit(
                        8*line1[1]
                        - (line0[0]+line0[1]+line0[2]
                           +line1[0]+line1[2]
                           +line2[0]+line2[1]+line2[2])
                    );
                end

                default: pixel_out <= line1[1]; // pass-through
            endcase
        end
    end

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
