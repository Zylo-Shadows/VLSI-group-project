// file: common_defs.vh
`ifndef COMMON_DEFS_VH
`define COMMON_DEFS_VH

parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 16;
parameter FIFO_DEPTH = 64;

parameter NOP = 32'h00000013; // ADDI x0,x0,0

`endif
