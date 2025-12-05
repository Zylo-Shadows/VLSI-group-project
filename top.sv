`timescale 1ns/1ps

module top (
    input  logic        clk,
    input  logic        rst_n,

    // I2C Interface
    input  logic        scl,
    inout  logic        sda
);

    logic [31:0] boot_addr;
    assign boot_addr = 32'h00000000;

    // TCM
    logic        sram_cen;
    logic        sram_wen;
    logic  [3:0] sram_ben;
    logic [31:0] sram_addr;
    logic [31:0] sram_din;
    logic [31:0] sram_dout;

    // AHB-Lite interface
    logic [31:0] HRDATA;
    logic        HREADY;
    logic        HRESP;
    logic [31:0] HADDR;
    logic  [1:0] HTRANS;
    logic        HWRITE;
    logic  [2:0] HSIZE;
    logic  [2:0] HBURST;
    logic [31:0] HWDATA;
    logic        HMASTLOCK;
    logic  [3:0] HPROT;

    // Flash
    logic [23:0] flash_addr;
    logic [31:0] flash_wdata;
    logic [31:0] flash_rdata;
    logic        flash_we;
    logic        flash_oe;
    logic        flash_ce;
    logic        flash_ready;

    logic        pc_load_id;
    logic        pc_load_ex;
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;
    logic        imem_ready;

    logic        cache_hit;

    flash_controller i_flash_ctrl (
        // Clock and Reset
        .clk(clk),
        .rst_n(rst_n),

        // AHB-Lite Interface
        .haddr(HADDR),
        .hburst(HBURST),
        .hmastlock(HMASTLOCK),
        .hprot(HPROT),
        .hsize(HSIZE),
        .htrans(HTRANS),
        .hwdata(HWDATA),
        .hwrite(HWRITE),
        .hsel(1'b1),
        .hready(1'b1),
        .hrdata(HRDATA),
        .hreadyout(HREADY),
        .hresp(HRESP),

        // I2C Interface
        .scl(scl),
        .sda(sda),

        // Flash Memory Interface
        .flash_addr(flash_addr),
        .flash_wdata(flash_wdata),
        .flash_rdata(flash_rdata),
        .flash_we(flash_we),
        .flash_oe(flash_oe),
        .flash_ce(flash_ce),
        .flash_ready(flash_ready)
    );

    flash_stub flash (
        .clk(clk),
        .rst_n(rst_n),
        .cs_n(!flash_ce),
        .we_n(!flash_we),
        .oe_n(!flash_oe),
        .addr(flash_addr),
        .wdata(flash_wdata),
        .rdata(flash_rdata),
        .ready(flash_ready)
    );

    SRAM #(
        .DEPTH(256)
    ) sram (
        .clk      (clk),
        .sram_cen (sram_cen),
        .sram_wen (sram_wen),
        .sram_ben (sram_ben),
        .sram_addr(sram_addr),
        .sram_din (sram_din),
        .sram_dout(sram_dout)
    );

    RV32E core (
        .clk         (clk),
        .rst_n       (rst_n),
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
        .HCLK     (clk),
        .HRESETn  (rst_n),

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
