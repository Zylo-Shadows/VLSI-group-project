`timescale 1ns/1ps

module top (
    input  logic        clk,
    input  logic        rst_n,

    // Serial Interface (Bootloading)
    input  logic        serial_rx,
    output logic        serial_tx,
    input  logic        boot_mode,

    // Flash SPI
    output logic        flash_cs_n,
    output logic        flash_sck,
    output logic        flash_mosi,
    input  logic        flash_miso,
    output logic        flash_wp_n,
    output logic        flash_hold_n
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

    logic        pc_load_id;
    logic        pc_load_ex;
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;
    logic        imem_ready;

    logic        cache_hit;

    flash_controller #(
        .FLASH_SIZE(32'h100000),
        .BAUD_RATE(115200),
        .CLK_FREQ(20000000)
    ) i_flash_ctrl (
        .clk(clk),
        .rst_n(rst_n),

        // AHB-Lite Interface
        .haddr(HADDR),
        // .hburst(HBURST),
        .hsize(HSIZE),
        .htrans(HTRANS),
        .hwdata(HWDATA),
        .hwrite(HWRITE),
        .hsel(1'b1),
        .hready_in(1'b1),
        .hrdata(HRDATA),
        .hready_out(HREADY),
        .hresp(HRESP),

        // Serial Interface (Bootloading)
        .serial_rx(serial_rx),
        .serial_tx(serial_tx),
        .boot_mode(boot_mode),

        // Flash SPI
        .flash_cs_n(flash_cs_n),
        .flash_sck(flash_sck),
        .flash_mosi(flash_mosi),
        .flash_miso(flash_miso),
        .flash_wp_n(flash_wp_n),
        .flash_hold_n(flash_hold_n)
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
