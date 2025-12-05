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
    output logic  [2:0] HBURST,
    output logic [31:0] HWDATA,
    output logic        HMASTLOCK,
    output logic  [3:0] HPROT
);

    // TCM
    logic        sram_cen;
    logic        sram_wen;
    logic  [3:0] sram_ben;
    logic [31:0] sram_addr;
    logic [31:0] sram_din;
    logic [31:0] sram_dout;

    // Core AHB

    logic        pc_load_id;
    logic        pc_load_ex;
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;
    logic        imem_ready;

    logic        cache_hit;

    SRAM #(
        .DEPTH(256)
    ) sram (
        .clk      (HCLK),
        .sram_cen (sram_cen),
        .sram_wen (sram_wen),
        .sram_ben (sram_ben),
        .sram_addr(sram_addr),
        .sram_din (sram_din),
        .sram_dout(sram_dout)
    );

    RV32E core (
        .clk         (HCLK),
        .rst_n       (HRESETn),
        .boot_addr   (boot_addr),

        // Instruction side
        .pc_load_id  (pc_load_id),
        .pc_load_ex  (pc_load_ex),
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
    instruction_cache_controller #(
        .CACHE_SIZE(1024),
        .BLOCK_SIZE(32)
    ) i_icache (
        // AHB-Lite interface (master port out to memory / interconnect)
        // Interface instantiation
        .HCLK     (HCLK),
        .HRESETn  (HRESETn),

        .HADDR    (HADDR),
        .HTRANS   (HTRANS),
        .HBURST   (HBURST),
        .HSIZE    (HSIZE),
        .HRDATA   (HRDATA),
        .HREADY   (HREADY),
        .HRESP    (HRESP),

        // CPU side — connects to your core’s instruction fetch signals
        .pc_load_id (pc_load_id),
        .pc_load_ex (pc_load_ex),
        .cpu_addr   (imem_addr),
        .cpu_data   (imem_rdata),
        .cpu_ready  (imem_ready),

        .cache_enable (1'b1),     // enable cache always
        .cache_hit    (cache_hit)
    );

    assign HWRITE    = 1'b0;        // Instruction fetch
    assign HMASTLOCK = 1'b0;        // No locks
    assign HPROT     = 4'b1011;

endmodule
