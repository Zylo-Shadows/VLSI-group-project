package types;
    typedef enum logic [2:0] {
        R_TYPE = 3'b000,
        I_TYPE = 3'b001,
        S_TYPE = 3'b010,
        B_TYPE = 3'b011,
        U_TYPE = 3'b100,
        J_TYPE = 3'b101
    } inst_format_t;

    typedef enum logic [6:0] {
        OP_LUI       = 7'b0110111,
        OP_AUIPC     = 7'b0010111,
        OP_JAL       = 7'b1101111,
        OP_JALR      = 7'b1100111,
        OP_BRANCH    = 7'b1100011,
        OP_LOAD      = 7'b0000011,
        OP_STORE     = 7'b0100011,
        OP_OP_IMM    = 7'b0010011,
        OP_OP        = 7'b0110011,
        OP_MISC_MEM  = 7'b0001111,
        OP_SYSTEM    = 7'b1110011
    } opcode_t;

    typedef enum logic [2:0] {
        CMP_EQ   = 3'b000,
        CMP_NE   = 3'b001,
        CMP_LT   = 3'b100,
        CMP_GE   = 3'b101,
        CMP_LTU  = 3'b110,
        CMP_GEU  = 3'b111
    } cmp_op_t;

    // {funct7[5], funct3}
    typedef enum logic [3:0] {
        ALU_ADD  = 4'b0000,
        ALU_SUB  = 4'b1000,
        ALU_SLL  = 4'b0001,
        ALU_SLT  = 4'b0010,
        ALU_SLTU = 4'b0011,
        ALU_XOR  = 4'b0100,
        ALU_SRL  = 4'b0101,
        ALU_SRA  = 4'b1101,
        ALU_OR   = 4'b0110,
        ALU_AND  = 4'b0111
    } alu_op_t;

endpackage
