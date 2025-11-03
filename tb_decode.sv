`timescale 1ns/1ps

import types::*;

module tb_decode;

  // Parameters
  parameter MAX_INSTR = 1048576;

  // Inputs
  logic [31:0] instruction;

  // Outputs
  logic [31:0] immediate;
  inst_format_t inst_fmt;
  logic [4:0] rs1_addr, rs2_addr, rd_addr;
  logic branch, jump, compare, cmp_imm, alu_imm, alu_pc;
  cmp_op_t cmp_op;
  alu_op_t alu_op;
  logic mem_read, mem_write;
  logic [1:0] mem_size;
  logic mem_unsigned;

  // Instruction memory
  logic [31:0] instr_mem [0:MAX_INSTR-1];
  integer num_instr;
  integer i;

  integer fd;

  // Instantiate the decoder
  instruction_decoder dut0 (
    .instruction(instruction),
    .instruction_format(inst_fmt),
    .rs1_addr(rs1_addr),
    .rs2_addr(rs2_addr),
    .rd_addr(rd_addr),
    .branch(branch),
    .jump(jump),
    .compare(compare),
    .cmp_imm(cmp_imm),
    .cmp_op(cmp_op),
    .alu_imm(alu_imm),
    .alu_pc(alu_pc),
    .alu_op(alu_op),
    .mem_read(mem_read),
    .mem_write(mem_write),
    .mem_size(mem_size),
    .mem_unsigned(mem_unsigned)
  );

  immediate_builder dut1 (
    .inst_fmt(inst_fmt),
    .instruction(instruction),
    .immediate(immediate)
  );

  initial begin
    fd = $fopen("instructions.bin","rb");
    num_instr = $fread(instr_mem, fd);
    $fclose(fd);

    for (i = 0; i < num_instr; i++) begin
      instruction = {instr_mem[i][7:0], instr_mem[i][15:8], instr_mem[i][23:16], instr_mem[i][31:24]};
      #1; // Small delay to allow outputs to settle

      $display("%x %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d",
               instruction,
               $signed(immediate),
               inst_fmt,
               rs1_addr,
               rs2_addr,
               rd_addr,
               branch,
               jump,
               compare,
               cmp_imm,
               cmp_op,
               alu_imm,
               alu_pc,
               alu_op,
               mem_read,
               mem_write,
               mem_size,
               mem_unsigned
      );
    end

    $finish;
  end

endmodule
