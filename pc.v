module pc_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] pc_start,
    input  wire        pc_load,
    input  wire [31:0] pc_in,
    output reg  [31:0] pc_out,
    output wire [31:0] pc_plus_4,
    output wire [31:0] pc_next
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc_out <= pc_start;
        else if (pc_load)
            pc_out <= pc_in;
        else
            pc_out <= pc_out + 32'd4;
    end

    assign pc_plus_4 = pc_out + 32'd4;
    assign pc_next   = pc_load ? pc_in : pc_plus_4;

endmodule