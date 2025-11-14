module mux_3to1 #(
    parameter WIDTH = 32
) (
    input  logic       [1:0] sel,
    input  logic [WIDTH-1:0] in0,
    input  logic [WIDTH-1:0] in1,
    input  logic [WIDTH-1:0] in2,
    output logic [WIDTH-1:0] out
);

    always_comb begin
        unique case (sel)
            2'd0: out = in0;
            2'd1: out = in1;
            2'd2: out = in2;
            2'd3: out = 'x;
            default: out = 'x;
        endcase
    end

endmodule
