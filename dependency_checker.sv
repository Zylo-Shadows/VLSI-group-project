module dependency_checker #(
    parameter REG_ADDR_WIDTH = 5
) (
    input  logic [REG_ADDR_WIDTH-1:0] rs1_addr,
    input  logic [REG_ADDR_WIDTH-1:0] rs2_addr,
    input  logic [REG_ADDR_WIDTH-1:0] rd1_addr,  // EX stage destination
    input  logic [REG_ADDR_WIDTH-1:0] rd2_addr,  // MEM stage destination
    output logic [1:0] alu_src1,  // Forward select for rs1
    output logic [1:0] alu_src2   // Forward select for rs2
);

    always_comb begin
        // Default: use register file outputs
        alu_src1 = 2'd0;
        alu_src2 = 2'd0;

        // Check dependency for rs1
        if (rs1_addr != 0 && rs1_addr == rd1_addr)
            alu_src1 = 2'd1; // Forward from MEM
        else if (rs1_addr != 0 && rs1_addr == rd2_addr)
            alu_src1 = 2'd2; // Forward from WB

        // Check dependency for rs2
        if (rs2_addr != 0 && rs2_addr == rd1_addr)
            alu_src2 = 2'd1; // Forward from MEM
        else if (rs2_addr != 0 && rs2_addr == rd2_addr)
            alu_src2 = 2'd2; // Forward from WB
    end

endmodule
