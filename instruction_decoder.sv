import types::*;

module instruction_decoder (
    input  logic [31:0]  instruction,

    // Decoded fields
    output inst_format_t instruction_format, // R, I, S, B, U, J

    // Register fields
    output logic [4:0]   rs1_addr,
    output logic [4:0]   rs2_addr,
    output logic [4:0]   rd_addr,

    // Control signals
    output logic         branch,
    output logic         jump,
    output logic         compare,
    output logic         cmp_imm,
    output cmp_op_t      cmp_op,
    output logic         alu_imm,
    output logic         alu_pc,
    output alu_op_t      alu_op,

    // Memory
    output logic         mem_read,
    output logic         mem_write,
    output logic [1:0]   mem_size,
    output logic         mem_unsigned
);

    opcode_t    opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = opcode_t'(instruction[6:0]);
    assign rd_addr = instruction[11:7];
    assign funct3 = instruction[14:12];
    // rd <- U-immediate + 0 for LUI
    assign rs1_addr = (opcode == OP_LUI ? 5'd0 : {1'b0, instruction[18:15]});
    assign rs2_addr = {1'b0, instruction[23:20]};
    assign funct7 = instruction[31:25];

    always_comb begin
        case (opcode)
            OP_OP_IMM,
            OP_LOAD,
            OP_JALR,
            OP_SYSTEM: instruction_format = I_TYPE;
            OP_STORE:  instruction_format = S_TYPE;
            OP_BRANCH: instruction_format = B_TYPE;
            OP_LUI,
            OP_AUIPC:  instruction_format = U_TYPE;
            OP_JAL:    instruction_format = J_TYPE;
            default:   instruction_format = R_TYPE;
        endcase
    end

    always_comb begin
        case (alu_op)
            ALU_SLT: begin
                compare = 1;
                cmp_op = CMP_BLT;
            end

            ALU_SLTU: begin
                compare = 1;
                cmp_op = CMP_BLTU;
            end

            default: begin
                compare = 0;
                cmp_op = cmp_op_t'(funct3);
            end
        endcase
    end

    always_comb begin
        {branch, jump, cmp_imm, alu_imm, alu_pc} = 0;
        alu_op = ALU_ADD;

        case (opcode)
            OP_OP: begin
                alu_op = alu_op_t'({funct7[5], funct3});
            end

            OP_OP_IMM: begin
                alu_op = alu_op_t'({funct7[5], funct3});
                if (alu_op != ALU_SRA) alu_op[3] = 1'b0;
                cmp_imm = 1;
                alu_imm = 1;
            end

            OP_LOAD, OP_STORE: alu_imm = 1;
            OP_BRANCH: begin
                branch = 1;
                alu_imm = 1;
                alu_pc = 1;
            end
            OP_LUI: alu_imm = 1;
            OP_AUIPC: begin
                alu_imm = 1;
                alu_pc = 1;
            end
            OP_JAL: begin
                jump = 1;
                alu_imm = 1;
                alu_pc = 1;
            end
            OP_JALR: begin
                jump = 1;
                alu_imm = 1;
            end
        endcase
    end

    assign mem_read     = (opcode == OP_LOAD);
    assign mem_write    = (opcode == OP_STORE);
    assign mem_size     = funct3[1:0];
    assign mem_unsigned = funct3[2];

endmodule
