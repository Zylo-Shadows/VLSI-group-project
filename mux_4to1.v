module mux_4to1 #(
    parameter WIDTH = 32
) (
    input wire       [1:0] sel,
    input wire [WIDTH-1:0] in0,
    input wire [WIDTH-1:0] in1,
    input wire [WIDTH-1:0] in2,
    input wire [WIDTH-1:0] in3,
    output reg [WIDTH-1:0] out
);

    always @(*) begin
        case (sel)
            2'd0: out = in0;
            2'd1: out = in1;
            2'd2: out = in2;
            2'd3: out = in3;
            default: out = {WIDTH{1'b0}};
        endcase
    end

endmodule
