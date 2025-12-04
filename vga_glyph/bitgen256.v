module bitgen256 (
    input clk,
    input bright,
	input [7:0] cidx_top, cidx_mid, cidx_bot,
	output reg [31:0] color_rgba_top, color_rgba_mid, color_rgba_bot
);

    reg [31:0] colors [0:255];

    initial begin
        $readmemh("vga256.hex", colors);
    end

    always @(posedge clk) begin
        if (bright) begin
	        color_rgba_top <= colors[cidx_top];
	        color_rgba_mid <= colors[cidx_mid];
	        color_rgba_bot <= colors[cidx_bot];
        end
        else begin
            color_rgba_top <= 32'b0;
            color_rgba_mid <= 32'b0;
            color_rgba_bot <= 32'b0;
        end
    end

endmodule
