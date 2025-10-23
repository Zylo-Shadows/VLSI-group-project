import types::inst_format_t

module immediate_builder (
    input  inst_format_t inst_fmt,
    input  logic [31:0]  instruction,
    output logic [31:0]  immediate
);

    always_comb begin
        case (inst_fmt)
            I_TYPE: begin
                // I-type: imm[11:0] = inst[31:20]
                immediate = {{20{instruction[31]}}, instruction[31:20]};
            end

            S_TYPE: begin
                // S-type: imm[11:5] = inst[31:25], imm[4:0] = inst[11:7]
                immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            end

            B_TYPE: begin
                // B-type: imm[12|10:5] = inst[31:25], imm[4:1|11] = inst[11:7]
                immediate = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
            end

            U_TYPE: begin
                // U-type: imm[31:12] = inst[31:12]
                immediate = {instruction[31:12], 12'b0};
            end

            J_TYPE: begin
                // J-type: imm[20|10:1|11|19:12] = inst[31:12]
                immediate = {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
            end

            default: begin
                immediate = 32'b0;
            end
        endcase
    end

endmodule
