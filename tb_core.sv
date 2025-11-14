`timescale 1ns/1ps
`include "definitions.vh"

import types::*;

module tb_core;

  parameter CLK_PERIOD = 10; // 100 MHz
  parameter MAX_INSTR  = 1048576;

  logic clk;
  logic rst_n;

  logic [31:0] boot_addr;

  logic [31:0] inst_addr;
  logic [31:0] instruction;
  logic inst_ready;

  logic        sram_cen;
  logic        sram_wen;
  logic [3:0]  sram_ben;
  logic [31:0] sram_addr;
  logic [31:0] sram_din;
  logic [31:0] sram_dout;

  integer num_instr;

  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  RV32E dut (
    .clk(clk),
    .rst_n(rst_n),
    .boot_addr(boot_addr),

    .inst_addr(inst_addr),
    .instruction(instruction),
    .inst_ready(inst_ready),

    .sram_cen(sram_cen),
    .sram_wen(sram_wen),
    .sram_ben(sram_ben),
    .sram_addr(sram_addr),
    .sram_din(sram_din),
    .sram_dout(sram_dout)
  );

  localparam MEM_SIZE = 2**24;

  logic [3:0][7:0] mem [0:MEM_SIZE-1];
  logic [$clog2(MEM_SIZE)-1:0] addr;
  assign addr = sram_addr[$clog2(MEM_SIZE)+1:2];

  always_ff @(posedge clk) begin
    if (!sram_cen) begin
      // Write
      if (!sram_wen) begin
        if (!sram_ben[0]) mem[addr][0] <= sram_din[7:0];
        if (!sram_ben[1]) mem[addr][1] <= sram_din[15:8];
        if (!sram_ben[2]) mem[addr][2] <= sram_din[23:16];
        if (!sram_ben[3]) mem[addr][3] <= sram_din[31:24];
      end

      // Read
      sram_dout <= {mem[addr][3], mem[addr][2], mem[addr][1], mem[addr][0]};
    end else begin
      sram_dout <= '0;
    end
  end

  logic [31:0] instr_mem [0:MAX_INSTR-1];

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      instruction <= NOP;
      inst_ready  <= 1'b0;
    end
    instruction <= instr_mem[inst_addr[$clog2(MAX_INSTR)+1:2]];
    inst_ready  <= 1'b1;
  end

  integer fd;

  initial begin
    fd = $fopen("instructions.bin","rb");
    num_instr = $fread(instr_mem, fd)/4;
    $fclose(fd);

    for (int i = 0; i < MAX_INSTR; i++) begin
      if (i < num_instr)
        instr_mem[i] = {instr_mem[i][7:0], instr_mem[i][15:8], instr_mem[i][23:16], instr_mem[i][31:24]};
      else
        instr_mem[i] = NOP;
    end

    rst_n = 0;
    boot_addr = 32'h00000004;
    #(CLK_PERIOD*5);
    rst_n = 1;

    #(num_instr*CLK_PERIOD*3/2);

    for (int i = 4; i < 2**20; i = i + 4) begin
      $display("%d %d", i, mem[i/4]);
    end

    $finish;
  end

endmodule
