module register_file (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        write_en,
    input  wire [4:0]  rs1_addr,  
    input  wire [4:0]  rs2_addr,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] rd_data,
    output reg  [31:0] rs1_data, 
    output reg  [31:0] rs2_data,
    output reg  [31:0] r16,
    output reg  [31:0] r17,
    output reg  [31:0] r18
);
    // 16+3 registers for DSP
    reg [31:0] regfile [0:18];
    integer i;
 
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < 19; i = i + 1)
                regfile[i] <= 32'd0;
        end else begin
            if (write_en && rd_addr != 5'd0)
                regfile[rd_addr] <= rd_data;
        end
    end

    assign rs1_data = regfile[rs1_addr[3:0]];
    assign rs2_data = regfile[rs2_addr[3:0]];

    assign r16 = regfile[5'd16];
    assign r17 = regfile[5'd17];
    assign r18 = regfile[5'd18];

endmodule
