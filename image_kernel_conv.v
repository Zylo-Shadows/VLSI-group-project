module image_conv #(
    parameter PIXEL_WIDTH = 8,          // bits per pixel
)(
    input  wire                   clk,  // one tick  per pixel
    input  wire                   rst_n,
    input  wire signed [PIXEL_WIDTH-1:0] pixel_in, // 8-bit pixel input (for single channel color)
    input  wire [1:0]             mode,      // 0=sharpen, 1=gaussian blur, 2=edge
    output reg  signed [PIXEL_WIDTH-1:0] pixel_out
);

    // 3x3 window shift registers to intitialize the kernel array
    //        | Column 0 |  Column 1 |  Column 2
    // -----------------------------------------
    // line 0 | top-left |  top-mid  |  top-right
    // -----------------------------------------
    // line 1 | mid-left |  mid-mid  |  top-right
    // -----------------------------------------
    // line 2 | bot-left |  bot-mid  |  bot-right
    reg signed [PIXEL_WIDTH-1:0] line0[0:2];   
    reg signed [PIXEL_WIDTH-1:0] line1[0:2];   
    reg signed [PIXEL_WIDTH-1:0] line2[0:2];   

    integer i;

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
