`timescale 1ns/1ps

module top (
    input  logic        HCLK,
    input  logic        HRESETn,
    input  logic [31:0] boot_addr,

    // AHB-Lite slave interface
    input  logic [31:0] HRDATA,
    input  logic        HREADY,
    input  logic        HRESP,
    output logic [31:0] HADDR,
    output logic  [1:0] HTRANS,
    output logic        HWRITE,
    output logic  [2:0] HSIZE,
    output logic  [3:0] HBURST,
    output logic [31:0] HWDATA,
    output logic        HMASTLOCK,
    output logic  [3:0] HPROT,

    // TCM 
    output logic        sram_cen,
    output logic        sram_wen,
    output logic [3:0]  sram_ben,
    output logic [31:0] sram_addr,
    output logic [31:0] sram_din,
    input  logic [31:0] sram_dout
);

    // Core ↔ TCM connections (data memory)
    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic [31:0] dmem_rdata;
    logic        dmem_read;
    logic        dmem_write;
    logic [1:0]  dmem_size;
    logic        dmem_ready;

    // Core AHB

    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;
    logic        imem_req;
    logic        imem_ready;


    // RV32E Core 

    RV32E core (
        .clk         (HCLK),
        .rst_n       (HRESETn),
        .boot_addr   (boot_addr),

        // Instruction side
        .inst_addr   (imem_addr),
        .instruction (imem_rdata),
        .inst_ready  (imem_ready),

        // Data side (connected to TCM)
        .sram_cen    (sram_cen),
        .sram_wen    (sram_wen),
        .sram_ben    (sram_ben),
        .sram_addr   (sram_addr),
        .sram_din    (sram_din),
        .sram_dout   (sram_dout)
    );

    
    // Instruction cache or AHB bus master
instruction_cache_controller i_icache (
    // AHB-Lite interface (master port out to memory / interconnect)
    .HCLK     (HCLK),
    .HRESETn  (HRESETn),
    .HADDR    (HADDR),
    .HRDATA   (HRDATA),
    .HTRANS   (HTRANS),
    .HREADY   (HREADY),
    .HSIZE    (HSIZE),

    // CPU side — connects to your core’s instruction fetch signals
    .cpu_addr   (imem_addr),
    .cpu_req    (imem_req),
    .cpu_data   (imem_rdata),
    .cpu_ready  (imem_ready),

    
    .cache_enable (1'b1),      // enable cache always
    .cache_flush  (1'b0),      // no flush unless you want to debug
    .cache_hit    (),          // optional monitor
    .cache_miss   ()
);

 // Fixed the AHB signals
    assign HWRITE    = 1'b0;        // Instruction fetch
    assign HMASTLOCK = 1'b0;        // No lockes
    assign HPROT     = 4'b1011;   

endmodule
