/*
ALU module which takes two operands of size 32-bits each and a 4 bit alu_op as input. 
Operation is performed on the basis of alu_op value and output is 32-bit result.
*/

import types::*;

module ALU_32(
  input [31:0] operand_a, operand_b,		//Registers to be operated on
  input [3:0] alu_op,				        //Control register to control which operation is done
  output reg [31:0] result			        //Result register 
);

  always@(*)
  begin
    //Defaults
    result = 32'b0;

    //Operating based on control input
    case(alu_op)

      //ADD control
      ALU_ADD: result = operand_a + operand_b;

      //SUB control
      ALU_SUB: result = operand_a - operand_b;

      //SLL control
      ALU_SLL: result = operand_a << operand_b[4:0]; //only uses lower 5 bits of operand_b since we can shift a max of 32 bits

      //XOR control
      ALU_XOR: result = operand_a ^ operand_b;

      //SRL control
      ALU_SRL: result = operand_a >> operand_b[4:0]; //only uses lower 5 bits of operand_b since we can shift a max of 32 bits

      //SRA control
      ALU_SRA: result = $signed(operand_a) >>> operand_b[4:0]; //preserves the sign bit and also only uses lower 5 bits of operand_b
      //since we can shift a max of 32 bits

      //OR control
      ALU_OR: result = operand_a | operand_b;

      //AND control
      ALU_AND: result = operand_a & operand_b;

      //Default case
      default: 	result = x';

    endcase

  end

endmodule