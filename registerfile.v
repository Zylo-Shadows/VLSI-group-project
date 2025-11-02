module register_file (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [3:0]  rs1_addr,
    input  wire [3:0]  rs2_addr,
    input  wire [3:0]  rd_addr,
    input  wire [31:0] rd_data,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data
);

    reg [31:0] regfile [0:18];
    integer i;

    always @(negedge rst_n or posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < 19; i = i + 1)
                regfile[i] <= 32'd0;
        end else begin
            if (rd_addr != 4'd0)
                regfile[rd_addr] <= rd_data;
        end
    end

reg [31:0] rs1_data_r;
reg [31:0] rs2_data_r;

assign rs1_data = rs1_data_r;
assign rs2_data = rs2_data_r;

always @(*) begin
    if (rs1_addr == 4'd0)
        rs1_data_r = 32'd0;
    else
        rs1_data_r = regfile[rs1_addr];

    if (rs2_addr == 4'd0)
        rs2_data_r = 32'd0;
    else
        rs2_data_r = regfile[rs2_addr];
end

endmodule
