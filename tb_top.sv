`timescale 1ns/1ps

import types::*;

module tb_top;

  parameter MAX_INSTR = 1048576;

  logic HCLK;
  logic HRESETn;

  logic [31:0] boot_addr;

  // AHB-Lite interface signals
  logic [31:0] HADDR;
  logic  [1:0] HTRANS;
  logic        HWRITE;
  logic  [2:0] HSIZE;
  logic  [2:0] HBURST;
  logic [31:0] HWDATA;
  logic        HMASTLOCK;
  logic  [3:0] HPROT;
  logic [31:0] HRDATA;
  logic        HREADY;
  logic  [1:0] HRESP;

  // SRAM interface
  logic        sram_cen;
  logic        sram_wen;
  logic [3:0]  sram_ben;
  logic [31:0] sram_addr;
  logic [31:0] sram_din;
  logic [31:0] sram_dout;

  logic HSEL;
  integer num_instr;

  initial begin
    HCLK = 0;
    forever #5 HCLK = ~HCLK; // 100 MHz clock
  end

  initial begin
    HRESETn = 0;
    boot_addr = 32'h00000004;
    HSEL = 1'b1;
    #50;
    HRESETn = 1;
  end

  top dut (
    .HCLK(HCLK),
    .HRESETn(HRESETn),
    .boot_addr(boot_addr),

    .HRDATA(HRDATA),
    .HREADY(HREADY),
    .HRESP(HRESP[0]),
    .HADDR(HADDR),
    .HTRANS(HTRANS),
    .HWRITE(HWRITE),
    .HSIZE(HSIZE),
    .HBURST(HBURST),
    .HWDATA(HWDATA),
    .HMASTLOCK(HMASTLOCK),
    .HPROT(HPROT),

    .sram_cen(sram_cen),
    .sram_wen(sram_wen),
    .sram_ben(sram_ben),
    .sram_addr(sram_addr),
    .sram_din(sram_din),
    .sram_dout(sram_dout)
  );

  localparam MEM_SIZE = MAX_INSTR * 4;

  //----------------------------------------
  // AHB Memory Slave
  //----------------------------------------
  MemorySlave #(
    .MEM_SIZE(MEM_SIZE),
    .LATENCY(2)
  ) mem_slave (
    .HCLK(HCLK),
    .HRESETn(HRESETn),
    .HADDR(HADDR),
    .HTRANS(HTRANS),
    .HWRITE(HWRITE),
    .HSIZE(HSIZE),
    .HWDATA(HWDATA),
    .HRDATA(HRDATA),
    .HREADY(HREADY),
    .HRESP(HRESP),
    .HSEL(HSEL),
    .num_instr(num_instr)
  );

  localparam MEM_SIZE = 2**24;

  logic [3:0][7:0] mem [0:MEM_SIZE-1];
  logic [$clog2(MEM_SIZE)-1:0] addr;
  assign addr = sram_addr[$clog2(MEM_SIZE)+1:2];

  always_ff @(posedge HCLK) begin
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

  initial begin
    #1;
    #(num_instr*MEM_SIZE*10);

    for (int i = 4; i < 2**20; i = i + 4) begin
      $display("%d", mem[i/4]);
    end

    $finish;
  end

endmodule
