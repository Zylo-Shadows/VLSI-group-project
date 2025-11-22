module pc_reg (
    input  wire        clk,
    input  wire        rst_n,  // synchronous reset
    input  wire        pc_en,
    input  wire [31:0] pc_start,
    input  wire        pc_load,
    input  wire [31:0] pc_in,
    output reg  [31:0] pc_out,
    output wire [31:0] pc_plus_4,
    output reg  [31:0] pc_next
);

    always @(posedge clk) begin
        if (!rst_n)
            pc_out <= pc_start;
        else if (pc_en)
            pc_out <= pc_next;
    end

    assign pc_plus_4 = pc_out + 32'd4;

    always @(*) begin
        if (pc_load)
            pc_next = pc_in;
        else
            pc_next = pc_plus_4;
    end

endmodule
