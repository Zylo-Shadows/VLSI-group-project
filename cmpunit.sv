import types::*;

module cmpunit (
    input  logic [31:0] operand_a,
    input  logic [31:0] operand_b,
    input  cmp_op_t     cmp_op,
    output logic        result
);

    // Internal signals for comparison results
    logic eq, lt_signed, lt_unsigned;
    
    // Basic comparisons
    assign eq = (operand_a == operand_b);
    assign lt_signed = ($signed(operand_a) < $signed(operand_b));
    assign lt_unsigned = (operand_a < operand_b);

    // Comparison result logic
    always_comb begin
        case (cmp_op)
            CMP_EQ:  result = eq;                    // Equal
            CMP_NE:  result = ~eq;                   // Not Equal
            CMP_LT:  result = lt_signed;             // Less Than (signed)
            CMP_GE:  result = ~lt_signed;            // Greater or Equal (signed)
            CMP_LTU: result = lt_unsigned;           // Less Than Unsigned
            CMP_GEU: result = ~lt_unsigned;          // Greater or Equal Unsigned
            default:  result = 1'b0;                 // Default case
        endcase
    end

endmodule